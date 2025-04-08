classdef ClassECC < ClassStage
    
    properties (Access = private)
        eHandle = -1;
        
        curPos = [0 0 0]; % nm
        curVel = [0 0 0]; % um/s
        commDelay = 0.010; % 5ms delay needed between consecutive commands sent to the controllers.
        debug = false;
        
        macroNumberOfPixels = -1; % number of lines
        macroMacroNumberOfPixels = -1; % number of points per line
        macroNormalScanVector = -1; % Vector of points in the normal direction (lines direction)
        macroScanVector = -1; % Vector of points in the macro (scanning) direction
        macroNormalScanAxis = -1; % normal direction axis (x, y or z)
        macroScanAxis = -1; % macro direction axis (x, y or z)
        macroScanVelocity = -1;
        macroNormalVelocity = -1;
        macroPixelTime = -1; % time duration at each pixel
        macroFixPosition = -1; % fixing the position so the first quadrature will be symmetric around the scanning point
        macroIndex = -1; % current line, -1 = not in scan
        fastScan = 0; % 0 for slow scan, 1 for fast scan.
        verySlow = 1; % 0 for slow scan, 1 for very slow scan.
    end
       
    properties (Constant)
        dllFolder = 'C:/Users/Owner/Google Drive/NV Lab/Control code/Drivers/Attocube/ECC100_DLL/Win_64Bit/lib/';
        hFolder = 'C:/Users/Owner/Google Drive/NV Lab/Control code/Drivers/Attocube/ECC100_DLL/Win_64Bit/inc/';
        libAlias = 'ecc';
        
        stageName = 'Stage (Coarse) - ECC';
        axes = 'xyz';
        posRangeLimit = [9000, 9000, 9000];     % Units set to microns.
        negRangeLimit = [-9000, -9000, -9000];  % Units set to microns.
        posSoftRangeLimit = [9000, 9000, 9000]; % Default is same as physical limit.
        negSoftRangeLimit = [-9000, -9000, -9000]; % Default is same as physical limit.
        maxAmplitude = 45; % Max amplitude in volt
        maxFrequency = 3000; % Max frequency in Hz
        minAmplitude = 20; % Min amplitude in volt
        minFrequency = 10; % Min frequency in Hz
        units = 'um';
        defaultVel = 1000 % Default velocity is 1000 um/s.

        maxScanSize = 9999;
        
        STEP_MINIMUM_SIZE = 0.1;
        STEP_DEFAULT_SIZE = 10;
    end
    
    methods (Static, Access = public)
        % Get instance constructor
        function obj = GetInstance()
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = ClassECC;
            end
            obj = localObj;
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
        
        function warningTiltUnimplemented
            warning('Tilt is not implemented for ECC stage');
        end
    end
    
    methods (Access = public)
        
        % Private default constructor
        function obj = ClassECC
            obj@ClassStage(ClassECC.stageName, ClassECC.axes);
            
            obj.LoadPiezoLibrary;
            obj.Connect;
            obj.Initialization;
            
            obj.availableProperties.(obj.HAS_OPEN_LOOP) = true;
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
        
        
        function Delay(obj, delay)
            if nargin == 1
                delay = obj.commDelay;
            end
            waitTime = delay;
            c1=clock;
            c2=clock;
            while (etime(c2,c1)<waitTime)
                c2=clock;
            end
        end
        
        
        function varargout = SendCommand(obj, command, axis, varargin)
            % Send the command to the controller and returns the output.
            % Automatically adds a waiting period before the command is sent.
            % if the command didn't got to the cotroller, print out error.
            
            tries = 1;
            while tries > 0
                Delay(obj);
                [eStatus, varargout{1:nargout}] = calllib(obj.libAlias, command, obj.eHandle, axis, varargin{:});
                try
                    CheckErrors(obj, eStatus);
                    tries = 0;
                catch err
                    switch err.identifier
                        case 'ECC:CommunicationTimeout'
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
                    if (tries == 3)
                        fprintf('Error was unresolved after %d tries\n',tries);
                        rethrow(err)
                    end
                    if (tries == 1); triesString = 'time'; else; triesString = 'times'; end
                    fprintf('Tried %d %s, Trying again...\n', tries, triesString);
                    tries = tries+1;
                    pause(2);
                end
            end
        end
        
        
        function varargout = SendRawCommand(obj, command, varargin)
            % Send the command to the controller and returns the output.
            % Automatically adds a waiting period before the command is sent.
            % if the command didn't got to the cotroller, print out error.
            
            Delay(obj);
            [eStatus, varargout{1:nargout}] = calllib(obj.libAlias, command, varargin{:});
            CheckErrors(obj, eStatus);
            
        end
        
        function  CheckErrors(obj, eStatus) %#ok<INUSL>
            switch eStatus
                case 0
                    return
                case 1
                    error('ECC:CommunicationTimeout', 'Communication timeout.');
                case 2
                    error('ECC:NoConnection', 'No active connection to the device.');
                case 3
                    error('ECC:CommunicationError', 'Error in comunication with driver.');
                case 7
                    error('ECC:DeviceInUse', 'Device is already in use by other.');
                case 9
                    error('ECC:ParameterError', 'Parameter out of range.');
                case 10
                    error('ECC:FeatureUnavialable', 'Feature only available in pro version.');
                otherwise
                    error('ECC:Unknown', 'Unspecified error.');
            end
        end
        
        
        function LoadPiezoLibrary(obj)
            % libfunctionsview ecc
            % Loads the ECC dll file.
            shrlib = [obj.dllFolder 'ecc.dll'];
            hfile = [obj.hFolder 'ecc.h'];
            
            % Only load dll if it wasn't loaded before.
            if(~libisloaded(obj.libAlias))
                loadlibrary(shrlib, hfile, 'alias', obj.libAlias);
            end
            fprintf('ECC library ready.\n');
        end
        
        
        function Connect(obj) %connect to the controller
            
            if (obj.eHandle == -1)
                %                 dptr=libpointer;
                [dc,dptr]=calllib('ecc','ECC_Check',libpointer);
                [~ ,id ,locked] = calllib('ecc','ECC_getDeviceInfo',0 , dptr.id , dptr.locked );
                if  (locked ~= 0)
                    fprintf('The device is locked and the id is %d.\n', id);
                else
                    fprintf('The device is unlocked and the id is %d.\n', id);
                end
                
                eid=dc-1;
                %eHandle=0;
                obj.eHandle = SendRawCommand(obj,'ECC_Connect', eid ,0);
                %[estat,eHandle]=calllib('ecc','ECC_Connect',eid,eHandle);
                
                %if (eStatus ~= 0)
                %disp(['Error ' eStatus '. Exiting...']);
                %return;
                %end
                
            end
        end
        
        function maxScanSize = ReturnMaxScanSize(obj, nDimensions)
            % Returns the maximum number of points allowed for an
            % 'nDimensions' scan.
            maxScanSize = obj.maxScanSize*ones(1,nDimensions);
        end
        
        function Initialization(obj)
            % Initializes the piezo stages.
            
            % Setting target range(=10 nm) for all axes.
            for i=1:3
                range = 10;
                SendCommand(obj, 'ECC_controlTargetRange', obj.GetAxisInternal(i), range, 1);
                fprintf ('The target range for axis %s is %d nanometer.\n', obj.axes(i), range);
            end
            
            % Checking connection to axes.
            CheckConnectionToAxes(obj);
            
            % Reference
            for i=1:3
                SetReference(obj, i);
            end
            
            % Setting the device to auto moving mode
            SetAutoMoving(obj)
            
            % Turn on all outputs
            for i=1:3
                EnableOutput(obj, i, 1);
            end
            
            % Set velocity & update location
            for i=1:3
                SetVelocity(obj, i, obj.defaultVel);
            end
            GetPosition(obj, obj.axes); % Updates obj.curPos
            
        end
        
        
        function CheckConnectionToAxes(obj) %check if the device is connected to the controller
            
            t=0;
            for i = 0:2
                eConn = SendCommand(obj, 'ECC_getStatusConnected', i, 0);
                if (~eConn)
                    fprintf('The device is not connected to axis %s, please check the wiring.\n', obj.axes(i+1));
                else
                    t=t+1;
                end
            end
            if (t==3)
                fprintf('All axes are connected.\n');
            end
            
        end
        
        
        function SetAutoMoving(obj)
            % Setting the device to auto moving mode (green light).
            
            % Set auto move
            for i=0:2
                movingStatus = SendCommand(obj, 'ECC_getStatusMoving', i, 0);
                if (movingStatus == 2) % Pending
                    SendCommand(obj, 'ECC_controlOutput', i, 1, 1);
                    movingStatus = SendCommand(obj, 'ECC_getStatusMoving', i, 0);
                end
                if movingStatus == 1 % Moving
                    % Moving, Do Nothing
                else % Idle, Force move to current posit
                    pos = SendCommand(obj, 'ECC_getPosition', i, 0);
                    SendCommand(obj, 'ECC_controlTargetPosition', i, pos, 1);
                    SendCommand(obj, 'ECC_controlMove', i, 1, 1);
                end
            end
            
            % Double Check
            for i=0:2
                movingStatus = SendCommand(obj, 'ECC_getStatusMoving', i, 0);
                if (movingStatus == 2) % Pending
                    SendCommand(obj, 'ECC_controlOutput', i, 1, 1);
                    movingStatus = SendCommand(obj, 'ECC_getStatusMoving', i, 0);
                end
                if movingStatus == 1 % Moving
                    % Moving, Do Nothing
                else % Idle, Force move to current posit
                    pos = SendCommand(obj, 'ECC_getPosition', i, 0);
                    SendCommand(obj, 'ECC_controlTargetPosition', i, pos, 1);
                    SendCommand(obj, 'ECC_controlMove', i, 1, 1);
                end
            end
            
            % Triple Check
            for i=0:2
                movingStatus = SendCommand(obj, 'ECC_getStatusMoving', i, 0);
                if ((movingStatus == 2) || (movingStatus == 0))
                    error('Auto movement failed.');
                else
                    fprintf('Auto movement succeeded for axis %s.\n', obj.axes(i+1));
                end
            end
        end
        
        
        function SetReference(obj, axisName) %Reference
            realAxis = obj.GetAxisInternal(axisName);
            SendCommand(obj, 'ECC_controlAutoReset', realAxis, 1, 1); % Auto Reset is on
            SendCommand(obj, 'ECC_controlReferenceAutoUpdate', realAxis, 1, 1); %when set, every time the reference marking is hit the reference position will be updated.
            range = SendCommand(obj, 'ECC_controlTargetRange', realAxis, 1000, 1);  % setting the range (changed from 10 to 100)
            valid = SendCommand(obj, 'ECC_getStatusReference', realAxis, 0);
            refPos = SendCommand(obj, 'ECC_getReferencePosition', realAxis, 0);
            while (~valid || abs(refPos) > range)
                questionString = sprintf('Refrence isn''t valid for axis %s. Move manually!', obj.axes(realAxis+1));
                if ~QuestionUserOkCancel('Invalid Reference', questionString)
                    break
                end
                valid = SendCommand(obj, 'ECC_getStatusReference', realAxis, 0);
            end
            if (valid && refPos==0)
                fprintf('The reference is set for axis %s.\n', obj.axes(realAxis+1));
            end
        end
        
        
        function axis = getAxis(obj, axisName) %#ok<INUSL>
            % gives the axis number (0 for x, 1 for y, 2 for z) when the
            % user enters the axis name (x,y,z or 1 for x, 2 for y and 3
            % for z).
            axis = ClassECC.GetAxisInternal(axisName) + 1;
            
        end
        
        
        function WaitFor(obj, axisName, what)
            % Waits until a specific action, defined by what, is finished.
            % Current options for what:
            % onTarget - Waits until the stage reaches it's target.
            realAxis = obj.GetAxisInternal(axisName);
            switch what
                case 'onTarget'
                    onTarget = 0;                    
                    while(~onTarget)
                        onTarget = SendCommand(obj, 'ECC_getStatusTargetRange', realAxis, 0);
                    end
            end
        end
        
        
        function Move(obj, axisName, posInMicrons)
            % Checking reference before movement
            % Absolute change in position (the user enters the position in microns) of axis (x,y,z or 1 for x, 2 for y and 3 for z).
            for i=1:length(axisName)
                realAxis = obj.GetAxisInternal(axisName(i));
                phAxis = realAxis +1;
                if (~SendCommand(obj, 'ECC_getStatusReference', realAxis, 0))
                    SetReference(obj, axisName(i));
                end
                %                 SetReference(obj, realAxis)
                pos = posInMicrons(i)*1000; %setting the units to nm
                if (posInMicrons(i) <= obj.posSoftRangeLimit(phAxis)) && (posInMicrons(i) >= obj.negSoftRangeLimit(phAxis)) %checking if the target position is in range
                    %                 axis = GetAxis(obj, axisName);
                    SendCommand(obj, 'ECC_controlTargetPosition', realAxis, pos, 1);
                    SendCommand(obj, 'ECC_controlMove', realAxis, 1, 1);
                else
                    warning ('The position you enter is outside of limit range!')
                end
                WaitFor(obj, axisName(i), 'onTarget')
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
        
        
        function posInMicrons = GetPosition(obj, axisName)
            %returns the position in microns
            len = length(axisName);
            posInMicrons = zeros(1, len);
            
            for i = 1:len
                realAxis = obj.GetAxisInternal(axisName(i));
                obj.curPos(realAxis+1) = SendCommand(obj, 'ECC_getPosition', realAxis ,0);
                posInMicrons(i) = obj.curPos(realAxis+1)./1000;
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
            
            pos = GetPosition(obj, obj.axes);
            for i=0:2
                fprintf ('position on axis %s is %d.\n', obj.axes(i+1), pos(i+1));
            end
        end
        
        
        function SetAmplitude(obj, axisName, amplitudeInVolt)
            %setting the amplitude.
            %input amplitude is in volt.
            %amplitude range is between 0 to 45 volt
            
            if (amplitudeInVolt > obj.maxAmplitude)
%                 amplitude = obj.maxAmplitude*1000;
                error('ECC:VoltOutOfMaxLimit', 'The voltage you enter is too high.');
            elseif (amplitudeInVolt < obj.minAmplitude)
%                 amplitude = obj.minAmplitude*1000;
                error('ECC:VoltOutOfMinLimit', 'The voltage you enter is too low.');
            else
                amplitude = amplitudeInVolt*1000;
            end
            realAxis = obj.GetAxisInternal(axisName);
%             amplitude = amplitudeInVolt*1000;
            SendCommand(obj, 'ECC_controlAmplitude', realAxis, amplitude, 1)
        end
        
        
        function amplitudeInVolt = GetAmplitude(obj, axisName)
            % returns the amplitude.
            % output amplitude is in volt.
            
            realAxis = obj.GetAxisInternal(axisName);
            amplitude = double(SendCommand(obj, 'ECC_controlAmplitude', realAxis, 0, 0));
            amplitudeInVolt = amplitude/1000;
        end
        
        
        function SetFrequency(obj, axisName, frequencyInHz)
            %setting the frequency.
            %input frequency is in Hz.
            %frequency range is between 0 to 1000 Hz.
            
            if (frequencyInHz > obj.maxFrequency)
%                 frequency = obj.maxFrequency*1000;
                error('ECC:FreqOutOfMaxLimit', 'The frequency you enter is too high.');
            elseif (frequencyInHz < obj.minFrequency)
%                 frequency = obj.minFrequency*1000;
                error('ECC:FreqOutOfMinLimit', 'The frequency you enter is too low.');
            else
                frequency = frequencyInHz*1000;                
            end
            realAxis = obj.GetAxisInternal(axisName);
%             frequency = frequencyInHz*1000;
            SendCommand(obj, 'ECC_controlFrequency', realAxis, frequency, 1)
        end
        
        
        function frequencyInHz = GetFrequency(obj, axisName)
            %returns the frequency.
            %output frequency is in Hz.
            
            realAxis = obj.GetAxisInternal(axisName);
            frequency = double(SendCommand(obj, 'ECC_controlFrequency', realAxis, 0, 0));
            frequencyInHz = frequency/1000;
        end
        
        
        function SetResolution(obj, axisName, resolution)
            %setting the resolution.
            %input resolution is in nanometer.
            
            realAxis = obj.GetAxisInternal(axisName);
            SendCommand(obj, 'ECC_controlAQuadBOutResolution', realAxis, resolution, 1)
            switch axisName
                case {1,2,3}
                    if (resolution < 10)
                        error ('ECC:ResOutOfLimit','the resolution you entered is too small');
                    end
            end
        end %
        
        
        function resolution = GetResolution(obj, axisName)
            %returns the resolution.
            %output resolution is in nanometer.
            
            realAxis = obj.GetAxisInternal(axisName);
            resolution = SendCommand(obj, 'ECC_controlAQuadBOutResolution', realAxis, 0, 0);
        end
        
        
        function SetClock(obj, axisName, clockInNano)
            %setting the clock.
            %input clock is in nanometer.
            realAxis = obj.GetAxisInternal(axisName);
            clock = clockInNano/20;
            SendCommand(obj, 'ECC_controlAQuadBOutClock', realAxis, clock, 1)
        end
        
        
        function clockInNano = GetClock(obj, axisName)
            %returns the clock.
            %output clock is in nanometer.
            realAxis = obj.GetAxisInternal(axisName);
            clock = SendCommand(obj, 'ECC_controlAQuadBOutClock', realAxis, 0, 0);
            clockInNano = clock*20;
        end
        
        
        function EnableOutput(obj, axisName, enable)
            % Enables changes in resolution and clock.
            %             enable = bool(enable);
            % if enable = 0 this means disable.
            SendCommand(obj, 'ECC_controlAQuadBOut', obj.GetAxisInternal(axisName), enable, 1);
            if enable % Workaround for a glitch when output is enabled
                SetClock(obj, axisName, 4000)
                SetClock(obj, axisName, 40)
                SetResolution(obj, axisName, 1000)
                SetResolution(obj, axisName, 100)
            end
        end
        
        
        function MoveALot (obj, axisName, steps, displace, res)
            axis = GetAxis(obj,axisName);
            SetResolution(obj, axisName, res);
            for i=1:steps
                pos0 = GetPosition(obj, axisName);
                Move(obj, axisName, pos0(axis)-displace);
                Delay(obj,0.01);
            end
        end
        
        
        function MoveALot1 (obj, axisName, totdisplace, displace, res)
            axis = GetAxis(obj,axisName);
            pos0 = GetPosition(obj, axisName);
            SetResolution(obj, axisName, res);
            steps = totdisplace/displace;
            for i=1:steps
                Move(obj, axisName, pos0(axis)+displace*i);
                Delay(obj,0.01);
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
        
        function SetDefaultVelocity(obj)
            % Set velocity & update location
            for i=1:3
                SetVelocity(obj, i, obj.defaultVel);
            end
        end
        
        function SetVelocity(obj, axisName, velocity) %seting the velocity in microns/sec
            realAxis = obj.GetAxisInternal(axisName);
            switch realAxis
                case {0,1,2}
                    if velocity < 1000
                        SetAmplitude(obj, axisName, 25);
                    else
                        SetAmplitude(obj, axisName, 30);
                    end
                    amplitude = GetAmplitude(obj, axisName);
                    frequency = round((velocity/(amplitude*0.047)));
                    %                 case 2
                    %                     if velocity < 1000
                    %                         SetAmplitude(obj, axisName, 25);
                    %                         amplitude = GetAmplitude(obj, axisName);
                    %                         frequency = round((velocity/(amplitude*0.047)));
                    %                     else
                    %                         SetAmplitude(obj, axisName, 25);
                    %                         amplitude = GetAmplitude(obj, axisName);
                    %                         frequency = round((velocity/(amplitude*0.047)));
                    %                     end
                otherwise
                    error('Could not find axis %s', axisName)
            end
            try
                SetFrequency(obj, axisName, frequency);
                obj.curVel(realAxis+1) = velocity;
            catch err
                switch err.identifier
                    case {'ECC:FreqOutOfMaxLimit', 'ECC:VoltageOutOfMaxLimit'}
                        error('ECC:VelOutOfMaxLimit','the velocity you enter is too high.');
                    case {'ECC:FreqOutOfMinLimit', 'ECC:VoltageOutOfMinLimit'}
                        error('ECC:VelOutOfMinLimit','the velocity you enter is too low.');
                    otherwise
                        rethrow(err)
                end
            end
        end
        
        
        function velocity = GetVelocity(obj, axisName)
            axis = GetAxis(obj,axisName);
            frequency = GetFrequency(obj,axisName);
            amplitude = GetAmplitude(obj,axisName);
            velocity = round(0.047*frequency*amplitude);
            obj.curVel(axis) = velocity;
        end
        
        function vel = Vel(obj, axisName)
            % Query and return velocity of axis (x,y,z or 1 for x, 2 for y
            % and 3 for z)
            % Vectorial axis is possible.
            vel = GetVelocity(obj, axisName);
        end
        
        function ScanOneDimension(obj, axisName, scanAxisVector, tPixel)
            % Does a macro scan for the given axis.
            % axisName - The axis to scan (x,y,z or 1 for x, 2 for y and 3)
            % scanAxisVector - A vector with the points to scan, points
            % should increase with equal distances between them.
            % tPixel - Scan time for each pixel (in seconds).
            % moving to the start point
            
            % prepare scan
            clock = (tPixel*1e9)/1000;
            SetClock(obj, axisName, clock);
            numberOfPixels = length(scanAxisVector) - 1;
            scanLength = scanAxisVector(end)-scanAxisVector(1);
            pixel = 1000*scanLength/numberOfPixels; % resolution in nm
            pixelResolution = ceil(pixel/4);
            fixPosition = pixelResolution/3000;
            startPoint = scanAxisVector(1) - fixPosition;
            endPoint = scanAxisVector(end)+ fixPosition;
            
            if obj.fastScan %Fast Scan
                try
                    SetResolution(obj, axisName, pixelResolution);
                catch err
                    switch err.identifier
                        case 'ECC:ResOutOfLimit'
                            fprintf('can not scan! either you entered too many points or scan length is too short\n');
                            return
                        otherwise
                            rethrow(err)
                    end
                end
                totalTime = numberOfPixels*tPixel;
                scanVelocity = scanLength/(totalTime);
                %normalVelocity = obj.curVel(GetAxis(obj,scanAxis));
                
                try
                    SetVelocity(obj, axisName, scanVelocity);
                catch err
                    switch err.identifier
                        case 'ECC:VelOutOfMaxLimit'
                            error('Can not scan! Either pixel time is too short or scan length is too long');
                        case 'ECC:VelOutOfMinLimit'
                            error('Can not scan! Either pixel time is too long or scan length is too short');
                        otherwise
                            rethrow(err)
                    end
                end
                
                Move(obj, axisName, startPoint);
                GetPosition(obj, axisName);
                
                %start scan
                Delay(obj,0.01);
                Move(obj, axisName, endPoint);
                GetPosition(obj, axisName);
                
                % reset velocety to normalVelocity
                SetVelocity(obj, axisName, obj.defaultVel);
                
                
            else %Slow Scan
                %                 if tPixel < 0.015
                %                     fprintf('Minimum pixel time is 15ms, %.1f were given, changing to 15ms\n', 1000*tPixel);
                %                     tPixel = 0.015;
                %                 end
                %                 tPixel = tPixel - 0.015; % The intrinsic delay is 15ms...
                %                 SetOnTargetWindow(obj, scanAxis, pixelSize, 0.5);
                %                 ChangeMode(obj, scanAxis, 'Nanostepping');
                %                 WaitFor(obj, scanAxis, 'ControllerReady')
                try
                    SetResolution(obj, axisName, pixelResolution);
                catch err
                    switch err.identifier
                        case 'ECC:ResOutOfLimit'
                            fprintf('can not scan! either you entered too many points or scan length is too short\n');
                            return
                        otherwise
                            rethrow(err)
                    end
                end
                fprintf('Scanning...');
                
                if obj.verySlow
                    for i=1:numberOfPixels
                        if (mod(i,numberOfPixels/10) == 0)
                            fprintf(' %d%%',100*i/numberOfPixels);
                        end
                        Move(obj, scanAxis, scanAxisVector(i));
                    end
                else
                    for i=1:numberOfPixels
                        if (mod(i,numberOfPixels/10) == 0)
                            fprintf(' %d%%',100*i/numberOfPixels);
                        end
                        Move(obj, scanAxis, scanAxisVector(i));
                        %                     SendCommand(obj, 'PI_DIO', scanAxisID, 1, 1, 1);
                        Delay(obj, tPixel);
                        %                     SendCommand(obj, 'PI_DIO', scanAxisID, 1, 0, 1);
                    end
                end
                
                % reset velocety to normalVelocity
                SetVelocity(obj, axisName, obj.defaultVel);
            end
        end
        
        function PrepareScanX(obj, x, y, z, nFlat, nOverRun, tPixel)
            % Defines a macro scan for x axis.
            % Call ScanX to start the scan.
            % x - A vector with the points to scan, points should have
            % equal distance between them.
            % y/z - The starting points for the other axes.
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
            % x/z - The starting points for the other axes.
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
            % x/y - The starting points for the other axes.
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
            % y/z - The starting points for the other axes.
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
            % x/z - The starting points for the other axes.
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
            % x/y - The starting points for the other axes.
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
            % Does a macro scan for given axes!
            % scanAxisVector1/2 - Vectors with the points to scan, points
            % should increase with equal distances between them.
            % tPixel - Scan time for each pixel is seconds.
            % scanAxis1/2 - The axes to scan (x,y,z or 1 for x, 2 for y and
            % 3 for z).
            % nFlat - Not used.
            % nOverRun - ignored.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Process Data
            clock = (tPixel*1e9)/1000;
            SetClock(obj, macroScanAxisName, clock);
            SetClock(obj, normalScanAxisName, clock);
            numberOfMacroPixels = length(macroScanAxisVector);
            numberOfNormalPixels = length(normalScanAxisVector);
            
            if (numberOfMacroPixels > obj.maxScanSize)
                fprintf('Can support scan of up to %d pixel for the macro axis, %d were given. Please seperate into several smaller scans externally',...
                    obj.maxScanSize, numberOfMacroPixels);
                return;
            end
            
            if obj.fastScan
                
                macroScanLength = abs(macroScanAxisVector(end)-macroScanAxisVector(1));
                macroPixel = 1000*macroScanLength/numberOfMacroPixels; %Resolution in nm
                macroPixelResolution = ceil(macroPixel/2);
                fixPosition = macroPixelResolution/2000;
                totalTimePerLine = numberOfMacroPixels*tPixel;
                scanVelocity = macroScanLength/(totalTimePerLine);
                SetResolution(obj, macroScanAxisName, macroPixelResolution);
                
                
                % Prepare Scan
                % obj.macroNumberOfPixels = numberOfNormalPixels;
                % obj.macroNormalScanVector = normalScanAxisVector;
                % obj.macroScanVector = macroScanAxisVector;
                % obj.macroNormalScanAxis = normalScanAxisName;
                % obj.macroScanAxis = macroScanAxisName;
                
                
            else %Slow Scan
                %                 if tPixel < 0.015
                %                     fprintf('Minimum pixel time is 15ms, %.1f were given, changing to 15ms\n', 1000*tPixel);
                %                     tPixel = 0.015;
                %                 end
                %                 tPixel = tPixel - 0.015; % The intrinsic delay is 15ms...
                %                 SetOnTargetWindow(obj, macroScanAxisName, macroPixelSize, 0.5);
                %                 SetOnTargetWindow(obj, normalScanAxisName, normalPixelSize, 0.5);
                
                
                macroScanLength = abs(macroScanAxisVector(end)-macroScanAxisVector(1));
                totalTimePerLine = numberOfMacroPixels*tPixel;
                scanVelocity = macroScanLength/(totalTimePerLine);
                %macroPixel = 1000*macroScanLength/numberOfMacroPixels; %Resolution in nm
                %                 macroPixelResolution = ceil(macroPixel/2); %ceil(macroPixel/4);
                macroPixelResolution = 1000*(macroScanAxisVector(2)-macroScanAxisVector(1))/2;
                SetResolution(obj, macroScanAxisName, abs(macroPixelResolution));
                %                 SetResolution(obj, macroScanAxisName, 10);
                fixPosition = macroPixelResolution/1000; %macroPixelResolution/2000;
                obj.macroPixelTime = tPixel;
            end
            
            % Set real start and end points
            startPoint = macroScanAxisVector(1) - fixPosition;
            obj.macroFixPosition = fixPosition;
            
            normalVelocity = obj.curVel(GetAxis(obj, macroScanAxisName));
            obj.macroNormalVelocity = normalVelocity;
            obj.macroScanVelocity = scanVelocity;
            %             obj.macroNormalNumberOfPixels = numberOfNormalPixels;
            %             obj.macroNumberOfPixels = numberOfMacroPixels;
            obj.macroMacroNumberOfPixels = numberOfMacroPixels; %??
            obj.macroNumberOfPixels = numberOfNormalPixels;
            obj.macroNormalScanVector = normalScanAxisVector;
            obj.macroScanVector = macroScanAxisVector;
            obj.macroNormalScanAxis = normalScanAxisName;
            obj.macroScanAxis = macroScanAxisName;
            obj.macroIndex = 1;
            Move(obj, obj.macroScanAxis, startPoint);
        end
        
        function PrepareScanXY(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XY SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xy axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % x/y - Vectors with the points to scan, points should have
            % equal distance between them.
            % z - The starting points for the other axis.
            % nFlat - Not used.
            % nOveRun - ignored.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if (obj.macroIndex ~= -1)
                error('2D Scan is in progress, either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.');
            end
            
            % Must disable other axis output before scan and enable it
            % afterwards - enabling causes noise, disabling doesn't.
            EnableOutput(obj, 'y', 0);
            EnableOutput(obj, 'z', 0);
            
            if ~obj.fastScan && obj.verySlow
                EnableOutput(obj, 'x', 0);
            end
            
            Move(obj, 'z', z);
            PrepareScanInTwoDimensions(obj, x, y, nFlat, nOverRun, tPixel, 'x', 'y');
        end
        
        function PrepareScanXZ(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xz axes!
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
            EnableOutput(obj, 'y', 0);
            EnableOutput(obj, 'z', 0);
            
            if ~obj.fastScan && obj.verySlow
                EnableOutput(obj, 'x', 0);
            end
            
            Move(obj, 'y', y);
            PrepareScanInTwoDimensions(obj, x, z, nFlat, nOverRun, tPixel, 'x', 'z');
        end
        
        function PrepareScanYX(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XY SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xy axes!
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
            
            if ~obj.fastScan && obj.verySlow
                EnableOutput(obj, 'y', 0);
            end
            
            Move(obj, 'z', z);
            PrepareScanInTwoDimensions(obj, y, x, nFlat, nOverRun, tPixel, 'y', 'x');
        end
        
        function PrepareScanYZ(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL YZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for yz axes!
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
            
            if ~obj.fastScan && obj.verySlow
                EnableOutput(obj, 'y', 0);
            end
            
            Move(obj, 'x', x);
            PrepareScanInTwoDimensions(obj, y, z, nFlat, nOverRun, tPixel, 'y', 'z');
        end
        
        function PrepareScanZX(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xz axes!
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
            
            if ~obj.fastScan && obj.verySlow
                EnableOutput(obj, 'z', 0);
            end
            
            Move(obj, 'y', y);
            PrepareScanInTwoDimensions(obj, z, x, nFlat, nOverRun, tPixel, 'z', 'x');
        end
        
        function PrepareScanZY(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL YZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for yz axes!
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
            
            if ~obj.fastScan && obj.verySlow
                EnableOutput(obj, 'z', 0);
            end
            
            Move(obj, 'x', x);
            PrepareScanInTwoDimensions(obj, z, y, nFlat, nOverRun, tPixel, 'z', 'y');
        end
        
        function [done, forwards] = ScanNextLine(obj)
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
            
            if obj.fastScan % Fast Scan
                
                if (obj.macroIndex == 1)
                    try
                        SetVelocity(obj, obj.macroScanAxis, obj.macroScanVelocity);
                    catch err
                        switch err.identifier
                            case 'ECC:VelOutOfMaxLimit'
                                warning('can not scan! either pixel time is too short or scan length is too long\n Continuing with Maximal Velocity\n');
%                                 return
                            case 'ECC:VelOutOfMinLimit'
                                warning('can not scan! either pixel time is too long or scan length is too short\n Continuing with Minimal Velocity\n');
%                                 return
                            otherwise
                                rethrow(err)
                        end
                    end
                end
                pause(2); %Added to give the Controller some more time....
                
                if (obj.macroIndex > obj.macroNumberOfPixels)
                    error('Attempted to scan next line after last line!')
                end
                
                % Scan
                Move(obj, obj.macroNormalScanAxis, obj.macroNormalScanVector(obj.macroIndex));
                if (mod(obj.macroIndex,2) ~= 0)
                    Move(obj,obj.macroScanAxis,obj.macroScanVector(end)+obj.macroFixPosition);
                    forwards = 1;
                else
                    Move(obj,obj.macroScanAxis,obj.macroScanVector(1)-obj.macroFixPosition);
                    forwards = 0;
                end
                
%                 % Change settings back
%                 done = (obj.macroIndex == obj.macroNumberOfPixels);
%                 obj.macroIndex = obj.macroIndex+1;
                
            else % Slow Scan
                
                if obj.verySlow
                    % create DAQ pulse out task (to create the per-pixel
                    % pulses that time the detection)
                    %                     ptask = SinglePulseTask(obj.macroPixelTime);
                    %                     status = DAQmxStartTask(ptask);
                    %                     DAQmxErr(status)
                    
                    tPixel = obj.macroPixelTime - 0.006;
                    if tPixel < 0
                        fprintf('Minimum pixel time is 6 ms, %.1f were given, changing to 6ms\n', 1000*tPixel);
                        tPixel = 0;
                    end
                    
                    device = 'dev1';
                    port = 1;
                    line = 3;
                    
                    DAQmx_Val_ChanForAllLines = daq.ni.NIDAQmx.DAQmx_Val_ChanForAllLines;
                    DAQmx_Val_GroupByChannel = daq.ni.NIDAQmx.DAQmx_Val_GroupByChannel;
                    
                    [ status, ~, task ] = DAQmxCreateTask([]);
                    DAQmxErr(status);
                    
                    status = DAQmxCreateDOChan(task, sprintf('/%s/port%d/line%d', device, port, line), '', DAQmx_Val_ChanForAllLines);
                    DAQmxErr(status);
                    
                    %Start Very Slow Scan
                    Move(obj, obj.macroNormalScanAxis, obj.macroNormalScanVector(obj.macroIndex));
                    if (mod(obj.macroIndex,2) ~= 0) % Forwards
                        for i=1:obj.macroMacroNumberOfPixels
                            %tic;
                            Move(obj, obj.macroScanAxis, obj.macroScanVector(i));
                            %toc
                            DAQmxWriteDigitalU32(task, 1, 1, 10, DAQmx_Val_GroupByChannel, 2^line, 1);
                            Delay(obj,tPixel);
                            DAQmxWriteDigitalU32(task, 1, 1, 10, DAQmx_Val_GroupByChannel, 0, 1);
                            %                             DAQmxSendSoftwareTrigger(ptask, 0);
                            %                             MakeSingleQuad(obj,obj.macroPixelTime);
                            %Delay(0.05); % This is so the stage wont move before the DAQ turns off the trigger
                        end
                        forwards = 1;
                    else % Backwards
                        for i=obj.macroMacroNumberOfPixels:-1:1
                            Move(obj, obj.macroScanAxis, obj.macroScanVector(i));
                            DAQmxWriteDigitalU32(task, 1, 1, 10, DAQmx_Val_GroupByChannel, 2^line, 1);
                            Delay(obj,tPixel);
                            DAQmxWriteDigitalU32(task, 1, 1, 10, DAQmx_Val_GroupByChannel, 0, 1);
                        end
                        forwards = 0;
                    end
                    
                    DAQmxStopTask(task);
                    DAQmxClearTask(task);
                    
                else
                    Move(obj, obj.macroNormalScanAxis, obj.macroNormalScanVector(obj.macroIndex));
                    if (mod(obj.macroIndex,2) ~= 0) % Forwards
                        for i=1:obj.macroMacroNumberOfPixels
                            Move(obj, obj.macroScanAxis, obj.macroScanVector(i));
                            Delay(obj,obj.macroPixelTime);
                        end
                        Move(obj, obj.macroScanAxis, obj.macroScanVector(end)+0.5*(obj.macroScanVector(2)-obj.macroScanVector(1)));
                        forwards = 1;
                    else % Backwards
                        for i=obj.macroMacroNumberOfPixels:-1:1
                            Move(obj, obj.macroScanAxis, obj.macroScanVector(i));
                            Delay(obj,obj.macroPixelTime);
                        end
                        Move(obj, obj.macroScanAxis, obj.macroScanVector(end)+obj.macroScanVector(2)-obj.macroScanVector(1));
                        forwards = 0;
                    end
                end
            end
            
            done = (obj.macroIndex == obj.macroNumberOfPixels);
            obj.macroIndex = obj.macroIndex+1;
            
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
            if (obj.macroScanAxis ~= -1) && (obj.macroNormalVelocity ~= -1)
                SetVelocity(obj, obj.macroScanAxis, obj.macroNormalVelocity);
            end
            obj.macroIndex = -1;
        end
        
        function ok = PointIsInRange(obj, axisName, point)
            % Checks if the given point is within the soft (and hard)
            % limits of the given axis (x,y,z or 1 for x, 2 for y and 3 for z).
            % Vectorial axis is possible.
            ok = ((point >= obj.negSoftRangeLimit*ones(size(axisName))) && (point <= obj.posSoftRangeLimit*ones(size(axisName))));
        end
        
        function [negSoftLimit, posSoftLimit] = ReturnLimits(obj, axisName)
            % Return the soft limits of the given axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            phAxis = obj.getAxis(axisName);
            negSoftLimit = obj.negSoftRangeLimit(phAxis);
            posSoftLimit = obj.posSoftRangeLimit(phAxis);
        end
        
        function [negHardLimit, posHardLimit] = ReturnHardLimits(obj, axisName)
            % Return the hard limits of the given axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            phAxis = obj.getAxis(axisName);
            negHardLimit = obj.negRangeLimit(phAxis);
            posHardLimit = obj.posRangeLimit(phAxis);
        end
        
        function SetSoftLimits(obj, phAxis, softLimit, negOrPos)
            % Set the new soft limits:
            % if negOrPos = 0 -> then softLimit = lower soft limit
            % if negOrPos = 1 -> then softLimit = higher soft limit
            % This is because each time this function is called only one of
            % the limits updates
            axisIndex = getAxis(obj, phAxis);
            
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
        
        
        function JoystickControl(obj, enable)
            % Changes the joystick state for all axes to the value of
            % 'enable' - 1 to turn Joystick on, 0 to turn it off.
            fprintf('No joystick connected\n');
        end
        
        function binaryButtonState = ReturnJoystickButtonState(obj) %#ok<MANU>
            % Returns the state of the buttons in 3 bit decimal format.
            % 1 for first button, 2 for second and 4 for the 3rd.
            binaryButtonState = 0;
        end
        
        
        
        
        function CloseConnection(obj)
            % Closes the connection to the controllers.
            if (obj.eHandle ~= -1)
                % Handle exists, attempt to close
                SendRawCommand(obj, 'ECC_Close', obj.eHandle);
                % estat = calllib('ecc','ECC_Close', eHandle);
                fprintf('Connection Closed: Handle %d released.\n', obj.eHandle);
                obj.eHandle = -1;
            else
                % Handle does not exists, ask user what to do.
                titleString = 'No Handle found';
                questionString = sprintf('Device Handle not found.\nDevice Handle is needed in order to close the connection.');
                closeDefaultString = 'Force Close Handles from 0 to 512';
                closeCustomString = 'Force Close a Custom Range of Handles';
                abortString = 'Abort';
                confirm = questdlg(questionString, titleString, closeDefaultString, abortString, closeDefaultString);
                switch confirm
                    case closeDefaultString
                        startRange = 0;
                        endRange = 512;
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
        
        function FastScan(obj, enable)
            % Changes the scan between fast & slow mode
            % 'enable' - 1 for fast scan, 0 for slow scan.
            if (obj.macroIndex ~= -1)
                error('2D Scan is in progress, either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.');
            end
            obj.fastScan = enable;
        end
        
        function VerySlow(obj, enable)
            % Changes the scan between fast & slow mode
            % 'enable' - 1 for fast scan, 0 for slow scan.
            if (obj.macroIndex ~= -1)
                error('2D Scan is in progress, either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.');
            end
            
            obj.verySlow = enable;
        end
    end
    
    methods
        % Blank/warning implementions of unavailable methods
        function ChangeLoopMode(obj, mode)
        % Changes between closed and open loop.
        % Mode should be either 'Open' or 'Closed'.
        end
        
        function success = SetTiltAngle(obj, thetaXZ, thetaYZ)
            % Sets the tilt angles between Z axis and XY axes.
            % Angles should be in degrees, valid angles are between -5 and 5
            % degrees.
            success = 0;
            obj.warningTiltUnimplemented();
        end
        
        function success = EnableTiltCorrection(obj, enable)
            % Enables the tilt correction according to the angles.
            success = 0;
            obj.warningTiltUnimplemented();
        end
        
        function [tiltEnabled, thetaXZ, thetaYZ] = GetTiltStatus(obj) %#ok<MANU>
            % Return the status of the tilt control.
            tiltEnabled = 0;
            thetaXZ = 0;
            thetaYZ = 0;
        end
        
        function Halt(obj) %#ok<MANU>
            warning('Stage has no halting mechanism!')
        end
        
    end
end