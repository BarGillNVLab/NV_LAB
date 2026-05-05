classdef ClassStanda8SMC4_stages < ClassStage
   
    properties (Constant)
        controllerModel = '8SMC4';
        NAME = 'Stage - 8SMC4'
        UNITS = 'um'
        
        NEEDED_FIELDS = {'address'}
        
        COMM_DELAY = 0.005; % 5ms delay needed between consecutive commands sent to the controllers.
        STEP_MINIMUM_SIZE = 0.001                   % in um
        STEP_DEFAULT_SIZE = 0.02                    % in um
        MAX_SCAN_SIZE = 1e6;
        
        WARNING_PREVIOUS_SCAN_CANCELLED = '2D Scan is in progress! Previous scan was cancelled';
    end
       
    properties (Access = protected)
        physicalAddress
        id
        
        leadScrewPitch
        travelRange
        countsPerTurn     % encoder counts per turn
        stepsPerTurn      % without encoder we use motor steps per turn
        maxSpeed
        isEncoder           % beelean. if there is encoder in the stage

        posSoftRangeLimit
        negSoftRangeLimit
        
        defaultVel = 1e3;   % in um/s (== 1mm/s)
        curPos
        curVel
        forceStop
        scanRunning
        macroScanAxis
        macroScanVector
        macroNormalScanAxis
        macroNormalScanVector
        macroScanStartEndVector
        macroScanPixelSizeInum
        macrotPixel
        macroPixelTime
        macroIndex
        macroNumberOfPixels
        fastScan
            
            
        % NiDaq
        digitalPulseTask = -1; % Digital pulse task for scanning
        
        % Tilt
        tiltCorrectionEnable = false
        tiltThetaXZ = 0
        tiltThetaYZ = 0
        
        VALID_AXES
        POSITIVE_HARD_LIMITS
        NEGATIVE_HARD_LIMITS
    end
    
    methods (Static, Access = public)
        function obj = create(stageStruct)
            % Get instance constructor
            missingField = FactoryHelper.usualChecks(stageStruct, ClassStanda8SMC4_stages.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Trying to create the Standa 8SMC4 stage, needed field "%s" was missing. Aborting',...
                    missingField);
            end
            if isfield(stageStruct, 'pg_controlled') && stageStruct.pg_controlled
                triggerChannel = 'pulseGenerator';
            else
                triggerChannel = stageStruct.niDaqChannel;
            end
            
            removeObjIfExists(ClassStanda8SMC4_stages.NAME);

            addressStruct = stageStruct.address;
            axes = fieldnames(addressStruct);
            validAxes = '';
            address = cell(1, length(axes));
            for k = 1:length(axes)
                validAxes = [validAxes, axes{k}];
                address{k} = addressStruct.(axes{k});
            end
            obj = ClassStanda8SMC4_stages(lower(validAxes), address, triggerChannel);
        end
        
        function axis = GetAxisInternal(axisName)
            % Gives the axis number (0 for x, 1 for y, 2 for z) when the
            % user enters the axis name (x,y,z or 1 for x, 2 for y and 3
            % for z).
            axis = zeros(size(axisName));
            for i = 1:length(axisName)
                if ((strcmpi(axisName(i),'x')) || (axisName(i) == 1))
                    axis(i) = 1;
                elseif (axisName(i) == 'y') || (axisName(i) == 'Y') || (axisName(i) == 2)
                    axis(i) = 2;
                elseif (axisName(i) == 'z') || (axisName(i) == 'Z') || (axisName(i) == 3)
                    axis(i) = 3;
                else
                    error(['Unknown axis: ' axisName]);
                end
            end
        end
    end
    
    methods (Access = protected) % Protected Functions
        function obj = ClassStanda8SMC4_stages(availableAxes, address, triggerChannel)
            % name - string
            % availableAxes - string. example: "xyz"
            name = ClassStanda8SMC4_stages.NAME;
            
            obj@ClassStage(name, availableAxes)
            
            obj.availableAxes = availableAxes;
            obj.VALID_AXES = availableAxes;
            obj.availableProperties.(obj.HAS_FAST_SCAN) = false;
            obj.availableProperties.(obj.HAS_SLOW_SCAN) = true;
            
            obj.physicalAddress = address;
            obj.Connect;
            
            obj.availableProperties.(obj.HAS_FAST_SCAN) = false;
            obj.fastScan = 0;
            obj.tiltCorrectionEnable = 0;
            obj.tiltThetaXZ = 0;
            obj.tiltThetaYZ = 0;
            
            try
                obj.readStagesParameters;
                if ~strcmp(triggerChannel, 'pulseGenerator')
                    nidaq = getObjByName(NiDaq.NAME);
                    nidaq.registerChannel(triggerChannel, obj.name);
                else
                    obj.pgControlled = 1;
                end
                obj.triggerChannel = triggerChannel;
                
                Initialization(obj);
            catch err
                obj.CloseConnection;
                rethrow(err);
            end
        end
        
        function Connect(obj)
            %load librery if neded
            if ~libisloaded('libximc')
                addpath(fullfile([PathHelper.getPathToNvLab, '/Control code/Drivers/ximc/ximc-2.10.5/ximc/win64/wrappers/matlab/']));
                addpath(fullfile([PathHelper.getPathToNvLab, '/Control code/Drivers/ximc/ximc-2.10.5/ximc/win64/']));
                loadlibrary('libximc.dll',@ximcm);
                disp('libximc is now loaded')
            else
                disp('libximc is already loaded')
            end
            % connect to device
            obj.id = cell(1, length(obj.VALID_AXES));
            for k = 1:length(obj.VALID_AXES)
                device_name = sprintf('xi-com:\\\\.\\%s', obj.physicalAddress{k});
                obj.id{k} = calllib('libximc','open_device', device_name);
                if isempty(obj.id{k})
                    error('Could not connect to stage at %s', obj.physicalAddress{k});
                end
                fprintf('connected to stage in %s\n', obj.physicalAddress{k});
            end
        end
        
        function Close(obj)
            for k = 1:length(obj.VALID_AXES)
                device_id_ptr = libpointer('int32Ptr', obj.id{k});
                calllib('libximc','close_device', device_id_ptr);
                obj.id{k} = [];
                fprintf('STANDA stage %s disconnected - remove me when time comes\n', obj.VALID_AXES(k))
            end
        end
        
        function readStagesParameters(obj)
            % This function read the relevant parameters of the specific
            % stages used in the setup.
            
            N = length(obj.VALID_AXES);
            obj.countsPerTurn = zeros(1, N);
            obj.leadScrewPitch = zeros(1, N);
            obj.travelRange = zeros(1, N);
            obj.curVel = zeros(1, N);
            obj.curPos = zeros(1, N);
            obj.maxSpeed = zeros(1, N);
            obj.countsPerTurn = zeros(1, N);     % encoder counts per turn
            obj.stepsPerTurn = zeros(1, N);      % without encoder we use motor steps per turn
            obj.isEncoder = zeros(1, N);         % beelean. if there is encoder in the stage
            obj.negSoftRangeLimit = zeros(1, N);
            obj.posSoftRangeLimit = zeros(1, N);
            for k = 1:N
                try
                    % Engine settings:
                    engine_settings_t = struct('NomVoltage',1,'NomCurrent',1,'NomSpeed',1,...
                        'uNomSpeed',1,'EngineFlags',1,'Antiplay',1,'MicrostepMode',1','StepsPerRev',1);
                    engine_settings = obj.SendCommand('get_engine_settings', k, engine_settings_t);
                    obj.stepsPerTurn(k) = engine_settings.StepsPerRev;
                    
                    % Stage settings:
                    stage_settings_t = struct('LeadScrewPitch',2,'Units',100,'MaxSpeed',50,'TravelRange',360,...
                        'SupplyVoltageMin',12,'SupplyVoltageMax',36,'MaxCurrentConsumption',0,...
                        'HorizontalLoadCapacity',0,'VerticalLoadCapacity',0);
                    stage_settings = obj.SendCommand('get_stage_settings', k, stage_settings_t);
                    obj.leadScrewPitch(k) = stage_settings.LeadScrewPitch;
                    obj.travelRange(k) = stage_settings.TravelRange*1e3;
                    
                    % Feedback settings (in presence of encoder):
%                     encoder_information_t = struct('Manufacturer', 0, 'PartNumber', 0);
%                     encoder_information = obj.SendCommand('get_encoder_information', k, encoder_information_t);
%                     obj.isEncoder(k) = encoder_information.Manufacturer ~= 0;
%                     if obj.isEncoder(k)
%                         feedback_settings_t = struct('IPS',0,'FeedbackType',7,'FeedbackFlags',7);
%                         feedback_settings = obj.SendCommand('get_feedback_settings', k, feedback_settings_t);
%                         obj.countsPerTurn(k) = feedback_settings.IPS;
%                     end
                    feedback_settings_t = struct('IPS',0,'FeedbackType',7,'FeedbackFlags',7);
                    feedback_settings = obj.SendCommand('get_feedback_settings', k, feedback_settings_t);
                    obj.countsPerTurn(k) = feedback_settings.IPS;
                    obj.isEncoder(k) = feedback_settings.FeedbackType ~= 5;
                    
                    % Borders:
                    stage_edges_t = struct('BorderFlags',1,'EnderFlags',11,'LeftBorder',0,'uLeftBorder',0,...
                        'RightBorder',10,'uRightBorder',100);
                    stage_edges = obj.SendCommand('get_edges_settings', k, stage_edges_t);
                    obj.maxSpeed(k) = stage_settings.MaxSpeed*1e3;
                    obj.posSoftRangeLimit(k) = obj.stepsToValue(stage_edges.RightBorder, k)*1e3;
                    obj.negSoftRangeLimit(k) = obj.stepsToValue(stage_edges.LeftBorder, k)*1e3;
                    
                    %%% spscific stage with a problem - should be delete after fixing!! Yachel 05.09.21
                    units = char(stage_settings.Units);
                    if units~='m' && units~='d'
                        obj.countsPerTurn(k) = 200;
                        obj.leadScrewPitch(k) = 0.25;
                        obj.travelRange(k) = 30*1e3;
                        obj.isEncoder(k) = 0;
%                         obj.speed = 1.25;
                        obj.maxSpeed(k) = 5*1e3;
                        obj.posSoftRangeLimit(k) = 14*1e3;
                        obj.negSoftRangeLimit(k) = -14*1e3;
                    end
                    %%%
                    
                catch errr
                    obj.Close();
                    rethrow(errr)
                end

            end
            
            obj.QueryVel;
            obj.QueryPos;
            obj.NEGATIVE_HARD_LIMITS = -obj.travelRange/2;
            obj.POSITIVE_HARD_LIMITS =  obj.travelRange/2;
        end
        
        function res_struct = GetStageStatus(obj, k)
            % here is a trick.
            % we need to init a struct with any real field from the header.
            dummy_struct = struct('Flags',999);
            parg_struct = libpointer('status_t', dummy_struct);
            [err, res_struct] = calllib('libximc','get_status', obj.id{k}, parg_struct);
            obj.testErr(err);
        end
        
        function full_res_struct = GetStatus(obj)
            full_res_struct = cell(1, length(obj.VALID_AXES));
            for k = 1:length(obj.VALID_AXES)
                full_res_struct{k} = obj.GetStageStatus(k);
            end
        end
        
        function Delay(obj, seconds) %#ok<INUSL>
            % Pauses for the given seconds.
            delay = tic;
            while toc(delay) < seconds
            end
        end
        
        function CommunicationDelay(obj)
            % Pauses for obj.commDelay seconds.
            obj.Delay(obj.COMM_DELAY);
        end
        
        function value = stepsToValue(obj, steps, k)
            if obj.isEncoder(k)
                value = steps*obj.leadScrewPitch(k)/obj.countsPerTurn(k);  
            else
                value = steps*obj.leadScrewPitch(k)/obj.stepsPerTurn(k);  
            end                
        end
        
        function steps = valueToSteps(obj, value, k)
            if obj.isEncoder(k)
                steps = value*obj.countsPerTurn(k)/obj.leadScrewPitch(k);  
            else
                steps = value*obj.stepsPerTurn(k)/obj.leadScrewPitch(k);  
            end                
        end

        function boardersCalibration(obj)
            % This function takes all the stages to the physical limits and
            % zero them in the middle of the travel range.
            prompt = 'The operation will take the stages to their limits, make sure the space is free. To continue write ''yes''\n';
            inputStr = input(prompt);
            if strcmp(inputStr, 'yes')
                for k = 1:length(obj.availableAxes)
                    fprintf('Calibrating axis %s... ', obj.availableAxes(k));
                    obj.Calibrate(k);
                    fprintf('Done!\n');
                end
            end
        end
        
        function structOut = SendCommand(obj, command, axisNumber, structIn)
            % Send the command to the controller and returns the output.
            [err, structOut] = calllib('libximc',command, obj.id{axisNumber}, structIn);
            obj.testErr(err)
        end
                
        function axisIndex = GetAxisIndex(obj, phAxis)
            % Converts x,y,z into the corresponding index for this
            % controller; if stage only has 'z' then z is 1.
            phAxis = GetAxis(obj, phAxis);
            CheckAxis(obj, phAxis)
            axisIndex = zeros(size(phAxis));
            for i = 1:length(phAxis)
                idx = phAxis(i);
                if idx > length(obj.availableAxes)
                    obj.sendError('Invalid axis')
                end
                axisIndex(i) = idx;
            end
        end
        
        function CheckAxis(obj, phAxis)
            % Checks that the given axis matches the connected stage.
            % 'phAxis' can be either a specific axis (x,y,z or 1 for x,
            % 2 for y, and 3 for z) or any vectorial combination of them.
            phAxis = obj.GetAxis(phAxis);
            if ~isempty(setdiff(phAxis, GetAxis(obj, obj.VALID_AXES)))
                if isscalar(phAxis)
                    string = 'axis is';
                else
                    string = 'axes are';
                end
                obj.sendError(sprintf('%s %s invalid for this setup.', upper(obj.SCAN_AXES(phAxis)), string));
            end
        end
        
        
        
        
        
        
        
%         function CheckReference(obj, phAxis)
%             % Checks whether the given (physical) axis is referenced, 
%             % and if not, asks for confirmation to reference it.
%             phAxis = GetAxis(obj, phAxis);
%             referenced = IsRefernced(obj, phAxis);
%             if all(referenced)
%                 % We are done
%                 return
%             end
%             
%             % Otherwise
%             unreferncedAxesNames = obj.VALID_AXES(phAxis(~referenced));
%             if isscalar(unreferncedAxesNames)
%                 questionStringPart1 = sprintf('WARNING!\n%s axis is unreferenced.\n', unreferncedAxesNames);
%             else
%                 questionStringPart1 = sprintf('WARNING!\n%s axes are unreferenced.\n', unreferncedAxesNames);
%             end
%             % Ask for user confirmation
%             questionStringPart2 = sprintf('Stages must be referenced before use.\nThis will move the stages.\nPlease make sure the movement will not cause damage to the equipment!');
%             questionString = [questionStringPart1 questionStringPart2];
%             titleString = 'Referencing Confirmation';
%             referenceString = 'Reference';
%             referenceCancelString = 'Cancel';
%             confirm = questdlg(questionString, titleString, referenceString, referenceCancelString, referenceCancelString);
%             switch confirm
%                 case referenceString
%                     Refernce(obj, unreferncedAxesNames)
%                 case referenceCancelString
%                     obj.sendError(sprintf('Referencing cancelled for controller MCS2: %s', ...
%                         unreferncedAxesNames));
%                 otherwise
%                     obj.sendError(sprintf('Referencing failed for controller MCS2: %s - No user confirmation was given', ...
%                         unreferncedAxesNames));
%             end
%         end
%         
%         function tf = IsRefernced(obj, phAxis)
%             % Check reference status for the given axis.
%             % 'phAxis' can be either a specific axis (x,y,z or 1 for x, 2 for y
%             % and 3 for z) or any vectorial combination of them.
%             len = length(phAxis);
%             tf = false(1, len);
%             realAxis = obj.GetAxisIndex(phAxis);
%             
%             for i = 1:length(realAxis)
%                 chState = obj.getChannelState(realAxis(i));
%                 tf(i) = bitget(chState, 8);     % Bit 7, if we count from 0
%             end
%             tf = logical(tf);
%         end
%         
%         function Refernce(obj, phAxis)
%             % Reference the given axis.
%             % 'phAxis' can be either a specific axis (x,y,z or 1 for x, 2 for y
%             % and 3 for z) or any vectorial combination of them.
%             CheckAxis(obj, phAxis)
%             realAxis = GetAxisIndex(obj, phAxis);
%             
%             len = length(realAxis);
%             for i = 1:len
%                 SendCommand(obj, 'SA_CTL_Reference', obj.id, realAxis(i), 0);
%             end
%             for i = 1:len
%                 WaitFor(obj, 'ReferencingDone', phAxis(i))
%             end
%             isRef = IsRefernced(obj, phAxis);
%             
%             % Check if ready & if referenced succeeded
%             if (~all(isRef))
%                 obj.sendError(sprintf('Referencing failed for controller MCS2 with ID %d: Reason unknown.', ...
%                     obj.id));
%             end
%         end
%         
%         function CheckCalibration(obj, phAxis)
%             % Checks whether the given (physical) axis is calibrated, 
%             % and if not, asks for confirmation to calibrate it.
%             phAxis = GetAxis(obj, phAxis);
%             calibrated = IsCalibrated(obj, phAxis);
%             if all(calibrated)
%                 % We are done
%                 return
%             end
%             
%             % Otherwise
%             uncalibratedAxesNames = obj.VALID_AXES(phAxis(~calibrated));
%             if isscalar(uncalibratedAxesNames)
%                 questionStringPart1 = sprintf('WARNING!\n%s axis is uncalibrated.\n', uncalibratedAxesNames);
%             else
%                 questionStringPart1 = sprintf('WARNING!\n%s axes are uncalibrated.\n', uncalibratedAxesNames);
%             end
%             % Ask for user confirmation
%             questionStringPart2 = sprintf('Stages should be calibrated before use.\nThis will move the stages.\nPlease make sure the movement will not cause damage to the equipment!');
%             questionString = [questionStringPart1 questionStringPart2];
%             titleString = 'Calibration Confirmation';
%             calibrateString = 'Calibrate';
%             calibrateCancelString = 'Cancel';
%             confirm = questdlg(questionString, titleString, calibrateString, calibrateCancelString, calibrateCancelString);
%             switch confirm
%                 case calibrateString
%                     Calibrate(obj, uncalibratedAxesNames)
%                 case calibrateCancelString
%                     obj.sendWarning(sprintf('Calibration cancelled for controller MCS2: %s', ...
%                         uncalibratedAxesNames));
%                 otherwise
%                     obj.sendWarning(sprintf('Calibration failed for controller MCS2: %s - No user confirmation was given', ...
%                         uncalibratedAxesNames));
%             end
%         end
%         
%         function tf = IsCalibrated(obj, phAxis)
%             % Check reference status for the given axis.
%             % 'phAxis' can be either a specific axis (x,y,z or 1 for x, 2 for y
%             % and 3 for z) or any vectorial combination of them.
%             len = length(phAxis);
%             tf = false(1, len);
%             realAxis = obj.GetAxisIndex(phAxis);
%             
%             for i = 1:length(realAxis)
%                 chState = obj.getChannelState(realAxis(i));
%                 tf(i) = bitget(chState, 7);     % Bit 6, if we count from 0
%             end
%             tf = logical(tf);
%         end
%         
        function Calibrate(obj, phAxis)
            % Reference the given axis.
            % 'phAxis' can be either a specific axis (x,y,z or 1 for x, 2 for y
            % and 3 for z) or any vectorial combination of them.
            CheckAxis(obj, phAxis)
            realAxis = GetAxisIndex(obj, phAxis);
            
%                 SendCommand(obj, 'SA_CTL_Calibrate', obj.id, realAxis(i), 0);
%                 WaitFor(obj, 'CalibratingDone', phAxis(i))
%             isCalib = IsCalibrated(obj, phAxis);
%             
%             % Check if ready & if calibration succeeded
%             if (~all(isCalib))
%                 obj.sendError(sprintf('Calibration failed for controller MCS2 with ID %d: Reason unknown.', ...
%                     obj.id));
%             end
        end
        
        function Initialization(obj)
            % Checks
%             CheckCalibration(obj, obj.VALID_AXES)
%             CheckReference(obj, obj.VALID_AXES)
            
            % Set velocity
            obj.SetVelocity(obj.VALID_AXES, zeros(size(obj.VALID_AXES))+obj.defaultVel);
            
            % Update position and velocity
            QueryPos(obj);
            QueryVel(obj);
            for i = 1:length(obj.VALID_AXES)
                fprintf('%s axis - Position: %.4f%s, Velocity: %d%s/s.\n', upper(obj.VALID_AXES(i)), obj.curPos(i), obj.UNITS, obj.curVel(i), obj.UNITS);
            end
        end
        
        function QueryPos(obj)
            % Queries the position and updates the internal variable.
            for k = 1:length(obj.VALID_AXES)
                get_position_calt_t = struct('Position',1,'uPosition', 1, 'EncPosition', 1);
                get_position_calt = obj.SendCommand('get_position', k, get_position_calt_t);
                pos = obj.stepsToValue(get_position_calt.Position + get_position_calt.uPosition/256, k);
                obj.curPos(k) = pos * 1e3; % Convert from mm to um
            end
        end
        
        function QueryVel(obj)
            % Queries the velocity and updates the internal variable.
            for k = 1:length(obj.VALID_AXES)
                move_settings_calb_t = struct('Speed', 0, 'Accel', 0, 'Decel', 0, 'AntiplaySpeed', 0);
                move_settings_calb = obj.SendCommand('get_move_settings', k, move_settings_calb_t);
                vel = obj.stepsToValue(move_settings_calb.Speed, k);
                obj.curVel(k) = vel * 1e3; % Convert from mm/s to um/s
            end
        end
        
        function WaitFor(obj, what, phAxis)
            % Waits until a specific action, defined by what, is finished.
            % 'phAxis' must a specific (physical) axis (x,y,z or 
            % 1 for x, 2 for y and 3 for z).
            % Current options for 'what':
            % MovementDone - Waits until movement is done.
            % ReferencingDone - waits until referencing is done.
            % WaveGeneratorDone - Waits until the wave generator is done.
            % for now - all of them checked for movement done!
            CheckAxis(obj, phAxis);
            realAxis = GetAxisIndex(obj, phAxis);
                
            timer = tic;
            timeout = 60; % 60 second timeout
            wait = true;
            while wait
                drawnow % Needed in order to get input from GUI
                if obj.forceStop % Checks if the user pressed the Halt Button
                    HaltPrivate(obj, phAxis);
                    break;
                end
                
                switch what
                    case 'MovementDone'
                        chState = GetStageStatus(obj, realAxis);
                        isMoving = chState.MoveSts;
                        wait = isMoving;
                    case 'CalibratingDone'
                        chState = GetStageStatus(obj, realAxis);
                        isMoving = chState.MoveSts;
                        wait = isMoving;
                    case 'ReferencingDone'
                        chState = GetStageStatus(obj, realAxis);
                        isMoving = chState.MoveSts;
                        wait = isMoving;
                    otherwise
                        obj.sendError(sprintf('Wrong Input %s', what));
                end
                
                if (toc(timer) > timeout)
                    obj.sendWarning(sprintf('Warning, timed out while waiting for controller status: "%s"', what));
                    break
                end
            end
        end
        
        function MovePrivate(obj, phAxis, pos)
            % Absolute change in position (pos) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            % Does not check if scan is running.
            % Does not move if HaltStage was triggered.
            % This function is the one used by all internal functions.
            CheckAxis(obj, phAxis)
            
            if obj.forceStop % Doesn't move if forceStop is enabled
                return
            end
            
            if obj.tiltCorrectionEnable
                [phAxis, pos] = TiltCorrection(phAxis, pos);
            end
            
            if ~PointIsInRange(obj, phAxis, pos) % Check that point is in limits
                obj.sendError('Move Command is outside the soft limits');
            end
            
%             CheckReference(obj, phAxis)
            
            % Convert position to mm, which are the units the stage recieves
            pos = pos * 1e-3;
            
            % Send the move command
            for i = 1:length(phAxis)
                realAxes = obj.GetAxisInternal(phAxis(i));
                setPositionPoints = floor(obj.valueToSteps(pos(i), realAxes));
                set_uPosition = round((obj.valueToSteps(pos(i), realAxes) - setPositionPoints) * 256);
                if set_uPosition == 256
                    setPositionPoints = setPositionPoints + 1;
                    set_uPosition = 0;
                end
                [err] = calllib('libximc','command_move', obj.id{realAxes}, setPositionPoints, set_uPosition);
                obj.testErr(err);
                WaitFor(obj, 'MovementDone', realAxes)
            end
        end

        function HaltPrivate(obj, phAxis)
            % Halts the stage.
            realAxes = GetAxisIndex(obj, phAxis);
            for i = 1:length(realAxes)
                obj.SendCommand('command_stop', realAxis(i), []);
            end
            obj.AbortScan;
            obj.sendWarning('Stage Halted!');
        end
        
        function SetVelocityPrivate(obj, phAxis, vel)
            % Absolute change in velocity (vel) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Does not check if scan is running.
            % Vectorial axis is possible.
            CheckAxis(obj, phAxis)
            vel = vel * 1e-3; % Convert from um/s to mm/s
            for i = 1:length(phAxis)
                realAxis = GetAxisIndex(obj, phAxis(i));
                move_settings_calb_t = struct('Speed', 0, 'Accel', 0, 'Decel', 0, 'AntiplaySpeed', 0);
                move_settings_calb = obj.SendCommand('get_move_settings', realAxis, move_settings_calb_t);
                move_settings_calb.Speed = obj.valueToSteps(vel(i), realAxis);
                obj.SendCommand('set_move_settings', realAxis, move_settings_calb);
            end
        end
        
        function [phAxis, pos] = TiltCorrection(obj, phAxis, pos)
            % Corrects the movement axis & pos vectors according to the 
            % tilt angles: If x and/or y axes are given, then z also moves
            % according the tilt angles.
            % However, if also or only z axis is given, then no changes
            % occurs.
            % Assumes the stage has all three xyz axes.
            phAxis = GetAxis(obj, phAxis);
            if ~contains(obj.SCAN_AXES(phAxis), 'z') % Only do something if there is no z axis
                QueryPos(obj);
                pos = [pos, obj.curPos(3)]; % Adds the z position command, start by writing the current position (as the base)
                for i=1:length(phAxis)
                    switch obj.SCAN_AXES(phAxis)
                        case 'x'
                            dx = pos(i) - obj.curPos(1);
                            pos(end) = pos(end) + dx*tan(obj.tiltThetaXZ*pi/180); % Adds movements according to the angles
                        case 'y'
                            dy = pos(i) - obj.curPos(2);
                            pos(end) = pos(end) + dy*tan(obj.tiltThetaYZ*pi/180); % Adds movements according to the angles
                    end
                end
                phAxis = [phAxis, 3]; % Add Z axis at the end
            end
        end
    end
    
    methods (Access = public)
        function CloseConnection(obj)
            % Closes the connection to the controllers.
            for k = 1:length(obj.VALID_AXES)
                device_id_ptr = libpointer('int32Ptr', obj.id{k});
                calllib('libximc','close_device', device_id_ptr);
                obj.id{k} = [];
                fprintf('STANDA stage %s disconnected\n', obj.VALID_AXES(k))
            end
        end
        
        function delete(obj)
            obj.CloseConnection;
        end
        
        function Reconnect(obj)
            % Reconnects the controller.
            CloseConnection(obj);
            Connect(obj);
            Initialization(obj);
        end
        
        function ok = PointIsInRange(obj, phAxis, point)
            % Checks if the given point is within the soft (and hard)
            % limits of the given axis (x,y,z or 1 for x, 2 for y and 3 for z).
            % Vectorial axis is possible.
            CheckAxis(obj, phAxis)
            axisIndex = GetAxis(obj, phAxis);
            ok = all((point >= obj.negSoftRangeLimit(axisIndex)) & (point <= obj.posSoftRangeLimit(axisIndex)));
        end
        
        function [negSoftLimit, posSoftLimit] = ReturnLimits(obj, phAxis)
            % Return the soft limits of the given axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            CheckAxis(obj, phAxis)
            axisIndex = GetAxis(obj, phAxis);
            negSoftLimit = obj.negSoftRangeLimit(axisIndex);
            posSoftLimit = obj.posSoftRangeLimit(axisIndex);
        end
        
        function [negHardLimit, posHardLimit] = ReturnHardLimits(obj, phAxis)
            % Return the hard limits of the given axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            CheckAxis(obj, phAxis)
            axisIndex = GetAxis(obj, phAxis);
            negHardLimit = obj.NEGATIVE_HARD_LIMITS(axisIndex);
            posHardLimit = obj.POSITIVE_HARD_LIMITS(axisIndex);
        end
        
        function SetSoftLimits(obj, phAxis, softLimit, negOrPos)
            % Set the new soft limits:
            % if negOrPos = 0 -> then softLimit = lower soft limit
            % if negOrPos = 1 -> then softLimit = higher soft limit
            % This is because each time this function is called only one of
            % the limits updates
            CheckAxis(obj, phAxis)
            axisIndex = GetAxis(obj, phAxis);
            if ((softLimit >= obj.NEGATIVE_HARD_LIMITS(axisIndex)) && (softLimit <= obj.POSITIVE_HARD_LIMITS(axisIndex)))
                if negOrPos == 0
                    obj.negSoftRangeLimit(axisIndex) = softLimit;
                else
                    obj.posSoftRangeLimit(axisIndex) = softLimit;
                end
            else
                obj.sendError(sprintf('Soft limit %.4f is outside of the hard limits %.4f - %.4f', ...
                    softLimit, obj.NEGATIVE_HARD_LIMITS(axisIndex), obj.POSITIVE_HARD_LIMITS(axisIndex)))
            end
        end
        
        function pos = Pos(obj, phAxis)
            % Query and return position of axis (x,y,z or 1 for x, 2 for y
            % and 3 for z)
            % Vectorial axis is possible.
            CheckAxis(obj, phAxis)
            QueryPos(obj);
            axisIndex = GetAxis(obj, phAxis);
            pos = obj.curPos(axisIndex);
        end
        
        function vel = Vel(obj, phAxis)
            % Query and return velocity of axis (x,y,z or 1 for x, 2 for y
            % and 3 for z)
            % Vectorial axis is possible.
            CheckAxis(obj, phAxis)
            QueryVel(obj);
            axisIndex = GetAxis(obj, phAxis);
            vel = obj.curVel(axisIndex);
        end
        
        function Move(obj, phAxis, pos)
            % Absolute change in position (pos) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            % Checks that a scan is not currently running and whether
            % HaltStage was triggered.
            if obj.scanRunning
                obj.sendWarning(obj.WARNING_PREVIOUS_SCAN_CANCELLED);
                obj.AbortScan;
            end
            
            if obj.forceStop % Ask for user confirmation if forcestop was triggered
                questionString = sprintf('Stages were forcefully halted!\nAre you sure you want to move?');
                yesString = 'Yes';
                noString = 'No';
                confirm = questdlg(questionString, 'Movement Confirmation', yesString, noString, yesString);
                switch confirm
                    case yesString
                        obj.forceStop = 0;
                    case noString
                        obj.sendWarning('Movement aborted!')
                        return;
                    otherwise
                        obj.sendWarning('Movement aborted!')
                        return;
                end
            end
            
            obj.MovePrivate(phAxis, pos);
        end
        
        function RelativeMove(obj, phAxis, change)
            % Relative change in position (pos) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            if obj.scanRunning
                obj.sendWarning(obj.WARNING_PREVIOUS_SCAN_CANCELLED);
                AbortScan(obj);
            end
            CheckAxis(obj, phAxis)
            QueryPos(obj);
            axisIndex = GetAxis(obj, phAxis);
            Move(obj, phAxis, obj.curPos(axisIndex) + change);
        end
        
        function Halt(obj)
            % Halts all stage movements.
            % This works by setting the parameter below to 1, which is
            % checked inside the "WaitFor" function. When the WaitFor is
            % triggered, is calls an internal function, "HaltPrivate", which
            % immediately sends a halt command to the controller.
            % Afterwards it also tries to abort scan. The reason abort scan
            % happens afterwards is to minimize the time it takes to
            % send the halt command to the controller.
            % This parameters also denies the "MovePrivate" command from
            % running.
            % It is reset by a normal/relative "Move Command", which will
            % be triggered whenever a new external move or scan command is
            % sent to the stage.
            obj.forceStop = 1;
        end
        
        function SetVelocity(obj, phAxis, vel)
            % Absolute change in velocity (vel) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            if obj.scanRunning
                obj.sendWarning('2D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            
            CheckAxis(obj, phAxis)
            SetVelocityPrivate(obj, phAxis, vel);
        end
        
        function ScanX(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% ONE DIMENSIONAL X SCAN MACRO %%%%%%%%%%%%%%
            % Does a macro scan for x axis.
            % x - A vector with the points to scan, points should have
            % equal distance between them.
            % y/z - The starting points for the other axes.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if obj.scanRunning
                obj.sendWarning('2D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            Move(obj, 'yz', [y z]);
            ScanOneDimension(obj, x, nFlat, nOverRun, tPixel, 'x');
            QueryPos(obj);
        end
        
        function ScanY(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% ONE DIMENSIONAL Y SCAN MACRO %%%%%%%%%%%%%%
            % Does a macro scan for y axis.
            % y - A vector with the points to scan, points should have
            % equal distance between them.
            % x/z - The starting points for the other axes.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if obj.scanRunning
                obj.sendWarning('2D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            Move(obj, 'xz', [x z]);
            ScanOneDimension(obj, y, nFlat, nOverRun, tPixel, 'y');
            QueryPos(obj);
        end
        
        function ScanZ(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% ONE DIMENSIONAL Z SCAN MACRO %%%%%%%%%%%%%%
            % Does a macro scan for z axis.
            % z - A vector with the points to scan, points should have
            % equal distance between them.
            % x/y - The starting points for the other axes.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if obj.scanRunning
                obj.sendWarning('2D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            Move(obj, 'xy', [x y]);
            ScanOneDimension(obj, z, nFlat, nOverRun, tPixel, 'z');
            QueryPos(obj);
        end
        
        function PrepareScanX(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%%%%% ONE DIMENSIONAL X SCAN %%%%%%%%%%%%%%%%%
            % Prepares a scan for X axis, writes the waveform and 
            % initializes the DDL function.
            % x - A vector with the points to scan, points should have
            % equal distance between them.
            % y/z - The starting points for the other axes.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if obj.scanRunning
                warning(obj.WARNING_PREVIOUS_SCAN_CANCELLED);
                AbortScan(obj);
            end
            Move(obj, 'yz', [y z]);
            PrepareScanInOneDimension(obj, x, nFlat, nOverRun, tPixel, 'x');
            QueryPos(obj);
        end
        
        function PrepareScanY(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%%%%% ONE DIMENSIONAL Y SCAN %%%%%%%%%%%%%%%%%
            % Prepares a scan for Y axis, writes the waveform and 
            % initializes the DDL function.
            % y - A vector with the points to scan, points should have
            % equal distance between them.
            % x/z - The starting points for the other axes.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if obj.scanRunning
                warning(obj.WARNING_PREVIOUS_SCAN_CANCELLED);
                AbortScan(obj);
            end
            Move(obj, 'xz', [x z]);
            PrepareScanInOneDimension(obj, y, nFlat, nOverRun, tPixel, 'y');
            QueryPos(obj);
        end
        
        function PrepareScanZ(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%%%%% ONE DIMENSIONAL Z SCAN %%%%%%%%%%%%%%%%%
            % Prepares a scan for Z axis, writes the waveform and 
            % initializes the DDL function.
            % z - A vector with the points to scan, points should have
            % equal distance between them.
            % x/y - The starting points for the other axes.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if obj.scanRunning
                warning(obj.WARNING_PREVIOUS_SCAN_CANCELLED);
                AbortScan(obj);
            end
            Move(obj, 'xy', [x y]);
            PrepareScanInOneDimension(obj, z, nFlat, nOverRun, tPixel, 'z');
            QueryPos(obj);
        end
        
        
        
        
        
        
        
        
        
        
        function PrepareScanInOneDimension(obj, scanAxisVector, nFlat, nOverRun, tPixel, scanAxis) %#ok<INUSL>
            % Prepares a one dimensional scan, writes the waveform and 
            % initializes the DDL function.
            % scanAxisVector - A vector with the points to scan, points
            % should increase with equal distances between them.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel (in seconds).
            % scanAxis - The axis to scan (x,y,z or 1 for x, 2 for y and 3
            % for z).
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Get parameters
            scanAxis = GetAxis(obj, scanAxis);
            
%             if (nOverRun < 10); nOverRun = 10; end % In order to be centered around the pixel we need at least one extra point from each side, and it's 2 because negative direction has a bug
            
            
            numberOfPixels = length(scanAxisVector); % This is the number of pixels
            pixelSizeInum = (scanAxisVector(end) - scanAxisVector(1))/(numberOfPixels-1); % Will be negative if scanning in reverse
            nOverRunInum = pixelSizeInum*nOverRun; % Can be negative if scanning in reverse
            startPointInum = scanAxisVector(1)-nOverRunInum;
            endPointInum = scanAxisVector(end)+nOverRunInum;
            
            maxPointInum = max(endPointInum, startPointInum);    
            minPointInum = min(endPointInum, startPointInum);
            if maxPointInum > obj.posSoftRangeLimit(scanAxis) || minPointInum < obj.negSoftRangeLimit(scanAxis)
                obj.sendError(sprintf('Scan is outside the limits: scan overhead requires adding an additional pixel from each side which increase the scan from %.3f %s to %.3f %s\n', startPointInum, StringHelper.MICRON, endPointInum, StringHelper.MICRON));
            end
            
            obj.macroScanAxis = scanAxis;
            obj.macrotPixel = tPixel;
            obj.macroScanVector = scanAxisVector;
            obj.macroScanStartEndVector = [startPointInum, endPointInum];
            obj.macroScanPixelSizeInum = pixelSizeInum;
            
            % Move to starting position, might be redundant sometimes, but
            % is used in some cases.
            MovePrivate(obj, scanAxis, startPointInum);
        end
        
        function ScanOneDimension(obj, scanAxisVector, nFlat, nOverRun, tPixel, scanAxis)  %#ok<INUSL>
            %%%%%%%%%%%%%% ONE DIMENSIONAL SCAN %%%%%%%%%%%%%%
            % Does a scan for the given axis.
            % Last 2 variables are for 2D scans.
            % scanAxisVector - A vector with the points to scan, points
            % should increase with equal distances between them.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel (in seconds).
            % scanAxis - The axis to scan (x,y,z or 1 for x, 2 for y and 3
            % for z).
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            scanAxis = GetAxis(obj, scanAxis);
            nidaq = getObjByName(NiDaq.NAME);
            obj.digitalPulseTask = nidaq.prepareDigitalOutputTask(obj.triggerChannel);
            
            line = obj.triggerChannel(end);     % For example, if the channel is 'PFI3', we want the line to be '3'
            for i = 1:length(scanAxisVector)
                Move(obj, scanAxis, scanAxisVector(i));
                nidaq.writeDigitalOnce(obj.digitalPulseTask, 1, line);
                pause(obj.macrotPixel);
                nidaq.writeDigitalOnce(obj.digitalPulseTask, 0, line);
            end
            obj.SetVelocity(obj.macroScanAxis, obj.defaultVel);
        end
        
        function PrepareScanXY(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XY SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xy axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % x/y - Vectors with the points to scan, points should have
            % equal distance between them.
            % z - The starting points for the other axis.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if obj.scanRunning
                obj.sendWarning('2D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            Move(obj, 'z', z);
            PrepareScanInTwoDimensions(obj, x, y, nFlat, nOverRun, tPixel, 'x', 'y');
            QueryPos(obj);
        end
        
        function PrepareScanXZ(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xz axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % x/z - Vectors with the points to scan, points should have
            % equal distance between them.
            % y - The starting points for the other axis.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if obj.scanRunning
                obj.sendWarning('2D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            Move(obj, 'y', y);
            PrepareScanInTwoDimensions(obj, x, z, nFlat, nOverRun, tPixel, 'x', 'z');
            QueryPos(obj);
        end
        
        function PrepareScanYX(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XY SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xy axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % x/y - Vectors with the points to scan, points should have
            % equal distance between them.
            % z - The starting points for the other axis.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if obj.scanRunning
                obj.sendWarning('2D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            Move(obj, 'z', z);
            PrepareScanInTwoDimensions(obj, y, x, nFlat, nOverRun, tPixel, 'y', 'x');
            QueryPos(obj);
        end
        
        function PrepareScanYZ(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL YZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for yz axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % y/z - Vectors with the points to scan, points should have
            % equal distance between them.
            % x - The starting points for the other axis.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if obj.scanRunning
                obj.sendWarning('2D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            Move(obj, 'x', x);
            PrepareScanInTwoDimensions(obj, y, z, nFlat, nOverRun, tPixel, 'y', 'z');
            QueryPos(obj);
        end
        
        function PrepareScanZX(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xz axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % x/z - Vectors with the points to scan, points should have
            % equal distance between them.
            % y - The starting points for the other axis.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if obj.scanRunning
                obj.sendWarning('2D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            Move(obj, 'y', y);
            PrepareScanInTwoDimensions(obj, z, x, nFlat, nOverRun, tPixel, 'z', 'x');
            QueryPos(obj);
        end
        
        function PrepareScanZY(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL YZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for yz axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % y/z - Vectors with the points to scan, points should have
            % equal distance between them.
            % x - The starting points for the other axis.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if obj.scanRunning
                obj.sendWarning('2D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            Move(obj, 'x', x);
            PrepareScanInTwoDimensions(obj, z, y, nFlat, nOverRun, tPixel, 'z', 'y');
            QueryPos(obj);
        end
        
        function PrepareScanInTwoDimensions(obj, macroScanAxisVector, normalScanAxisVector, nFlat, nOverRun, tPixel, macroScanAxis, normalScanAxis) 
            %%%%%%%%%%%%%% TWO DIMENSIONAL SCAN MACRO %%%%%%%%%%%%%%
            % Does a macro scan for given axes!
            % scanAxisVector1/2 - Vectors with the points to scan, points
            % should increase with equal distances between them.
            % nFlat - How many flat points should be in the beginning of the scan.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            % scanAxis1/2 - The axes to scan (x,y,z or 1 for x, 2 for y and
            % 3 for z).
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            numberOfMacroPixels = length(macroScanAxisVector);
            numberOfNormalPixels = length(normalScanAxisVector);
            
            % Prepare Scan
            obj.macroPixelTime = tPixel;
            obj.macroNumberOfPixels = numberOfNormalPixels;
            obj.macroScanVector = macroScanAxisVector;
            obj.macroScanAxis = macroScanAxis;
            obj.macroNormalScanAxis = normalScanAxis;
            obj.macroNormalScanVector = normalScanAxisVector;
            obj.macroIndex = 1;
            obj.macroScanStartEndVector = macroScanAxisVector([1, end]);
            
            obj.PrepareScanInOneDimension(macroScanAxisVector, nFlat, nOverRun, tPixel, macroScanAxis);
            obj.Move([normalScanAxis, macroScanAxis], [normalScanAxisVector(1), macroScanAxisVector(1)]);
        end
        
        function [forwards, done] = ScanNextLine(obj)
            % Scans the next line for the 2D scan, to be used after
            % 'PrepareScanXX'.
            % No other commands should be used between 'PrepareScanXX' or
            % until 'AbortScan' has been called.
            % forwards is set to 1 when the scan is forward and is set to 0
            % when it's backwards
            if ~obj.scanRunning
                obj.sendError('No scan detected.\nFunction can only be called after ''PrepareScanXX!''');
            end
            
            % Scan
            MovePrivate(obj, obj.macroNormalScanAxis, obj.macroNormalScanVector(obj.macroIndex));
            if mod(obj.macroIndex, 2) % Odd scans, start from 1 and go to 2
                forwards = 1;
                ScanOneDimension(obj, obj.macroScanVector, 0, 0, obj.macroPixelTime, obj.macroScanAxis)
            else % Even scans, start from 2 and go to 1
                forwards = 0;
                % ScanOneDimension(obj, flip(obj.macroScanVector), 0, 0, obj.macroPixelTime, obj.macroScanAxis)
                ScanOneDimension(obj, obj.macroScanVector, 0, 0, obj.macroPixelTime, obj.macroScanAxis)         % Changes by Yachel temporarly because of drift between the scan directions 22.02.24
            end
            done = (obj.macroIndex == obj.macroNumberOfPixels);
            obj.macroIndex = obj.macroIndex + 1;
        end
        
        function PrepareRescanLine(obj)
            % Prepares the previous line for rescanning.
            % Scanning is done with "ScanNextLine"
            if ~obj.scanRunning
                obj.sendWarning('No scan detected. Function can only be called after ''PrepareScanXX!''.\nThis will work if attempting to rescan a 1D scan, but macro will be rewritten.\n');
                return
            elseif (obj.macroIndex == 1)
                obj.sendError('Scan did not start yet. Function can only be called after ''ScanNextLine!''');
            end
            
            % Decrease index
            obj.macroIndex = obj.macroIndex - 1;
            
            % Go to start point
            if mod(obj.macroIndex, 2) % Odd scans, start from 1 and go to 2
                MovePrivate(obj, obj.macroScanAxis, obj.macroScanStartEndVector(1));
            else % Even scans, start from 2 and go to 1
                MovePrivate(obj, obj.macroScanAxis, obj.macroScanStartEndVector(2));
            end
        end
        
        function AbortScan(obj)
            % Aborts the 2D scan defined by 'PrepareScanXX';
            if obj.scanRunning
                obj.macroIndex = -1;
                obj.scanRunning = 0;
            end
        end
        
         function [tiltEnabled, thetaXZ, thetaYZ] = GetTiltStatus(obj)
            % Return the status of the tilt control.
            tiltEnabled = obj.tiltCorrectionEnable;
            thetaXZ = obj.tiltThetaXZ;
            thetaYZ = obj.tiltThetaYZ;
          end 
        
        function JoystickControl(obj, enable) %#ok<INUSD>
            % Changes the joystick state for all axes to the value of
            % 'enable' - 1 to turn Joystick on, 0 to turn it off.
            obj.sendWarning(sprintf('No joystick support for the %s controller.\n', obj.controllerModel));
        end
        
        function binaryButtonState = ReturnJoystickButtonState(obj)
            % Returns the state of the buttons in 3 bit decimal format.
            % 1 for first button, 2 for second and 4 for the 3rd.
            obj.sendWarning(sprintf('No joystick support for the %s controller.\n', obj.controllerModel));
            binaryButtonState = 0;
        end
        
        function maxScanSize = ReturnMaxScanSize(obj, nDimensions)
            % Returns the maximum number of points allowed for an
            % 'nDimensions' scan.
            maxScanSize = obj.MAX_SCAN_SIZE;
        end
        
        function ChangeLoopMode(obj, mode)
            % Changes between closed and open loop.
            % 'mode' should be either 'Open' or 'Closed'.
            % Stage will auto-lock when in open mode, which should increase
            % stability.
            error('Standa stage cannot chnage loop mode!')
        end
        
        function FastScan(obj, enable)
            % Changes the scan between fast & slow mode
            % 'enable' - 1 for fast scan, 0 for slow scan.
            if enable
                obj.sendWarning('No fast scan for this stage!');
            end
            obj.fastScan = 0;
        end
        
        function success = EnableTiltCorrection(obj, enable)
            % Enables the tilt correction according to the angles.
            if ~strcmp(obj.VALID_AXES, obj.SCAN_AXES)
                string = BooleanHelper.ifTrueElse(isscalar(obj.VALID_AXES), 'axis', 'axes');
                obj.sendWarning(sprintf('Controller %s has only %s %s, and can''t do tilt correction.', ...
                    obj.controllerModel, obj.VALID_AXES, string));
                success = 0;
                return;
            end
            obj.tiltCorrectionEnable = enable;
            success = 1;
        end
        
        function success = SetTiltAngle(obj, thetaXZ, thetaYZ)
            % Sets the tilt angles between Z axis and XY axes.
            % Angles should be in degrees, valid angles are between -5 and 5
            % degrees.
            if (thetaXZ < -5 || thetaXZ > 5) || (thetaYZ < -5 || thetaYZ > 5)
                obj.sendWarning(sprintf('Angles are outside the limits (-5 to 5 degrees).\nAngles were not set.'));
                success = 0;
                return
            end
            obj.tiltThetaXZ = thetaXZ;
            obj.tiltThetaYZ = thetaYZ;
            success = 1;
        end
        
        function testErr(obj, err)
            if err ~= 0
                error('error %d was found on connection to standa stage', err)                
            end            
        end
        
    end
end