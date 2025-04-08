classdef (Sealed) ClassPILPS65 < ClassPIMicos
    % Created by Yoav Romach, The Hebrew University, September, 2016
    % Used to control 3 PI Micos LPS-65 Piezo Motor stages
    % libfunctionsview('PI') to view functions
    
    properties (Constant, Access = protected)
        controllerModel = 'E-861';
        validAxes = 'xyz';
        units = 'um';
    end
    
    properties (Constant, Access = private)  % todo: is this the right place for it?
        maxScanSize = [198 98];
        szAxes = '1';
    end
    
    properties (Access = protected)
        ID
        axesID
        posRangeLimit
        negRangeLimit
        posSoftRangeLimit
        negSoftRangeLimit
        defaultVel
        curPos
        curVel
        forceStop
        scanRunning
        scanStruct
        
        macroNormalNumberOfPixels
        macroNumberOfPixels
        macroNormalScanVector
        macroScanVector
        macroNormalScanAxis
        macroScanAxis
        macroScanVelocity
        macroNormalVelocity
        macroPixelTime
        macroStartPoint
        macroEndPoint
        macroIndex
        macroScan
    end
    
    properties (Constant)
        NAME = 'Stage (fine) - PI LPS65'
        
        NEEDED_FIELDS = {'niDaqChannel'}
        
        STEP_MINIMUM_SIZE = 0.0005  % Check!
        STEP_DEFAULT_SIZE = 0.1     % Check!
        
        MINIMUM_SLOW_PIXEL_TIME = 15e-3;    % in seconds ( == 15ms )
        MINIMUM_FAST_PIXEL_TIME = 5e-3;     % in seconds ( == 15ms )
    end
    
    methods (Static, Access = public) % Get instance constructor
        function obj = create(stageStruct)
            
            missingField = FactoryHelper.usualChecks(stageStruct, ClassPILPS65.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Trying to create the ClassPILPS65 stage, needed field "%s" was missing. Aborting',...
                    missingField);
            end
            
            niDaqChannel = stageStruct.niDaqChannel;
            removeObjIfExists(ClassPILPS65.NAME);
            obj = ClassPILPS65(niDaqChannel);
        end
    end
    
    methods (Access = private) % Private Functions
        function obj = ClassPILPS65(niDaqChannel)
            % Private default constructor.
            name = ClassPILPS65.NAME;
            availAxis = ClassPILPS65.validAxes;
            obj = obj@ClassPIMicos(name, availAxis);
            
            daq = getObjByName(NiDaq.NAME);
            daq.registerChannel(niDaqChannel, obj.name);
            
            obj.ID = -1;
            obj.axesID = [-1, -1, -1];
            obj.posRangeLimit = [6500 6500 6500]; % Units set to microns.
            obj.negRangeLimit = [-6500 -6500 -6500]; % Units set to microns.
            obj.posSoftRangeLimit = obj.posRangeLimit;
            obj.negSoftRangeLimit = obj.negRangeLimit;
            obj.defaultVel = 500; % Default velocity is 500 um/s.
            obj.curPos = [0 0 0];
            obj.curVel = [0 0 0];
            obj.forceStop = 0;
            obj.scanRunning = 0;
            obj.scanStruct = struct([]);
            
            % Properties of fast ("macro") scan
            obj.macroNormalNumberOfPixels = -1;
            obj.macroNumberOfPixels = -1;
            obj.macroNormalScanVector = -1;
            obj.macroScanVector = -1;
            obj.macroNormalScanAxis = -1;
            obj.macroScanAxis = -1;
            obj.macroScanVelocity = -1;
            obj.macroNormalVelocity = -1;
            obj.macroPixelTime = -1;
            obj.macroStartPoint = -1;
            obj.macroEndPoint = -1;
            obj.macroIndex = -1;
            obj.macroScan = 0; % 0 for slow scan, 1 for fast scan
            
            obj.availableProperties.(obj.HAS_FAST_SCAN) = true;
            obj.availableProperties.(obj.HAS_SLOW_SCAN) = true;
            obj.availableProperties.(obj.TILTABLE) = true;
            obj.availableProperties.(obj.HAS_CLOSED_LOOP) = true;
            obj.availableProperties.(obj.HAS_OPEN_LOOP) = true;
            obj.getJoystick;        % inits the joystick, and adds it to the available properties
            
            obj.Connect();
            obj.Initialization();
        end
    end
    
    methods (Access = protected) % Overwrite ClassPIMicos functions
        function Connect(obj)
            % Connects to all axes controllers.
            if obj.ID < 0
                % Look for USB controller
                USBDescription = obj.FindController(obj.controllerModel);
                
                % Open USB daisy chain
                [obj.ID, ~, numberOfConnectedDevices, ~] = SendPICommandWithoutReturnCode(obj, 'PI_OpenUSBDaisyChain', USBDescription, 0, blanks(1024), 1024); %increased [blanks(128), 128] to [blanks(1024), 1024]
                obj.CheckIDForError(obj.ID, 'USB Controller found but connection attempt failed!');
                % fprintf('Found %d devices connected to %s via USB',numberOfConnectedDevices,USBDescription);
                
                if numberOfConnectedDevices ~= length(obj.validAxes)
                    calllib(obj.libAlias, 'PI_CloseDaisyChain', obj.ID);
                    obj.sendError(sprintf('There should be %d devices, one for each axis!', length(obj.validAxes)))
                end
            end
            
            % Connect to axes
            for i = 1:numberOfConnectedDevices
                if obj.axesID(i) < 0
                    obj.axesID(i) = SendPICommandWithoutReturnCode(obj, 'PI_ConnectDaisyChainDevice', obj.ID, i);
                    obj.CheckIDForError(obj.axesID(i), ['Could not connect to ' obj.axesName(i) ' axis controller!']);
                end
            end
        end
        
        function DisconnectController(obj, id)
            % This function disconnects the controller at the given ID
            fprintf('Trying to close daisy chain with ID %d (%d/3)\n', id/3, id);
            SendPICommandWithoutReturnCode(obj, 'PI_CloseDaisyChain', id/3);
        end
        
        function Initialization(obj)
            % Initializes the piezo stages.
            
            % Turns off joystick
            JoystickControl(obj, false);
            
            % Set mode to mixed.
            for i=1:length(obj.validAxes)
                ChangeMode(obj, obj.axesName(i), 'Mixed');
            end
            
            % Reference
            CheckRefernce(obj, obj.validAxes)
            
            % Physical units check
            for i=1:length(obj.validAxes)
                [~,~,~,axisUnits] = SendPICommand(obj, 'PI_qSPA', obj.axesID(i), obj.szAxes, hex2dec('7000601'), 0, '', 4);
                if ~strcmpi(strtrim(axisUnits), obj.units)
                    obj.sendError(sprintf('%s axis - Stage units are in%s, should be%s', upper(obj.axesName(i)), axisUnits, obj.units));
                else
                    fprintf('%s axis - Units are in%s for position and%s/s for velocity.\n', upper(obj.axesName(i)), obj.units, obj.units);
                end
            end
            
            % Physical limit check
            for i=1:length(obj.validAxes)
                [~,~,posPhysicalLimitDistance,~] = SendPICommand(obj, 'PI_qSPA', obj.axesID(i), obj.szAxes, 47, 0, '', 0);
                [~,~,negPhysicalLimitDistance,~] = SendPICommand(obj, 'PI_qSPA', obj.axesID(i), obj.szAxes, 23, 0, '', 0);
                if ((negPhysicalLimitDistance ~= -obj.negRangeLimit(i)) || (posPhysicalLimitDistance ~= obj.posRangeLimit(i)))
                    errorMsg = sprintf('Physical limits for %s axis are incorrect!\nShould be: %d to %d.\nReal value: %d to %d.\nMaybe units are incorrect?',...
                        obj.axesName(i), obj.negRangeLimit, obj.posRangeLimit, -negPhysicalLimitDistance, posPhysicalLimitDistance);
                    obj.sendError(errorMsg);
                end
                fprintf('%s axis - Physical limits are from %d%s to %d%s.\n', upper(obj.axesName(i)), obj.negRangeLimit(i), obj.units, obj.posRangeLimit(i), obj.units);
            end
            
            % Soft limit check.
            for i=1:length(obj.validAxes)
                [~,~,obj.posSoftRangeLimit(i),~] = SendPICommand(obj, 'PI_qSPA', obj.axesID(i), obj.szAxes, 21, 0, '', 0);
                [~,~,obj.negSoftRangeLimit(i),~] = SendPICommand(obj, 'PI_qSPA', obj.axesID(i), obj.szAxes, 48, 0, '', 0);
                fprintf('%s axis - Soft limits are from %.1f%s to %.1f%s.\n', upper(obj.axesName(i)), obj.negSoftRangeLimit(i), obj.units, obj.posSoftRangeLimit(i), obj.units);
            end
            
            % Set velocity
            for i=1:length(obj.validAxes)
                SetVelocity(obj, i, obj.defaultVel);
            end
            
            % Update position and velocity
            QueryPos(obj);
            QueryVel(obj);
            for i=1:length(obj.validAxes)
                fprintf('%s axis - Position: %.4f%s, Velocity: %d%s/s.\n', upper(obj.axesName(i)), obj.curPos(i), obj.units, obj.curVel(i), obj.units);
            end
            
            % Delete Macros
            for i=1:length(obj.validAxes)
                DeleteMacro(obj, obj.axesID(i) , '')
            end
            obj.scanStruct = struct([]);
        end
        
        function ChangeMode(obj, phAxis, mode)
            % Changes between mixed mode and nano stepping mode.
            % Mode should be:
            % 'Mixed' - for mixed analog and nano stepping mode.
            % 'Nanostepping' - for nano stepping mode only.
            % This function is lengthy operation, if directly after this
            % function another command is being sent to the controller then
            % WaitFor(obj, axis, 'ControllerReady') should be added.
            axisID = obj.axesID(GetAxis(obj, phAxis));
            switch mode
                case 'Mixed'
                    SendPICommand(obj, 'PI_SPA', axisID, obj.szAxes, hex2dec('7001A00'), 1, '');
                case 'Nanostepping'
                    SendPICommand(obj, 'PI_SPA', axisID, obj.szAxes, hex2dec('7001A00'), 0, '');
                otherwise
                    errorMsg = sprintf('Unknown mode %s', mode);
                    obj.sendError(errorMsg);
            end
            ChangeLoopMode(obj, phAxis, 'Closed');
        end
        
        function SetOnTargetWindow(obj, phAxis, pixelSize, spatialResolutionRatio)
            % Sets the OnTarget window according to the given pixel size
            % and resolution.
            % The window is given by +-(pixelSize*spatialResolutionRatio)/2
            axisID = obj.axesID(GetAxis(obj, phAxis));
            counts = round(pixelSize*spatialResolutionRatio/0.0005); % 1 count is 0.5nm
            SendPICommand(obj, 'PI_SPA', axisID, obj.szAxes, hex2dec('36'), counts, '')
        end
        
        function QueryPos(obj)
            % Queries the position for all axes and updates the internal
            % variables.
            for i=1:length(obj.validAxes)
                [~,obj.curPos(i)] = SendPICommand(obj, 'PI_qPOS', obj.axesID(i), obj.szAxes, obj.curPos(i));
            end
        end
        
        function QueryVel(obj)
            % Queries the velocity for all axes and updates the internal
            % variables.
            for i=1:length(obj.validAxes)
                [~,obj.curVel(i)] = SendPICommand(obj, 'PI_qVEL', obj.axesID(i), obj.szAxes, obj.curVel(i));
            end
        end
        
        function WaitFor(obj, phAxis, what)
            % Waits until a specific action, defined by what, is finished.
            % 'phAxis' should be a specific axis (x,y,z or 1 for x, 2 for y
            % and 3 for z).
            % Current options for what:
            % MovementDone - Waits until movement is done.
            % onTarget - Waits until the stage reaches it's target.
            % MacroDone - Waits until the macro stopped running.
            % ControllerReady - Waits until the controller is ready.
            axisID = obj.axesID(GetAxis(obj, phAxis));
            timer = tic;
            timeout = 30; % 30 second timeout
            wait = 1;
            while wait
                drawnow % Needed in order to get input from GUI
                if obj.forceStop % Checks if the user pressed the Halt Button
                    HaltPrivate(obj, axisID);
                    break;
                end
                
                switch what
                    case 'MovementDone'
                        [~, moving] = SendPICommand(obj, 'PI_IsMoving', axisID, obj.szAxes, 1);
                        wait = moving;
                    case 'onTarget'
                        [~, onTarget] = SendPICommand(obj, 'PI_qONT', axisID, obj.szAxes, 0);
                        wait = ~onTarget;
                    case 'MacroDone'
                        macroRunning = SendPICommand(obj, 'PI_IsRunningMacro', axisID, 1);
                        wait = macroRunning;
                    case 'ControllerReady'
                        ready = SendPICommand(obj, 'PI_IsControllerReady', axisID, 0);
                        wait = ~ready;
                    otherwise
                        errorMsg = sprintf('Wrong Input %s', what);
                        obj.sendError(errorMsg);
                end
                
                if (toc(timer) > timeout)
                    warning('Warning, timed out while waiting for controller status: "%s"', what);
                    break
                end
            end
        end
        
        function DeleteMacro(obj, axisID, macroName)
            % Deletes the given macro from the controller.
            % If macroName is null, deletes all macros.
            % Macro names are case insensitive.
            [~, macroNames] = SendPICommand(obj, 'PI_qMAC', axisID, '', blanks(64), 64);
            macroNames = strsplit(macroNames);
            for i=1:length(macroNames)
                if isempty(macroNames{i})
                    continue
                elseif isempty(macroName)
                    %                     fprintf('Macro deleted: %s\n',macroNames{i});
                    SendPICommand(obj, 'PI_MAC_DEL', axisID, macroNames{i});
                elseif strcmpi(macroName, macroNames{i})
                    %                     fprintf('Macro deleted: %s\n',macroName);
                    SendPICommand(obj, 'PI_MAC_DEL', axisID, macroName);
                end
            end
        end
        
        function ScanOneDimension(obj, scanAxisVector, nFlat, nOverRun, tPixel, scanAxis)
            %%%%%%%%%%%%%% ONE DIMENSIONAL SCAN MACRO %%%%%%%%%%%%%%
            % Does a macro scan for the given axis.
            % scanAxisVector - A vector with the points to scan, points
            % should increase with equal distances between them.
            % nFlat - Not used.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel (in seconds).
            % scanAxis - The axis to scan (x,y,z or 1 for x, 2 for y and 3
            % for z).
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            numberOfPixels = length(scanAxisVector);
            scanAxis = GetAxis(obj, scanAxis);
            scanAxisID = obj.axesID(scanAxis);
            scanLength = scanAxisVector(end)-scanAxisVector(1);
            pixelSize = scanLength/(numberOfPixels-1);
            
            for i=1:length(obj.validAxes)% set all stage outputs to zero before the scan (so the or gate will work)
                SendPICommand(obj, 'PI_DIO', obj.axesID(i), 1, 0, 1);
            end
            
            if obj.macroScan % Macro Scan
                %% Process Data
                if (numberOfPixels > obj.maxScanSize(1))
                    fprintf('Can support scan of up to %d pixel, %d were requested. Please seperate into several smaller scans externally', obj.maxScanSize(1), numberOfPixels);
                    return;
                end
                minTPixel = obj.MINIMUM_FAST_PIXEL_TIME;
                if tPixel < minTPixel
                    fprintf('Minimum pixel time is %.1fms, %.1f were requested, changing to %.1fms\n', ...
                        1000*minTPixel, 1000*tPixel, 1000*minTPixel);
                    tPixel = minTPixel;
                end
                
                scanVelocity = abs(pixelSize/tPixel);
                normalVelocity = obj.curVel(scanAxis);
                
                % Set real start and end points
                if (nOverRun == 0); nOverRun = 2; end % In order to be centered around the pixel we need at least one extra point from each side.
                startPoint = scanAxisVector(1) - pixelSize*nOverRun;
                endPoint = scanAxisVector(end) + pixelSize*nOverRun;
                
                %% Write Macro only if last scan was different
                localScanStruct = struct('scanAxisVector', scanAxisVector, 'nFlat', nFlat, 'nOverRun', nOverRun, 'tPixel', tPixel, 'scanAxis', scanAxis, 'd', 1);
                if ~isequal(localScanStruct, obj.scanStruct)
                    obj.scanStruct = localScanStruct;
                    DeleteMacro(obj, scanAxisID, '');
                    fprintf('Writing Macro...');
                    
                    if (scanAxisVector(end) > scanAxisVector(1))
                        string = 'POS? 1 > ';
                    else
                        string = 'POS? 1 < ';
                    end
                    
                    SendPICommand(obj, 'PI_MAC_BEG', scanAxisID, 'SCAN');
                    SendPICommand(obj, 'PI_MOV', scanAxisID, obj.szAxes, endPoint);
                    for i=1:numberOfPixels
                        if (mod(i,numberOfPixels/10) == 0)
                            fprintf(' %d%%',100*i/numberOfPixels);
                        end
                        SendPICommand(obj, 'PI_WAC', scanAxisID, [string num2str(scanAxisVector(i) - pixelSize/2)]);
                        SendPICommand(obj, 'PI_DIO', scanAxisID, 1, 1, 1); % stage output 1
                        SendPICommand(obj, 'PI_DIO', scanAxisID, 1, 0, 1); % stage output 0
                    end
                    SendPICommand(obj, 'PI_WAC', scanAxisID, [string num2str(scanAxisVector(end) + pixelSize/2)]);
                    SendPICommand(obj, 'PI_DIO', scanAxisID, 1, 1, 1); % stage output 1
                    SendPICommand(obj, 'PI_DIO', scanAxisID, 1, 0, 1); % stage output 0
                    fprintf('\n');
                    SendPICommand(obj, 'PI_MAC_END', scanAxisID);
                else
                    fprintf('Using macro from previous scan''s.\n');
                end
                
                %% Run Macro
                % Prepare Axis
                ChangeMode(obj, scanAxis, 'Nanostepping');
                WaitFor(obj, scanAxis, 'ControllerReady')
                MovePrivate(obj, scanAxis, startPoint);
                SetVelocity(obj, scanAxis, scanVelocity);
                
                % Run Macro
                SendPICommand(obj, 'PI_MAC_START', scanAxisID, 'SCAN');
                WaitFor(obj, scanAxis, 'MacroDone');
                
                % Change settings back.
                ChangeMode(obj, scanAxis, 'Mixed');
                WaitFor(obj, scanAxis, 'ControllerReady')
                SetVelocity(obj, scanAxis, normalVelocity);
                
            else % Slow Scan
                minTPixel = obj.MINIMUM_SLOW_PIXEL_TIME;
                if tPixel < minTPixel
                    fprintf('Minimum pixel time is %.1fms, %.1f were requested, changing to %.1fms\n', ...
                        1000*minTPixel, 1000*tPixel, 1000*minTPixel);
                    tPixel = minTPixel;
                end
                tPixel = tPixel - 0.015; % The intrinsic delay is 15ms...
                SetOnTargetWindow(obj, scanAxis, abs(pixelSize), 0.5);
                ChangeMode(obj, scanAxis, 'Nanostepping');
                WaitFor(obj, scanAxis, 'ControllerReady')
                %                 start = clock;
                fprintf('Scanning...');
                %                 fprintf(' - %.3fs \n', sum(clock-start));
                for i=1:numberOfPixels
                    if (mod(i,numberOfPixels/10) == 0)
                        fprintf(' %d%%',100*i/numberOfPixels);
                    end
                    MovePrivate(obj, scanAxis, scanAxisVector(i));
                    SendPICommand(obj, 'PI_DIO', scanAxisID, 1, 1, 1);
                    Delay(obj, tPixel);
                    SendPICommand(obj, 'PI_DIO', scanAxisID, 1, 0, 1);
                end
                fprintf('\n');
                ChangeMode(obj, scanAxis, 'Mixed');
                WaitFor(obj, scanAxis, 'ControllerReady')
            end
        end
        
        function PrepareScanInTwoDimensions(obj, macroScanAxisVector, normalScanAxisVector, nFlat, nOverRun, tPixel, macroScanAxis, normalScanAxis)
            %%%%%%%%%%%%%% TWO DIMENSIONAL SCAN MACRO %%%%%%%%%%%%%%
            % Does a macro scan for given axes!
            % scanAxisVector1/2 - Vectors with the points to scan, points
            % should increase with equal distances between them.
            % nFlat - Not used.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            % scanAxis1/2 - The axes to scan (x,y,z or 1 for x, 2 for y and
            % 3 for z).
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            numberOfMacroPixels = length(macroScanAxisVector);
            numberOfNormalPixels = length(normalScanAxisVector);
            macroScanAxis = GetAxis(obj, macroScanAxis);
            macroScanAxisID = obj.axesID(macroScanAxis);
            macroScanLength = macroScanAxisVector(end)-macroScanAxisVector(1);
            macroPixelSize = macroScanLength/(numberOfMacroPixels-1);
            normalScanAxis = GetAxis(obj, normalScanAxis);
            normalScanLength = normalScanAxisVector(end)-normalScanAxisVector(1);
            normalPixelSize = normalScanLength/(numberOfNormalPixels-1);

            for i=1:length(obj.validAxes)% set all stage outputs to zero before the scan (so the or gate will work)
                SendPICommand(obj, 'PI_DIO', obj.axesID(i), 1, 0, 1);
            end
            
            if obj.macroScan % Macro Scan
                if (numberOfMacroPixels > obj.maxScanSize(2))
                    fprintf('Can support scan of up to %d pixel for the macro axis, %d were requested. Please seperate into several smaller scans externally',...
                        obj.maxScanSize(2), numberOfMacroPixels);
                    return;
                end
                
                minTPixel = obj.MINIMUM_FAST_PIXEL_TIME;
                if tPixel < minTPixel
                    fprintf('Minimum pixel time is %.1fms, %.1f were requested, changing to %.1fms\n', ...
                        1000*minTPixel, 1000*tPixel, 1000*minTPixel);
                    tPixel = minTPixel;
                end
                
                scanVelocity = abs(macroPixelSize/tPixel);
                normalVelocity = obj.curVel(macroScanAxis);
                
                % Set real start and end points
                if (nOverRun == 0); nOverRun = 1; end % In order to be centered around the pixel we need at least one extra point from each side.
                startPoint = macroScanAxisVector(1) - macroPixelSize*nOverRun;
                endPoint = macroScanAxisVector(end) + macroPixelSize*nOverRun;
                
                %% Write Macros only if last scan was different
                localScanStruct = struct('scanAxisVector', macroScanAxisVector, 'nFlat', nFlat, 'nOverRun', nOverRun, 'tPixel', tPixel, 'scanAxis', macroScanAxis, 'd', 2);
                if ~isequal(localScanStruct, obj.scanStruct)
                    obj.scanStruct = localScanStruct;
                    DeleteMacro(obj, macroScanAxisID, '');
                    
                    if (macroScanAxisVector(end) > macroScanAxisVector(1))
                        forwardString = 'POS? 1 > ';
                        backwardString = 'POS? 1 < ';
                    else
                        forwardString = 'POS? 1 < ';
                        backwardString = 'POS? 1 > ';
                    end
                     
                    % Forward
                    fprintf('Writing Forward Macro...');
                    SendPICommand(obj, 'PI_MAC_BEG', macroScanAxisID, 'SCANFORW');
                    SendPICommand(obj, 'PI_MOV', macroScanAxisID, obj.szAxes, endPoint);
                    for i=1:numberOfMacroPixels
                        if (mod(i,numberOfMacroPixels/10) == 0)
                            fprintf(' %d%%',100*i/numberOfMacroPixels);
                        end
                        SendPICommand(obj, 'PI_WAC', macroScanAxisID, [forwardString num2str(macroScanAxisVector(i) - macroPixelSize/2)]);
                        SendPICommand(obj, 'PI_DIO', macroScanAxisID, 1, 1, 1); % stage output 1
                        SendPICommand(obj, 'PI_DIO', macroScanAxisID, 1, 0, 1); % stage output 0
                    end
                    SendPICommand(obj, 'PI_WAC', macroScanAxisID, [forwardString num2str(macroScanAxisVector(end) + macroPixelSize/2)]);
                    SendPICommand(obj, 'PI_DIO', macroScanAxisID, 1, 1, 1); % stage output 1
                    SendPICommand(obj, 'PI_DIO', macroScanAxisID, 1, 0, 1); % stage output 0
                    fprintf('\n');
                    SendPICommand(obj, 'PI_MAC_END', macroScanAxisID);
                    
                    % Backward
                    fprintf('Writing Backward Macro...');
                    SendPICommand(obj, 'PI_MAC_BEG', macroScanAxisID, 'SCANBACK');
                    SendPICommand(obj, 'PI_MOV', macroScanAxisID, obj.szAxes, startPoint);
                    for i=numberOfMacroPixels:-1:1
                        if (mod(numberOfMacroPixels-i+1,numberOfMacroPixels/10) == 0)
                            fprintf(' %d%%',100*(numberOfMacroPixels-i+1)/numberOfMacroPixels);
                        end
                        SendPICommand(obj, 'PI_WAC', macroScanAxisID, [backwardString num2str(macroScanAxisVector(i) + macroPixelSize/2)]);
                        SendPICommand(obj, 'PI_DIO', macroScanAxisID, 1, 1, 1); % stage output 1
                        SendPICommand(obj, 'PI_DIO', macroScanAxisID, 1, 0, 1); % stage output 0
                    end
                    SendPICommand(obj, 'PI_WAC', macroScanAxisID, [backwardString num2str(macroScanAxisVector(1) - macroPixelSize/2)]);
                    SendPICommand(obj, 'PI_DIO', macroScanAxisID, 1, 1, 1); % stage output 1
                    SendPICommand(obj, 'PI_DIO', macroScanAxisID, 1, 0, 1); % stage output 0
                    fprintf('\n');
                    SendPICommand(obj, 'PI_MAC_END', macroScanAxisID);
                    
                    obj.macroScanVelocity = scanVelocity;
                    obj.macroNormalVelocity = normalVelocity;
                else
                    fprintf('Using previous scan''s macros...\n');
                end
                
            else % Slow Scan
                minTPixel = obj.MINIMUM_SLOW_PIXEL_TIME;
                if tPixel < minTPixel
                    fprintf('Minimum pixel time is %.1fms, %.1f were requested, changing to %.1fms\n', ...
                        1000*minTPixel, 1000*tPixel, 1000*minTPixel);
                    tPixel = minTPixel;
                end
                tPixel = tPixel - 0.015; % The intrinsic delay is 15ms...
                SetOnTargetWindow(obj, macroScanAxis, abs(macroPixelSize), 0.5);
                SetOnTargetWindow(obj, normalScanAxis, abs(normalPixelSize), 0.5);
                startPoint = macroScanAxisVector(1);
                endPoint = macroScanAxisVector(end);
            end
            
            %% Prepare Scan
            obj.macroNormalNumberOfPixels = numberOfNormalPixels;
            obj.macroNumberOfPixels = numberOfMacroPixels;
            obj.macroNormalScanVector = normalScanAxisVector;
            obj.macroScanVector = macroScanAxisVector;
            obj.macroNormalScanAxis = normalScanAxis;
            obj.macroScanAxis = macroScanAxis;
            obj.macroPixelTime = tPixel;
            obj.macroStartPoint = startPoint;
            obj.macroEndPoint = endPoint;
            obj.macroIndex = 1;
            obj.scanRunning = 1;
            MovePrivate(obj, obj.macroScanAxis, startPoint);
            
            %% Prepare Controllers
            ChangeMode(obj, macroScanAxis, 'Nanostepping');
            ChangeMode(obj, normalScanAxis, 'Nanostepping');
            WaitFor(obj, macroScanAxis, 'ControllerReady')
            WaitFor(obj, normalScanAxis, 'ControllerReady')
        end
        
        function MovePrivate(obj, phAxis, pos)
            % Absolute change in position (pos) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            % Does not check if scan is running.
            % Does not move if HaltStage was triggered.
            % This function is the one used by all internal functions.
            
            if obj.forceStop % Doesn't move if forceStop is enabled
                return
            end
            
            if obj.tiltCorrectionEnable
                [phAxis, pos] = TiltCorrection(obj, phAxis, pos);
            end
            
            if ~PointIsInRange(obj, phAxis, pos) % Check that point is in limits
                obj.sendError('Move Command is outside the soft limits');
            end
            
            CheckRefernce(obj, phAxis)
            
            % Send the move command
            axisID = obj.axesID(GetAxis(obj, phAxis));
            for i=1:length(phAxis)
                SendPICommand(obj, 'PI_MOV', axisID(i), obj.szAxes, pos(i));
            end
            
            % Wait for move command to finish
            for i=1:length(phAxis)
                WaitFor(obj, phAxis(i), 'onTarget')
            end
        end
        
        function HaltPrivate(obj, axisID)
            % Halts the stage on the given axis.
            SendPICommand(obj, 'PI_HLT', axisID, obj.szAxes);
            AbortScan(obj)
            warning('Stage Halted!');
        end
        
        function SetVelocityPrivate(obj, phAxis, vel)
            % Absolute change in velocity (vel) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Does not check if scan is running.
            % Vectorial axis is possible.
            phAxis = GetAxis(obj, phAxis);
            axisID = obj.axesID(GetAxis(obj, phAxis));
            for i=1:length(phAxis)
                SendPICommand(obj, 'PI_VEL', axisID(i), obj.szAxes, vel(i));
            end
        end
        
        function refernced = IsRefernced(obj, phAxis)
            % Check reference status for the given axis.
            % 'phAxis' can be either a specific axis (x,y,z or 1 for x,
            % 2 for y and 3 for z) or any vectorial combination of them.
            axisID = obj.axesID(GetAxis(obj, phAxis));
            refernced = zeros(size(phAxis));
            
            for i=1:length(phAxis)
                [~, refernced(i)] = SendPICommand(obj, 'PI_qFRF', axisID(i), obj.szAxes, 0);
            end
        end
        
        function Refernce(obj, phAxis)
            % Reference the given axis.
            % 'phAxis' can be either a specific axis (x,y,z or 1 for x, 2 for y
            % and 3 for z) or any vectorial combination of them.
            phAxis = GetAxis(obj, phAxis);
            axisID = obj.axesID(phAxis);
            
            for i=1:length(phAxis)
                SendPICommand(obj, 'PI_FRF', axisID(i), obj.szAxes);
            end
            
            % Check if ready & if referenced succeeded
            for i=1:length(phAxis)
                WaitFor(obj, phAxis(i), 'ControllerReady')
                [~, refernced] = SendPICommand(obj, 'PI_qFRF', axisID(i), obj.szAxes, 0);
                if (~refernced)
                    errorMsg = sprintf(...
                        'Referencing failed for controller %s with ID %d (%s axis): Reason unknown.', ...
                        obj.controllerModel, axisID(i), obj.axesName(phAxis(i)));
                    obj.sendError(errorMsg);
                end
            end
        end
    end
    
    methods (Access = public) %Overwrite ClassPIMicos functions
        
        function CloseConnection(obj)
            % Closes the connection to the controllers.
            if (obj.ID ~= -1)
                % ID exists, attempt to close
                SendPICommandWithoutReturnCode(obj, 'PI_CloseDaisyChain', obj.ID);
                fprintf('Connection Closed: ID %d released.\n', obj.ID);
            else
                obj.ForceCloseConnection(obj.controllerModel);
            end
            obj.macroIndex = -1;
            obj.scanRunning = 0;
            obj.ID = -1;
            obj.axesID = -1*ones(size(obj.axesID));
        end
        
        function forwards = ScanNextLine(obj)
            % Scans the next line for the 2D scan, to be used after
            % 'PrepareScanXX'.
            % No other commands should be used between 'PrepareScanXX' or
            % until 'AbortScan' has been called.
            % forwards is set to 1 when the scan is forward and is set to 0
            % when it's backwards
            if ~obj.scanRunning
                obj.sendError('No scan detected.\nFunction can only be called after ''PrepareScanXX!''');
            end
            macroScanAxisID = obj.axesID(obj.macroScanAxis);
            
            if obj.macroScan % Macro Scan
                % Prepare Axes
                if (obj.macroIndex == 1)
                    SetVelocityPrivate(obj, obj.macroScanAxis, obj.macroScanVelocity);
                end
                
                % Scan
                MovePrivate(obj, obj.macroNormalScanAxis, obj.macroNormalScanVector(obj.macroIndex));
                if (mod(obj.macroIndex,2) ~= 0)
                    SendPICommand(obj, 'PI_MAC_START', macroScanAxisID, 'SCANFORW');
                    forwards = 1;
                else
                    SendPICommand(obj, 'PI_MAC_START', macroScanAxisID, 'SCANBACK');
                    forwards = 0;
                end
                WaitFor(obj, obj.macroScanAxis, 'MacroDone');
            else % Slow Scan
                MovePrivate(obj, obj.macroNormalScanAxis, obj.macroNormalScanVector(obj.macroIndex));
                if (mod(obj.macroIndex,2) ~= 0) % Forwards
                    for i=1:obj.macroNumberOfPixels
                        MovePrivate(obj, obj.macroScanAxis, obj.macroScanVector(i));
                        SendPICommand(obj, 'PI_DIO', macroScanAxisID, 1, 1, 1);
                        Delay(obj, obj.macroPixelTime);
                        SendPICommand(obj, 'PI_DIO', macroScanAxisID, 1, 0, 1);
                    end
                    forwards = 1;
                else % Backwards
                    for i=obj.macroNumberOfPixels:-1:1
                        MovePrivate(obj, obj.macroScanAxis, obj.macroScanVector(i));
                        SendPICommand(obj, 'PI_DIO', macroScanAxisID, 1, 1, 1);
                        Delay(obj, obj.macroPixelTime);
                        SendPICommand(obj, 'PI_DIO', macroScanAxisID, 1, 0, 1);
                    end
                    forwards = 0;
                end
            end
            obj.macroIndex = obj.macroIndex+1;
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
            
            % Go back to the start of the line
            if obj.macroScan % If macro scanning, we need to move without tilt correction is working.
                if (mod(obj.macroIndex, 2) ~= 0)
                    SendPICommand(obj, 'PI_MOV', obj.axesID(obj.macroScanAxis), obj.szAxes, obj.macroStartPoint);
                else
                    SendPICommand(obj, 'PI_MOV', obj.axesID(obj.macroScanAxis), obj.szAxes, obj.macroEndPoint);
                end
            else
                if (mod(obj.macroIndex, 2) ~= 0)
                    MovePrivate(obj, obj.macroScanAxis, obj.macroStartPoint);
                else
                    MovePrivate(obj, obj.macroScanAxis, obj.macroEndPoint);
                end
            end
        end
        
        function AbortScan(obj)
            % Aborts the 2D scan defined by 'PrepareScanXX';
            if obj.scanRunning
                if obj.macroScan % Macro Scan
                    SetVelocityPrivate(obj, obj.macroScanAxis, obj.macroNormalVelocity);
                    SendPICommand(obj, 'PI_MOV', obj.axesID(obj.macroScanAxis), obj.szAxes, obj.macroStartPoint); % This is done in order to have the correct Z height, only matters if tilt correction is working.
                else
                    % Do Nothing
                end
                ChangeMode(obj, obj.macroScanAxis, 'Mixed');
                ChangeMode(obj, obj.macroNormalScanAxis, 'Mixed');
                WaitFor(obj, obj.macroScanAxis, 'ControllerReady')
                WaitFor(obj, obj.macroNormalScanAxis, 'ControllerReady')
                obj.macroIndex = -1;
                obj.scanRunning = 0;
            end
        end
        
        function maxScanSize = ReturnMaxScanSize(obj, nDimensions)
            % Returns the maximum number of points allowed for an
            % 'nDimensions' scan.
            if obj.macroScan % Macro Scan
                maxScanSize = obj.maxScanSize(nDimensions);
            else
                maxScanSize = 9999;
            end
        end
        
        function JoystickControl(obj, enable)
            % Changes the joystick state for all axes to the value of
            % 'enable' - true to turn Joystick on, false to turn it off.
            if enable % If need to enable, ask user to confirm, otherwise, just disable.
                questionString = sprintf('WARNING!\nPlease make sure that there is a joystick connected to the controllers.\nEnabling the joystick with no joystick connected might result in uncontrolled movements.');
                title = 'Enable Joystick';
                confirm = QuestionUserOkCancel(title, questionString);
                if ~confirm
                    fprintf('Joystick NOT enabled!\n');
                    return
                end
            end
            
            % Send command to controller: GCS manual p. 50
            
            enable = BooleanHelper.ifTrueElse(enable, 1, 0);
            for i = 1:length(obj.validAxes)
                controllerID = obj.axesID(i);
                SendPICommand(obj, 'PI_JON', controllerID, 1, enable, 1);
            end
        end
        
        function binaryButtonState = ReturnJoystickButtonState(obj)
            % Returns the state of the buttons in 3 bit decimal format.
            % 1 for first button, 2 for second and 4 for the 3rd.
            binaryButtonState = 0;
            for i = 1:length(obj.validAxes)
                [~, ~, buttonState] = SendPICommand(obj, 'PI_qJBS', obj.axesID(i), 1, 1, 1, 1);
                binaryButtonState = binaryButtonState + 2^(i-1)*buttonState;
            end
        end
        
        function FastScan(obj, enable)
            % Changes the scan between fast & slow mode
            % 'enable' - 1 for fast scan, 0 for slow scan.
            if obj.scanRunning
                warning(obj.WARNING_PREVIOUS_SCAN_CANCELLED);
                AbortScan(obj);
            end
            
            obj.macroScan = enable;
        end
        
        function ChangeLoopMode(obj, varargin)
            % Changes between closed and open loop.
            % 'phAxis' can be either a specific axis (x,y,z or 1 for x, 2 for y
            % and 3 for z) or any vectorial combination of them.
            % If 'phAxis' is not given, all axes are changed.
            % 'mode' should be either 'Open' or 'Closed'.
            % Stage will auto-lock when in open mode, which should increase
            % stability.
            narginchk(2,3)
            
            switch nargin
                case 3
                    phAxis = varargin{1};
                    mode = varargin{2};
                    axisID = obj.axesID(GetAxis(obj, phAxis));
                    switch mode
                        case 'Open'
                            SendPICommand(obj, 'PI_SVO', axisID, obj.szAxes, 0);
                        case 'Closed'
                            SendPICommand(obj, 'PI_SVO', axisID, obj.szAxes, 1);
                        otherwise
                            errorMsg = sprintf('Unknown mode: %s', mode);
                            obj.sendError(errorMsg);
                    end
                case 2
                    mode = varargin{1};
                    for i = 1:length(obj.validAxes)
                        ChangeLoopMode(obj, obj.validAxes(i), mode)
                    end
            end
            obj.loopMode = mode;
            obj.sendEventStageAvailabilityChanged;
        end
    end
end