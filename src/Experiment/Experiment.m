classdef (Abstract) Experiment < EventSender & EventListener & Savable
    %EXPERIMENT A generic experiment in the lab.
    % Abstract class for creating all other experiments.
    
    properties (Abstract, Constant)
        NAME
    end
    
    properties (Constant, Hidden)
        MAX_VECTOR_LENGTH = 100000;
        
        MIN_TAU = 1e-3;     % in \mus (== 1 ns)
        MAX_TAU = 1e6;      % in \mus
        
        DEFAULT_LAST_DELAY = 10e-2; % in \mus (== 100 ns)
       
    end
    
    properties (Hidden, SetAccess = protected)
        mCategory                   % string. For loading (might change in subclasses)
       
        changeFlag = false;         % logical. True if changes have been made 
                                    % in Experiment parameters, that require
                                    % restarting the experiment
        
        detectionPeriodsPerRepeat   % Int. Indicates the number pf detection periods per repeat
        runsPerPerform              % Int. Indicates the number of times a seqeunce is started per parameter. % Need to change name to runsPerParameter!!!
    end
    
    properties (SetAccess = protected)
        mCurrentXAxisParam          % ExpParameter in charge of axis x (which has name and value)
        topParam                    % Optional ExpParameter, parallel to the x axis parameter
        mCurrentYAxisParam          % ExpParameter in charge of axis y - maybe needed, but usually empty.
        rightParam                  % Optional ExpParameter, parallel to the y axis parameter
        
        signalParam                 % ExpParameter in charge of Experiment (raw) result (which has name and value)
        signalParam2                % ditto, for second optional raw result
        averagesTimeStamp           % matrix of size ('averages'*6), time stamp for each end of an average, format(row): [year,month,day,hour,minute,second] 
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        averages                    % int. Number of measurements to average fromfre
        repeats                     % int. Number of repeats per measurement
        isTracking                  % logical. initialize tracking
        trackThreshhold             % double (between 0 and 1). Change in signal that will start the tracker
        checkGlitchInData = false;  % logical. if true, under processData, we will check for glitches and send an error if needed
        TrackWithIR = 0;            % logical. Track With IR on (created for experiments with singlet readout)
        laserInitializationDuration % laser initialization in pulsed experiments
        shouldAutosave
        detectionDuration           % detection windows, in us
        referenceDetectionDuration	% in us. Detection duration of the reference read
        fixDelays = true;           % logical. Flag for whether the PG should automatically fix delays.
                                    % Default is true.
        lastDelay                   % In part ot the sequences we have delay between the MW segment to the laser and readout.
        summaryData                 % struct with the summary of the data contains in the sequence
        MWChannel   = 'MW';         % The name of the default MW channel, can be changed.
        WindFreakChannels = [1, 0]  % logical. Channel on/off, by default only channel 1 is on.
        countWithLifeTime = false;  % If the setup has lifetime measurement, sum the lifetime counts as the way to count.
        smallDelay = 0;
        
        saveEachAverage = 0;        % if equal 1 saves each experiment signal and reference to a given directory
        selpath = '';               % folder path for saving averages separatly
        balancedMeas = 0;           % logical. true when there is balbnced measurement in the setup - acquisition of the input laser in parallel to the signal
        inputConfig = 'auto';       % When using photodiode and not SPCM, to define the input configuration. options: 'norm', 'diff', or 'auto'. 'auto' mean 'diff' if avaliable and 'norm' otherwise.
        
        % photodiode parameters:
        GIMeas = false;             % logical. true if detection by photodiode and gated integrator. defult is detection by SPCM
        acquisitionDuration = 0.3;  % when using gated integrator - acquisition time of the ADC
        GIresetDuration = 3;        % when using gated integrator - reset time of the Gated integrator
        stabilizationDuration = 1.1;% when using gated integrator - the time between the Gated integrator closed to the acquisition
        restartAverageFlag = false; % if true, delete last average and restart the experiment
        digitizerFullDataAcquisition = false;    % logical. To get full data points from digitizer.
        recordVoltageSpan = false;  % boolean. When true the experiment saves the measured voltage histogram
        voltageHistogram            % struct with the measured voltage histogram
        voltageOffset = [];         % voltage offset point to generate from the DAQ to differential port.   

        % camera properties

        % AWG parameters:
        IQ = struct('IQ_arrays', [], 'clock', 1e9, 'switchWF', true, 'duration', 0.1, 'wfRepeats', -1, 'filename', '', 'function', '', 'useIQ', 0);
        create_triggers
%         IQ.wv_path;             % string array
%         IQ.IQ_arrays; % creating a 2x1x3 matrix. [2,i,j] - 2: I&Q, i: IQ vector length, j: number of segments. if IQ vector length = 1, we will create a constant I&Q with that value.
%         IQ.switchWF; % trigger switching between segments at the end of a segment (1 - switch, 0 - don't switch)
%         IQ.wf_duration = [0.1 0.1 0.1]; % duration can be exact or longer than needed (if duration is shorter, wfRepeats needs to be desired_duration/WF_duration
%         IQ.wfRepeats = [-1 -1 -1]; % number of times to repeat the segment, when -1 run continuesly (CW)
%         IQ.function; % not supported yet, hopefully in the future one can input a function for I and Q to be calculated automatically
    end
    
    properties (SetAccess = protected)
        signal              % double. Measured signal in the experiment (basically, unprocessed)
        sterr               % double. Measured sterr of the signal.
        currIter = 0;       % int. number of current iteration (average)
        currParamIter = 0;  % Counts the current parameters' iteration
    end
    
    properties (Hidden, SetAccess = protected)
        freqGenName = [];   % The name of the FG used in the experiment. Default is empty. Can be a cell array of names.
        givenFG     = [];   % The FG given during initilization.
    end
    
    properties (Hidden, SetAccess = {?Trackable, ?SpcmCounter})
        isRunning = false;          % boolean, used to check if currently running.
        stopFlag = true;
        emergencyStopFlag = false;  % if true, we stop the experiment as soon as possible
        restartFlag = true;         % if true, then starting now the experiment will delete old data
        pausedAverage = false;
    end
    
    properties (Dependent, Access = {?Experiment, ?ViewExperimentPlot}) % Inclusion of ?Experiment gives access to its subclasses
        totalNumberOfParams
        imageSize
    end
    
    % For plotting
    properties (Hidden, Access = {?Experiment, ?ViewExperimentPlot}) % Inclusion of ?Experiment gives access to its subclasses
        gAxes
        isPlotAlternate = false;
        isPlotAlternateAvailable = false;
        parameterName = 'parameters';
        
        % Default values, may be overridden by subclasses
        displayType1 = 'Normal';
        displayType2 = 'Referenced';
    end
    
    properties (Constant)
        PATH_ALL_EXPERIMENTS = sprintf('%sControl code\\%s\\Experiment\\Experiments\\', ...
            PathHelper.getPathToNvLab(), PathHelper.SetupMode);
        PATH_CALIBRATIONS = [Experiment.PATH_ALL_EXPERIMENTS, 'Calibrations\']
        
        EVENT_DATA_UPDATED = 'dataUpdated'                  % when something changed regarding the plot (new data, change in x\y axis, change in x\y labels)
        EVENT_PARAM_ITERATION_DONE = 'paramIterationDone'   % when a small parameter iteration is done (update progress bar)
        EVENT_EXP_RESUMED = 'experimentResumed'             % when the experiment is starting to run
        EVENT_EXP_PAUSED = 'experimentPaused'               % when the experiment stops from running
        EVENT_PLOT_ANALYZE_FIT = 'plot_analyzie_fit'        % when the experiment wants the plot to draw the fitting-function-analysis
        EVENT_PARAM_CHANGED = 'experimentParameterChanged'  % when one of the sequence params \ general params is changed
        
        % Exception handling
        EXCEPTION_ID_NO_EXPERIMENT = 'getExp:noExp';
        EXCEPTION_ID_NOT_CURRENT = 'getExp:notCurrExp';
    end
    
    %% General
    methods
        function sendEventDataUpdated(obj); obj.sendEvent(struct(obj.EVENT_DATA_UPDATED, true)); end
        function sendEventParamIterationDone(obj); obj.sendEvent(struct(obj.EVENT_PARAM_ITERATION_DONE, true)); end
        function sendEventExpResumed(obj); obj.sendEvent(struct(obj.EVENT_EXP_RESUMED, true)); end
        function sendEventExpPaused(obj); obj.sendEvent(struct(obj.EVENT_EXP_PAUSED, true)); end
        function sendEventPlotAnalyzeFit(obj); obj.sendEvent(struct(obj.EVENT_PLOT_ANALYZE_FIT, true)); end
        function sendEventParamChanged(obj); obj.sendEvent(struct(obj.EVENT_PARAM_CHANGED, true)); end
        
        function obj = Experiment(name)
            Setup.init();       % In case no one has done this before
            
            % If we explicitly called the constructor, and did not get it
            % by its name, the old Experiment of this kind will be deleted
            oldObjOrNan = removeObjIfExists(name);
            if isa(oldObjOrNan, 'Experiment')
                oldAxes = oldObjOrNan.gAxes;
                oldObjOrNan.delete();
                fprintf('Creating a new %s Experiment. All of its parameters were reset to default.\n', name)
            end
            
            obj@EventSender(name);
            obj@Savable(name);
            obj@EventListener({Tracker.NAME, StageScanner.NAME, SaveLoadCatExp.NAME});
            
            addBaseObject(obj);
            if exist('oldAxes', 'var')
                obj.gAxes = oldAxes;
            end
            
%             emptyValue = [];
%             emptyUnits = '';
%             obj.mCurrentXAxisParam = ExpParamDoubleVector('X axis', emptyValue, emptyValue, emptyUnits, obj.name);
%             obj.mCurrentYAxisParam = ExpParamDoubleVector('Y axis', emptyValue, emptyValue, emptyUnits, obj.name);
%             obj.signalParam = ExpResultDoubleVector('', emptyValue, emptyValue, emptyUnits, obj.name);
            
            obj.mCategory = Savable.CATEGORY_EXPERIMENTS; % will be overridden in Trackable
            
            obj.isTracking = true;   % Initialize tracking
            obj.trackThreshhold = 0.7;
            obj.shouldAutosave = true;
        end
        
        function cellOfStrings = getAllExpParameterProperties(obj)
            % Get all the property-names of properties from the
            % Experiment object that are from type "ExpParameter"
            allVariableProperties = obj.getAllNonConstProperties();
            isPropExpParam = cellfun(@(x) isa(obj.(x), 'ExpParameter'), allVariableProperties);
            cellOfStrings = allVariableProperties(isPropExpParam);
        end
        
        function robAndPausePrevious(obj, prevExp)
            % Copy parameters from previous experiment
            if isa(prevExp, 'Experiment') && isvalid(prevExp)
                prevExp.pause;
                
                % Get all the ExpParameter's from the previous experiment
                for paramNameCell = prevExp.getAllExpParameterProperties()
                    paramName = paramNameCell{:};
                    if isprop(obj, paramName)
                        % If the current experiment has this property also
                        obj.(paramName) = prevExp.(paramName);
                        obj.(paramName).expName = obj.name;  % expParam, I am (now) your parent!
                    end
                end
                
            else
                obj.sendError('Could not rob previous experiment - since it was not an experiment to begin with')
            end
        end

        function delete(obj) %#ok<INUSD>
            % We don't want to accidently save over current file
            sl = SaveLoad.getInstance(Savable.CATEGORY_EXPERIMENTS);
            sl.clearLocal;
        end
    end
       
    %% Setters
    methods
        function checkDetectionDuration(obj, newVal)
            % Returns an error if property is invalid.
            if ~isnumeric(newVal)
                obj.sendError('detectionDuration must be a number or a vector of numbers')
            end
            if ~all(newVal > 0)
                obj.sendError('DetectionDurations must be strictly positive! Ignoring.')
            end
        end
        
        function checkTimeScalar(obj, newVal)
            if ~isscalar(newVal)
                obj.sendError('Parameter must be a scalar! Ignoring.')
            end
            if ~ValidationHelper.isInBorders(newVal, obj.MIN_TAU, obj.MAX_TAU)
                errMsg = sprintf(...
                    'Parameter must be between %d and %d!', obj.MIN_TAU, obj.MAX_TAU);
                obj.sendError(errMsg);
            end
        end
        function checkPositive(obj, newVal)
            if newVal < 0
                obj.sendError('Parameter must be a positive! Ignoring.')
            end
        end
        
        function checkTimeVector(obj, newVal)
            if ~ValidationHelper.isValidVector(newVal, obj.MAX_VECTOR_LENGTH)
                obj.sendError('Parameter must be a valid vector, and not too long! Ignoring.')
            end
            if ~ValidationHelper.isInBorders(newVal, obj.MIN_TAU, obj.MAX_TAU)
                errMsg = sprintf(...
                    'All values of the parameter must be between %d and %d!', obj.MIN_TAU, obj.MAX_TAU);
                obj.sendError(errMsg);
            end
        end
        
        function checkTimeVectorWithZero(obj, newVal)
            if ~ValidationHelper.isValidVector(newVal, obj.MAX_VECTOR_LENGTH)
                obj.sendError('Parameter must be a valid vector, and not too long! Ignoring.')
            end
            if ~ValidationHelper.isInBorders(newVal, 0, obj.MAX_TAU)
                errMsg = sprintf(...
                    'All values of the parameter must be between %d and %d!', 0, obj.MAX_TAU);
                obj.sendError(errMsg);
            end
        end
        
        function checkTimeVectorOrMatrix(obj, newVal)
            if ~ValidationHelper.isValidVectorOrMatrix(newVal, obj.MAX_VECTOR_LENGTH)
                obj.sendError('Parameter must be a valid vector, and not too long! Ignoring.')
            end
            if ~ValidationHelper.isInBorders(newVal, obj.MIN_TAU, obj.MAX_TAU)
                errMsg = sprintf(...
                    'All values of the parameter must be between %d and %d!', obj.MIN_TAU, obj.MAX_TAU);
                obj.sendError(errMsg);
            end
        end
        
        function checkMaxTime(obj, newVal)
            if ~ValidationHelper.isInBorders(newVal, 0, obj.MAX_TAU)
                errMsg = sprintf(...
                    'Parameter must be between %d and %d!', 0, obj.MAX_TAU);
                obj.sendError(errMsg);
            end
        end
        
        function checkChannels(obj, newVal)
            pg = getObjByName(PulseGenerator.NAME);
            if isempty(pg); throwBaseObjException(PulseGenerator.Name); end
            listOfAvailableChannels = pg.channelNames;
            if ~iscell(newVal)
                newVal = {newVal};
            end
            for i = 1:length(newVal)
                chan = newVal{i};
                if ~contains(chan, listOfAvailableChannels)
                    errMsg = sprintf('Channel %s could not be found! Aborting.', chan);
                    obj.sendError(errMsg)
                end
            end
        end
        
        function checkFrequencyVector(obj, newVal)
            if ~ValidationHelper.isValidVector(newVal, obj.MAX_VECTOR_LENGTH)
                obj.sendError('Frequency must be a valid vector, and not too long! Ignoring.')
            end
        end
        
        function checkFrequencyScalar(obj, newVal)
            if ~isscalar(newVal)
                obj.sendError('Frequency must be scalar')
            end
        end
        
        function checkAmplitude(obj, newVal)
            if ~isscalar(newVal) && length(newVal) > FrequencyGenerator.nChannelsAvailable
                obj.sendError('Invalid number of amplitudes for Experiment! Ignoring.')
            end
        end
        
        function checkAmplitudeVector(obj, newVal)
            if ~ValidationHelper.isValidVector(newVal, obj.MAX_VECTOR_LENGTH)
                obj.sendError('Amplitudes must be a valid vector, and not too long! Ignoring.')
            end
        end

        function checkPhase(obj, newVal)
            if ~isscalar(newVal) && length(newVal) > FrequencyGenerator.nChannelsAvailable
                obj.sendError('Invalid number of amplitudes for Experiment! Ignoring.')
            end
        end
        
        function checkPhaseVector(obj, newVal)
             if ~ValidationHelper.isValidVector(newVal, obj.MAX_VECTOR_LENGTH)
                obj.sendError('Invalid number of amplitudes for Experiment! Ignoring.')
            end
        end

        function checkNumberOfChannels(obj, newVal)
            if ~isscalar(newVal)
                obj.sendError('Number of channels must be scalar!')
            end
            if ~ValidationHelper.isValuePositiveInteger(newVal)
                obj.sendError('Number of channels must be a positive integer!')
            end
            if ~ValidationHelper.isInBorders(newVal, 1, FrequencyGenerator.nChannelsAvailable)
                obj.sendError('Number of channels cannot exceed the number of available channels!')
            end
        end
        
        function checkBoolean(obj, newVal)
            if ~isscalar(newVal)
                obj.sendError('Parameter must be scalar!')
            end
            if ~ValidationHelper.isTrueOrFalse(newVal)
                errMsg = sprintf(...
                    'Parameter must be true or false!');
                obj.sendError(errMsg);
            end
        end
        
        function checkState(obj, newVal)
            if ~all(newVal == 1 || newVal == 0 || newVal == -1)
                errMsg = sprintf(...
                    'Parameter must be 0, +1 or -1!');
                obj.sendError(errMsg);
            end
        end
        
        function checkGreenLaserPower(obj, newVal)
            laser = getObjByName('Green Laser');
            [~, laserParts] = laser.getContollableParts();
            % Now assumes laser changing the first laser part:
            laserPart = laserParts{1};
            if ~ValidationHelper.isInBorders(newVal, laserPart.minValue, laserPart.maxValue)
                obj.sendError('Laser power is out of range!')
            end
        end
        
        function checkMode(obj, newVal)
            switch newVal
                case 'CW'
                case 'pulsed'
                otherwise
                    obj.sendError('Unknown mode! Ignoring.')
            end
        end
        
       
        function set.detectionDuration(obj, newVal)
            % MATLAB setter, that cannot be overridden in subclasses, per
            % MathWorks design. We therefore use checkDetectionDuration(),
            % which can be overridden.
            checkDetectionDuration(obj, newVal);
            % If we got here, then newVal is OK.
            obj.detectionDuration = newVal;
            obj.changeFlag = true;  %#ok<MCSUP> % We need to update the PG
        end
        
        function set.referenceDetectionDuration(obj, newVal)
            % MATLAB setter, that cannot be overridden in subclasses, per
            % MathWorks design. We therefore use checkDetectionDuration(),
            % which can be overridden.
            checkDetectionDuration(obj, newVal);
            % If we got here, then newVal is OK.
            obj.referenceDetectionDuration = newVal;
            obj.changeFlag = true;  %#ok<MCSUP> % We need to update the PG
        end
        
        function set.averages(obj, newVal)
            if ~isscalar(newVal) || ~ValidationHelper.isValuePositiveInteger(newVal)
                obj.sendError('averages must be a positive integer!')
            end
            obj.averages = newVal;
        end
        
        function set.repeats(obj, newVal)
            if ~isscalar(newVal) || ~ValidationHelper.isValuePositiveInteger(newVal)
                obj.sendError('repeats must be a positive integer!')
            end
            obj.repeats = newVal;
            obj.changeFlag = true;  %#ok<MCSUP> % We need to update the PG
        end
        
        function set.laserInitializationDuration(obj ,newVal)	% newVal in microsec
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.laserInitializationDuration = newVal;
            obj.changeFlag = true; %#ok<MCSUP> % We need to update the PG
        end
        
        function set.shouldAutosave(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.shouldAutosave = newVal;
        end
        
        function set.isTracking(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.isTracking = newVal;
        end
        
        function set.trackThreshhold(obj ,newVal)	% newVal between 0 and 1
            if ~isscalar(newVal)
                obj.sendError('trackThreshhold must be a scalar! Ignoring.')
            end
            if ~ValidationHelper.isInBorders(newVal, 0, 1)
                errMsg = sprintf(...
                    'trackThreshhold must be between %d and %d!', 0, 1);
                obj.sendError(errMsg);
            end
            % If we got here, then newVal is OK.
            obj.trackThreshhold = newVal;
        end
        
        function set.TrackWithIR(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.TrackWithIR = newVal;
        end

        function set.fixDelays(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.fixDelays = newVal;
            obj.changeFlag = true;  %#ok<MCSUP> % We need to update the PG
        end
        
        function set.countWithLifeTime(obj, newVal)
            % allows to measure counts from spcm histogram and to access
            % lifetime data or sort counts according to time bins.
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.countWithLifeTime = newVal;
            spcm = getObjByName(Spcm.NAME);
            if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled') %currently available only with the timetagger
                spcm.countWithLifeTime = obj.countWithLifeTime;
            end
            obj.changeFlag = true; %use different method to compute counts
        end
        
        function totalParamNum = get.totalNumberOfParams(obj)
            totalParamNum = getTotalNumberOfParams(obj);
        end

        function size = get.imageSize(obj)
            spcm = getObjByName(Spcm.NAME);
            if spcm.hasCamera
                [~, ~, width, hight] = spcm.camera.getROI;
            else
                width = 1;
                hight = 1;
            end
            size = [width, hight];
        end
    end
    
    %% Running
    methods
        function run(obj)
            %%% Primary function of class. Runs the Experiment.
            
            % This Experiment is running and is therefore the current one.
            obj.getSetCurrentExp(obj.NAME);
            
            % Before we start, we want to initialize all devices
            obj.prepare;
            
            if obj.changeFlag && obj.currIter == 0
                % Since there is no data, we can just restart without
                % asking.
                obj.sendEventParamChanged;
                obj.changeFlag = false;
                obj.restartFlag = true;
            elseif obj.changeFlag
                % We might not be able to continue with the old Experiment,
                % since something critical has changed
                obj.sendEventParamChanged;
                obj.changeFlag = false;
                
                % Dialog box
                strQuestion = sprintf('Critical parameters have been changed!\n Do you want to restart the Experiment?');
                strTitle = 'Parameters changed';
                if QuestionUserYesNo(strTitle, strQuestion)
                    obj.restartFlag = true;
                end
            end
            if obj.restartFlag
                % Resetting data
                obj.reset;
                obj.restartFlag = false;    % If we pause now, it will already be the middle of an experiment, and we want to be able to resume it.
                
                if obj.isTracking
                    tracker = getObjByName(Tracker.NAME);
                    if isempty(tracker); throwBaseObjException(Tracker.Name); end
                    trackablePos = tracker.getTrackable(TrackablePosition.NAME);
                    if ~trackablePos.isHistoryEmpty ...
                            && QuestionUserYesNo('Restart tracking?', 'Do you want to restart tracking?')
                        trackablePos.resetTrack
                    end
                end
            end
            
            % Torn on helmholtz if exist
            h = getObjByName('Helmholtz');
            if ~isempty(h)
                if strcmp(h.helmControl, h.CONTROL_STATE{2})
                    h.output('on');
                    pause(0.5);
                end
            end
            
            % Starting
            GuiControllerExperiment(obj.name).start;
            
            obj.stopFlag = false;
            obj.emergencyStopFlag = false;  % In case we stopped the experiment abruptly
            obj.isRunning = true;
            if obj.currParamIter == obj.totalNumberOfParams
                obj.currParamIter = 0;
            end
            sendEventExpResumed(obj);
            
            first = obj.currIter + 1;	% If we paused and did not restart, this is not 1
            
            for i = first : obj.averages
                obj.currIter = i;
                if obj.currParamIter >= obj.totalNumberOfParams
                    obj.currParamIter = 0;
                end
                try
                    perform(obj);
                    if obj.checkEmergencyStop() && obj.currParamIter < obj.totalNumberOfParams
                        obj.currIter = obj.currIter - 1; % This iteration did not succeed
                        obj.sendWarning('Experiment emergency stop!')
                        break;
                    end
                    if obj.restartAverageFlag
                        obj.currIter = obj.currIter - 1; % This iteration did not succeed
                        obj.clearUncompleteRun;
                        break;
                    end
                    plotResults(obj);
                    obj.averagesTimeStamp(i,:) = clock;
                    sendEventDataUpdated(obj)   % Saves, and maybe other things
                    percentage = i/obj.averages*100;
                    percision = log10(obj.averages);    % Enough percision, according to division result
                    fprintf('%.*f%%\n', percision, percentage)
                    
                    if obj.stopFlag
                        break
                    end

                catch err
                    obj.currIter = obj.currIter - 1; % This iteration did not succeed
                    err2warning(err)
                    break
                end
                if obj.saveEachAverage
                    % for saving each average separately
                    if isempty(obj.selpath)
                        obj.selpath = uigetdir;
                    end
                    average_num = obj.currIter;
                    tempSignal = squeeze(obj.signal(1,:,average_num,:,:));
                    tempRef = squeeze(obj.signal(2,:,average_num,:,:));

                    sigFileName = "signal_Average_" + num2str(average_num)+".mat";
                    refFileName = "reference_Average_" + num2str(average_num)+".mat";
                    fullFilePathSignal = fullfile(obj.selpath, sigFileName);
                    fullFilePathReference = fullfile(obj.selpath, refFileName);
                    save(fullFilePathSignal, 'tempSignal');
                    save(fullFilePathReference, 'tempRef');
                    fprintf('Current signal and reference have been saved');

                end
            end
            if obj.saveEachAverage
                all_avg = squeeze(mean(obj.signal, 3));
                sig_avg = squeeze(all_avg(1,:,:,:));
                ref_avg = squeeze(all_avg(2,:,:,:));
                fullFilePath = fullfile(obj.selpath,{'average_signal.mat'; 'average_reference.mat'});
                save(fullFilePath{1}, 'sig_avg');
                save(fullFilePath{2}, 'ref_avg');
                fprintf('all variables have been saved');
                
            end

            if obj.restartAverageFlag
                obj.restartAverageFlag = false;
                obj.run;
            end

            obj.isRunning = false;
            obj.stopFlag = true;
            obj.wrapUp;
            sendEventExpPaused(obj);
            
            % Torn off helmholtz if exist
            if ~isempty(h)
                if strcmp(h.helmControl, h.CONTROL_STATE{2})
                    h.output('off');
                end
            end
        end
        
        function pause(obj)
            obj.stopFlag = true;
        end
        
        function emergencyStop(obj)
            obj.emergencyStopFlag = true;
            obj.pause;
        end
        
        function stop = checkEmergencyStop(obj)
            drawnow     % Oddly, this causes us to change the value of obj.emergencyStopFlag RIGHT NOW, and not wait for the queue
            stop = obj.emergencyStopFlag;
        end
        
        function restart(obj)
            obj.restartFlag = true;
            obj.changeFlag = false;     % It doesn't matter, since we are restarting anyway
            obj.run;
        end
        
        function clearUncompleteRun(obj)
            switch length(size(obj.signal)) % 1st is meas/ref, last is averages
                case 3 % one parameter
                    obj.signal(:, :, obj.currIter + 1) = 0;
                case 4 % two parameters
                    obj.signal(:, :, :, obj.currIter + 1) = 0;
                case 5 % three parameters
                    obj.signal(:, :, :, :, obj.currIter + 1) = 0;
                otherwise % wtf?
                    obj.sendError('Cannot clear last run');
            end
            obj.currParamIter = 0;
            obj.sendEventParamIterationDone();
        end
        
        function data = getData(obj)
            data = {obj.mCurrentXAxisParam, obj.signalParam, obj.signalParam2};
        end
        
        function data = getAltData(obj)
            altData = obj.alternateSignal();
            data = [{obj.mCurrentXAxisParam}, altData];
        end
        
        function plotSequence(obj, varargin)
            % Plots the sequence, can input an optional axis handle
            obj.prepare();
            pg = getObjByName(PulseGenerator.NAME);
            if isempty(pg); throwBaseObjException(PulseGenerator.Name); end
            axisHandle = pg.plotSequence(varargin{:});
            title(axisHandle, obj.NAME)
        end
        
        function plotDelayedSequence(obj, varargin)
            % Plots the sequence, can input an optional axis handle
            obj.prepare();
            pg = getObjByName(PulseGenerator.NAME);
            if isempty(pg); throwBaseObjException(PulseGenerator.Name); end
            axisHandle = pg.plotDelayedSequence(varargin{:});
            title(axisHandle, sprintf('%s - with delays fixed', obj.NAME));
        end

        function S = getSequence(obj)
            obj.prepare();
            pg = getObjByName(PulseGenerator.NAME);
            S = pg.sequence;
        end

        function loadJsonParams(obj, params, jsonLocation)
            % Loading properties to the experiment from Json file
            % 'params': Cell array of properties to load ({'frequency', 'amplitude'}). 'all' for load all avaliable properties
            % 'jsonLocation': Full address of the json file. With no input, using the file from the address in the 'setupParamsLocation' at 'c\lab'
            if ~exist('params', 'var')
                params = 'all';
            end
            if ~exist('jsonLocation', 'var')
                jsonLocation = '';
            end
            if ~iscell(params); params = {params}; end
            loadedParams = JsonInfoReader.getParams(jsonLocation);
            if ~any(strcmpi(params, 'all'))
                fields = fieldnames(loadedParams);
                for i = 1:length(fields)
                    if ~any(strcmp(fields{i}, params))
                        loadedParams = rmfield(loadedParams, fields{i});
                    end
                end
            end
            obj.loadStateFromStruct(loadedParams);
        end
        
        function saveJsonParams(obj, params, jsonLocation)
            % Write parameters to Json file
            % 'params': Cell array of properties to save ({'frequency', 'amplitude'}). 'all' for save all avaliable properties
            % 'jsonLocation': Full address of the json file. With no input, using the file from the address in the 'setupParamsLocation' at 'c\lab'
            if ~exist('params', 'var')
                params = 'all';
            end
            if ~exist('jsonLocation', 'var')
                jsonLocation = '';
            end
            if ~iscell(params); params = {params}; end
            if any(strcmpi(params, 'all'))
                params = properties(obj);
            end
            paramsStruct = struct;
            for i = 1:length(params)
                if isprop(obj, params{i})
                    paramsStruct.(params{i}) = obj.(params{i});
                end
            end
            JsonInfoReader.setParams(paramsStruct, jsonLocation);
        end

        function checkDetectinDuration(obj)
            spcm = getObjByName(Spcm.NAME);
            if isempty(spcm); throwBaseObjException(Spcm.Name); end
            if spcm.hasCamera
                obj.isTracking = false;
                detectiontime = obj.detectionDuration;
                referencetime = obj.referenceDetectionDuration;
                exposuretime = spcm.camera.imgparams.exposuretime;
                if exposuretime > detectiontime
                    obj.detectionDuration = exposuretime; %should be in microseconds
                    fprintf('Detection duration has been set to %d milliseconds\n', obj.detectionDuration/1000);
                end
                if exposuretime > referencetime
                    obj.referenceDetectionDuration = exposuretime; %should be in microseconds
                    fprintf('Reference duration has been set to %d milliseconds\n', obj.referenceDetectionDuration/ 1000);
                end
            end
        end
        
    end
    
    %% Defining the Experiment; to be overridden
    methods (Abstract, Access = protected)
        % Specifics of each of the experiments
        
        prepare(obj) 
        % Initialize devices (SPCM, PulseGenerator, etc.)
        
        perform(obj)
        % Perform the main part of the experiment.
        
        wrapUp(obj)
        % Closes everything
        
        alternateSignal(obj)
        % Returns alternate view of the data, ExpParam (yParam), if 
        % possible. If not, it returns an empty variable.
        % Can return a cell array ExpParams. If it is a cell array, then
        % the last cell is a cell of strings which indiciates what are the
        % ExpParams - Options: {'yParam', 'yParam2', 'yParam2+', 'xParam'}
        % Do not use both 'yParam2' and 'yParam2+'.
        % More can be added as needed.
    end
        
    %% Plotting
    methods
        function addGraphicAxes(obj, gAxes)
            % "Setter" for the axes, when they are created in the GUI
            if ~(isgraphics(gAxes) && isvalid(gAxes))
                obj.sendWarning('Graphic Axes were not created. Plotting is unavailable');
                return
            end
            obj.gAxes = gAxes;
        end

        function checkGraphicAxes(obj)
            if  ~isempty(obj.gAxes) && ~(isgraphics(obj.gAxes) && isvalid(obj.gAxes))
                % gAxes are no longer available, so we discard them
                obj.gAxes = [];
            end
        end
    end
    
    methods (Access = private)
        function savePlot(obj, folder, filename)
            % Saves the plot from the Experiment as .png and .fig files
            
            if ~strcmp(obj.NAME, obj.current)
                % We only save the current Experiment
                return
            end
            
            if isempty(obj.gAxes)
                return % Nothing to do here
                % todo: Maybe we want to plot and then save, whatever happens?
            end
            
            % Only save non empty experiments
            if obj.currIter == 0
                return
            end
            
            %%% Copy axes to an invisible figure
            figureInvis = AxesHelper.copyToNewFigure(obj.gAxes);
            
            %%% Get name for saving
            filename = PathHelper.removeDotSuffix(filename);
            fullpath = PathHelper.joinToFullPath(folder, filename);
            
            %%% Save image (.png)
            fullPathImage = [fullpath '.' ImageScanResult.IMAGE_FILE_SUFFIX];
            saveas(figureInvis, fullPathImage);
            
            %%% Save figure (.fig)
            % The figure is saved as invisible, but we set its creation
            % function to set it as visible
            set(figureInvis, 'CreateFcn', 'set(gcbo, ''Visible'', ''on'')'); % No other methods of specifying the function seemed to work...
            savefig(figureInvis, fullpath)
            
            %%% close the figure
            close(figureInvis);
        end
        
        function n = nDim(obj)
            % Helper function, to tell whether the experiment is 1D or 2D
            yAxisExists = ~isempty(obj.mCurrentYAxisParam) && ~isempty(obj.mCurrentYAxisParam.value);
            n = BooleanHelper.ifTrueElse(yAxisExists, 2, 1);
        end
    end
    
    methods (Access = {?Experiment, ?ViewExperimentPlot}) % Inclusion of ?Experiment gives access to its subclasses
        function plotResultsWhenSwitchingViews(obj)
            delete(obj.gAxes.Children); % Need to delete old plot incase axes changed
            
            % If in the middle of run, and in the middle of average, then
            % look at previous index because current one is not finished.
            if obj.currParamIter > 0 && obj.currParamIter < obj.totalNumberOfParams && obj.isRunning
                obj.currIter = obj.currIter - 1;
            end
            plotResults(obj)
            if obj.currParamIter > 0 && obj.currParamIter < obj.totalNumberOfParams && obj.isRunning
                obj.currIter = obj.currIter + 1; % And change it back
            end
        end
        
        function plotResults(obj)
            % Plots the data in axes inside ViewExperimentPlot. Can be
            % overridden to allow for special kinds of plots, when an
            % Experiment requires that.
            
            obj.checkGraphicAxes();
            if isempty(obj.gAxes)
                return
            end
            isImageData = prod(obj.imageSize) > 1;

            % Check whether we have an alternate plot
            if obj.isPlotAlternate && obj.currIter > 0
                params = obj.alternateSignal();
                if iscell(params) % Check if there are multiple params
                    paramsLegend = params{end};
                    if length(paramsLegend) ~= length(params) - 1
                        obj.sendError('Incorrect alternate plot format');
                    end
                    for i = 1:length(paramsLegend) % If so, then load them according to the legend
                        switch paramsLegend{i}
                            case 'yParam'
                                dataParam = params{i};
                            case 'yParam2'
                                dataParam2Plus = params{i};
                            case 'yParam2+'
                                dataParam2Plus = params{i};
                            case 'xParam'
                                xAxisParam = params{i};
                            otherwise
                                obj.sendError('Incorrect alternate plot format');
                        end
                        if ~exist('xAxisParam', 'var')
                            xAxisParam = obj.mCurrentXAxisParam;
                        end
                    end
                else % If there is only one param, then it is data param and the x axis is normal
                    dataParam = params;
                    xAxisParam = obj.mCurrentXAxisParam;
                end
            else % We are not in alternate plot, but there is something to plot
                dataParam = obj.signalParam;
                if isa(obj.signalParam2, 'ExpParameter') && ~isempty(obj.signalParam2.value) % Check if we have a second signal to plot over the first
                    dataParam2Plus = obj.signalParam2;
                end
                xAxisParam = obj.mCurrentXAxisParam;
            end
            
            if isempty(dataParam)
                % Default plot
                dataParam = ExpResultDoubleVector('', [], [], '', obj.NAME);
            end
            data = dataParam.value;
            err = dataParam.sterr;
            if isImageData; data = mean(mean(data, ndims(data)), ndims(data)-1); end
            if isImageData; err = sqrt(sum(sum(err.^2, ndims(err)), ndims(err)-1)) / prod(obj.imageSize); end
            
            if isempty(data) || all(all(isnan(data)))
                % Default plot
                data = AxesHelper.DEFAULT_Y;
                err = [];
            end
            
            d = obj.nDim;
            
            firstAxisVector = xAxisParam.value;
            if d == 2
                secondAxisVector = obj.mCurrentYAxisParam.value; % Just in case we need it
            else
                secondAxisVector = [];
            end
            
            if isempty(obj.gAxes.Children)
                % Nothing is plotted yet
                bottomLabel = xAxisParam.label;
                switch d
                    case 1
                        leftLabel = dataParam.label;
                        AxesHelper.fill(obj.gAxes, data, d, ...
                            firstAxisVector, [], bottomLabel, leftLabel, err);
                    case 2
                        leftLabel = obj.mCurrentYAxisParam.label;
                        datalabel = dataParam.label;
                        AxesHelper.fill(obj.gAxes, data, d, ...
                            firstAxisVector, secondAxisVector, bottomLabel, leftLabel, err, datalabel);
                    otherwise
                        error('This shouldn''t have happenned!')
                end
                
                % Maybe this experiment shows more than one x/y-axis
                if ~isempty(obj.topParam)
                    AxesHelper.addAxisAcross(obj.gAxes, 'x', ...
                        obj.topParam.value, ...
                        obj.topParam.label);
                end
                if ~isempty(obj.rightParam)
                    AxesHelper.addAxisAcross(obj.gAxes, 'y', ...
                        obj.rightParam.value, ...
                        obj.rightParam.label);
                end
            else
                switch d
                    case 1
                        AxesHelper.update(obj.gAxes, data, d, firstAxisVector, [], err)
                    case 2
                        AxesHelper.update(obj.gAxes, data, d, firstAxisVector, secondAxisVector, err)
                end
            end
            
            if exist('dataParam2Plus', 'var') && ~isempty(dataParam2Plus)
                % If there is more than one signal (Y) parameter, we want
                % to plot it above the first one.
                
                legendForPlot = cell(1, length(dataParam2Plus) + 1);
                legendForPlot{1} = dataParam.desc; % 
                
                if iscell(dataParam2Plus)
                    % There is more then one extra parameter
                    for i = 1:length(dataParam2Plus)
                        data = dataParam2Plus{i}.value;
                        err = dataParam2Plus{i}.sterr;
                        if isImageData; data = mean(mean(data, ndims(data)), ndims(data)-1); end
                        if isImageData; err = sqrt(sum(sum(err.^2, ndims(err)), ndims(err)-1)) / prod(obj.imageSize); end
                        AxesHelper.add(obj.gAxes, data, firstAxisVector, err)
                        legendForPlot{i+1} = dataParam2Plus{i}.desc;
                    end
                else
                    data = dataParam2Plus.value;
                    err = dataParam2Plus.sterr;
                    if isImageData; data = mean(mean(data, ndims(data)), ndims(data)-1); end
                    if isImageData; err = sqrt(sum(sum(err.^2, ndims(err)), ndims(err)-1)) / prod(obj.imageSize); end
                    AxesHelper.add(obj.gAxes, data, firstAxisVector, err)
                    legendForPlot{2} = dataParam2Plus.desc;
                end
            end
            if exist('legendForPlot', 'var') && ~all(cellfun(@(x) isempty(x), legendForPlot)) % Only add legend if there is something to add.
                legend(obj.gAxes, legendForPlot);
            else
                legend(obj.gAxes, 'off')
            end
            
            obj.summaryData.x = xAxisParam.value;
            obj.summaryData.y = data';
            obj.summaryData.err = err';
            
        end
    end
    
    %% Overridden from EventListener
    methods
        % When events happen, this function jumps.
        % Event is the event sent from the EventSender
        function onEvent(obj, event)
            if strcmp(event.creator.name, SaveLoadCatExp.NAME) ...
                    && isfield(event.extraInfo, SaveLoad.EVENT_SAVE_SUCCESS_LOCAL_TO_FILE) ...
                    
                folder = event.extraInfo.(SaveLoad.EVENT_FOLDER);
                filename = event.extraInfo.(SaveLoad.EVENT_FILENAME);
                obj.savePlot(folder, filename);
                return
            end
            
            if isfield(event.extraInfo, StageScanner.EVENT_SCAN_STARTED)
                obj.pause;
            end
        end
    end
    
    
    %% Overridden from Savable
    methods (Access = protected)
        function outStruct = saveStateAsStruct(obj, category, type)
            % Saves the state as struct. If you want to save stuff, make
            % (outStruct = struct;) and put stuff inside. If you don't
            % want to save now, make (outStruct = NaN;)
            %
            % category - string. Some objects saves themself only with
            %                    specific category (image/experiments/etc.)
            % type - string.     Whether the objects saves at the beginning
            %                    of the run (parameter) or at its end (result)
            
            % We should save if either:
            %   @ This is the current Experiment
            %   @ This is a trackable
            shouldSave = (strcmp(category, Savable.CATEGORY_EXPERIMENTS) && strcmp(obj.NAME, obj.current)) ...
                || strcmp(category, Savable.CATEGORY_TRACKER);
            
            if shouldSave
                     % We only save the current Experiment
                if strcmp(type, Savable.TYPE_PARAMS)
                    outStruct = obj.saveParamsToStruct;     % Has default implementation. Might be overidden by subclasses.
                    outStruct.expName = obj.name;
                else
                    outStruct = obj.saveResultsToStruct;    % Has default implementation. Might be overidden by subclasses.
                end
            else
                outStruct = NaN;
            end
            
        end
        
        function loadStateFromStruct(obj, savedStruct, category, subCategory) %#ok<INUSD>
            % loads the state from a struct.
            % to support older versoins, always check for a value in the
            % struct before using it. view example in the first line.
            % category - a string, some savable objects will load stuff
            %            only for the 'image_lasers' category and not for
            %            'image_stages' category, for example
            % subCategory - string. could be empty string
            if ~exist('category', 'var')
                category = 'experiments';
            end

            % mCategory is overrided by Tracker, and we need to check it
            if ~strcmp(category, obj.mCategory); return; end
                
            for paramNameCell = obj.getAllNonConstProperties()
                paramName = paramNameCell{:};
                if isfield(savedStruct, paramName)
                    % If the current experiment has this property also
                    try
                        obj.(paramName) = savedStruct.(paramName);
                    catch
                    end
                end
            end
            obj.changeFlag = true;
        end
        
        function string = returnReadableString(obj, savedStruct) %#ok<INUSD>
            % return a readable string to be shown. if this object
            % doesn't need a readable string, make (string = NaN;) or
            % (string = '');
            
            string = NaN;
        end
    end
    
    %% Default saving options for Experiment. Might be overridden by subclasses
    methods
        function outStruct = saveParamsToStruct(obj)
            for paramNameCell = obj.getAllNonConstProperties()
                paramName = paramNameCell{:};
                outStruct.(paramName) = obj.(paramName);
            end
        end
        
        function outStruct = saveResultsToStruct(obj)
            outStruct = obj.saveParamsToStruct;
        end
    end
    
    %% Helper functions
    methods (Static, Access = protected)
        function s = getRawData(pg, spcm)
            if spcm.hasPhotodiode || spcm.hasCamera; spcm.startExperimentCount; end
            pg.run;
            s = spcm.readFromExperiment;
            if spcm.hasPhotodiode || spcm.hasCamera; spcm.stopExperimentCount; end
            if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled'); spcm.stopExperimentCount; end
        end
        
        function name = getFgName(FG)
            % Get name of relevant frequency generator.
            
            if nargin == 0 || isempty(FG)
                % No input -- we take the default FG
                name = FrequencyGenerator.getDefaultFgName;
            elseif iscell(FG) % If it is a cell, works recursivly and return a cell array of names
                name = cell(1, length(FG));
                for i = 1:length(FG)
                    name{i} = obj.getFgName(FG{i});
                end
            elseif ischar(FG)
                FgObj = getObjByName(FG);
                if isempty(FgObj)
                    throwBaseObjException(FG)
                else
                    name = FG;
                end
            elseif isa(FG, 'FrequencyGenerator')
                name = FG.name;
            else
                EventStation.anonymousError('Sorry, but a %s is not a Frequency Generator...', class(FG))
            end
        end
    end
    
    methods (Access = protected)
        function [signal, sterr] = processData(obj, rawData)
            kc = 1e3;     % kilocounts
            musec = 1e-6;   % microseconds
            
            if isrow(rawData); rawData = rawData'; end
            n = obj.repeats;
            m = size(rawData, 1)/n;
            M = obj.imageSize(1);
            N = obj.imageSize(2);

            % added by rotem 18.4.21 %
            if mod(10,m)
                if ~obj.digitizerFullDataAcquisition
                    m = obj.detectionPeriodsPerRepeat;
                    n = floor(size(rawData, 1)/m);
                    rawData = rawData(1:m*n);
                end
            end
            
            s = reshape(rawData, [m, n, M, N]);
            s = permute(s, [2, 1, 3, 4]);
            
            timeNormalization = [obj.detectionDuration obj.referenceDetectionDuration]*musec;
            if isprop(obj, 'weakDetectionDuration') timeNormalization = [obj.weakDetectionDuration(obj.param_idx) obj.detectionDuration obj.referenceDetectionDuration]*musec; end;
            if isprop(obj, 'changeDetectionDuration') if obj.changeDetectionDuration timeNormalization = [obj.tau(obj.param_idx) obj.referenceDetectionDuration]*musec; end; end;

            if length(timeNormalization) ~= m &&  length(timeNormalization) > 1
                if length(timeNormalization) == m/2
                    timeNormalization = [timeNormalization timeNormalization]; % There are two copies of the data, happens when there is double measurement!
                elseif mod(m, 2) == 0 % There are multiple copies! Even more than double measurement
                    timeNormalization = repmat(timeNormalization, 1, m/2);
                else
                    error('Incomptiable data structure');
                end
            end

            if obj.checkGlitchInData
                s = obj.checkGlitchInRawData(rawData, s);
            end

            spcm = getObjByName(Spcm.NAME);
            start = BooleanHelper.ifTrueElse(n > 10, 2, 1);     % removing the first repeat because the first detection is not after init sequence. Yachel 08.05.22
            if spcm.hasPhotodiode
                % normalization of the signal before avarage, to reduce low frequency noise. Yachel 03/25
                refSignal = s(:, 1:2:end, :, :) ./ s(:, 2:2:end, :, :);
                ref = mean(s(start:end, 2:2:end, :, :), 1, "omitnan");
                s(:, 1:2:end, :, :) = ref .* refSignal;
                s(:, 2:2:end, :, :) = ref +  refSignal * 0;
            end

            signal = mean(s(start:end, :, :, :), 1, "omitnan");                  % "omitnan" to ignore bad repeat and not throw all this point. added by yachel 23.07.23
            sterr = ste(s(start:end, :, :, :), 0, 1);

            if ~spcm.hasPhotodiode && ~spcm.hasCamera
                signal = signal./timeNormalization/kc;      %kcounts per second
                sterr = sterr./timeNormalization/kc;        % convert to kcps
            else
                if spcm.hasGatedIntegrator
                    timeNormalization = timeNormalization / musec;
                    signal = signal./timeNormalization./spcm.GIgain; %kcounts per second
                    sterr = sterr./timeNormalization./spcm.GIgain; % convert to kcps
                end
            end

            if obj.digitizerFullDataAcquisition
                d = obj.detectionPeriodsPerRepeat;
                signal = reshape(signal, d, m/d, M, N);
                sterr = reshape(sterr, d, m/d, M, N);
            end
        end

        function s = checkGlitchInRawData(obj, rawData, s)
            spcm = getObjByName(Spcm.NAME);
            if ~spcm.hasPhotodiode
                if obj.referenceDetectionDuration > 2*obj.detectionDuration % Makes sure that the reference is much longer than the detection duration. Also checks that there is a reference.
                    for i = 1:M
                        for j = 1:N
                            sTwoColumns = reshape(rawData(:,:,i,j), 2, size(rawData,1)/2)';
                            % We want to average enough of S & Ref such that they will
                            % be 3 sigma apart: k*R - 4*sqrt(k*R) > k*S + 4*sqrt(k*S).
                            % k is the number os terms we are averaging and R * S are
                            % the means for the reference and signal.
                            % We assume that at least k*R is normally distrubuted,
                            % which means k*R > 20.
                            % This leads to a quadrtic equation with the solution
                            % k = 16 * (sqrt(R) + sqrt(S))^2 ./ (R-S)^2.
                            %                 if any(sTwoColumns(:,1) > sTwoColumns(:,2));
                            %                     any(sTwoColumns(:,1) > sTwoColumns(:,2))
                            %                 end
                            meanS = mean(sTwoColumns(:,1));
                            meanRef = mean(sTwoColumns(:,2));
                            k = ceil(16 * (sqrt(meanRef) + sqrt(meanS))^2 / (meanRef-meanS)^2);

                            % If there was a glitch, then the meanS and meanRef are
                            % wrong! This gives a bound for 4 sigma.
                            sumBoth = (meanS+meanRef);
                            MeanSTheory = sumBoth * obj.detectionDuration / (obj.detectionDuration + obj.referenceDetectionDuration);
                            MeanRefTheory = sumBoth * obj.referenceDetectionDuration / (obj.detectionDuration + obj.referenceDetectionDuration);
                            maxK = ceil(25 * (sqrt(MeanRefTheory) + sqrt(MeanSTheory))^2 / (MeanRefTheory-MeanSTheory)^2);

                            k = min(k, maxK);
                            smoothedS = movmean(sTwoColumns, k, 1);
                            if any(smoothedS(:, 1) > smoothedS(:, 2))
                                glitchesIndices = smoothedS(:, 1) > smoothedS(:, 2);
                                numOfGlitches = sum(abs(diff(glitchesIndices)));
                                if k > 5
                                    %                         obj.sendWarning(sprintf('Voodoo ground glitch detected %.2f%% of the times, total of %d :o', 100*numOfGlitches/length(sTwoColumns), numOfGlitches));
                                    obj.sendError(sprintf('Voodoo ground glitch detected %.2f%% of the times, total of %d :o', 100*numOfGlitches/length(sTwoColumns), numOfGlitches));
                                else
                                    sTwoColumns(glitchesIndices, :) = fliplr(sTwoColumns(glitchesIndices, :));
                                    s(:,:,i,j) = (reshape(sTwoColumns', m, n))';
                                    obj.sendWarning(sprintf('Voodoo ground glitch detected (and fixed!) %.2f%% of the times, total of %d :o', 100*numOfGlitches/length(sTwoColumns), numOfGlitches));
                                end
                            end
                        end
                    end
                end
            else
                start = BooleanHelper.ifTrueElse(size(s,1) > 10, 2, 1);
                sig = mean(s(start:end, :, :, :), 1, "omitnan");           
                sigma = std(s(start:end, :, :, :), 0, 1, "omitnan");
                glitchesIndices = abs(s - sig) > 4*sigma;
                glitchesIndices = any(glitchesIndices, 2);
                s(glitchesIndices, :, :, :) = nan;
            end
        end
        
        function [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr)
            % Calculates the mean and standard error of the ratio of two
            % normal disributions. This is an approximation of the Ratio
            % Distribution to a Normal Distribution. See wikipedia, or
            % lablog:
            % https://en.wikipedia.org/wiki/Ratio_distribution#Uncorrelated_noncentral_normal_ratio
            % http://www.bargilllab.com/lablog/2017/05/14/attempting-to-better-extract-coherence-curves/
            M = obj.imageSize(1);
            N = obj.imageSize(2);

            if obj.currIter == 1
                % Nothing to calculate the mean over
                value = S1./S2;
                S1mean = S1;
                S2mean = S2;
            else
                dataSize = size(S1);
                dim = length(dataSize) -(M>1)-(N>1);
                if dim > 2
                    S1 = reshape(S1, [], dataSize(end-(M>1)-(N>1)));
                    S2 = reshape(S2, [], dataSize(end-(M>1)-(N>1)));
                    S1sterr = reshape(S1sterr, [], dataSize(end-(M>1)-(N>1)));
                    S2sterr = reshape(S2sterr, [], dataSize(end-(M>1)-(N>1)));
                end
                value = mean(S1./S2, 2, "omitnan");
                S1mean = mean(S1, 2, "omitnan");
                S2mean = mean(S2, 2, "omitnan");
                S1sterr = obj.getCombinedSterr(S1, S1sterr);
                S2sterr = obj.getCombinedSterr(S2, S2sterr);
                if dim > 2
                    sz = 1:length(dataSize);
                    imageDim = BooleanHelper.ifTrueElse(M > 1, sz(end-1:end), []);
                    dataSize = dataSize([1:end-1-(M>1)-(N>1), imageDim]);
                    value = reshape(value, dataSize);
                    S1mean = reshape(S1mean, dataSize);
                    S2mean = reshape(S2mean, dataSize);
                    S1sterr = reshape(S1sterr, dataSize);
                    S2sterr = reshape(S2sterr, dataSize);
                end
            end
            sterr = (S1mean./S2mean).*sqrt(S1sterr.^2./S1mean.^2 + S2sterr.^2./S2mean.^2);
        end
        
        function sterr = getCombinedSterr(obj, means, sterrs)
            % Calculate the combined standard error when combining the data
            % coming from several normal distribution. Formula taken from:
            % https://math.stackexchange.com/questions/2971315/how-do-i-combine-standard-deviations-of-two-groups
            % Note that it was adjusted for standard error (and not
            % deviation), and runs iteratively.
            m = obj.repeats;
            meanSoFar = means(:,1,:,:);
            sterrSoFar = sterrs(:,1,:,:);
            for i = 2:size(means, 2)
                n = m * (i-1);
                meanSoFar = ((i-2)*meanSoFar+means(:,i-1,:,:))/(i-1);
                sterrSoFar = sqrt(((n*(n-1)*sterrSoFar.^2)+(m*(m-1)*sterrs(:,i,:,:).^2))./((n+m)*(n+m-1)) + n*m*(meanSoFar-means(:,i,:,:)).^2 ./ ((n+m)^2*(n+m-1)));
            end
            sterr = sterrSoFar;
        end
        
        function reset(obj)
            % All Experiments need this.
            M = obj.imageSize(1);
            N = obj.imageSize(2);
            obj.signal = zeros(obj.detectionPeriodsPerRepeat * obj.runsPerPerform, obj.getTotalNumberOfParams, obj.averages, M, N);
            obj.sterr = zeros(obj.detectionPeriodsPerRepeat * obj.runsPerPerform, obj.getTotalNumberOfParams, obj.averages, M, N);
            
            obj.signalParam.value = [];
            obj.signalParam2.value = [];
            obj.signalParam.sterr = [];
            obj.signalParam2.sterr = [];
            obj.currIter = 0;
            obj.currParamIter = 0;
            obj.averagesTimeStamp = zeros(obj.averages, 6);
            obj.plotResults;     % Update the plot
            
            %clear the timetagger measurement if it exists - added by rotem 18.4.21
            spcm = getObjByName(Spcm.NAME);
            if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
               spcm.clearExperimentRead();
            end
            
            % Inform user
            pg = getObjByName(PulseGenerator.NAME);
            if isempty(pg); throwBaseObjException(PulseGenerator.Name); end
            seqTime = pg.sequenceDuration() * 1e-6; % Multiplication in 1e-6 is for converting usecs to secs.
            
            nRepeatsRuns = obj.getTotalNumberOfParams * obj.runsPerPerform;
            averageTime = obj.repeats * seqTime * nRepeatsRuns;
            if averageTime < 60 % Less than a minute
                fprintf('Starting %d averages with each average taking %.1f seconds, on average.\n', ...
                    obj.averages, averageTime);
            elseif averageTime < 3600 % Less than an hour
                fprintf('Starting %d averages with each average taking %d minutes & %d seconds, on average.\n', ...
                    obj.averages, floor(averageTime/60), round(mod(averageTime, 60)));
            else % More than an hour
                fprintf('Starting %d averages with each average taking %d hours & %d minutes, on average.\n', ...
                    obj.averages, floor(averageTime/3600), round(mod(averageTime, 3600)/60));
            end
        end
        
        function wrapUpInternal(obj)
            % Things that need to happen when the experiment is done (that
            % all experiments need):
            % Stops the SPCM, disconnects the FG
            
            spcm = getObjByName(Spcm.NAME);
            spcm.setSPCMEnable(false);
            spcm.stopExperimentCount;
            if spcm.hasCamera    
                spcm.returnToDefault;
            end
            if spcm.hasGatedIntegrator()
                spcm.detectionWithGI = 0;
            end
            if spcm.hasPhotodiode
                if obj.recordVoltageSpan 
                    obj.voltageHistogram = spcm.voltageHistogram;
                end
            end

            % Disconnect FrequencyGenerator
            if ~isempty(obj.freqGenName)
                if iscell(obj.freqGenName)
                    for i = 1:length(obj.freqGenName)
                        fg = getObjByName(obj.freqGenName{i});
                        if ~fg.keepOn
                            fg.output = false(1,fg.numChannels);
                        end
                        fg.disconnect;
                        if isa(fg, 'FrequencyGeneratorSGT100A')
                            fg.disconnectIQ(fg);
                        end
                    end
                else
                    fg = getObjByName(obj.freqGenName);
                    if ~fg.keepOn
                        fg.output = false;
                    end
                    fg.disconnect;
                    if isa(fg, 'FrequencyGeneratorSGT100A')
                        fg.disconnectIQ(fg);
                    end
                end
            end
        end
        
        function prepareInternal(obj, S)
            % Things to do when experiment is starting (that all
            % experiments need):
            % Prepare the SPCM, FG and PG
            % the spcm is instanced because we need to make changes for the
            % case of a camera
            % S is the sequence which is loaded into the PG
            
            % Send to PulseGenerator
            pg = getObjByName(PulseGenerator.NAME);
            if isempty(pg); throwBaseObjException(PulseGenerator.Name); end
            % Initialize SPCM
            spcm = getObjByName(Spcm.NAME);
            if isempty(spcm); throwBaseObjException(Spcm.Name); end
            if spcm.hasCamera
                delay = spcm.camera.DELAY_BETWEEN_TRIGGERS;
                S.addDelayAfterDetection(delay, 'greenLaser');
            end

           
            try
                pg.setSequence(S);
            catch err
                if (strcmp(err.message, 'Channel I could not be found! Aborting.') || ...
                        strcmp(err.message, 'Channel Q could not be found! Aborting.')) && ...
                        isprop(obj, 'useIQ')
                    obj.sendWarning('IQ channels not found, changing "useIQ" to false');
                    obj.useIQ = false;
                    obj.prepare();
                    obj.changeFlag = false; % To counter the change from useIQ
                    return
                end
                rethrow(err);
            end
            pg.repeats = obj.repeats;
            pg.fixDelays = obj.fixDelays;

            % change pulses to trigger if neccesary
            fgCell = FrequencyGenerator.getFG();
            fg_names = cellfun(@(c) c.name, fgCell, 'UniformOutput', false);
            if exist('fg_names','var') % added by lion - this gives an error if fg_names doesnt exists
                if any(contains(fg_names, 'SGT'))
                    if obj.IQ.useIQ == 1
                        % S.changePulseToTrigger('SGT', 'TRIGGER', 5*1e-3, true);
                        pg.changeSequence('','','',{'channel', 'SGT', 'channel_2','TRIGGER', 'trigger_duration', 5*1e-3, 'add_trigger', true});
                        obj.LoadAWG();
                    else
                        % S.changePulseToTrigger('SGT', 'TRIGGER', 5*1e-3, false);
                        pg.changeSequence('','','',{'channel', 'SGT', 'channel_2','TRIGGER', 'trigger_duration', 5*1e-3, 'add_trigger', false});
                    end
                end
            end
            
            % Set Frequency Generator
            if ~isempty(obj.freqGenName)
                numChannels = 0;
                if iscell(obj.freqGenName)
                    % There are multiple FG, and they might have multiple
                    % channels. For each FG, check the number of channels,
                    % and set them.
                    for i = 1:length(obj.freqGenName)
                        fg = getObjByName(obj.freqGenName{i});
                        if isempty(fg); throwBaseObjException(obj.freqGenName{i}); end
                        fg.connect;
                        numChannels = numChannels + fg.numChannels;
                        if fg.numChannels > 1
                            fg.output = obj.WindFreakChannels;
                        else
                            fg.output = true(1, fg.numChannels);
                        end
                        try
                            if obj.IQ.useIQ
                                fg.IQ.output = true;
                                fg.LoadAWGInternal(fg);
                            end
                        catch err
                            warning('No internal IQ')
                        end
                    end
                else
                    fg = getObjByName(obj.freqGenName);
                    if isempty(fg); throwBaseObjException(obj.freqGenName); end
                    fg.connect;
                    numChannels = numChannels + fg.numChannels;
                    if ~contains(fg.name, 'TektronixAWG')
                        fg.output = true(1, fg.numChannels);
                        try
                            if obj.IQ.useIQ
                                fg.IQ.output = true;
                                fg.LoadAWGInternal(fg);
                            end
                        catch
                            warning('No internal IQ')
                        end
                    end
                end
                
                if length(obj.amplitude) <= numChannels
                    obj.setMultipleFGAmplitudes(obj.amplitude);
                end
                
                if length(obj.frequency) <= numChannels
                    obj.setMultipleFGFrequencies(obj.frequency);
                end
            end
            
            
            if spcm.hasGatedIntegrator() && any(strcmp(S.activeChannelNames,'GIgate'))
                spcm.detectionWithGI = 1;
            end
            if spcm.hasPhotodiode
                if obj.detectionDuration ~= obj.referenceDetectionDuration
                    error('Currently, with digitizer detection duration should be equal to the reference detection duration')
                end
                spcm.segmentDuration = obj.detectionDuration;
                spcm.fullDataAcquisition = obj.digitizerFullDataAcquisition;
                spcm.recordVoltageSpan = obj.recordVoltageSpan;
                spcm.daqVolatgeOffset = obj.voltageOffset;
            end

            
            if spcm.hasDiffInput()
                switch obj.inputConfig
                    case 'diff'
                        spcm.diffrentialInput = 1;
                    case 'norm'
                        spcm.diffrentialInput = 0;
                    case 'auto'
                        spcm.diffrentialInput = spcm.availableProperties.(spcm.HAS_DIFF_INPUT);
                    otherwise
                        obj.sendError('"inputConfig" property can get just "diff", "norm", or "auto" values')
                end
            end
            if spcm.hasLaserRef()
                spcm.balancedMeas = obj.balancedMeas;
            end
            spcm.setSPCMEnable(true);
            numScans = obj.detectionPeriodsPerRepeat*obj.repeats;
            
            if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')   %just checking. added by rotem 29.1.21
                 numScans = obj.detectionPeriodsPerRepeat*obj.repeats*obj.getTotalNumberOfParams*obj.runsPerPerform; %obj.runsPerPerform added by yachel 29.6.21
            end
            
            seqTime = pg.sequenceDuration() * 1e-6; % Multiplication in 1e-6 is for converting usecs to secs.
            timeout = 2 * seqTime * obj.repeats;  % some multiple of the actual duration
            spcm.prepareExperimentCount(numScans, timeout, obj.getTotalNumberOfParams*obj.runsPerPerform); % obj.getTotalNumberOfParams added by rotem 18.4.21 %obj.runsPerPerform added by yachel 29.6.21
            if isempty(obj.averagesTimeStamp)
                obj.averagesTimeStamp = zeros(obj.averages, 6);
            end
        end
        
        function setMultipleFGAmplitudes(obj, amplitudes)
            % There are multiple FGs, and each has a different number of
            % channels. Sets the FGs' channels amplitude according to their
            % order.
            if iscell(obj.freqGenName) % Multiple FGs
                J = 1;
                for i = 1:length(obj.freqGenName)
                    fg = getObjByName(obj.freqGenName{i});
                    if isempty(fg); throwBaseObjException(obj.freqGenName{i}); end
                    endJ = min(J + fg.numChannels - 1, length(amplitudes));
                    fg.amplitude = amplitudes(J:endJ);
                    J = J + fg.numChannels;
                end
            else % Single FG
                fg = getObjByName(obj.freqGenName);
                if isempty(fg); throwBaseObjException(obj.freqGenName); end
                fg.amplitude = amplitudes;
            end
        end
        
        function setMultipleFGFrequencies(obj, frequencies)
            % There are multiple FGs, and each has a different number of
            % channels. Sets the FGs' channels frequencies according to
            % their order.
            if iscell(obj.freqGenName) % Multiple FGs
                J = 1;
                for i = 1:length(obj.freqGenName)
                    fg = getObjByName(obj.freqGenName{i});
                    if ~fg.keepOn || isa(fg, 'FrequencyGeneratorSGT100A')
                        if isempty(fg); throwBaseObjException(obj.freqGenName{i}); end
                        endJ = min(J + fg.numChannels - 1, length(frequencies));
                        fg.frequency = frequencies(J:endJ);
                    end
                    J = J + fg.numChannels;
                end
            else % Signle FG
                fg = getObjByName(obj.freqGenName);
                if ~fg.keepOn || isa(fg, 'FrequencyGeneratorSGT100A')
                    if isempty(fg); throwBaseObjException(obj.freqGenName); end
                    fg.frequency = frequencies;
                end
            end
        end

        function IQinfo = generate_IQ(obj, I_vec, Q_vec, varargin) % varargin = [clock, startPlayback, KeepLocalFile, path, filename, comment, copyright, no_scaling]

            % find the SGT100 from the list of available FGs
            fgCell = FrequencyGenerator.getFG();
            fg_names = cellfun(@(c) c.name, fgCell, 'UniformOutput', false);
            % sgt_idx = find(contains(fg_names, 'SGT'));
            % sgt100 = fgCell{sgt_idx};
            sgt100 = fgCell{contains(fg_names, 'SGT')};

            fg = getObjByName(obj.freqGenName);

            % set defaults for non mandatory fields (and clockrate)
            defult = {'clock', 300e6, 'duration', 0.1e-6, 'StartPlayback', 0, 'KeepLocalFile', 0, 'path', '/hdd/', 'filename','untitled.wv', 'comment', '', 'copyright', '', 'no_scaling', 0};
            % populate parameters with user input (if there's no user input use defaults)
            IQinfo = varargin2param(defult, varargin);

            if isempty(IQinfo.filename)  % temp patch
                IQinfo.filename = 'untitled.wv';
            end

            IQinfo.duration = IQinfo.duration*1e-6; %convert to us

            if length(I_vec) == 1
                I_vec = I_vec*ones(1,(1+IQinfo.clock.*IQinfo.duration));
            end
            if length(Q_vec) == 1
                Q_vec = Q_vec*ones(1, (1+IQinfo.clock.*IQinfo.duration));
            end

            IQinfo.I_data = I_vec;
            IQinfo.Q_data = Q_vec;

            [Status] = rs_generate_wave( sgt100.visa, IQinfo, IQinfo.StartPlayback, IQinfo.KeepLocalFile )
        end

        function LoadAWG(obj)

            fgCell = FrequencyGenerator.getFG();
            fg_names = cellfun(@(c) c.name, fgCell, 'UniformOutput', false);
            fg = fgCell{contains(fg_names, 'SGT')};
            fg.IQ.segment_names = []; % temporarly here, needs to be moved to experiment wrapup (not necessarily the function, but the operation)
%             fg.IQ.repeats = []; % temporarly here, needs to be moved to experiment wrapup (not necessarily the function, but the operation)
            if size(obj.IQ.wfRepeats) == 1
                fg.IQ.repeats = obj.IQ.wfRepeats*ones(1,size(obj.IQ.IQ_arrays, 3));
            else
                fg.IQ.repeats = obj.IQ.wfRepeats;
            end
            

            opt_params = [fieldnames(obj.IQ), struct2cell(obj.IQ)];
            opt_params = opt_params(2:end,:)';
            opt_params = opt_params(:);
            for i = 1:size(obj.IQ.IQ_arrays, 3)
                if length(obj.IQ.duration) > 1
                    idx = cellfun(@(c) contains(char(c), 'duration') , opt_params, 'UniformOutput', true);
                    opt_params{find(idx)+1} = obj.IQ.duration(i);
                end
                if length(obj.IQ.switchWF) > 1
                    idx = cellfun(@(c) contains(char(c), 'switchWF') , opt_params, 'UniformOutput', true);
                    opt_params{find(idx)+1} = obj.IQ.switchWF(i);
                end
                if length(obj.IQ.wfRepeats) > 1
                    idx = cellfun(@(c) contains(char(c), 'wfRepeats') , opt_params, 'UniformOutput', true);
                    opt_params{find(idx)+1} = obj.IQ.wfRepeats(i);
%                     fg.IQ.repeats = [fg.IQ.repeats, obj.IQ.wfRepeats(i)];
                end
                if ~exist(obj.IQ.filename)
                    idx = cellfun(@(c) contains(char(c), 'filename') , opt_params, 'UniformOutput', true);
                    opt_params{find(idx)+1} = ['untitled', num2str(i), '.wv'];
                    fg.IQ.segment_names = [fg.IQ.segment_names; convertCharsToStrings(opt_params{find(idx)+1})];
%                     fgCell = FrequencyGenerator.getFG();
%                     fn_name = cellfun(@(c) c.name, opt_params, 'UniformOutput', false);
%                     fn_idx = find(contains(fn_name, 'SGT'));
%                     opt_params(fn_idx) = ['untitled', num2str(i), '.wv'];
                    % sgt100 = fgCell{sgt_idx};
%                     sgt100 = fgCell{contains(fg_names, 'SGT')};
%                     obj.IQ.filename = ['untitled', num2str(i), '.wv'];
                end
                obj.generate_IQ(obj.IQ.IQ_arrays(1,:,i), obj.IQ.IQ_arrays(2,:,i), opt_params);
            end
        end
    end
    
    methods (Static, Access = {?Experiment, ?ExperimentAWG, ?SpcmCounter})
        function expName = getSetCurrentExp(newExperimentName)
            % "Static property" which stores the name of the experiment
            % currently running.
            % If given input, it will be saved as the new current
            % experiment name.
            persistent eName
            
            if exist('newExperimentName', 'var')
                if isa(newExperimentName, 'Experiment')
                    newExperimentName = newExperimentName.name;
                else
                    assert(ischar(newExperimentName))
                end
                
                eName = newExperimentName;
            elseif isempty(eName)
                eName = '';
            end
            
            expName = eName;
        end
    end

    methods (Static)
        function [expNamesCell, expClassNamesCell] = getExperimentNames()
            %GETEXPERIMENTSNAMES returns cell of char arrays with names of
            %valid Experiments.
            % Algorithm: scan '\Experiments' folder, and get the Constant
            % property 'EXP_NAME' from each file (if exists). Add also
            % 'SpcmCounter', whatever be in the folder
            
            persistent expNames expClassNames
            if isempty(expNames)
                % Get 'regular' Experiments
                path = Experiment.PATH_ALL_EXPERIMENTS;
                [~, expFileNames] = PathHelper.getAllFilesInFolder(path, 'm');
                % Get Callibration Experiments
                path2 = Experiment.PATH_CALIBRATIONS;
                [~, calibFileNames] = PathHelper.getAllFilesInFolder(path2, 'm');
                % Get Trackables
                path3 = Trackable.PATH_ALL_TRACKABLES;
                [~, trckblFileNames] = PathHelper.getAllFilesInFolder(path3, 'm');
                % Join
                expFileNames = [expFileNames, calibFileNames, trckblFileNames];
                
                % Extract names
                expClassNames = PathHelper.removeDotSuffix(expFileNames);
                expNames = cell(size(expFileNames));
                for i = 1:length(expFileNames)
                    % We extract the NAME property using an in-house
                    % function (which avoids using eval)
                    try
                        expNames{i} = getConstPropertyfromString(expClassNames{i}, 'NAME');
                    catch err
                        warning(err.message)
                    end
                end
                expNames{end+1} = SpcmCounter.NAME;     % todo: think about this
            end
            
            expNamesCell = expNames;
            expClassNamesCell = expClassNames;
        end
        
        function expName = current()
            % Public getter to private static property
            expName = Experiment.getSetCurrentExp();
        end
        
        function outputList = strList(inputList)
            s = inputList';
            outputList = cat(2,s{:});
        end
        
    end
        
    %% Saving, loading and extracting data
    methods
        function save(obj, path)
            % Saves the experiment.
            % Three use cases - 
            % 1. no input argument (except obj): saves the file in the
            %    default folder, under a default name (e.g.
            %    'Echo_20180917_113506.mat')
            % 2. one extra argument - full path: saves the file as the path
            %    requested.
            % 3. one extra argument - folder name: saves the file at the
            %    specified folder, with the default name.
            
            
            % In order to save the Experiment which invoked this method, we
            % need to set it as The Current Experiment
            Experiment.getSetCurrentExp(obj.NAME);
            
            sl = SaveLoad.getInstance(Savable.CATEGORY_EXPERIMENTS);
            if ~isfield(sl.mLocalSaveStruct, obj.NAME)
                sl.saveParamsToLocalStruct();
            end
            sl.saveResultsToLocalStruct();
            switch nargin
                case 1
                    % Use case 1
                    sl.save;
                case 2
                    filename = PathHelper.getFileNameFromFullPathFile(path);
                    if isempty(filename)
                        % Use case 3
                        path = PathHelper.joinToFullPath(path, sl.mLoadedFileName);
                    end
                    path = [PathHelper.removeDotSuffix(path), SaveLoad.SAVE_FILE_SUFFIX];  % Making sure there is proper suffix
                    sl.saveAs(path)
            end
        end
        
        function load(obj, savedStruct)
            % Load a previously saved experiment.
            if isfield(savedStruct, 'Name') && strcmp(obj.NAME, savedStruct.Name)
                loadStateFromStruct(obj, savedStruct, Savable.CATEGORY_EXPERIMENTS, '')
                obj.restartFlag = false;
            elseif isfield(savedStruct, obj.NAME)
                loadStateFromStruct(obj, savedStruct.(obj.NAME), Savable.CATEGORY_EXPERIMENTS, '')
                obj.restartFlag = false;
            else
                obj.sendWarning('Experiment is of the wrong kind')
            end
        end
    end
end