classdef ClassGalvo < ClassStage
    
    properties (Constant)
        NAME = 'Stage (Fine) - Galvo'
        VALID_AXES = 'xy';
        
        NEEDED_FIELDS_STAGE = {'readPositionChannel', 'writePositionChannel'}
            % There are possibly also 'readInternalCommandChannel' &
            % 'readErrorChannel', but they don't seem to be needed anywhere
        NEEDED_FIELDS_EXTRA = {'pulseChannel'}
        OPTIONAL_FIELDS = {'minValue', 'maxValue'}
        
        STEP_MINIMUM_SIZE = 4e-3 % double. in degrees.
        STEP_DEFAULT_SIZE = 1;   % double. in microns.
        POSITIVE_RANGE_LIMIT = [250 250];    % in microns ( == 15mm )
        NEGATIVE_RANGE_LIMIT = [-250 -250];   % in microns ( == -15mm )
        
        MINIMUM_PIXEL_TIME = 8e-3;      % in seconds ( == 8ms )
        
        ITERATIONS_NUM = 100;   % Think about it: why 100 averages?
        
        outputVoltageScalingFactor = [0.9931 0.9966];	% When reading voltage from the galvo, the output volage is smaller by this scaling factor (error range for this const is 0.00005)
        outputVoltageOffset = [-0.001735 0.001708];     % When reading zero voltage, the output volage value is this const (error rage for this const is 6.125e-5 volt)
    end
    
    properties
        
        voltToAngleScaling = 1; % for galvo GVS012 the scaling in the input is 1v per 1degree
        angleToVoltScaling = 2; % for galvo GVS012 the scaling in the output is 0.5v per 1degree
        mechanicalAngleToOpticAngle = 2;
        
        D = 2.8;            % distance between optics to sample (might change)
        lens1 = 70;         % focal length of the 1st lens (in mm)
        lens2 = 150;        % focal length of the 2st lens (in mm)
        
        xfac = 50/50;       % without 50/42.5or47.5, 50 actual microns would look like 45 in the scans.
        yfac = 50/50;
        
        units = ' \mum';
        posRangeLimit
        negRangeLimit
        posSoftRangeLimit	% Default is same as physical limit.
        negSoftRangeLimit   % Default is same as physical limit.
        
        defaultVel = 1e3;   % Default velocity is 1000 um/s.
        curPos = [0 0];     % Current position
        curVel = [0 0];     % Current velocity
        
        commDelay = 5e-3;	% 5ms delay needed between consecutive commands sent to the controllers.
%         readInternalCommandChannel
%         readErrorChannel
        readPositionChannel
        writePositionChannel
        pulseChannel
        maxScanSize = 9999;
        
        macroNumberOfPixels = -1;       % number of lines
        macroMacroNumberOfPixels = -1;  % number of points per line
        macroNormalScanVector = -1;     % Vector of points in the normal direction (lines direction)
        macroScanVector = -1;           % Vector of points in the macro (scanning) direction
        macroNormalScanAxis = -1;       % normal direction axis (x, y or z)
        macroScanAxis = -1;             % macro direction axis (x, y or z)
        macroPixelTime = -1;            % time duration at each pixel
        macroIndex = -1;                % current line, -1 = not in scan
        analogVoltageTask = -1;         % Analog voltage task for scanning
        digitalPulseTask = -1;          % Digital pulse task for scanning
        
        macroScan
        macroStartPoint
        macroEndPoint
    end
    
    methods (Static) % Get instance constructor
        function obj = create(stageStruct)
            % Struct validation
            stageFields = ClassGalvo.NEEDED_FIELDS_STAGE;
            
            missingField = 	FactoryHelper.usualChecks(stageStruct, [stageFields, ClassGalvo.NEEDED_FIELDS_EXTRA]);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Trying to create the ClassGalvo stage, needed field "%s" was missing. Aborting',...
                    missingField);
            end
            for i = 1:length(stageFields)
                field = stageFields{i};
                if length(stageStruct.(field)) ~= 2
                    EventStation.anonymousError(...
                        'For ClassGalvo stage, "%s" failed to have exactly 2 channels (one for each axis). Aborting',...
                        field);
                end
            end
            stageStruct = FactoryHelper.supplementStruct(stageStruct, ClassGalvo.OPTIONAL_FIELDS);
            
            % For readability
            readPositionChannel = stageStruct.readPositionChannel;
%             readInternalCommandChannel = stageStruct.readInternalCommandChannel;
%             readErrorChannel = stageStruct.readErrorChannel;
            writePositionChannel = stageStruct.writePositionChannel;
            pulseChannel = stageStruct.pulseChannel;
            minValue = stageStruct.minValue;
            maxValue = stageStruct.maxValue;
            
            % Actual object creation
            removeObjIfExists(ClassGalvo.NAME);
            obj = ClassGalvo(readPositionChannel, writePositionChannel, ...
                pulseChannel, minValue, maxValue);
        end
    end
    
    methods (Access = private)
        % Private default constructor
        function obj = ClassGalvo(readPositionChannel, writePositionChannel, pulseChannel, minVal, maxVal)
            %%% Create the object
            name = ClassGalvo.NAME;
            availAxis = ClassGalvo.VALID_AXES;
            obj@ClassStage(name, availAxis)
            
            %%% Register NiDaq Channels (We don't need the stage to be NiDaqControlled)
            % Channel IDs
            channels = [readPositionChannel(1:2); writePositionChannel(1:2); pulseChannel];
            % Names
            channelNames = {'GalvoReadPosX', 'GalvoReadPosY', 'GalvoWritePosX', 'GalvoWritePosY', ClassGalvo.NAME};
            % ^ The last one is the channel which other system objects recognize as "the signal from the stage"
            
            nidaq = getObjByName(NiDaq.NAME);
            for k = 1:length(channels)
                nidaq.registerChannel(channels{k}, channelNames{k}, minVal, maxVal)
            end
            
            %%% Save evrything we need 
            axSize = size(availAxis);
            obj.posRangeLimit = obj.POSITIVE_RANGE_LIMIT; % Units set to microns.
            obj.negRangeLimit = obj.NEGATIVE_RANGE_LIMIT; % Units set to microns.
            obj.posSoftRangeLimit = obj.posRangeLimit;
            obj.negSoftRangeLimit = obj.negRangeLimit;
            
            obj.curPos = [0 0];
            obj.curVel = [0 0];
            
            obj.availableProperties.(obj.HAS_SLOW_SCAN) = true;
            
            obj.readPositionChannel = readPositionChannel;
            obj.writePositionChannel = writePositionChannel;
            obj.pulseChannel = pulseChannel;
        end
    end
        
    methods
        function Connect(obj) %connect to the controller
        end
        
        function Initialization(obj)
        end
        
        function CloseConnection(obj)
            % Closes the connection to the stage.
        end
        
        function Delay(obj, delay)
            if nargin == 1
                delay = obj.commDelay;
            end
            % probably should use tic & toc
            waitTime = delay;
            c1=clock;
            c2=clock;
            while etime(c2, c1) < waitTime
                c2=clock;
            end
        end
        
        function errorZAxisUnavailable(obj)
            obj.sendError('Movement in the Z direction is unavailable');
        end
        
        function PrepareScanX(obj, x, y, ~, nFlat, nOverRun, tPixel)
            % Defines a macro scan for x axis.
            % Call ScanX to start the scan.
            % x - A vector with the points to scan, points should have
            %       equal distance between them.
            % y/z - The starting points for the other axes.
            % nFlat - Not used.
            % nOverRun - ignored.
            % tPixel - Scan time for each pixel.
            
            if (obj.macroIndex ~= -1)
                warning('1D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            PrepareScanInTwoDimensions(obj, x, y, nFlat, nOverRun, tPixel, 'x', 'y');
        end
        
        function PrepareScanY(obj, x, y, ~, nFlat, nOverRun, tPixel)
            % Defines a macro scan for y axis.
            % Call ScanY to start the scan.
            % y - A vector with the points to scan, points should have
            %       equal distance between them.
            % x/z - The starting points for the other axes.
            % nFlat - Not used.
            % nOverRun - ignored.
            % tPixel - Scan time for each pixel.
            
            if (obj.macroIndex ~= -1)
                warning('1D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            PrepareScanInTwoDimensions(obj, y, x, nFlat, nOverRun, tPixel, 'y', 'x');
        end
        
        function ScanX(obj, x, y, z, nFlat, nOverRun, tPixel) %#ok<INUSD>
            %%%%%%%%%%%%%% ONE DIMENSIONAL X SCAN MACRO %%%%%%%%%%%%%%
            % Does a macro scan for x axis, should be called after
            % PrepareScanX.
            % Input should be the same for both functions.
            %
            % x - A vector with the points to scan, points should have
            %       equal distance between them.
            % y/z - The starting points for the other axes.
            % nFlat - Not used.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if (obj.macroIndex == -1)
                obj.sendError('No scan detected.\nFunction can only be called after ''PrepareScanX!''');
            end
            ScanNextLine(obj);
        end
        
        function ScanY(obj, x, y, z, nFlat, nOverRun, tPixel) %#ok<INUSD>
            %%%%%%%%%%%%%% ONE DIMENSIONAL Y SCAN MACRO %%%%%%%%%%%%%%
            % Does a macro scan for y axis, should be called after
            % PrepareScanY.
            % Input should be the same for both functions.
            % y - A vector with the points to scan, points should have
            %       equal distance between them.
            % x/z - The starting points for the other axes.
            % nFlat - Not used.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if (obj.macroIndex == -1)
                obj.sendError('No scan detected.\nFunction can only be called after ''PrepareScanY!''');
            end
            ScanNextLine(obj);
        end
        
        function PrepareScanInTwoDimensions(obj, macroScanAxisVector, normalScanAxisVector, nFlat, nOverRun, tPixel, macroScanAxisName, normalScanAxisName) %#ok<INUSL>
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
            numberOfMacroPixels = length(macroScanAxisVector);
            numberOfNormalPixels = length(normalScanAxisVector);
            
            if (numberOfMacroPixels > obj.maxScanSize)
                fprintf('Can support scan of up to %d pixel for the macro axis, %d were requested. Please seperate into several smaller scans externally',...
                    obj.maxScanSize, numberOfMacroPixels);
                return;
            end
            
            obj.macroPixelTime = tPixel;
            startPoint = macroScanAxisVector(1);
            
            obj.macroMacroNumberOfPixels = numberOfMacroPixels;
            obj.macroNumberOfPixels = numberOfNormalPixels;
            obj.macroNormalScanVector = normalScanAxisVector;
            obj.macroScanVector = macroScanAxisVector;
            obj.macroNormalScanAxis = normalScanAxisName;
            obj.macroScanAxis = macroScanAxisName;
            obj.macroIndex = 1;
            obj.analogVoltageTask = PrepareVoltageTask(obj, obj.macroScanAxis); % Creates the DAQ task for writing voltage
            obj.digitalPulseTask = PreparePulseTask(obj); % Creates the DAQ task for creating pulses
            Move(obj, obj.macroScanAxis, startPoint);
        end
        
        function PrepareScanXY(obj, x, y, ~, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XY SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xy axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            %
            % x/y - Vectors with the points to scan, points should have
            %       equal distance between them.
            % z - The starting points for the other axis.
            % nFlat - Not used.
            % nOveRun - ignored.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if (obj.macroIndex ~= -1)
                warning('2D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            PrepareScanInTwoDimensions(obj, x, y, nFlat, nOverRun, tPixel, 'x', 'y');
        end
        
        function PrepareScanYX(obj, x, y, ~, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XY SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xy axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            %
            % x/y - Vectors with the points to scan, points should have
            %       equal distance between them.
            % z - The starting points for the other axis.
            % nFlat - Not used.
            % nOveRun - How many extra points should be taken from each.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if (obj.macroIndex ~= -1)
                warning('2D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            PrepareScanInTwoDimensions(obj, y, x, nFlat, nOverRun, tPixel, 'y', 'x');
        end
        
        function [forwards, done] = ScanNextLine(obj)
            % Scans the next line for the 2D scan, to be used after
            % 'PrepareScanXX'.
            % done is set to 1 after the last line has been scanned.
            % No other commands should be used between 'PrepareScanXX' and
            % until 'ScanNextLine' has returned done, or until 'AbortScan'
            % has been called.
            % forwards is set to true when the scan is forward and to false
            % when it's backwards.
            
            if (obj.macroIndex == -1)
                obj.sendError(sprintf('No scan detected.\nFunction can only be called after ''PrepareScanXX!'''));
            end
            
            tPixel = obj.macroPixelTime - obj.MINIMUM_PIXEL_TIME;
            if tPixel < 0
                obj.sendWarning(sprintf('Minimum pixel time is 8 ms, %.1f were requested, changing to 8 ms', 1000*tPixel));
                tPixel = 0;
            end
            
            % Backwards / Forwards
            forwards = (mod(obj.macroIndex,2) ~= 0);    % We are scanning back and forth,
                                                        % so every second line is backwards
            indices = 1:obj.macroMacroNumberOfPixels;
            if ~forwards
                indices = fliplr(indices);
            end
            
            % Scan constants
            channel = obj.pulseChannel;
            line = str2double(channel(end));    % channel is of the form 'portM/lineN', where M and N are integers
            nidaq = getObjByName(NiDaq.NAME);
            
            % Start Scan
            Move(obj, obj.macroNormalScanAxis, obj.macroNormalScanVector(obj.macroIndex));
            for i = indices     % might be forwards or backwards
                Move(obj, obj.macroScanAxis, obj.macroScanVector(i), obj.analogVoltageTask); % Same as move, without creating and closing the task.
                nidaq.writeDigitalOnce(obj.digitalPulseTask, 1, line);
                Delay(obj, tPixel);
                nidaq.writeDigitalOnce(obj.digitalPulseTask, 0, line);
            end
            
            done = (obj.macroIndex == obj.macroNumberOfPixels);
            obj.macroIndex = obj.macroIndex+1;
        end
        
        %{
function PrepareRescanLine(obj)
            % Prepares the previous line for rescanning.
            % Scanning is done with "ScanNextLine"
%             if ~obj.scanRunning
%                 warning('No scan detected. Function can only be called after ''PrepareScanXX!''.\nThis will work if attempting to rescan a 1D scan, but macro will be rewritten.\n');
%                 return
%             elseif (obj.macroIndex == 1)
        if (obj.macroIndex == 1)
                obj.sendError('Scan did not start yet. Function can only be called after ''ScanNextLine!''');
            end
            
            % Decrease index
            obj.macroIndex = obj.macroIndex - 1;
            
            % Go back to the start of the line
            if (mod(obj.macroIndex,2) ~= 0)
                MovePrivate(obj,obj.macroScanAxis,obj.macroScanVector(1)-obj.macroFixPosition);
            else
                MovePrivate(obj,obj.macroScanAxis,obj.macroScanVector(end)+obj.macroFixPosition);
            end
         end
        %}
        
        
        function PrepareRescanLine(obj)
            % Prepares the previous line for rescanning.
            % Scanning is done with "ScanNextLine"
            %             if ~obj.scanRunning
            %                 warning('No scan detected. Function can only be called after ''PrepareScanXX!''.\nThis will work if attempting to rescan a 1D scan, but macro will be rewritten.\n');
            %                 return
            %             elseif (obj.macroIndex == 1)
            if obj.macroIndex == 1
                obj.sendError('Scan did not start yet. Function can only be called after ''ScanNextLine!''');
            end
            
            todo = 'This looks wrong'
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
                    %                     MovePrivate(obj, obj.macroScanAxis, obj.macroStartPoint);
                    Move(obj.macroScanAxis, obj.macroStartPoint);
                else
                    %                     MovePrivate(obj, obj.macroScanAxis, obj.macroEndPoint);
                    Move(obj.macroScanAxis, obj.macroEndPoint);
                    
                end
            end
        end
        
        
        
        
        function task = PrepareVoltageTask(obj, phAxis)
            nidaq = getObjByName(NiDaq.NAME);
            channel = getChannel(obj, 'WritePosition', phAxis);
            task = nidaq.prepareVoltageOutputTask(channel);
        end
        
        function task = PreparePulseTask(obj)
            nidaq = getObjByName(NiDaq.NAME);
            channel = getChannel(obj, 'Pulse');
            task = nidaq.prepareDigitalOutputTask(channel);
        end
        
        function ClearTask(obj, task) %#ok<INUSL>
            nidaq = getObjByName(NiDaq.NAME);
            nidaq.endTask(task);
        end
        
        function WriteVoltage(obj, phAxis, voltage, task)
            % Setting the voltage.
            % Diffrent channels correspond to diffrent axes.
            nidaq = getObjByName(NiDaq.NAME);
            
            if nargin == 3
                task = 0;
            end
            
            if task == 0 % either according to prev. condition, or as input parameter
                tfClose = true;
                task = PrepareVoltageTask(obj, phAxis);
                nidaq.startTask(task);
            else
                tfClose = false;
            end
            
            nidaq.writeVoltageOnce(voltage, task);

            if tfClose
                ClearTask(obj, task)
            end
        end
        
        function voltage = readVoltage(obj, what, phAxis)
            % Getting the voltage.
            % Diffrent channels for diffrent axes.
            phAxis = GetAxis(obj, phAxis);
            channel = getChannel(obj, what, phAxis);
            
            % Parameters for reading
            numSampsPerChan = obj.ITERATIONS_NUM;
            timeout = 10;
            
            nidaq = getObjByName(NiDaq.NAME);
            voltage = nidaq.readVoltage(channel, numSampsPerChan, timeout);

            
            voltage = mean(voltage);
            % Scaling
            m = obj.outputVoltageScalingFactor(phAxis);
            n = obj.outputVoltageOffset(phAxis);
            voltage = (voltage)/m - n ;
        end
        
        function channel = getChannel(obj, what, phAxis)
            % Get relevant Nidaq channel
            if strcmp(what, 'Pulse')
                channel = obj.pulseChannel;
                % Axis is irrelevant
                return
            end
            
            phAxis = GetAxis(obj, phAxis);
            if ~ismember(phAxis, [1 2])
                obj.sendError(sprintf('Only x & y (1 & 2) axes are supported, %d was given', phAxis));
            end
            switch what
                case 'ReadPosition'
                    channel = obj.readPositionChannel{phAxis};
%                 case 'ReadInternalCommand'
%                     channel = obj.readInternalCommandChannel{axis};
%                 case 'ReadError'
%                     channel = obj.readErrorChannel{axis};
                case 'WritePosition'
                    channel = obj.writePositionChannel(phAxis);
            end
            channel = char(channel);
        end
        
        function angle = GetAngle(obj, phAxis)
            % returns the mechanical angle in dergrees.
            % angle range is between -20 to 20 degrees.
            voltage = readVoltage(obj, 'ReadPosition', phAxis);
            angle = voltage*obj.voltToAngleScaling;
        end
        
        function MoveAngle(obj, phAxis, angle, task)
            % setting the mechanical angle of a given axis.
            % translating the mechanical angle to input voltage.
            if nargin==3
                task = 0;
            end
            voltage = angle*obj.angleToVoltScaling;
            
            WriteVoltage(obj, phAxis, voltage, task)
        end
        
        function posInMicrons = GetPositionXY(obj, phAxis)
            % Returns the position in microns for axes x&y / 1&2
            angle = GetAngle(obj, phAxis);
            % Translating the mechanical angle to the optical angle after
            % the lenses
            opticAngle = angle * obj.mechanicalAngleToOpticAngle; % The incident angle in the 1st lens
            opticAngleAfterLenses = opticAngle * (obj.lens1/obj.lens2);
            
            currentaxis = GetAxis(obj, phAxis);
            if (currentaxis==1)
                opticAngleAfterLenses=opticAngleAfterLenses * obj.xfac;
            elseif (currentaxis==2)
                opticAngleAfterLenses=opticAngleAfterLenses * obj.yfac;
            end
            
            % Translating the optical angle to the transmitted angle from
            % the second lens
            pos = obj.D * tan(opticAngleAfterLenses*pi/180);
            posInMicrons = pos*1000; %change the units to um
            if (currentaxis==2) % the y axis of the Galvo is opposite than expected
                posInMicrons = -1*posInMicrons;
            end
        end
        
        function posInMicrons = GetPositionZ(obj) %#ok<MANU>
            % Returns the position in microns for axis z/3
            % for now returns only pos=0. todo: change this
            tempPosz = 0;
            posInMicrons = tempPosz;
        end
        
        function posInMicrons = Pos(obj, axisName)
            % Returns the position in microns for all axes (1 for x, 2 for
            % y, 3 for z)
            posInMicrons = zeros(size(axisName));
            for i=1:length(axisName)
                phAxis = GetAxis(obj, axisName(i));
                if phAxis == 3
                    posInMicrons(i) = GetPositionZ(obj);
                else
                    posInMicrons(i) = GetPositionXY(obj, phAxis);
                end
            end
        end
        
        function MoveXY(obj, phAxis, posInMicrons, task)
            % Moving the beam to a given position on axes x&y (1&2)
            if nargin==3
                task = 0;
            end
            pos = posInMicrons/1000; %change the units to mm
            opticAngleInRad = atan((pos/obj.D));
            opticAngleInDegree = opticAngleInRad*180/pi;
            % Translating the optical angle to the mechanical angle
            % before the lenses
            opticAngleBeforeLenses = opticAngleInDegree/(obj.lens1/obj.lens2);
            mechanicalAngle = opticAngleBeforeLenses/obj.mechanicalAngleToOpticAngle;
            
            currentaxis = GetAxis(obj, phAxis);
            if (currentaxis==1)
                mechanicalAngle=mechanicalAngle / obj.xfac;
            elseif (currentaxis==2)
                mechanicalAngle=mechanicalAngle / obj.yfac;
            end
            
            MoveAngle(obj, phAxis, mechanicalAngle, task);
        end
        
        function MoveZ(obj, posInMicrons)
            % To be connected to Z-stage later on
            obj.sendError(sprintf('No Z axis! You can''t move to %d\n', posInMicrons));
        end
        
        function Move(obj, axisName, posInMicrons, task)
            % Moving the beam to a giving position on axes x&y&z (1&2&3)
            if nargin == 3
                task = 0;
            end
            for i=1:length(axisName)
                phAxis = GetAxis(obj, axisName(i));
                if phAxis == 2 % the y axis of the Galvo is opposite than expected
                    posInMicrons(i) = -1*posInMicrons(i);
                end
                if phAxis == 3
                    MoveZ(obj, posInMicrons(i));
                else
                    MoveXY(obj, phAxis, posInMicrons(i), task);
                end
            end
        end
        
        function RelativeMove(obj, axisName, change)
            % Relative change in position (pos) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            pos = Pos(obj, axisName);
            Move(obj, axisName, pos + change);
        end
        
        function [inputVoltage, outputVoltage, error] = TestVoltage(obj, phAxis)
            inputVoltage = -10:0.5:10;
            phAxis = GetAxis(obj, phAxis);
            a = zeros(1, obj.ITERATIONS_NUM);
            outputVoltage = zeros(size(inputVoltage));
            error = zeros(size(inputVoltage));
            factor = obj.voltToAngleScaling/obj.angleToVoltScaling;
            for i=1:length(inputVoltage)
                WriteVoltage(obj, phAxis, inputVoltage(i))
                for j=1:N
                    a(j)= readVoltage(obj, 'ReadPosition', phAxis);
                end
                outputVoltage(i) = mean(a)*factor;
                error(i) = std(a)*factor/sqrt(N);
            end
        end
        
        function AbortScan(obj)
            % Aborts the 2D scan defined by 'PrepareScanXX';
            ClearTask(obj, obj.digitalPulseTask); % Clears the DAQ task for creating pulses
            obj.digitalPulseTask = -1;
            
            ClearTask(obj, obj.analogVoltageTask); % Clears the DAQ task for writing voltage
            obj.analogVoltageTask = -1;
            
            obj.macroIndex = -1;
        end
        
        function ok = PointIsInRange(obj, axisName, point)
            % Checks if the given point is within the soft (and hard)
            % limits of the given axis (x,y,z or 1 for x, 2 for y and 3 for z).
            % Vectorial axis is possible.
            [negSoftLimit, posSoftLimit] = ReturnLimits(obj, axisName);
            ok = ((point >= negSoftLimit) && (point <= posSoftLimit));
        end
        
        function [negSoftLimit, posSoftLimit] = ReturnLimits(obj, axisName)
            % Return the soft limits of the given axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            index = obj.getAxis(axisName);
            negSoftLimit = obj.negSoftRangeLimit(index);
            posSoftLimit = obj.posSoftRangeLimit(index);
        end
        
        function [negHardLimit, posHardLimit] = ReturnHardLimits(obj, axisName)
            % Return the hard limits of the given axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            negHardLimit = obj.negRangeLimit*ones(size(axisName));
            posHardLimit = obj.posRangeLimit*ones(size(axisName));
        end
        
        function FastScan(obj, enable)
            % Changes the scan between fast & slow mode
            % 'enable' - 1 for fast scan, 0 for slow scan.
            if (obj.macroIndex ~= -1)
                obj.sendWarning('2D Scan is in progress, previous scan canceled');
                AbortScan(obj);
            end
            if enable
                obj.sendError('Fast scan is not supported by the Galvo Mirrors, please switch to slow scan');
            end
        end
        
        function maxScanSize = ReturnMaxScanSize(obj, nDimensions)
            % Returns the maximum number of points allowed for an
            % 'nDimensions' scan.
            maxScanSize = obj.maxScanSize * ones( size(nDimensions) );
        end
        
        function [tiltEnabled, thetaXZ, thetaYZ] = GetTiltStatus(~)
            % Return the status of the tilt control.
            tiltEnabled = 0;
            thetaXZ = 0;
            thetaYZ = 0;
        end
        
        function vel = Vel(obj, phAxis)
            % Query and return velocity of axis (x,y,z or 1 for x, 2 for y
            % and 3 for z)
            % Vectorial axis is possible.
            axisIndex = GetAxisIndex(obj, phAxis);
            vel = obj.curVel(axisIndex);
        end
        
        function binaryButtonState = ReturnJoystickButtonState(obj)
            % Returns the state of the buttons in 3 bit decimal format.
            % 1 for first button, 2 for second and 4 for the 3rd.
            obj.sendWarning('No joystick support for the Galvo stage.');
            binaryButtonState = 0;
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
                    softLimit, obj.negRangeLimit(axisIndex), obj.posRangeLimit(axisIndex)));
            end
        end
        
        function ScanZ(obj, x, y, z, nFlat, nOverRun, tPixel) %#ok<INUSD>
            %%%%%%%%%%%%%%%%% ONE DIMENSIONAL Z SCAN %%%%%%%%%%%%%%%%%
            % Does a scan for z axis.
            % z - A vector with the points to scan, points should have
            %       equal distance between them.
            % x/y - The starting points for the other axes.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.errorZAxisUnavailable;
        end
        
        function SetVelocity(obj, phAxis, vel)
            % Absolute change in velocity (vel) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            obj.sendError('Setting velocity is not implemented');
        end
        
        function Reconnect(obj)
            % Reconnects the controller.
        end
        
        function Halt(obj)
            % Halts all stage movements.
        end
        
        
        function PrepareScanZ(obj, x, y, z, nFlat, nOverRun, tPixel) %#ok<INUSD>
            %%%%%%%%%%%%%%%%% ONE DIMENSIONAL Z SCAN %%%%%%%%%%%%%%%%%
            % Prepares a scan for z axis, to be called before ScanZ.
            %
            % z - A vector with the points to scan, points should have
            %       equal distance between them.
            % x/y - The starting points for the other axes.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.errorZAxisUnavailable;
        end
        
        function PrepareScanXZ(obj, x, y, z, nFlat, nOverRun, tPixel) %#ok<INUSD>
            %%%%%%%%%%%%%% TWO DIMENSIONAL XZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xz axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            %
            % x/z - Vectors with the points to scan, points should have
            %       equal distance between them.
            % y - The starting points for the other axis.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.errorZAxisUnavailable;
        end
        
        function PrepareScanYZ(obj, x, y, z, nFlat, nOverRun, tPixel) %#ok<INUSD>
            %%%%%%%%%%%%%% TWO DIMENSIONAL YZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for yz axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            %
            % y/z - Vectors with the points to scan, points should have
            %       equal distance between them.
            % x - The starting points for the other axis.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.errorZAxisUnavailable;
        end
        
        function PrepareScanZX(obj, x, y, z, nFlat, nOverRun, tPixel) %#ok<INUSD>
            %%%%%%%%%%%%%% TWO DIMENSIONAL XZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xz axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            %
            % x/z - Vectors with the points to scan, points should have
            %       equal distance between them.
            % y - The starting points for the other axis.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.errorZAxisUnavailable;
        end
        
        function PrepareScanZY(obj, x, y, z, nFlat, nOverRun, tPixel) %#ok<INUSD>
            %%%%%%%%%%%%%% TWO DIMENSIONAL YZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for yz axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % y/z - Vectors with the points to scan, points should have
            %       equal distance between them.
            % x - The starting points for the other axis.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.errorZAxisUnavailable;
        end
        
        function JoystickControl(obj, enable) %#ok<INUSD>
            % Changes the joystick state for all axes to the value of
            % 'enable' - true to turn Joystick on, false to turn it off.
            obj.sendWarning('No joystick support for the Galvo stage.');
        end
        
        function ChangeLoopMode(obj, mode)
        % Changes between closed and open loop.
        % Mode should be either 'Open' or 'Closed'.
        end
        
        function success = SetTiltAngle(obj, thetaXZ, thetaYZ)
        % Sets the tilt angles between Z axis and XY axes.
        % Angles should be in degrees, valid angles are between -5 and 5
        % degrees.
        end
        
        function success = EnableTiltCorrection(obj, enable)
        % Enables the tilt correction according to the angles.
        end
        
    end
end