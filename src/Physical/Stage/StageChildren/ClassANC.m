classdef ClassANC < ClassStage
    %CLASSANC Used to control Attocube's ANC stage
    
    properties (Constant)
        NAME = 'Stage (Coarse) - ANC'
        VALID_AXES = 'xyz';
        UNITS = 'um'
        
        NEEDED_FIELDS = {'niDaqChannel'}
        
        LIB_DLL_FOLDER = 'C:\Attocube\ANC350_DLL\Win_64Bit\';
        LIB_DLL_FILENAME = 'anc350v2.dll';
        LIB_H_FOLDER = 'C:\Attocube\ANC350_DLL\Documentation\include\';
        LIB_H_FILENAME = 'anc350v2';
        LIB_ALIAS = 'anc350v2';
        
        POSITIVE_HARD_LIMITS = [8055 8005 1600];  % in microns. the values include a saftey range of 20 um.
        NEGATIVE_HARD_LIMITS = [31 -45 -2];       % in microns. the values include a saftey range of 20 um.
        STEP_MINIMUM_SIZE = 10      % double. in um
        STEP_DEFAULT_SIZE = 100     % double. in um
        
        commDelay = 0.05;%0.005; % 5ms delay needed between consecutive commands sent to the controllers.
        onTargetResolution = 2;% in um. under the onTargetResolution the stage is "on target".
    end
    
    properties
        deviceHandle = -1;  % Default value. Means stage is disconnected
        
        % Default values
        stageOffset = [0 0 0];
        posRangeLimit = ClassANC.POSITIVE_HARD_LIMITS;
        negRangeLimit = ClassANC.NEGATIVE_HARD_LIMITS;
        posSoftRangeLimit = ClassANC.POSITIVE_HARD_LIMITS;
        negSoftRangeLimit = ClassANC.NEGATIVE_HARD_LIMITS;
        defaultVel = 1000 % Default velocity is 1000 um/s.
        
        curPos = [0 0 0]; % nm
        curVel = [0 0 0]; % um/s
        
        forceStop       % logical. True if we want to stop mid-movement
        
        maxAmplitude = 45; %max amplidute in volt
        maxFrequency = 3000; %max frequency in Hz
        minAmplitude = 20; %min amplidute in volt
        minFrequency = 10; %min frequency in Hz
        
        % For scan
        maxScanSize = 9999;
        macroNumberOfPixels = -1;
        macroMacroNumberOfPixels = -1; % number of points per line
        macroNormalScanVector = -1;
        macroScanVector = -1;
        macroNormalScanAxis = -1;
        macroScanAxis = -1;
        macroPixelTime = -1; % time duration at each pixel
        macroScanVelocity = -1;
        macroNormalVelocity = -1;
        macroFixPosition = 0;
        macroIndex = -1; % -1 = not in scan
        
        % NiDaq
        triggerChannel
        digitalPulseTask = -1; % Digital pulse task for scanning
        
        % Tilt
        tiltCorrectionEnable = false
        tiltThetaXZ = 0
        tiltThetaYZ = 0
    end
    
    methods (Static, Access = public)
        % Get instance constructor
        function obj = create(stageStruct)
            
            missingField = FactoryHelper.usualChecks(stageStruct, ClassANC.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Trying to create the ANC stage, needed field "%s" was missing. Aborting',...
                    missingField);
            end
            
            niDaqChannel = stageStruct.niDaqChannel;
            removeObjIfExists(ClassANC.NAME);
            obj = ClassANC(niDaqChannel);       
        end
        
        function axis = GetAxisInternal(axisName)
            % Gives the axis number (0 for x, 1 for y, 2 for z) when the
            % user enters the axis name (x,y,z or 1 for x, 2 for y and 3
            % for z).
            axis = zeros(size(axisName));
            for i = 1:length(axisName)
                if ((strcmpi(axisName(i),'x')) || (axisName(i) == 1))
                    axis(i) = 0;
                elseif (axisName(i) == 'y') || (axisName(i) == 'Y') || (axisName(i) == 2)
                    axis(i) = 1;
                elseif (axisName(i) == 'z') || (axisName(i) == 'Z') || (axisName(i) == 3)
                    axis(i) = 2;
                else
                    error(['Unknown axis: ' axisName]);
                end
            end
            
        end
    end
    
    methods (Access = private)
        function obj = ClassANC(niDaqChannel)
            name = ClassANC.NAME;
            availAxes = ClassANC.VALID_AXES;
            obj@ClassStage(name, availAxes)
            
            obj.Connect;
            
            daq = getObjByName(NiDaq.NAME);
            daq.registerChannel(niDaqChannel, obj.name);
            obj.triggerChannel = niDaqChannel;
            
            obj.availableProperties.(obj.HAS_OPEN_LOOP) = true;
            obj.availableProperties.(obj.HAS_SLOW_SCAN) = true;
            obj.availableProperties.(obj.TILTABLE) = true;
        end
    end
    
    methods
        function Connect(obj) % Connect to the controller
            if (obj.deviceHandle == -1)
                obj.LoadPiezoLibrary;
                [dc, dptr] = calllib(obj.LIB_ALIAS, 'PositionerCheck', libpointer);
                id = dptr.id;
                if dptr.locked
                    fprintf('The device is locked and the id is %d.\n Close the daisy!', id);
                else
                    fprintf('The device is unlocked and the id is %d.\n', id);
                end
                eid = dc - 1;
                obj.deviceHandle = SendRawCommand(obj, 'PositionerConnect', eid ,0);
            end
        end
        
        function LoadPiezoLibrary(obj)
            % Loads the dll file.
            aliasANC = obj.LIB_ALIAS;
            
            if ~libisloaded(aliasANC)
                shrlib = [obj.LIB_DLL_FOLDER, obj.LIB_DLL_FILENAME];
                hfile = [obj.LIB_H_FOLDER, obj.LIB_H_FILENAME];
                loadlibrary(shrlib, hfile, 'alias', aliasANC);
                fprintf('Matlab: ANC library loaded.\n');
            end
        end
        
        function Initialization(obj)
            % Initializes the piezo stages.
            CheckConnectionToAxis(obj); % Checking connection to Axis.
            
            for i=1:3
                EnableOutput(obj, i, 1); % Turn on all outputs
                SetVelocity(obj,i, obj.defaultVel); % Set velocity & update location
            end
        end
        
        function CloseConnection(obj)
            % Closes the connection to the controllers.
            if (obj.deviceHandle ~= -1)
                % Handle exists, attempt to close
                SendRawCommand(obj, 'PositionerClose', obj.deviceHandle);
                fprintf('Connection Closed: Handle %d released.\n', obj.deviceHandle);
                obj.deviceHandle = -1;
            else
                % Handle does not exists, ask user what to do.
                titleString = 'No Handle found';
                questionString = sprintf('Device Handle not found.\nDevice Handle is needed in order to close the connection.');
                closeDefaultString = 'Force Close Handles from 0 to 512';
                %closeCustomString = 'Force Close a Custom Range of Handles';
                abortString = 'Abort';
                confirm = questdlg(questionString, titleString, closeDefaultString, abortString, closeDefaultString);
                switch confirm
                    case closeDefaultString
                        range = 0:512;
                        for handle = range
                            SendRawCommand(obj, 'PositionerClose', handle);
                        end
                        %case closeCustomString
                        %startRange = input('At which Handle to start?\n');
                        %endRange = input('At which Handle to end?\n');
                    case abortString
                        fprintf('No Connections Closed.\n');
                        return;
                    otherwise
                        fprintf('No Connections Closed: No input given.\n');
                        return;
                end
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
        
        function Delay(obj)
            c1=clock;
            c2=clock;
            while(etime(c2,c1)<obj.commDelay)
                c2=clock;
            end
        end
        
        function varargout = SendCommand(obj, command, axis, varargin)
            % Send the command to the controller and returns the output.
            % Automatically adds a waiting period before the command is sent.
            % if the command didn't got to the cotroller, print out error.
            
            obj.Connect(); %connect to device if not connected already
            
            tries = 1;
            while tries > 0
                Delay(obj);
                [eStatus, varargout{1:nargout}] = calllib(obj.LIB_ALIAS, command, obj.deviceHandle, axis, varargin{:});
                try
                    CheckErrors(obj, eStatus);
                    tries = 0;
                catch err
                    switch err.identifier
                        case 'ANC:CommunicationTimeout'
                            fprintf('Communication Error - Timeout\n');
                        otherwise
                            fprintf('%s\n', err.identifier);
                            titleString = 'Unexpected error';
                            questionString = sprintf('%s\nSending the command again might result in unexpected behavior...', err.message);
                            retryString = 'Retry command';
                            abortString = 'Abort';
                            confirm = questdlg(questionString, titleString, retryString, abortString, abortString);
                            switch confirm
                                case retryString
                                    warning(err.message);
                                case abortString
                                    rethrow(err);
                                otherwise
                                    rethrow(err);
                            end
                    end
                    if (tries == 5)
                        fprintf('Error was unresolved after %d tries\n', tries);
                        rethrow(err)
                    end
                    triesString = BooleanHelper.ifTrueElse(tries == 1, 'time', 'times');
                    fprintf('Tried %d %s, Trying again...\n', tries, triesString);
                    tries = tries+1;
                    pause(1);
                end
            end
        end
        
        
        function varargout = SendRawCommand(obj, command, varargin)
            % Send the command to the controller and returns the output.
            % Automatically adds a waiting period before the command is sent.
            % If the command didn't got to the cotroller, print out error.
            
            Delay(obj);
            [~, varargout{1:nargout}] = calllib(obj.LIB_ALIAS, command, varargin{:});
        end
        
        
        function  CheckErrors(obj, eStatus) %#ok<INUSL>
            switch eStatus
                case 0
                    return
                case 1
                    error('ANC:CommunicationTimeout', 'Communication timeout.');
                case 2
                    error('ANC:NoConnection', 'No active connection to the device.');
                case 3
                    error('ANC:CommunicationError', 'Error in comunication with driver.');
                case 4
                    error('ANC:deviceRunning', 'The device is running.');
                case 5
                    error('ANC:NoBootImage', 'Boot image doesnt found.');
                case 6
                    error('ANC:InvalidParameter', 'Given parameter is invalid.');
                case 7
                    error('ANC:DeviceInUse', 'Device is already in use by other.');
                case 8
                    error('ANC:ParameterError', 'Parameter out of range.');
                otherwise
                    error('ANC:Unknown', 'Unspecified error.');
            end
        end
        
        function maxScanSize = ReturnMaxScanSize(obj, nDimensions)
            % Returns the maximum number of points allowed for an
            % 'nDimensions' scan.
            maxScanSize = obj.maxScanSize;
        end
        
        function ChangeLoopMode(obj, mode)
            % Changes between closed and open loop.
            % 'mode' should be either 'Open' or 'Closed'.
            % Stage will auto-lock when in open mode, which should increase
            % stability.

            error('ANC stage cannot chnage loop mode!')
        end
        
        function [tiltEnabled, thetaXZ, thetaYZ] = GetTiltStatus(obj)
            % Return the status of the tilt control.
            tiltEnabled = obj.tiltCorrectionEnable;
            thetaXZ = obj.tiltThetaXZ;
            thetaYZ = obj.tiltThetaYZ;
        end
        
        function success = EnableTiltCorrection(obj, enable)
            % Enables the tilt correction according to the angles.
            if ~strcmp(obj.validAxes, obj.axesName)
                string = BooleanHelper.ifTrueElse(isscalar(obj.validAxes), 'axis', 'axes');
                obj.sendWarning(sprintf('Controller %s has only %s %s, and can''t do tilt correction.', ...
                    obj.controllerModel, obj.validAxes, string));
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
 
        function CheckConnectionToAxis(obj) %check if the device is connected to the controller
            nPhAxes = length(obj.availableAxes);    % Should be 3
            isPhAxisConnected = false(1,nPhAxes);
            
            for i = 0 : (nPhAxes-1)
                eConn = GetStatus(obj, i);
                phAxisNumber = i+1;
                if (eConn == 8)
                    phAxLetter = obj.GetLetterFromAxis(phAxisNumber);
                    fprintf('The device is not connected to axis %s, please check the wiring.\n', phAxLetter);
                else
                    isPhAxisConnected(phAxisNumber) = true;
                end
            end
            if all(isPhAxisConnected)
                fprintf('All stage axes are connected.\n');
            end
        end
        
        function status = GetStatus(obj, axis) %checks the positioner status:
            % 0 for 'axis is moving', 1 for 'hump detected', 2 for 'Error
            % of sensor', 3 for 'Sensor not connected'
            status = SendCommand(obj, 'PositionerGetStatus', axis, 0);
        end
        
        function SetReferenceXY(obj, axisName) %Reference for x and y
            realAxis = obj.GetAxisInternal(axisName);
            if realAxis == 2
                error('ANC:UsingReferenceXYForZAxis', 'This function doen`t apply to z axis!')
            else
                %finding max position
                Move(obj, axisName, obj.MaxPosForReference) %when setting the reference the positioner travels to the end of the range in order to find max position
                pause(1); % let the stage enough time to start moving before checking it's status
                status = GetStatus(obj, realAxis);
                while status == 1
                    status = GetStatus(obj, realAxis);
                end
                maxPosition = GetPosition(obj,axisName);
                
                % Finding min position
                Move(obj, axisName,obj.MinPosForReference) %when setting the reference the positioner travels to the end of the range in order to find min position
                pause(1); % let the stage enough time to start moving before checking it's status
                status = GetStatus(obj, realAxis);
                while status
                    status = GetStatus(obj, realAxis);
                end
                minPosition = GetPosition(obj,axisName);
                % Setting the reference position
                refPos = (maxPosition + minPosition)/2;
                Move(obj,axisName,refPos);
                pause(1); % Let the stage enough time to start moving before checking its status
                status = GetStatus(obj, realAxis);
                while status == 1
                    status = GetStatus(obj ,realAxis);
                end
                %                 SendCommand(obj, 'PositionerResetPosition', axis); no
                %                 reset positioner for our stage
                %                 pos = GetPosition(axis);
                %                 if pos == 0
                fprintf('The reference is set for axis %s.\n', obj.(realAxis+1));
            end
        end
        
        function WaitFor(obj, axisName, targetPos)
            %waits until the stage is on target <-> the different between
            %the target position and the current position is smaller than
            %the defined onTargetResolution (=2um).
            realAxis = obj.GetAxisInternal(axisName);
            curPos = GetPosition(obj, axisName);
            curPos = curPos + obj.stageOffset(realAxis + 1);
            while (abs(targetPos - curPos) > obj.onTargetResolution)
                curPos = GetPosition(obj, axisName) + obj.stageOffset(realAxis + 1);
                obj.sendEventPositionChanged;
                if obj.forceStop
                    obj.HaltPrivate;
                    break
                end
            end
        end
        
        
        function Move(obj, axisName, targetPosInMicrons)
            % Absolute change in position (the user enters the target position in microns) of axis (x,y,z or 1 for x, 2 for y and 3 for z).
            for i=1:length(axisName)
                realAxis = obj.GetAxisInternal(axisName(i));
                targetPos = GetTargetPosition(obj, axisName(i), targetPosInMicrons(i));
                if (targetPos <= obj.posSoftRangeLimit(i))  && (targetPos >= obj.negSoftRangeLimit(i)) %checking if the target position is in range
                    SendCommand(obj, 'PositionerMoveAbsolute', realAxis, targetPos*1000, 1);
                else
                    warning ('The position you enter is outside of limit range!')
                end
                WaitFor(obj, axisName(i),targetPos)  % wait until the position is set...... takes most time
            end
            GetPosition(obj, axisName);
        end
        
        function RelativeMove(obj, axisName, change)
            % Relative change in position (pos) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            if (obj.macroIndex ~= -1)
                error('2D Scan is in progress, either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.');
            end
            pos = Pos(obj, axisName);
            Move(obj, axisName, pos + change);
        end
        
        function targetPos = GetTargetPosition(obj, axisName,targetPosInMicrons)
            %returns the target position in microns in the stage reference
            %- translate the target pos entered by the user to the stage
            %frame
            realAxis = obj.GetAxisInternal(axisName);
            targetPos = targetPosInMicrons + obj.stageOffset(realAxis + 1);
            
        end
        
        function posInMicrons = GetPosition(obj, axisName)
            %returns the position in microns in the user frame
            posInMicrons = zeros(size(axisName));
            for i=1:length(axisName)
                realAxis = obj.GetAxisInternal(axisName(i));
                obj.curPos(realAxis + 1) = SendCommand(obj, 'PositionerGetPosition', realAxis ,0);
                posInMicrons(i) = obj.curPos(realAxis + 1)./1000 - obj.stageOffset(realAxis + 1);
            end
        end
        
        function pos = Pos(obj, axisName)
            % Query and return position of axis (x,y,z or 1 for x, 2 for y
            % and 3 for z)
            % Vectorial axis is possible.
            pos = GetPosition(obj, axisName);
        end
        
        function PrintPosition(obj)
            %printing the  position in microns
            
            pos = GetPosition(obj, axisName);
            for i=0:2
                fprintf ('position on axis %s is %d.\n', obj.(i+1), pos(i+1));
            end
        end
        
        function Halt(obj)
            % Halts all stage movements.
            % This works by setting the parameter below to 1, which is
            % checked inside the "WaitFor" function. When the WaitFor is
            % triggered, is calls an internal function, "HaltPrivate", which
            % immediately sends a halt command to the controller.
            % Afterwards it also tries to abort scan. The reason abort scan
            % happens afterwards is to minimize the the time it takes to
            % send the halt command to the controller.
            % This parameters also denies the "MovePrivate" command from
            % running.
            % It is reset by a normal/relative "Move Command", which will
            % be triggered whenever a new external move or scan command is
            % sent to the stage.
            obj.forceStop = 1;
        end
        
        
        function SetAmplitude(obj, axisName, amplitudeInVolt)
            %setting the amplitude.
            %input amplitude is in volt.
            %amplitude range is between 0 to 45 volt
            
            if (amplitudeInVolt > obj.maxAmplitude)
                error('ANC:VoltOutOfMaxLimit', 'The voltage you enter is too high.');
            elseif (amplitudeInVolt < obj.minAmplitude)
                error('ANC:VoltOutOfMinLimit', 'The voltage you enter is too low.');
            end
            axis = obj.GetAxisInternal(axisName);
            amplitude = amplitudeInVolt*1000;
            SendCommand(obj, 'PositionerAmplitude', axis, amplitude)
        end
        
        
        function amplitudeInVolt = GetAmplitude(obj, axisName)
            % returns the amplitude.
            % output amplitude is in volt.
            
            axis = obj.GetAxisInternal(axisName);
            amplitude = double(SendCommand(obj, 'PositionerGetAmplitude', axis,0));
            amplitudeInVolt = amplitude/1000;
        end
        
        
        function SetFrequency(obj, axisName, frequencyInHz)
            % Setting the frequency.
            % input frequency is in Hz.
            % frequency range is between 0 to 1000 Hz.
            
            if (frequencyInHz > obj.maxFrequency)
                error('ANC:FreqOutOfMaxLimit', 'The frequency you enter is too high.');
            elseif (frequencyInHz < obj.minFrequency)
                error('ANC:FreqOutOfMinLimit', 'The frequency you enter is too low.');
            end
            axis = obj.GetAxisInternal(axisName);
            frequency = double(frequencyInHz);
            SendCommand(obj, 'PositionerFrequency', axis, frequency)
        end
        
        
        function frequencyInHz = GetFrequency(obj, axisName)
            %returns the frequency.
            %output frequency is in Hz.
            
            axis = obj.GetAxisInternal(axisName);
            frequency = double(SendCommand(obj, 'PositionerGetFrequency', axis ,1));
            frequencyInHz = frequency;
        end
        
        
        function SetResolution(obj, axisName, resolution)
            %select the position differene which causes a single step on
            %the output signal.
            %input resolution is in nanometer.
            
            axis = obj.GetAxisInternal(axisName);
            SendCommand(obj, 'PositionerQuadratureAxis', 0, axis)
            SendCommand(obj, 'PositionerQuadratureOutputPeriod', axis, resolution)
            %             switch axisName
            %                 case {1,2,3}
            if (resolution < 10)
                error ('ANC:ResOutOfLimit','the resolution you entered is too small');
            end
            %             end
        end
        
        
        function EnableOutput(obj, axisName, enable)
            % Enables changes in resolution and clock.
            %             enable = bool(enable);
            SendCommand(obj, 'PositionerSetOutput',obj.GetAxisInternal(axisName), 1);
            if enable % Workaround for a glitch when output is enabled
                SetResolution(obj, axisName, 1000)
                SetResolution(obj, axisName, 100)
            end
        end
        
        
        function MoveALot (obj, axisName, steps, displace, res)
            axis = GetAxisInternal(obj,axisName);
            SetResolution(obj, axisName, res);
            for i=1:steps
                pos0 = GetPosition(obj, axisName);
                Move(obj, axisName, pos0(axis+1)-displace);
                pause(0.01);
            end
        end
        
        
        function MoveALot1 (obj, axisName, totdisplace, displace, res)
            axis = obj.GetAxisInternal(axisName);
            pos0 = GetPosition(obj, axisName);
            SetResolution(obj, axisName, res);
            steps = totdisplace/displace;
            for i=1:steps
                Move(obj, axisName, pos0(axis+1)+displace*i);
                pause(0.01);
            end
        end
        
        
        function SetAll(obj, axisName,frequency,amplitude,res)
            SetFrequency(obj,axisName,frequency);
            SetAmplitude(obj,axisName,amplitude);
            SetResolution(obj,axisName,res);
        end
        
        
        function PrintDataForAxis(obj,axisName)
            frequency = GetFrequency(obj,axisName);
            amplitude = GetAmplitude(obj,axisName);
            resolution = GetResolution(obj,axisName);
            clock = GetClock(obj,axisName);
            velocity = GetVelocity(obj, axisName);
            fprintf ('The Frequency is %dHz.\n, The Amplitude is %dV.\n, The Resolution is %dnm.\n, The Clock is %dns.\n, The Velocity is %d microns per second.\n', frequency, amplitude, resolution, clock, velocity);
        end
        
        
        function SetVelocity(obj, axisName, velocity) %seting the velocity in microns/sec
            axis = obj.GetAxisInternal(axisName);
            switch axis
                case {0,1,2}
                    if velocity < 1000
                        SetAmplitude(obj, axisName, 40); %SetAmplitude(obj, axisName, 25);
                    else
                        SetAmplitude(obj, axisName, 40); %SetAmplitude(obj, axisName, 30);
                    end
                    amplitude = GetAmplitude(obj, axisName);
                    frequency = round(velocity/(amplitude-10)/0.015);
            end
            try
                SetFrequency(obj, axisName, frequency);
                obj.curVel(axis+1) = velocity;
            catch err
                %                 obj.macroIndex=-1;
                switch err.identifier
                    case {'ANC:FreqOutOfMaxLimit', 'ANC:VoltageOutOfMaxLimit'}
                        error('ANC:VelOutOfMaxLimit','the velocity you enter is too high.');
                    case {'ANC:FreqOutOfMinLimit', 'ANC:VoltageOutOfMinLimit'}
                        error('ANC:VelOutOfMinLimit','the velocity you enter is too low.');
                    otherwise
                        rethrow(err)
                end
            end
        end
        
        function velocity = GetVelocity(obj, axisName)
            axis = GetAxisInternal(obj,axisName);
            velocity = double(SendCommand(obj, 'PositionerGetSpeed', axis ,1))/1000; % in units of um/s
            obj.curVel(axis+1) = velocity;
        end
        
        function vel = Vel(obj, axisName)
            % Query and return velocity of axis (x,y,z or 1 for x, 2 for y
            % and 3 for z)
            % Vectorial axis is possible.
            vel = GetVelocity(obj, axisName);
        end
        
        function FastScan(obj, enable) %#ok<INUSL>
            if enable
                error('Fast scan is not supported, please switch to slow scan');
            end
        end
        
        function ScanOneDimension(obj, axisName, scanAxisVector, tPixel)
            % Does a macro scan for the given axis.
            % axisName - The axis to scan (x,y,z or 1 for x, 2 for y and 3)
            % scanAxisVector - A vector with the points to scan, points
            % should increase with equal distances between them.
            % tPixel - Scan time for each pixel (in seconds).
            % moving to the start point
            
            % prepare scan
            %             clock = (tPixel*1e9)/1000;
            %             SetClock(obj, axisName, clock);
            numberOfPixels = length(scanAxisVector) - 1;
            scanLength = scanAxisVector(end)-scanAxisVector(1);
            pixel = 1000*scanLength/numberOfPixels; % resolution in nm
            pixelResolution = ceil(pixel/4);
            fixPosition = pixelResolution/3000;
            startPoint = scanAxisVector(1)-fixPosition;
            endPoint = scanAxisVector(end)+fixPosition;
            try
                SetResolution(obj, axisName, pixelResolution);
            catch err
                switch err.identifier
                    case 'ANC:ResOutOfLimit'
                        fprintf('can not scan! either you entered too many points or scan length is too short\n');
                        return
                    otherwise
                        rethrow(err)
                end
            end
            totalTime = numberOfPixels*tPixel;
            scanVelocity = scanLength/(totalTime);
            %normalVelocity = obj.curVel(GetAxisInternal(obj,scanAxis));
            
            try
                SetVelocity(obj, axisName, scanVelocity);
            catch err
                switch err.identifier
                    case 'ANC:VelOutOfMaxLimit'
                        error('Can not scan! Either pixel time is too short or scan length is too long');
                    case 'ANC:VelOutOfMinLimit'
                        error('Can not scan! Either pixel time is too long or scan length is too short');
                    otherwise
                        rethrow(err)
                end
            end
            
            
            Move(obj, axisName, startPoint);
            
            % Start scan
            pause(0.01);
            pos = GetPosition(obj, axisName);
            while (abs(pos-startPoint)>1)
                pos = GetPosition(obj, axisName);
            end
            Move(obj, axisName, endPoint);
            pause(0.01);
            
            pos = GetPosition(obj, axisName);
            while (abs(pos-endPoint)>1)
                pos = GetPosition(obj, axisName);
            end
            
            %%% reset velocety to normalVelocity
            %                 SetVelocity(obj, axisName, obj.defaultVel);
            
        end
        
        
        function PrepareScanX(obj, x, y, z, nFlat, nOverRun, tPixel)
            % Defines a macro scan for x axis.
            % Call ScanX to start the scan.
            % x - A vector with the points to scan, points should have
            % equal distance between them.
            % y/z - The starting points for the other .
            % nFlat - Not used.
            % nOverRun - ignored.
            % tPixel - Scan time for each pixel.
            PrepareScanXY(obj, x, y, z, nFlat, nOverRun, tPixel);
        end
        
        function PrepareScanY(obj, x, y, z, nFlat, nOverRun, tPixel)
            % Defines a macro scan for x axis.
            % Call ScanX to start the scan.
            % y - A vector with the points to scan, points should have
            % equal distance between them.
            % x/z - The starting points for the other .
            % nFlat - Not used.
            % nOverRun - ignored.
            % tPixel - Scan time for each pixel.
            PrepareScanYZ(obj, x, y, z, nFlat, nOverRun, tPixel);
        end
        
        function PrepareScanZ(obj, x, y, z, nFlat, nOverRun, tPixel)
            % Defines a macro scan for x axis.
            % Call ScanX to start the scan.
            % z - A vector with the points to scan, points should have
            % equal distance between them.
            % x/y - The starting points for the other .
            % nFlat - Not used.
            % nOverRun - ignored.
            % tPixel - Scan time for each pixel.
            PrepareScanZX(obj, x, y, z, nFlat, nOverRun, tPixel);
        end
        
        function ScanX(obj, x, y, z, nFlat, nOverRun, tPixel) %#ok<*INUSD>
            %%%%%%%%%%%%%% ONE DIMENSIONAL X SCAN MACRO %%%%%%%%%%%%%%
            % Does a macro scan for x axis, should be called after
            % PrepareScanX.
            % Input should be the same for both functions.
            % x - A vector with the points to scan, points should have
            % equal distance between them.
            % y/z - The starting points for the other .
            % nFlat - Not used.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if (obj.macroIndex == -1)
                error('No scan detected.\nFunction can only be called after ''PrepareScanX!''');
            end
            ScanNextLine(obj);
        end
        
        function ScanY(obj, x, y, z, nFlat, nOverRun, tPixel) %#ok<*INUSD>
            %%%%%%%%%%%%%% ONE DIMENSIONAL Y SCAN MACRO %%%%%%%%%%%%%%
            % Does a macro scan for y axis, should be called after
            % PrepareScanY.
            % Input should be the same for both functions.
            % y - A vector with the points to scan, points should have
            % equal distance between them.
            % x/z - The starting points for the other .
            % nFlat - Not used.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if (obj.macroIndex == -1)
                error('No scan detected.\nFunction can only be called after ''PrepareScanY!''');
            end
            ScanNextLine(obj);
        end
        
        function ScanZ(obj, x, y, z, nFlat, nOverRun, tPixel) %#ok<*INUSD>
            %%%%%%%%%%%%%% ONE DIMENSIONAL Z SCAN MACRO %%%%%%%%%%%%%%
            % Does a macro scan for z axis, should be called after
            % PrepareScanZ.
            % Input should be the same for both functions.
            % z - A vector with the points to scan, points should have
            % equal distance between them.
            % x/y - The starting points for the other .
            % nFlat - Not used.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if (obj.macroIndex == -1)
                error('No scan detected.\nFunction can only be called after ''PrepareScanX!''');
            end
            ScanNextLine(obj);
        end
        
        function PrepareScanInTwoDimensions(obj, macroScanAxisVector, normalScanAxisVector, nFlat, nOverRun, tPixel, macroScanAxisName, normalScanAxisName)
            %%%%%%%%%%%%%% TWO DIMENSIONAL SCAN MACRO %%%%%%%%%%%%%%
            % Does a macro scan for given !
            % scanAxisVector1/2 - Vectors with the points to scan, points
            % should increase with equal distances between them.
            % tPixel - Scan time for each pixel is seconds.
            % scanAxis1/2 - The  to scan (x,y,z or 1 for x, 2 for y and
            % 3 for z).
            % nFlat - Not used.
            % nOverRun - ignored.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Process Data
            %             clock = (tPixel*1e9)/1000;
            %             SetClock(obj, macroScanAxisName, clock);
            %             SetClock(obj, normalScanAxisName, clock);
            numberOfMacroPixels = length(macroScanAxisVector);
            numberOfNormalPixels = length(normalScanAxisVector);
            
            if (numberOfMacroPixels > obj.maxScanSize)
                fprintf('Can support scan of up to %d pixel for the macro axis, %d were given. Please seperate into several smaller scans externally',...
                    obj.maxScanSize, numberOfMacroPixels);
                return;
            end
            
            
            macroScanLength = macroScanAxisVector(end) - macroScanAxisVector(1);
            macroPixel = 1000*macroScanLength/numberOfMacroPixels; %Resolution in nm
            macroPixelResolution = ceil(macroPixel/4);
            fixPosition = macroPixelResolution/2000;
            totalTimePerLine = numberOfMacroPixels*tPixel;
            scanVelocity = macroScanLength/(totalTimePerLine);
            normalVelocity = obj.curVel(obj.GetAxisInternal(macroScanAxisName)+1);
            SetResolution(obj, macroScanAxisName, macroPixelResolution);
            
            % Set real start and end points
            startPoint = macroScanAxisVector(1) - fixPosition;
            
            % Prepare Scan
            obj.macroPixelTime = tPixel;
            
            obj.macroMacroNumberOfPixels = numberOfMacroPixels;
            obj.macroNumberOfPixels = numberOfNormalPixels;
            obj.macroNormalScanVector = normalScanAxisVector;
            obj.macroScanVector = macroScanAxisVector;
            obj.macroNormalScanAxis = normalScanAxisName;
            obj.macroScanAxis = macroScanAxisName;
            obj.macroScanVelocity = scanVelocity;
            obj.macroNormalVelocity = normalVelocity;
            obj.macroIndex = 1;
            obj.macroFixPosition = fixPosition;
            
            Move(obj, obj.macroScanAxis, startPoint);
        end
        
        function PrepareScanXY(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XY SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xy !
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % x/y - Vectors with the points to scan, points should have
            % equal distance between them.
            % z - The starting points for the other axis.
            % nFlat - Not used.
            % nOveRun - ignored.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            %             if (obj.macroIndex ~= -1)
            %                 error('2D Scan is in progress, either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.');
            %             end
            
            % Must disable other axis output before scan and enable it
            % afterwards - enabling causes noise, disabling doesn't.
            EnableOutput(obj, 'y', 0);
            EnableOutput(obj, 'z', 0);
            
            Move(obj, 'z', z);
            PrepareScanInTwoDimensions(obj, x, y, nFlat, nOverRun, tPixel, 'x', 'y');
        end
        
        function PrepareScanXZ(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xz !
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % x/z - Vectors with the points to scan, points should have
            % equal distance between them.
            % y - The starting points for the other axis.
            % nFlat - Not used.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % please comment out after fixing AbortScan issue
            %             if (obj.macroIndex ~= -1)
            %                 error('2D Scan is in progress, either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.');
            %  end
            
            % Must disable other axis output before scan and enable it
            % afterwards - enabling causes noise, disabling doesn't.
            EnableOutput(obj, 'y', 0);
            EnableOutput(obj, 'z', 0);
            
            Move(obj, 'y', y);
            PrepareScanInTwoDimensions(obj, x, z, nFlat, nOverRun, tPixel, 'x', 'z');
        end
        
        function PrepareScanYX(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XY SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xy !
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % x/y - Vectors with the points to scan, points should have
            % equal distance between them.
            % z - The starting points for the other axis.
            % nFlat - Not used.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if (obj.macroIndex ~= -1)
                error('2D Scan is in progress, either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.');
            end
            
            % Must disable other axis output before scan and enable it
            % afterwards - enabling causes noise, disabling doesn't.
            EnableOutput(obj, 'x', 0);
            EnableOutput(obj, 'z', 0);
            
            Move(obj, 'z', z);
            PrepareScanInTwoDimensions(obj, y, x, nFlat, nOverRun, tPixel, 'y', 'x');
        end
        
        function PrepareScanYZ(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL YZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for yz !
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % y/z - Vectors with the points to scan, points should have
            % equal distance between them.
            % x - The starting points for the other axis.
            % nFlat - Not used.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if (obj.macroIndex ~= -1)
                error('2D Scan is in progress, either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.');
            end
            
            % Must disable other axis output before scan and enable it
            % afterwards - enabling causes noise, disabling doesn't.
            EnableOutput(obj, 'x', 0);
            EnableOutput(obj, 'z', 0);
            
            Move(obj, 'x', x);
            PrepareScanInTwoDimensions(obj, y, z, nFlat, nOverRun, tPixel, 'y', 'z');
        end
        
        function PrepareScanZX(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xz !
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % x/z - Vectors with the points to scan, points should have
            % equal distance between them.
            % y - The starting points for the other axis.
            % nFlat - Not used.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if (obj.macroIndex ~= -1)
                error('2D Scan is in progress, either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.');
            end
            
            % Must disable other axis output before scan and enable it
            % afterwards - enabling causes noise, disabling doesn't.
            EnableOutput(obj, 'x', 0);
            EnableOutput(obj, 'y', 0);
            
            Move(obj, 'y', y);
            PrepareScanInTwoDimensions(obj, z, x, nFlat, nOverRun, tPixel, 'z', 'x');
        end
        
        function PrepareScanZY(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL YZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for yz !
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % y/z - Vectors with the points to scan, points should have
            % equal distance between them.
            % x - The starting points for the other axis.
            % nFlat - Not used.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if (obj.macroIndex ~= -1)
                error('2D Scan is in progress, either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.');
            end
            
            % Must disable other axis output before scan and enable it
            % afterwards - enabling causes noise, disabling doesn't.
            EnableOutput(obj, 'x', 0);
            EnableOutput(obj, 'y', 0);
            
            Move(obj, 'x', x);
            PrepareScanInTwoDimensions(obj, z, y, nFlat, nOverRun, tPixel, 'z', 'y');
        end
        
        function [forwards, done] = ScanNextLine(obj)
            % Scans the next line for the 2D scan, to be used after
            % 'PrepareScanXX'.
            % done is set to 1 after the last line has been scanned.
            % No other commands should be used between 'PrepareScanXX' and
            % until 'ScanNextLine' has returned done, or until 'AbortScan'
            % has been called.
            % forwards is set to 1 when the scan is forward and is set to 0
            % when it's backwards
            
            
            if (obj.macroIndex == -1)
                error('No scan detected.\nFunction can only be called after ''PrepareScanXX!''');
            end
            
            % Prepare Axes
            if (obj.macroIndex == 1)
                try
                    SetVelocity(obj, obj.macroScanAxis, obj.macroScanVelocity);
                catch err
                    switch err.identifier
                        case 'ANC:VelOutOfMaxLimit'
                            fprintf('can not scan! either pixel time is too short or scan length is too long\n');
                            return
                        case 'ANC:VelOutOfMinLimit'
                            fprintf('can not scan! either pixel time is too long or scan length is too short\n');
                            return
                        otherwise
                            rethrow(err)
                    end
                end
            end
            
            if (obj.macroIndex > obj.macroNumberOfPixels)
                error('Attempted to scan next line after last line!')
            end
            
            %preparing DAQ output (trigger for SPCM readouts) for the scan
            nidaq = getObjByName(NiDaq.NAME);
            obj.digitalPulseTask = nidaq.prepareDigitalOutputTask(obj.triggerChannel);
            
            % Scan
            Move(obj, obj.macroNormalScanAxis, obj.macroNormalScanVector(obj.macroIndex));
            Delay(obj)
            % Only forward scans are implemented due to hysteresis
            Move(obj, obj.macroScanAxis, obj.macroScanVector(1));
            Delay(obj) % Wait before start scanning
            
            line = obj.triggerChannel(end);     % For example, if the channel is 'PFI3', we want the line to be '3'
            for i=1:obj.macroMacroNumberOfPixels
                Move(obj, obj.macroScanAxis, obj.macroScanVector(i)); % Same as move, without creating and closing the task.
                nidaq.writeDigitalOnce(obj.digitalPulseTask, 1, line);
                Delay(obj);
                nidaq.writeDigitalOnce(obj.digitalPulseTask, 0, line);
            end
            forwards = 1;
            
            
            % Change settings back
            done = (obj.macroIndex == obj.macroNumberOfPixels);
            obj.macroIndex = obj.macroIndex + 1;
        end
        
        function PrepareRescanLine(obj)
            % Prepares the previous line for rescanning.
            % Scanning is done with "ScanNextLine"
            if (obj.macroIndex == -1)
                error('No scan detected. Function can only be called after ''PrepareScanXX!''');
            elseif (obj.macroIndex == 1)
                error('Scan did not start yet. Function can only be called after ''ScanNextLine!''');
            end
            
            % Decrease index
            obj.macroIndex = obj.macroIndex - 1;
            
            % Go back to the start of the line
            if (mod(obj.macroIndex,2) ~= 0)
                Move(obj,obj.macroScanAxis,obj.macroScanVector(1)-obj.macroFixPosition);
            else
                Move(obj,obj.macroScanAxis,obj.macroScanVector(end)+obj.macroFixPosition);
            end
        end
        
        function AbortScan(obj)
            % Aborts the 2D scan defined by 'PrepareScanXX';
            for i=1:3
                EnableOutput(obj, i, 1);
            end
            %             if (obj.macroScanAxis ~= -1) && (obj.macroNormalVelocity ~= -1)
            %                 SetVelocity(obj, obj.macroScanAxis, obj.macroNormalVelocity);
            %             end
            obj.macroIndex = -1;
        end
        
        function ok = PointIsInRange(obj, axisName, point)
            % Checks if the given point is within the soft (and hard)
            % limits of the given axis (x,y,z or 1 for x, 2 for y and 3 for z).
            % Vectorial axis is possible.
            ok = ((point >= (obj.negSoftRangeLimit - obj.stageOffset)) & (point <= (obj.posSoftRangeLimit - obj.stageOffset)));
            %%ok = ((point >= obj.negSoftRangeLimit*ones(size(axisName))) && (point <= obj.posSoftRangeLimit*ones(size(axisName))));
            ok = [1 1 1];
        end
        
        function [negSoftLimit, posSoftLimit] = ReturnSoftLimits(obj, axisName)
            % Return the soft limits of the given axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            negSoftLimit = obj.negSoftRangeLimit;
            posSoftLimit = obj.posSoftRangeLimit;
        end
        
        function SetSoftLimits(obj, phAxis, softLimit, negOrPos)
            % Set the new soft limits:
            % if negOrPos = 0 -> then softLimit = lower soft limit
            % if negOrPos = 1 -> then softLimit = higher soft limit
            % This is because each time this function is called only one of
            % the limits updates
            CheckAxis(obj, phAxis)
            axisIndex = GetAxisIndex(obj, phAxis);
            if ((softLimit >= obj.negRangeLimit(axisIndex)) && (softLimit <= obj.posRangeLimit(axisIndex)))
                if negOrPos == 0
                    obj.negSoftRangeLimit(axisIndex) = softLimit;
                else
                    obj.posSoftRangeLimit(axisIndex) = softLimit;
                end
            else
                obj.sendError(sprintf('Soft limit %.4f is outside of the hard limits %.4f - %.4f', ...
                    softLimit, obj.negRangeLimit(axisIndex), obj.posRangeLimit(axisIndex)))
            end
        end
        
        function [negLimit, posLimit] = ReturnLimits(obj, axisName)% returning the limits for the GUI - Limits around 0
            % Return the soft limits of the given axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            phAxis = obj.getAxis(axisName);
            
            negLimit = obj.negSoftRangeLimit(phAxis) - obj.stageOffset(phAxis);
            posLimit = obj.posSoftRangeLimit(phAxis) - obj.stageOffset(phAxis);
        end
        
        function [negHardLimit, posHardLimit] = ReturnHardLimits(obj, axisName)
            % Return the hard limits of the given axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            phAxis = obj.getAxis(axisName);
            
            negHardLimit = obj.negRangeLimit(phAxis);
            posHardLimit = obj.posRangeLimit(phAxis);
        end
        
        function JoystickControl(obj, enable)
            % Changes the joystick state for all  to the value of
            % 'enable' - 1 to turn Joystick on, 0 to turn it off.
            fprintf('No joystick connected\n');
        end
        
        function binaryButtonState = ReturnJoystickButtonState(obj)
            % Returns the state of the buttons in 3 bit decimal format.
            % 1 for first button, 2 for second and 4 for the 3rd.
            obj.sendWarning('No joystick support for the ANC controller.');
            binaryButtonState = 0;
        end
    end
    
    methods (Access = private)
        function HaltPrivate(obj)
            obj.forceStop = false;
            
            axesLetters = obj.availableAxes; % For brevity
            for i=1:length(axesLetters)
                realAxis = obj.GetAxisInternal(axesLetters(i));
                SendCommand(obj, 'PositionerStopMoving', realAxis);
            end
        end
    end
    
end

