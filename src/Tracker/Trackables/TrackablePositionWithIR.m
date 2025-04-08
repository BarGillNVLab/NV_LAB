classdef TrackablePositionWithIR < Trackable % & StageScanner
    %TRACKABLEPOSITION Makes sure that the experiment is still focused on the desired NV center 
    % The class uses a simple algorithm to counter mechanical drift
    % of the stage

    properties (SetAccess = private)
        stepNum = 0;	% int. Steps since beginning of tracking
        currAxis = 1;   % int. Numerical value of currently scanned axis (1 for X, etc.)

        mSignal
        mSignal_ste
        mScanParams     % Object of class StageScanParams, to store current running scan
        stepSize        % nx1 double. Holds the current size of position step
        
        % Tracking options
        initialStepSize
        minimumStepSize
    end
    
    properties % have setters
        mStageName
        mLaserName
        mLaserNameIR
        
        pixelTime
        nMaxIterations
    end
    
    properties (Constant)
        NAME = 'trackablePositionWithIR';

        EVENT_STAGE_CHANGED = 'stageChanged'
        
        % Default properties
        NUM_MAX_ITERATIONS = 30;   % After that many steps, convergence is improbable
        PIXEL_TIME = 1 ;  % in seconds
        
        % vector constants, for [X Y Z]
        INITIAL_STEP_VECTOR = [0.05 0.05 0.1];    %[0.1 0.1 0.05];
        MINIMUM_STEP_VECTOR = [0.02 0.02 0.02]; %[0.01 0.01 0.01];
        STEP_RATIO_VECTOR = [0.5 0.5 0.5];     % Needs to be strictly between 0 and 1
        ZERO_VECTOR = [0 0 0];
        
        HISTORY_FIELDS = {'position', 'step', 'time', 'value', 'ste'}
        
        DEFAULT_CONTINUOUS_TRACKING = false;
        
        OPTIONAL_FIELDS = {'initialStep', 'minimumStep'};
    end
    
    methods (Static)
        function obj = getInstance(stageName)
            % Get stage
            if ~exist('stageName', 'var')
                stage = JsonInfoReader.getDefaultObject('stages');
                stageName = stage.name;
                
                % Obselete code, might be useful in the future:
%                 stages = ClassStage.getScannableStages;
%                 stage = stages{1};
%                 obj.mStageName = stage.NAME;
            end
            
            % Get optional variables
            jsonStruct = JsonInfoReader.getJson();
            if isfield(jsonStruct, 'trackablePosition')
                tpStruct = jsonStruct.trackablePosition;
            else
                tpStruct = struct;  % Empty struct, to be supplemented
            end
            tpStruct = FactoryHelper.supplementStruct(tpStruct, TrackablePosition.OPTIONAL_FIELDS);
            initStep = tpStruct.initialStep;
            minStep = tpStruct.minimumStep;
            
            obj = TrackablePosition(stageName, initStep, minStep);
        end
    end
    
    methods (Access = private)
        function obj = TrackablePositionWithIR(stageName, initStep, minStep)
            obj@Trackable(TrackablePositionWithIR.NAME);
            
            obj.mStageName = stageName;
            stage = getObjByName(stageName);
            if isempty(stage)
                throwBaseObjException(stageName);
            end
            if ~stage.isScannable
                obj.sendError('Can''t create Trackable Position with non-scanning stage!')
            end
            
            % We also need these:
            phAxes = stage.getAxis(stage.availableAxes);
            obj.mScanParams = StageScanParams;
            obj.mLaserName = LaserGate.GREEN_LASER_NAME;
            obj.mLaserNameIR = LaserGate.IR_LASER_NAME;
            
            % Set default tracking properties
            obj.pixelTime = obj.PIXEL_TIME;
            obj.nMaxIterations = obj.NUM_MAX_ITERATIONS;
            
            % Get properties from input, if they exist
            if isempty(initStep); initStep = obj.INITIAL_STEP_VECTOR; end
            obj.initialStepSize = initStep(phAxes);
            if isempty(minStep); minStep = obj.MINIMUM_STEP_VECTOR; end
            obj.minimumStepSize = minStep(phAxes);
            
            obj.shouldAutosave = false;
        end
    end
    
    %% Overridden from Experiment
    methods (Access = protected)
        function prepare(obj)           
            %%%% Initialize %%%%
            obj.resetAlgorithm;
            stage = getObjByName(obj.mStageName);
                if isempty(stage); throwBaseObjException(stageName); end
            
            spcm = getObjByName(Spcm.NAME);
                if isempty(spcm); throwBaseObjException(Spcm.NAME); end
            spcm.setSPCMEnable(true);
            
            laser = getObjByName(obj.mLaserName);
                if isempty(laser); throwBaseObjException(obj.mLaserName); end
            laser.isOn = true;
            
            laserIR = getObjByName(obj.mLaserNameIR);
                if isempty(laserIR); throwBaseObjException(obj.mLaserNameIR); end
            laserIR.isOn = true;
            
            % Check if MW needs to be turned on
            if ~isempty(obj.parent) && isprop(obj.parent, 'mode') && isequal(obj.parent.mode, 'CW')
                if iscell(obj.parent.freqGenName)
                    for i = 1:length(obj.parent.freqGenName)
                        fg = getObjByName(obj.parent.freqGenName{i});
                        if isempty(fg); throwBaseObjException(obj.parent.freqGenName{i}); end
                        fg.amplitude = obj.amplitude(i) - 1.5;
                    end
                else
                    fg = getObjByName(obj.parent.freqGenName);
                    if isempty(fg); throwBaseObjException(obj.parent.freqGenName); end
                    if isscalar(obj.parent.amplitude)
                        fg.amplitude = obj.parent.amplitude - 1.5;
                    end
                end
                mwSwitch = getObjByName('MW');
                mwSwitch.isEnabled = true;
            end
            
            %%%% Get initial position and signal value, for history %%%%
            % Set parameters for scan
            phAxes = stage.getAxis(stage.availableAxes);
            sp = obj.mScanParams;
            sp.fixedPos = stage.Pos(phAxes);
            sp.pixelTime = obj.pixelTime;
            scanner = StageScanner.init;
            if ~ischar(scanner.mStageName) || ~strcmp(scanner.mStageName, obj.mStageName)
                scanner.switchTo(obj.mStageName)
            end
            
            % We are up and running. Now show GUI, so we can actually see
            % what's going on
            gui = GuiControllerTrackablePosition;
            try
                gui.start();
            catch err
                EventStation.anonymousWarning('Tracker window could not open. Continuing tracking nonetheless.');
                err2warning(err);
            end
            
            [obj.mSignal, obj.mSignal_ste] = scanner.scanPoint(stage, spcm, sp);
            if obj.isHistoryEmpty
                obj.recordSessionEnd;     % record starting point (time == 0, index == 1)
            else
                obj.recordCurrentState;
            end
        end
        
        function perform(obj)
            % Execution of at least one iteration is acheived by using
            % {while(true) {statements} if(condition) {break}}
            while true
                obj.HovavAlgorithm;
                obj.recordSessionEnd;
                if ~obj.isRunningContinuously; break; end
                obj.sendEventTrackableExpEnded;
            end
        end 
        
        function dataParam = alternateSignal(obj) %#ok<MANU>
            dataParam = [];
        end
        
        function wrapUp(obj)
            % No analysis required (yet?)
            
            
            % Closes SPCM, laser and MW. Might want to check if they were
            % open before the tracker started.
            
            spcm = getObjByName(Spcm.NAME);
                if isempty(spcm); throwBaseObjException(Spcm.NAME); end
            spcm.setSPCMEnable(false);
            
            laser = getObjByName(obj.mLaserName);
                if isempty(laser); throwBaseObjException(obj.mLaserName); end
            laser.isOn = false;
            
            laserIR = getObjByName(obj.mLaserNameIR);
                if isempty(laserIR); throwBaseObjException(obj.mLaserNameIR); end
            laserIR.isOn = false;
            
            % Check if MW needs to be turned off
            if ~isempty(obj.parent) && isprop(obj.parent, 'mode') && isequal(obj.parent.mode, 'CW')
                if iscell(obj.parent.freqGenName)
                    for i = 1:length(obj.parent.freqGenName)
                        fg = getObjByName(obj.parent.freqGenName{i});
                        if isempty(fg); throwBaseObjException(obj.parent.freqGenName{i}); end
                        fg.amplitude = obj.parent.amplitude(i);
                    end
                else
                    fg = getObjByName(obj.parent.freqGenName);
                    if isempty(fg); throwBaseObjException(obj.parent.freqGenName); end
                    if isscalar(obj.parent.amplitude)
                        fg.amplitude = obj.parent.amplitude;
                    end
                end
                mwSwitch = getObjByName('MW');
                mwSwitch.isEnabled = false;
            end
        end
    end
    
    methods
        function params = getTotalNumberOfParams(obj) %#ok<MANU>
            params = 0;
        end
    end
       
    %% Overridden from Trackable
    methods
        function resetTrack(obj)
            obj.resetAlgorithm;
            obj.timer.reset;
            obj.clearHistory;
        end
        
        function params = getAllTrackalbeParameter(obj) %#ok<MANU>
        % Returns a cell of values/paramters from the trackable experiment
        params = NaN;
        end
        
        function str = textOutput(obj)
            stage = getObjByName(obj.mStageName);
            phAxes = stage.getAxis(stage.availableAxes);
            
            if all(obj.stepSize <= obj.minimumStepSize(phAxes))
                str = sprintf('Local maximum was found in %u steps', obj.stepNum);
            elseif obj.stopFlag
                str = 'Operation terminated by user';
            elseif obj.isDivergent
                str = 'Maximum number of iterations reached without convergence';
            else
                str = 'This shouldn''t have happenned...';
            end
        end
    end
    
    %% setters
    methods
        function set.mStageName(obj, newStageName)
            if ~strcmp(obj.mStageName, newStageName)    % MATLAB doc says this check is done internally, but we don't count on it
                if obj.isCurrentlyTracking
                    obj.sendWarning('Can''t switch stage while tracking. Try again later.')
                else
                    obj.mStageName = newStageName;
                    obj.sendEvent(struct(obj.EVENT_STAGE_CHANGED, true));
                end
            end
        end
        
        function setMinimumStepSize(obj, index, newSize)
            % Allows for vector input
            try
                if length(newSize) ~= length(index)
                    error('Inputs are incompatible. Cannot Complete action.')
                elseif  any (index > length(obj.minimumStepSize)) || any(newSize <= 0)
                    error('Cannot set this step size!')
                elseif any(newSize > obj.initialStepSize(index))
                    error('Minimum step size can''t be larger than the initial step size, or tracking will LITERALLY take forever.')
                elseif any(newSize <= 0)
                    error('There is no point in setting negative step size.')
                end
                obj.minimumStepSize(index) = newSize;
            catch err
                obj.sendError(err.message);
            end
        end
        
        function setInitialStepSize(obj, index, newSize)
            % Allows for vector input
            try
                if length(newSize) ~= length(index)
                    error('Inputs are incompatible. Cannot Complete action.')
                elseif  any (index > length(obj.minimumStepSize)) || any(newSize <= 0)
                    error('Cannot set this step size!')
                elseif any(newSize < obj.minimumStepSize(index))
                    error('Initial step size can''t be smaller than the minimum step size, or tracking will LITERALLY take forever.')
                end
                obj.initialStepSize(index) = newSize;
            catch err
                obj.sendError(err.message);
            end
        end
        
        function set.pixelTime(obj, newTime)
            if ~(newTime > 0)       % False if zero or less, and also if not a number
                obj.sendError('Pixel time must be a positive number');
            end
            obj.pixelTime = newTime;
        end
        
        function set.nMaxIterations(obj, newNum)
            if isnumeric(newNum)
                num = uint32(newNum);
            else
                num = uint32(str2double(newNum));
            end
            
            if num == 0
                errorMsg = sprintf('We don''t allow for %s iterations', newNum);
                obj.sendError(errorMsg);
            elseif num ~= newNum
                obj.sendWarning('Maximum number of iterations was rounded to nearest integer')
            end
                obj.nMaxIterations = num;     
        end
        
    end
        
    methods (Access = private)
        function recordCurrentState(obj)
            record = struct;
            record.position = round(obj.mScanParams.fixedPos, 3);
            record.step = obj.stepSize;
            record.value = obj.mSignal;
            record.ste = obj.mSignal_ste;
            record.time = obj.timer.toc;  % personalized timer
            
            if isempty(obj.mHistory) || ~isequal(rmfield(obj.mHistory{end}, {'step','time'}), rmfield(record, {'step','time'})) % Only save if sometime changed
                obj.mHistory{end+1} = record;
                obj.sendEventTrackableUpdated;
            elseif obj.sessionEnds(end) == length(obj.mHistory)+1 % If we got here at the end, then we need to correct the last point.
                obj.sessionEnds(end) = length(obj.mHistory);
                obj.sendEventTrackableUpdated;
            end
        end
        
        function recordSessionEnd(obj)
            obj.sessionEnds(end+1) = length(obj.mHistory)+1; % Save the index of this point in time
            obj.recordCurrentState;
        end
    end

    %% Scanning algorithms.
    % For now, only one, should include more in the future
    methods
        function HovavAlgorithm(obj)
            % Moves axis-wise (cyclicly) to the direction of the
            % derivative. In other words, this is a simple axis-wise form
            % of gradient ascent.
            stage = getObjByName(obj.mStageName);
            spcm = getObjByName(Spcm.NAME);
            phAxes = stage.getAxis(stage.availableAxes);
            len = length(phAxes);
            scanner = StageScanner.init;
            
            % Initialize scan parameters for search
            sp = obj.mScanParams;
            sp.fixedPos = stage.Pos(phAxes);
            sp.pixelTime = obj.pixelTime;
            
            obj.stepNum = obj.stepNum + 1;   % The first step is always counted
            obj.currIter = obj.stepNum;
            
            while ~obj.stopFlag && any(obj.stepSize > obj.minimumStepSize(phAxes)) && ~obj.isDivergent
                obj.sendEventTrackableUpdated; % Make sure GUI is updated.
                cAxis = obj.currAxis;   % For brevity
                if obj.stepSize(cAxis) > obj.minimumStepSize(cAxis)
                    pos = sp.fixedPos(cAxis);
                    step = obj.stepSize(cAxis);
                    
                    % scan to find forward and backward 'derivative'
                    % backward
                    sp.fixedPos(cAxis) = pos - step;
                    [signals(1), signal_ste(1)] = scanner.scanPoint(stage, spcm, sp);
                    obj.sendEventTrackableUpdated; % Make sure GUI is updated.
                    if obj.stopFlag % Stop and go back to previous place
                        sp.fixedPos(cAxis) = pos;           % Save the last best place, ...
                        stage.move(phAxes, sp.fixedPos);    % and return there
                        break;
                    end
                    
                    % current
                    sp.fixedPos(cAxis) = pos;
                    [signals(2), signal_ste(2)] = scanner.scanPoint(stage, spcm, sp);
                    obj.sendEventTrackableUpdated; % Make sure GUI is updated.
                    if obj.stopFlag % Stop, no need to move because we are already in previous place.
                        break;
                    end
                    
                    % forward
                    sp.fixedPos(cAxis) = pos + step;
                    [signals(3), signal_ste(3)] = scanner.scanPoint(stage, spcm, sp);
                    obj.sendEventTrackableUpdated; % Make sure GUI is updated.
                    if obj.stopFlag
                        % Already finished scanning, so we can continue and
                        % see what is the best place.
                    end
                    
                    shouldMoveBack = (signals(1) - signals(2) > mean(signal_ste(1:2))); % The "back" signal is considerably higher
                    shouldMoveFwd = (signals(3) - signals(2) > mean(signal_ste(2:3)));   % The "fwd" signal is considerably higher
                    
                    shouldContinue = false;
                    if shouldMoveBack
                        if shouldMoveFwd
                            % local minimum; don't move
                            disp('Conflict.... make longer scans?')
                        else
                            % should go back and look for maximum:
                            % prepare for next step
                            newStep = -step;
                            pos = pos + newStep;
                            newSignal = signals(1);   % value @ best position yet
                            newSignal_ste = signal_ste(1);
                            shouldContinue = true;
                        end
                    elseif shouldMoveFwd
                            % should go forward and look for maximum:
                            % prepare for next step
                            newStep = step;
                            pos = pos + newStep;
                            newSignal = signals(3);   % value @ best position yet
                            newSignal_ste = signal_ste(3);
                            shouldContinue = true;
                    else
                        % local maximum or plateau; don't move
                    end
                    sp.fixedPos(cAxis) = pos; % Save best location
                    stage.move(phAxes, sp.fixedPos);
                    
                    while shouldContinue
                        if obj.isDivergent || obj.stopFlag; break; end
                        % we are still iterating; save current position before moving on
                        obj.mSignal = newSignal;    % Save value @ best position yet
                        obj.mSignal_ste = newSignal_ste;
                        obj.recordCurrentState;
                        
                        obj.stepNum = obj.stepNum + 1;
                        obj.currIter = obj.stepNum;
                        % New pos = (pos + step), if you should move forward;
                        %           (pos - step), if you should move backwards
                        pos = pos + newStep;
                        sp.fixedPos(cAxis) = pos;
                        [newSignal, newSignal_ste] = scanner.scanPoint(stage, spcm, sp);
                        obj.sendEventTrackableUpdated; % Make sure GUI is updated.
                        
                        mean_ste = mean([newSignal_ste, obj.mSignal_ste]);
                        shouldContinue = (newSignal - obj.mSignal > mean_ste);
                        
                        if ~shouldContinue
                            % We are about to exit the loop
                            sp.fixedPos(cAxis) = pos - newStep; % Save the last best place, ...
                            stage.move(phAxes, sp.fixedPos);    % and return there
                        end
                    end
                    obj.stepSize(cAxis) = step * obj.STEP_RATIO_VECTOR(cAxis);
                end
                obj.currAxis = mod(cAxis, len) + 1; % Cycle through 1:len
            end
        end
        
        function resetAlgorithm(obj)
            obj.stopFlag = false;
            obj.stepNum = 0;
            obj.currIter = obj.stepNum;
            obj.currAxis = 1;
            
            obj.mSignal = [];
            obj.mScanParams = StageScanParams;
            obj.stepSize = obj.initialStepSize;
        end
        
        function tf = isDivergent(obj)
            % If we arrive at the maximum number of iterations, we assume
            % the tracking sequence will not converge, and we stop it
            tf = (obj.stepNum >= obj.NUM_MAX_ITERATIONS);
        end
        
    end
    
end