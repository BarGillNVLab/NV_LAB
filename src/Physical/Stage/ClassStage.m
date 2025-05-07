classdef (Abstract) ClassStage < EventSender & Savable & EventListener
    % Created by Yoav Romach, The Hebrew University, September, 2016
    properties
        availableAxes           % string. For example - 'xy'
        scanParams              % object of class StageScanParams
        availableProperties = struct;
        stepSize                % double
        loopMode = 'Closed'     % string. 'Closed' by default. Can be either that or 'Open'.
        pgControlled = 0        % boolean. if the trigger for scanning is comming from the pulse generator
        triggerChannel
        triggerChannelLine
    end
    
    properties (Abstract, Constant)
        STEP_MINIMUM_SIZE   % double
        STEP_DEFAULT_SIZE   % double
    end
    
    properties (Constant)
        SCAN_AXES = 'xyz';
        SCAN_AXES_SIZE = 3; % int. Length of SCAN_AXES
             
        TILT_MIN_LIM_DEG = -5;
        TILT_MAX_LIM_DEG = 5;
        
        HAS_FAST_SCAN = 'hasFastScan';
        HAS_SLOW_SCAN = 'hasSlowScan';
        TILTABLE = 'tiltable';
        HAS_CLOSED_LOOP = 'hasClosedLoop';
        HAS_OPEN_LOOP = 'hasOpenLoop';
        HAS_JOYSTICK = 'hasJoystick';
                    
        EVENT_SCAN_PARAMS_CHANGED = 'scanParamsChanged';
        EVENT_LIM_CHANGED = 'limitChanged';
        EVENT_STEP_SIZE_CHANGED = 'stepSizeChanged';
        EVENT_POSITION_CHANGED = 'positionChanged';
        EVENT_TILT_CHANGED = 'tiltChanged';
        EVENT_STAGE_AVAILABLITY_CHANGED = 'stageAvailabilityChanged';
    end
    
    methods (Static, Access = public) % Get instance constructor
        function stages = getStages()
            % Return an instance of cell{all stages}
            
            persistent stagesCellContainer
            if isempty(stagesCellContainer) || ~isvalid(stagesCellContainer)
                stagesJson = JsonInfoReader.getJson.stages;
                stagesCellContainer = CellContainer;
                
                try
                    for i = 1: length(stagesJson)
                        if iscell(stagesJson)
                            curStageStruct = stagesJson{i};
                        else
                            curStageStruct = stagesJson(i);
                        end
                        stageType = curStageStruct.type;
                        switch stageType
                            case 'LPS-65' % Setup 1 LPS-65
                                newStage = getObjByName(ClassPILPS65.NAME);
                                if isempty(newStage)
                                    newStage = ClassPILPS65.create(curStageStruct);
                                end
                            case 'Galvo' % Galvo mirrors for the Cryo setup
                                newStage = getObjByName(ClassGalvo.NAME);
                                if isempty(newStage)
                                    newStage = ClassGalvo.create(curStageStruct);
                                end
                            case 'ANC' % Setup 3 ANC stages
                                newStage = getObjByName(ClassANC.NAME);
                                if isempty(newStage)
                                    newStage = ClassANC.create(curStageStruct);
                                end
                            case 'ANC300' % Setup 3 ANC300 stages
                                newStage = getObjByName(ClassANC300.NAME);
                                if isempty(newStage)
                                    newStage = ClassANC300.create(curStageStruct);
                                end
                            case 'ANC350' % Setup 8 ANC350 stages
                                newStage = getObjByName(ClassANC350.NAME);
                                if isempty(newStage)
                                    newStage = ClassANC350.create(curStageStruct);
                                end
                            case 'PIP-562'
                                newStage = getObjByName(ClassPIP562.NAME);
                                if isempty(newStage)
                                    newStage = ClassPIP562.create(curStageStruct);
                                end
                            case 'PIM-686'
                                newStage = ClassPIM686.GetInstance();
                            case 'PIM-501'
                                newStage = ClassPIM501.GetInstance();
                            case 'PIM-686&PIM-501'
                                newStage = ClassPIM686M501.GetInstance();
                            case 'MCS2'
                                newStage = getObjByName(ClassMCS2.NAME);
                                if isempty(newStage)
                                    newStage = ClassMCS2.create(curStageStruct);
                                end
                            case 'ECC' % ECC100 stages
                                newStage = ClassECC.GetInstance();
                            case 'STEDCoarse'
                                newStage = ClassSTEDCoarse.GetInstance();
                            case 'Standa-85MC4'
                                newStage = ClassStanda8SMC4_stages.create(curStageStruct);
                            case 'Dummy'
                                if isfield(curStageStruct, 'name')
                                    stageName = curStageStruct.name;
                                else
                                    stageName = 'Dummy stage';
                                end
                                
                                % Maybe this already exists, and we will
                                % then replace it.
                                oldStage = getObjByName(stageName);
                                if ~isempty(oldStage)
                                    EventStation.anonymousWarning('%s will be overridden!', stageName);
                                    removeObjIfExists(oldStage);
                                end
                                
                                
                                if isfield(curStageStruct, 'is_scanable')
                                    stageScanable = curStageStruct.is_scanable;
                                else
                                    stageScanable = true;
                                end
                                
                                if isfield(curStageStruct, 'axes')
                                    stageAxes = curStageStruct.axes;
                                else
                                    stageAxes = ClassStage.SCAN_AXES;  % all of them
                                end
                                
                                if isfield(curStageStruct, 'tilt_available')
                                    tiltAvailable = curStageStruct.tilt_available;
                                else
                                    tiltAvailable = true;
                                end
                                
                                newStage = ClassDummyStage(stageName, stageAxes, stageScanable, tiltAvailable);
                            otherwise
                                EventStation.anonymousError('Unknown stage: %s', stageType);
                        end
                        
                        %%%% init the new stage %%%%
                        newStage.initScanParams();
                        stagesCellContainer.cells{end + 1} = newStage;
                    end
                catch err
                    % Close open stages. We will open them again when needed
                    stages = stagesCellContainer.cells;
                    for i = 1:length(stages)
                        delete(stages{i});
                    end
                    stagesCellContainer = [];
                    rethrow(err)
                end
                    
            end  % if isempty || ~isvalid
            
            stages = stagesCellContainer.cells;

        end  % function getStages()
        
        function scannableStages = getScannableStages
            % Among available stages, return only those which are scannable
            stages = ClassStage.getStages;
            scannableStages = {};
            for i = 1:length(stages)
                if stages{i}.isScannable
                    scannableStages{end + 1} = stages{i}; %#ok<AGROW>
                end
            end
        end
        
        function phAxis = getAxis(phAxis)
            % Converts x,y,z into the corresponding numeric value (1,2,3).
            % If already in numeric value it does nothing.
            tempAxis = zeros(size(phAxis)); % Needed because axis could be of type string
            for i=1:length(phAxis)
                index = phAxis(i);
                if (index < 1 || index > 3)
                    index = strfind(ClassStage.SCAN_AXES, lower(phAxis(i)));
                    if isempty(index) || (index < 1 || index > 3)
                        EventStation.anonymousError(['Unknown axis: ', phAxis(i)]);
                    end
                end
                tempAxis(i) = index;
            end
            phAxis = tempAxis;
        end
        
        function string = GetLetterFromAxis(phAxis)
            % Returns a letter from an axis. supports vectorial axis
            phAxis = ClassStage.getAxis(phAxis);
            string = ClassStage.SCAN_AXES(phAxis);
        end

    end  % methods (static, public)
    
    methods (Access = protected)
        function obj = ClassStage(name, availableAxes)
            % name - string
            % availableAxes - string. example: "xyz"
            obj@EventSender(name);
            obj@Savable(name);
            obj@EventListener(StageControlEvents.NAME);
            addBaseObject(obj);  % so it can be reached by getObjByName()
            
            obj.availableAxes = availableAxes;
            obj.stepSize = obj.STEP_DEFAULT_SIZE;
        end
        
        function initScanParams(obj)
            phAxis = ClassStage.getAxis(obj.availableAxes);
            [limNeg, limPos] = obj.ReturnLimits(phAxis);
            obj.scanParams = StageScanParams;
            obj.scanParams.from(phAxis) = limNeg;
            obj.scanParams.to(phAxis) = limPos;
            obj.scanParams.isFixed = ones(1, ClassStage.SCAN_AXES_SIZE);    % all fixed except what the stage supports (look 3 lines below)
            obj.scanParams.isFixed(phAxis) = false;
            obj.scanParams.fixedPos(phAxis) = obj.Pos(phAxis);
            obj.scanParams.fastScan = obj.hasFastScan;
        end
        
        % wrapper for the static method getAxis
        function phAxes = GetAxis(~, phAxis)
            phAxes = ClassStage.getAxis(phAxis);
        end
        
    end
    
    methods (Abstract, Access = public)
        ok = PointIsInRange(obj, phAxis, point)
        % Checks if the given point is within the soft (and hard) limits of
        % the given (physical) axis (x,y,z or 1 for x, 2 for y,
        % and 3 for z).
        % Vectorial axis is possible.
        
        [negSoftLimit, posSoftLimit] = ReturnLimits(obj, phAxis)
        % Return the soft limits of the given axis (x,y,z or 1 for x,
        % 2 for y and 3 for z).
        % Vectorial axis is possible.
        
        [negHardLimit, posHardLimit] = ReturnHardLimits(obj, phAxis)
        % Return the hard limits of the given axis (x,y,z or 1 for x,
        % 2 for y and 3 for z).
        % Vectorial axis is possible.
        
        pos = Pos(obj, phAxis)
        % Query and return position of axis (x,y,z or 1 for x, 2 for y
        % and 3 for z)
        % Vectorial axis is possible.
        
        vel = Vel(obj, phAxis)
        % Query and return velocity of axis (x,y,z or 1 for x, 2 for y
        % and 3 for z)
        % Vectorial axis is possible.
        
        binaryButtonState = ReturnJoystickButtonState(obj)
        % Returns the state of the buttons in 3 bit decimal format.
        % 1 for first button, 2 for second and 4 for the 3rd.
        
        [tiltEnabled, thetaXZ, thetaYZ] = GetTiltStatus(obj)
        % Return the status of the tilt control.
        
        
    end
    
    
    methods (Abstract, Access = public)
        % Classes that have multiple stages need to add a 'stage' argument
        % to the end of every function.
        
        SetSoftLimits(obj, phAxis, softLimit, negOrPos)
        % Set the new soft limits:
        % if negOrPos = 0 -> then softLimit = lower soft limit
        % if negOrPos = 1 -> then softLimit = higher soft limit
        % This is because each time this function is called only one of
        % the limits updates
        
        SetVelocity(obj, phAxis, vel)
        % Absolute change in velocity (vel) of axis (x,y,z or 1 for x,
        % 2 for y and 3 for z).
        % Vectorial axis is possible.
        
        CloseConnection(obj)
        % Closes the connection to the stage.
        
        Reconnect(obj)
        % Reconnects the controller.
        
        Move(obj, phAxis, pos)
        % Absolute change in position (pos) of axis (x,y,z or 1 for x,
        % 2 for y and 3 for z).
        % Vectorial axis is possible.
        
        RelativeMove(obj, phAxis, change)
        % Relative change in position (pos) of axis (x,y,z or 1 for x,
        % 2 for y and 3 for z).
        % Vectorial axis is possible.
        
        Halt(obj)
        % Halts all stage movements.
        
        ScanX(obj, x, y, z, nFlat, nOverRun, tPixel)
        %%%%%%%%%%%%%%%%% ONE DIMENSIONAL X SCAN %%%%%%%%%%%%%%%%%
        % Does a scan for x axis.
        % x - A vector with the points to scan, points should have
        % equal distance between them.
        % y/z - The starting points for the other axes.
        % tPixel - Scan time for each pixel.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        ScanY(obj, x, y, z, nFlat, nOverRun, tPixel)
        %%%%%%%%%%%%%%%%% ONE DIMENSIONAL Y SCAN %%%%%%%%%%%%%%%%%
        % Does a scan for y axis.
        % y - A vector with the points to scan, points should have
        % equal distance between them.
        % x/z - The starting points for the other axes.
        % tPixel - Scan time for each pixel.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        ScanZ(obj, x, y, z, nFlat, nOverRun, tPixel)
        %%%%%%%%%%%%%%%%% ONE DIMENSIONAL Z SCAN %%%%%%%%%%%%%%%%%
        % Does a scan for z axis.
        % z - A vector with the points to scan, points should have
        % equal distance between them.
        % x/y - The starting points for the other axes.
        % tPixel - Scan time for each pixel.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        PrepareScanX(obj, x, y, z, nFlat, nOverRun, tPixel)
        %%%%%%%%%%%%%%%%% ONE DIMENSIONAL X SCAN %%%%%%%%%%%%%%%%%
        % Prepares a scan for x axis, to be called before ScanX.
        % x - A vector with the points to scan, points should have
        % equal distance between them.
        % y/z - The starting points for the other axes.
        % tPixel - Scan time for each pixel.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        PrepareScanY(obj, x, y, z, nFlat, nOverRun, tPixel)
        %%%%%%%%%%%%%%%%% ONE DIMENSIONAL Y SCAN %%%%%%%%%%%%%%%%%
        % Prepares a scan for y axis, to be called before ScanY.
        % y - A vector with the points to scan, points should have
        % equal distance between them.
        % x/z - The starting points for the other axes.
        % tPixel - Scan time for each pixel.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        PrepareScanZ(obj, x, y, z, nFlat, nOverRun, tPixel)
        %%%%%%%%%%%%%%%%% ONE DIMENSIONAL Z SCAN %%%%%%%%%%%%%%%%%
        % Prepares a scan for z axis, to be called before ScanZ.
        % z - A vector with the points to scan, points should have
        % equal distance between them.
        % x/y - The starting points for the other axes.
        % tPixel - Scan time for each pixel.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        PrepareScanXY(obj, x, y, z, nFlat, nOverRun, tPixel)
        %%%%%%%%%%%%%% TWO DIMENSIONAL XY SCAN MACRO %%%%%%%%%%%%%%
        % Prepare a macro scan for xy axes!
        % Scanning is done by calling 'ScanNextLine'.
        % Aborting via 'AbortScan'.
        % x/y - Vectors with the points to scan, points should have
        % equal distance between them.
        % z - The starting points for the other axis.
        % tPixel - Scan time for each pixel.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        PrepareScanXZ(obj, x, y, z, nFlat, nOverRun, tPixel)
        %%%%%%%%%%%%%% TWO DIMENSIONAL XZ SCAN MACRO %%%%%%%%%%%%%%
        % Prepare a macro scan for xz axes!
        % Scanning is done by calling 'ScanNextLine'.
        % Aborting via 'AbortScan'.
        % x/z - Vectors with the points to scan, points should have
        % equal distance between them.
        % y - The starting points for the other axis.
        % tPixel - Scan time for each pixel.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        PrepareScanYX(obj, x, y, z, nFlat, nOverRun, tPixel)
        %%%%%%%%%%%%%% TWO DIMENSIONAL XY SCAN MACRO %%%%%%%%%%%%%%
        % Prepare a macro scan for xy axes!
        % Scanning is done by calling 'ScanNextLine'.
        % Aborting via 'AbortScan'.
        % x/y - Vectors with the points to scan, points should have
        % equal distance between them.
        % z - The starting points for the other axis.
        % tPixel - Scan time for each pixel.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        PrepareScanYZ(obj, x, y, z, nFlat, nOverRun, tPixel)
        %%%%%%%%%%%%%% TWO DIMENSIONAL YZ SCAN MACRO %%%%%%%%%%%%%%
        % Prepare a macro scan for yz axes!
        % Scanning is done by calling 'ScanNextLine'.
        % Aborting via 'AbortScan'.
        % y/z - Vectors with the points to scan, points should have
        % equal distance between them.
        % x - The starting points for the other axis.
        % tPixel - Scan time for each pixel.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        PrepareScanZX(obj, x, y, z, nFlat, nOverRun, tPixel)
        %%%%%%%%%%%%%% TWO DIMENSIONAL XZ SCAN MACRO %%%%%%%%%%%%%%
        % Prepare a macro scan for xz axes!
        % Scanning is done by calling 'ScanNextLine'.
        % Aborting via 'AbortScan'.
        % x/z - Vectors with the points to scan, points should have
        % equal distance between them.
        % y - The starting points for the other axis.
        % tPixel - Scan time for each pixel.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        PrepareScanZY(obj, x, y, z, nFlat, nOverRun, tPixel)
        %%%%%%%%%%%%%% TWO DIMENSIONAL YZ SCAN MACRO %%%%%%%%%%%%%%
        % Prepare a macro scan for yz axes!
        % Scanning is done by calling 'ScanNextLine'.
        % Aborting via 'AbortScan'.
        % y/z - Vectors with the points to scan, points should have
        % equal distance between them.
        % x - The starting points for the other axis.
        % tPixel - Scan time for each pixel.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        [forwards, done] = ScanNextLine(obj)
        % Scans the next line for the 2D scan, to be used after
        % 'PrepareScanXX'.
        % forwards is set to 1 when the scan is forward and is set to 0
        % when it's backwards
        % DONE IS CURRENTLY NOT IMPLEMENTED ANYWHERE!
        % done is set to 1 after the last line has been scanned.
        % No other commands should be used between 'PrepareScanXX' and
        % until 'ScanNextLine' has returned done, or until 'AbortScan'
        % has been called.

        
        PrepareRescanLine(obj)
        % Prepares the previous line for rescanning.
        % Scanning is done with "ScanNextLine"
        
        AbortScan(obj)
        % Aborts the 2D scan defined by 'PrepareScanXX';
        
        maxScanSize = ReturnMaxScanSize(obj, nDimensions)
        % Returns the maximum number of points allowed for an
        % 'nDimensions' scan.
        
        JoystickControl(obj, enable)
        % Changes the joystick state for all axes to the value of
        % 'enable' - true to turn Joystick on, false to turn it off.
        
        FastScan(obj, enable)
        % Changes the scan between the fast & the slow modes.
        % 'enable' - 1 for fast scan, 0 for slow scan.
        
        ChangeLoopMode(obj, mode)
        % Changes between closed and open loop.
        % Mode should be either 'Open' or 'Closed'.
        
%         GetLoopMode(obj)
%         % Get current loop mode (either 'Open' or 'Closed') from the
%         % hardware.
        
        success = SetTiltAngle(obj, thetaXZ, thetaYZ)
        % Sets the tilt angles between Z axis and XY axes.
        % Angles should be in degrees, valid angles are between -5 and 5
        % degrees.
        
        success = EnableTiltCorrection(obj, enable)
        % Enables the tilt correction according to the angles.
        
    end
    
    
    methods
        function sendEventScanParamsChanged(obj)
            obj.sendEvent(struct(obj.EVENT_SCAN_PARAMS_CHANGED, true));
        end
        function sendEventLimitsChanged(obj)
            obj.sendEvent(struct(obj.EVENT_LIM_CHANGED, true));
        end
        function sendEventPositionChanged(obj)
            obj.sendEvent(struct(obj.EVENT_POSITION_CHANGED, true));
        end
        function sendEventStageAvailabilityChanged(obj)
            % e.g., stage is in open loop, or scan started, or ended
            obj.sendEvent(struct(obj.EVENT_STAGE_AVAILABLITY_CHANGED, true));
        end
        
        function sendPosToScanParams(obj)
            % New behavior: update "Fixed Position" to be current position,
            % in all available axes.
            params = obj.scanParams;
            axesIndex = obj.getAxis(obj.availableAxes);
            pos = obj.Pos(axesIndex);
            
            %%%% If we're off bounds by a bit, set fixedPos as bound
            [lowerBound, upperBound] = obj.ReturnLimits(axesIndex);
            pos(pos > upperBound) = upperBound(pos > upperBound);
            pos(pos < lowerBound) = lowerBound(pos < lowerBound);
            %%%%
            
            params.fixedPos(axesIndex) = pos;
            obj.sendEventScanParamsChanged;
            
            % % Old behavior: For all the positions marked as "fixed" in
            % % obj.scanParams, update them by the current position
            % params = obj.scanParams;
            % currentPos = obj.Pos(obj.SCAN_AXES);
            % params.fixedPos(find(params.isFixed)) = currentPos(find(params.isFixed)); %#ok<FNDSB>
            % if any(params.isFixed)
            %     obj.sendEventScanParamsChanged();
            % end
        end
        
        function moveByScanParams(obj)
            % For all the positions marked as "fixed" in obj.scanParams,
            % move to this position
            params = obj.scanParams;
            try
                obj.sanityCheckForScanRange(params);
            catch err
                obj.sendError(err.message)  % We don't send the error in the sanity check, so we need to do it here
            end
            phAxes = obj.SCAN_AXES(find(params.isFixed)); %#ok<FNDSB>
            fixedPos = params.fixedPos(find(params.isFixed)); %#ok<FNDSB>
            if isempty(phAxes)
                obj.sendError('At least one axis needs to be fixed for this operation')
            else
                obj.move(phAxes, fixedPos);
            end
        end

        function prepareWriteTrigger(obj)
            try
                x = obj.pgControlled;
            catch ME
                disp(getReport(ME))
            end
            disp(x)
            disp(class(obj.pgControlled))
            if ~obj.pgControlled
                nidaq = getObjByName(NiDaq.NAME);
                obj.triggerChannelLine = obj.triggerChannel(end);                             % For example, if the channel is 'PFI3', we want the line to be '3'
                obj.digitalPulseTask = nidaq.prepareDigitalOutputTask(obj.triggerChannel);
            end
        end

        function writeTrigger(obj, value)
            if obj.pgControlled
                pg = getObjByName(PulseGenerator.NAME);
                if value
                    pg.On('detector');
                else
                    pg.Off('detector');
                end
            else
                nidaq.writeDigitalOnce(obj.digitalPulseTask, value, obj.triggerChannelLine);
            end
        end
        
        function move(obj, phAxis, pos)
            % Calls Move, sends an event. Listens to errors to send errorEvent
            try
                obj.Move(phAxis, pos);
                obj.sendEventPositionChanged;
            catch matlabError
                obj.sendError(matlabError.message);
            end
        end
        
        function relativeMove(obj, phAxis, change)
            % Calls RelativeMove, sends an event. Listens to errors to send errorEvent.
            % Vectorial axis is possible
            obj.RelativeMove(phAxis, change);
            obj.sendEventPositionChanged;
        end
        
        function setTiltAngle(obj, thetaXZ, thetaYZ)
            % Calls obj.SetTiltAngle to set the tilt angles between Z axis and
            % XY axes, and than sends an event.
            %
            % Angles should be in degrees, valid angles are between -5 and 5
            % degrees.
            try
                if ~obj.tiltAvailable
                    error('This stage doesn''t support tilt!');
                end
                
                if ~ValidationHelper.isInBorders(thetaXZ, obj.TILT_MIN_LIM_DEG, obj.TILT_MAX_LIM_DEG)
                    error('"thetaXZ" is not in borders!\n''thetaXZ'': %d, min: %d, max: %d', thetaXZ, obj.TILT_MIN_LIM_DEG, obj.TILT_MAX_LIM_DEG);
                end
                if ~ValidationHelper.isInBorders(thetaYZ, obj.TILT_MIN_LIM_DEG, obj.TILT_MAX_LIM_DEG)
                    error('"thetaYZ" is not in borders!\n''thetaYZ'': %d, min: %d, max: %d', thetaYZ, obj.TILT_MIN_LIM_DEG, obj.TILT_MAX_LIM_DEG);
                end
                
                obj.SetTiltAngle(thetaXZ, thetaYZ);
                obj.sendEvent(struct(ClassStage.EVENT_TILT_CHANGED, true));
            catch matlabError
                obj.sendError(matlabError.message);
            end
        end
        
        function enableTiltCorrection(obj, enable)
            % Enables the tilt correction according to the angles. than
            % sends an event
            try
                if ~obj.tiltAvailable
                    error('This stage doesn''t support tilt!');
                end
                obj.EnableTiltCorrection(enable);
                obj.sendEvent(struct(obj.EVENT_TILT_CHANGED, true));
            catch matlabError
                obj.sendError(matlabError.message);
            end
        end
        
        
        function sanityCheckForScanRange(obj, scanParams)
            % Sanity checks on the scan parameters
            % The way: copy the scan parameters, call updateByLimit() on
            % the new object and see if something has changed.  
            % 
            % If nothing changed, then all the parameters were in the
            % limits in the first place! 
            [limNeg, limPos] = obj.ReturnLimits(obj.availableAxes);
            wasChange = scanParams.copy.updateByLimit(obj.availableAxes, limNeg, limPos);
            if wasChange
                error('Sanity checks on the scan parameters failed!');  % Don't sendError(), because we might want to do stuff before
            end
            largeMovement = false;
            for i=1:length(obj.availableAxes)
                if scanParams.isFixed(i)
                    largeMovement = largeMovement || abs(obj.Pos(i) - scanParams.fixedPos(i)) > 1000;
                else
                    largeMovement = largeMovement ||...
                        abs(obj.Pos(i) - scanParams.from(i)) > 1000 ||...
                        abs(obj.Pos(i) - scanParams.to(i)) > 1000;
                end
            end
            if largeMovement
                questionString = sprintf('The scan will cause the stage to move by more than 1mm\nAre you sure you want to scan?');
                scanString = 'Scan';
                abortString = 'Abort';
                confirm = questdlg(questionString, 'Unexpected error', scanString, abortString, abortString);
                switch confirm
                    case scanString
                        % Do nothing.
                    case abortString
                        error('Sanity checks on the scan parameters failed!');  % Don't sendError(), because we might want to do stuff before
                    otherwise
                        error('Sanity checks on the scan parameters failed!');  % Don't sendError(), because we might want to do stuff before
                end
            end
        end
        
        function getJoystick(obj)
            % We create the joystick here, for techniacl reasons. It should
            % be in Setup.init, when available
            Joystick.init(obj.name);
            obj.availableProperties.(obj.HAS_JOYSTICK) = true;
        end
        
    end
    
    %% setters and getters
    methods
        function set.scanParams(obj, newValue)
            % Validates the input, sets the newValue, sends an event
            if isa(newValue, 'StageScanParams')
                [newLimNeg, newLimPos] = obj.ReturnLimits(obj.availableAxes);
                newValue.updateByLimit(obj.availableAxes, newLimNeg, newLimPos);
                obj.scanParams = newValue;
                obj.sendEventScanParamsChanged();
            else
                obj.sendWarning('Can only assign object of type "StageScanParams"! Ignoring');
            end
        end
        
        function set.stepSize(obj, newValue)
            % Validates the input, sets the newValue, sends an event
            if ~isnumeric(newValue)
                obj.sendError('Step size must be numeric!');
            end
            if newValue < obj.STEP_MINIMUM_SIZE
                obj.sendError(sprintf('Step size minimum is %d! (you tried %d)', obj.STEP_MINIMUM_SIZE, newValue));
            end
            
            obj.stepSize = newValue;
            obj.sendEvent(struct(obj.EVENT_STEP_SIZE_CHANGED, true));
        end
        function setLim(obj, newValue, pAxis, zeroForLowerOneForUpper)
            % Validates the input, sets the newValue, sends an event
            %
            % new value - double. Value of new limit
            % pAxis - array of chars or doubles. Physical axis to control
            % zeroForLowerOneForUpper - 0 will set the lower limit. 1 - the upper one
            try
                pAxis = obj.GetAxis(pAxis);

                %%% Input checks %%%
                % (#1) Are we still in the relevant limits? %%%
                [lowerSoftLim, upperSoftLim] = obj.ReturnLimits(pAxis);
                [lowerHardLim, upperHardLim] = obj.ReturnHardLimits(pAxis);
                
                if zeroForLowerOneForUpper == 0
                    % Lower limit should be in [hardLowerLim, softUpperLim]
                    if any(newValue < lowerHardLim) || any(newValue > upperSoftLim)
                        error('New value is out of limits! limits: [%d, %d]', lowerHardLim, upperSoftLim)
                    end
                elseif zeroForLowerOneForUpper == 1
                    % Upper limit should be in [softLowerLim, hardUpperLim]
                    if any(newValue < lowerSoftLim) || any(newValue > upperHardLim)
                        error('New value out of limits! limits: [%d, %d]', lowerSoftLim, upperHardLim)
                    end
                else
                    error('Parameter "zeroForLowerOneForUpper" should only be 0 or 1')
                end
                
                % (#2) Do we need to move the stage?
                stagePos = obj.Pos(pAxis);
                
                if zeroForLowerOneForUpper
                    [newLimNeg, newLimPos] = deal(lowerSoftLim, newValue);
                else
                    [newLimNeg, newLimPos] = deal(newValue, upperSoftLim);
                end
                if ~ValidationHelper.isInBorders(stagePos, newLimNeg, newLimPos)
                    % Ask the user whether to move the stage or to revert
                    
                    if zeroForLowerOneForUpper
                        msgLimUpperOrLower = 'upper';
                    else
                        msgLimUpperOrLower = 'lower';
                    end
                    msgAxis = ClassStage.GetLetterFromAxis(pAxis);
                    msgStagePos = num2str(obj.Pos(ClassStage.SCAN_AXES));
                    msg = sprintf(...
                        ['You are about to change the %s limit to %d in axis %s.\n', ...
                        'Doing so will move the stage!\n', ....
                        '(Current position in %s: %s,\n', ...
                        'new position in axis %s: %d).\n', ...
                        'Are you sure?'], ...
                        msgLimUpperOrLower, ...
                        newValue, ...
                        msgAxis, ...
                        ClassStage.SCAN_AXES, ...
                        num2str(msgStagePos), ...
                        msgAxis, ...
                        newValue);
                        
                    if ~QuestionUserYesNo('Confirm limit change', msg)
                        % Stop and don't do anything.
                        error('User canceled the operation.');
                    else
                        needToMoveStage = true;
                    end
                    
                else % The new limits DO NOT change the stage position
                    needToMoveStage = false;
                end
                
                %%%% Actual work %%%%
                obj.SetSoftLimits(pAxis, newValue, zeroForLowerOneForUpper);
                obj.sendEventLimitsChanged();
                
                [newLimNeg, newLimPos] = obj.ReturnLimits(pAxis);
                scanParamsChanged = obj.scanParams.updateByLimit(pAxis, newLimNeg, newLimPos);
                if scanParamsChanged
                    obj.sendEventScanParamsChanged();
                end
                
                if needToMoveStage
                    obj.move(pAxis, newValue);  % This will send an event by itself
                end
                
            catch matlabError
                obj.sendError(matlabError.message);
            end
        end
        
    end
    
    methods % Available properties    
        function properties = getAvailableProperties(obj)
            properties = obj.avilableProperties;
        end

        function bool = isScannable(obj)
            bool = isfield(obj.availableProperties,obj.HAS_SLOW_SCAN) || ...
                isfield(obj.availableProperties,obj.HAS_FAST_SCAN);
        end
        
        function bool = hasFastScan(obj)
%             if isfield(obj.availableProperties, obj.HAS_FAST_SCAN)
%                 bool = obj.availableProperties.(obj.HAS_FAST_SCAN);
%             end
        bool = isfield(obj.availableProperties,obj.HAS_FAST_SCAN);
        end
        
        function bool = hasSlowScan(obj)
            bool = isfield(obj.availableProperties,obj.HAS_SLOW_SCAN);
        end
        
        function bool = tiltAvailable(obj)
            bool = isfield(obj.availableProperties,obj.TILTABLE);
        end
        
        function bool = hasOpenLoop(obj)
            bool = isfield(obj.availableProperties,obj.HAS_OPEN_LOOP);
        end
        
        function bool = hasClosedLoop(obj)
            bool = isfield(obj.availableProperties,obj.HAS_CLOSED_LOOP);
        end
        
        function bool = hasJoystick(obj)
            bool = isfield(obj.availableProperties,obj.HAS_JOYSTICK);
        end
        
    end
    
    %% overriden from Savable
    methods (Access = protected) 
        function outStruct = saveStateAsStruct(obj, category, type) %#ok<INUSL>
            % Saves the state as struct. if you want to save stuff, make
            % (outStruct = struct;) and put stuff inside. If you dont
            % want to save, make (outStruct = NaN;)
            %
            % category - string. Some objects saves themself only with
            %                    specific category (image/experiments/etc.)
            % type - string.     Whether the objects saves at the beginning
            %                    of the run (parameter) or at its end (result)
            if ~strcmp(type, Savable.TYPE_PARAMS)
                outStruct = NaN;
                return
            end
            
            % Save only the stage position
            position = obj.Pos(obj.availableAxes);
            outStruct = struct('position', position);
        end
        
        function loadStateFromStruct(obj, savedStruct, category, subCategory) 
            % Loads the state from a struct.
            % To support older versions, always check for a value in the
            % struct before using it. View example in the first line.
            % category - string
            % subCategory - string. could be empty string
            
            switch category
                case Savable.CATEGORY_IMAGE
                    % save from "image" category - the scan parameters are
                    % saved here.
                    % saves for "image" are divided by sub-categories, only
                    % load if you have to!
                    if any(strcmp(subCategory, {Savable.SUB_CATEGORY_DEFAULT, Savable.CATEGORY_IMAGE_SUBCAT_STAGE}))
                        % ^ only if sub-category includes the stage
                        if isfield(savedStruct, 'scanParams')
                            % For backward compatibility: in later versions,
                            % the scan parameters are saved only in the
                            % stage scanner
                            obj.scanParams = StageScanParams.fromStruct(savedStruct.scanParams);
                            obj.sendEventScanParamsChanged();
                        end
                    end
                    
                case Savable.CATEGORY_EXPERIMENTS
                    position = savedStruct.position;
                    obj.move(ClassStage.SCAN_AXES, position);
            end
        end
        
        function string = returnReadableString(obj, savedStruct)
            % Return a readable string to be shown. if this object
            % doesn't need a readable string, make (string = NaN;) or
            % (string = '');
            scanner = getObjByName(StageScanner.NAME);
            if strcmp(scanner.mStageName, obj.name)
                % The parameters are already recorded by the stage scanner,
                % and we do not need them from here
                string = NaN;
                return
            end
            
            n = length(obj.availableAxes);
            string = sprintf('%s position:', obj.name);
            
            indentation = 5;
            for i = 1:n
                axLetter = obj.availableAxes(i);
                position = savedStruct.position(i);
                axisString = sprintf('%s axis: %.3f', axLetter, position);
                string = sprintf('%s\n%s', string, ...
                    StringHelper.indent(axisString, indentation));
            end
        end
    end
    
    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if isfield(event.extraInfo, StageControlEvents.HALT);               obj.Halt();             end
            if isfield(event.extraInfo, StageControlEvents.CLOSE_CONNECTION);   obj.CloseConnection();  end
        end
    end
end