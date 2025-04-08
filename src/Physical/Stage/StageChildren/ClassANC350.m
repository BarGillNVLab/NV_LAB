classdef ClassANC350  < ClassStage % < handle %
    % ClassANC350 Used to control Attocube's ANC stage
     
    properties (Constant)
        NAME = 'Stage - ANC350';
        VALID_AXES = 'xyz';
        
        STEP_MINIMUM_SIZE = 0.001      % double. in um
        STEP_DEFAULT_SIZE = 100     % double. in um

        % files & values for
        NEEDED_FIELDS = {'niDaqChannel'};
        LIB_ALIAS = "anc350v4";
%         LIB_DLL_FOLDER = 'C:\Users\owner\Desktop\AttoCube DOK\Software\Software_ANC350v4_v1.2.0\ANC350_Library\Win64\';
%         newer version:
        LIB_DLL_FOLDER = 'G:\My Drive\NV Lab\Drivers & Software\attocube\Software_ANC350v4\Software\ANC350_Library\Win64\';
        LIB_DLL_FILENAME = 'anc350v4.dll';
%         LIB_H_FOLDER = 'C:\Users\owner\Desktop\AttoCube DOK\Software\Software_ANC350v4_v1.2.0\ANC350_Library\Documentation\inc\';
%         newer version:
        LIB_H_FOLDER = 'G:\My Drive\NV Lab\Drivers & Software\attocube\Software_ANC350v4\Software\ANC350_Library\Documentation\inc\';
        LIB_H_FILENAME1 = 'anc350res';
        LIB_H_FILENAME2 = 'ancdel';
        LIB_H_FILENAME3 = 'anc350num';
        LIB_H_FILENAME4 = 'anc350fps';

        POSITIVE_HARD_LIMITS = [6000 6000 6000];  % the values are random need to check actual numbers!!!
        NEGATIVE_HARD_LIMITS = [0 0 0]% [10 10 10]*1e-6;% the values are random need to check actual numbers!!!

        ON = 1;
        OFF = 0;
        MAX_SCAN_SIZE = 1e6;
    end

    properties
        stageOffset = [0 0 0]; % the values are random need to check actual numbers!!!
        deviceHandle;
        Ptr_handle; % pointer to deviceHandle
        PtrPtr_handle; % pointer to pointer of deviceHandle
        
        % VELOCITY = [50 50 50]; % [x, y, z]
        VelocityArray; 
        AmplitudeRange = [1:60; 1:60; 1:60];
        ScanAxis = -1;
        FastScanEnable = 0;
        
        macroScanAxis
        macroNormalScanAxis
        macroScanAxisVector
        normalScanAxisVector
        IndexNormalVector
        lengthNormalVector
        lengthMacroVector
        scanRunning = -1;
        TPixel
        triggerChannel

        Temp = 300 % defult temp in kelvin
        forceStop = 0;
    end

    methods (Static)
        function obj = create(stageStruct)
            obj = ClassANC350(stageStruct.niDaqChannel);
        end
    end

    methods (Access = private)
        function obj = ClassANC350(niDaqChannel)
            name = ClassANC350.NAME;
            availableAxes = ClassANC350.VALID_AXES;
            obj@ClassStage(name, availableAxes)

            % load ANC library and connect stages
            obj.deviceHandle = -1; % Default value. Means stage is disconnected
            obj.Ptr_handle = libpointer("voidPtr",obj.deviceHandle);
            obj.PtrPtr_handle = libpointer("voidPtrPtr",obj.Ptr_handle);
            % obj.availableProperties.(obj.HAS_FAST_SCAN) = true;
            obj.availableProperties.(obj.HAS_SLOW_SCAN) = true;
            obj.LoadANC350Library;
            Connect(obj);
            LoadVelocityCalibration(obj);

            nidaq = getObjByName(NiDaq.NAME);
            nidaq.registerChannel(niDaqChannel, obj.name);
            obj.triggerChannel = niDaqChannel;
        end
    end

    methods (Access = public)
        
        function Connect(obj)
            % Connect to the controller

            if (obj.deviceHandle == -1) % stage disconnected
                aliasANC = obj.LIB_ALIAS;
                IfAll  = 0x03;
                rc = calllib(aliasANC, 'ANC_discover', IfAll, libpointer('uint32Ptr'));
                pause(5);
                if rc == 0
                    rc = calllib(aliasANC, 'ANC_connect',0,obj.PtrPtr_handle);
                    if (rc == 0)
                        obj.deviceHandle = 1;
                        fprintf("Stage Connected\n");
                    else
                        CheckError(obj,rc);
                    end 
                else
                    CheckError(obj,rc);
                    fprintf("Stage not found\n");
                end
            elseif (obj.deviceHandle == 1) % Stage already connected
                fprintf("Stage already connected\n");
            end
        end

        function LoadANC350Library(obj)
            % Loads ANC350 dll file.

            aliasANC = obj.LIB_ALIAS;
            if ~libisloaded(aliasANC) % if library is not loaded than load library
                shrlib = [obj.LIB_DLL_FOLDER, obj.LIB_DLL_FILENAME];
                hfile1 = [obj.LIB_H_FOLDER, obj.LIB_H_FILENAME1];
                hfile2 = [obj.LIB_H_FOLDER, obj.LIB_H_FILENAME2];
                hfile3 = [obj.LIB_H_FOLDER, obj.LIB_H_FILENAME3];
                hfile4 = [obj.LIB_H_FOLDER, obj.LIB_H_FILENAME4];
                loadlibrary(shrlib, hfile1,'addheader',hfile2,'addheader',hfile3, 'addheader',hfile4, 'alias', aliasANC);
                fprintf('Matlab: ANC library loaded.\n');
            end
        end

        function LoadVelocityCalibration(obj) % not finished !!!!!!
            % load velocity calibration
            obj.VelocityArray =  [1:60; 1:60; 1:60];

%             path = 'G:\My Drive\NV Lab\Setup 8\Calibrations\VelocityCalibration';
%             [struct_array,empty] = getFolders(obj,path);
%             if(empty == 0) % choose temp of calibrtion
%                 [temp] = chooseFeil(obj,struct_array,'Folder');
%                 path = append(path,'\',temp);
%                 [struct_array,empty] = getFolders(obj,path);
%                 
%                 if(empty == 0) % choose date of calibrtion
%                     [FolderName] = chooseFeil(obj,struct_array,'Folder');
%                     path = append(path,'\',FolderName);
%                     [struct_array,empty] = getFolders(obj,path);
% 
%                     if(empty == 0) % choose the calibrtion file
%                         [fileName] = chooseFeil(obj,struct_array,'file');
%                         path = append(path,'\',fileName);
%                         obj.VelocityArray = cell2mat(struct2cell(load(path, 'vel')));
%                     else
%                         fprintf('No file for calibrtion found in folder %s\n',FolderName);
%                         chooseToCalibrat(obj);
%                     end
%                 else
%                     fprintf('No calibrtion data found for temp of %s',temp);
%                     chooseToCalibrat(obj);
%                 end
%             else
%                 fprintf('No calibrtion data found\n');
%                 chooseToCalibrat(obj);
%             end
        end

        function chooseToCalibrat(obj)
            x = 0;
            while(x ~= 'y' || x ~= 'Y' || x ~= 'N' || x ~= 'n')
                x = input("would you like to calibrat the stages? Y/N\n","s");
                if(x == 'N' || x == 'n')
                    obj.VelocityArray = [1:60; 1:60; 1:60];
                elseif(x == 'Y' || x == 'y')
                    VelocityCalibration(obj,'y',3000,4000); % for know deflt vel
                    % obj.VelocityCalibration([1 2 3],[0 0 0],[6000 6000 6000]);
                else
                    fprintf("illegal input\n ");
                end
            end
        end

        function [struct_array,empty] = getFolders(~,path)
            % given path do folder return struct with all the feils and if 
            % the folder is empty

            d = dir(path);
            struct_array =struct('name',[],'folder',[],'date',[],'bytes',[],'isdir',[],'datenum',[]);
            index = 1;
            for i = 1:length(d)
                c = getfield(d(i),"name");
                if(~strcmp(c,'desktop.ini') && ~strcmp(c,'.') && ~strcmp(c,'..'))
                    struct_array(index) = d(i);
                    index = index + 1;
                end
            end

            empty = 0;
            if(size(struct_array,2) == 1)
                if(isempty(struct_array.name))
                    empty = 1;
                end
            end
        end

        function [fileName] = chooseFeil(~,struct_array,doc)
            % choose feil from given folder in struct_array
            
            if(size(struct_array,2) == 1)
                fileName = struct_array.name;
            else
                fprintf("choose %s\n",doc);
                for i = 1:size(struct_array,2)
                    fprintf('%d. %s\n',i,struct_array(i).name);
                end
                x = 0;
                while(x < 1 || x > size(struct_array,2))
                    x = input('');
                    if(x < 1 || x > size(struct_array,2))
                        fprintf("illegal input\n");
                    end
                end
                fileName = struct_array(x).name;
            end
        end

        function SetTemp(obj,temp)
            path = 'G:\My Drive\NV Lab\Setup 8\Calibrations\VelocityCalibration';
            [struct_array,~] = getFolders(obj,path);
            found = 0;
            str = append(string(temp),'k');
            for i = 1:size(struct_array,2)
                if(strcmp(struct_array(i).name,str))
                    found =1;
                    break;
                end
            end

            if(found == 0)
                mkdir(path,append(string(temp),'K'));
            end
            obj.Temp = temp;
        end

        function CheckError(~, code)
            % Check error for stage.
            % All functions of this ANC library return one of these 
            % constants for success control (see Documentation for more information).
            ANC_Ok = 0; % Success
            ANC_Error = -1; % Unspecified error
            ANC_Timeout = 1; % Receive timed out
            ANC_NotConnected = 2; % No connection was established
            ANC_DriverError = 3; % Error accessing the USB driver
            ANC_DeviceLocked = 7; % Can't connect, device already in use
            ANC_Unknown = 8; % Unknown error
            ANC_NoDevice = 9; % Invalid device number used in call
            ANC_NoAxis = 10; % Invalid axis number in function call
            ANC_OutOfRange = 11; % Parameter in call is out of range
            ANC_NotAvailable = 12; % Function not available for device type
            ANC_FileError = 13; % Error opening or interpreting a file
            switch code
                case ANC_Ok
                    return
                case ANC_Error
                    fprintf( "Error: unspecific\n" )
                    return
                case ANC_Timeout
                    fprintf( "Error: communication timeout\n" )
                    return
                case ANC_NotConnected
                    fprintf( "Error: not connected\n" )
                    return
                case ANC_DriverError
                    fprintf( "Error: not connected\n" )
                    return
                case ANC_DeviceLocked
                    fprintf( "Error: device locked\n" )
                    return
                case ANC_NoDevice
                    fprintf( "Error: invalid device number\n" )
                    return
                case ANC_NoAxis
                    fprintf( "Error: invalid axis number\n" )
                    return
                case ANC_OutOfRange
                    fprintf( "Error: parameter out of range\n" )
                    return
                case ANC_NotAvailable
                    fprintf( "Error: function not available\n" )
                    return
                case ANC_FileError
                    fprintf( "Error: can't open or parse file\n" )
                    return
                otherwise
                    fprintf( "Error: unknown\n" )
                    return
            end
        end

        function CloseConnection(obj)
            % Closes the connection to the controllers.

            if (obj.deviceHandle ~= -1)
                % Handle exists, attempt to close
                rc = calllib(obj.LIB_ALIAS, 'ANC_disconnect',obj.Ptr_handle);
                if (rc == 0)
                    fprintf('Connection Closed\n');
                    obj.deviceHandle = -1;
                else
                    obj.CheckError(rc);
                end 
            else
                % Handle does not exists.
                fprintf('No Handle found\n');
            end
        end

        function [negLimit, posLimit] = ReturnLimits(obj, axisName)
            % Return the soft limits of the given axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.

            phAxis = PrivateGetAxis(obj, axisName);
            negLimit = obj.NEGATIVE_HARD_LIMITS(phAxis) - obj.stageOffset(phAxis);
            posLimit = obj.POSITIVE_HARD_LIMITS(phAxis) - obj.stageOffset(phAxis);
        end
        
        function ok = PointIsInRange(obj, phAxis, point)
            % Checks if the given point is within the soft (and hard)
            % limits of the given axis (x,y,z or 1 for x, 2 for y and 3 for z).
            % Vectorial axis is possible.

            phAxis = PrivateGetAxis(obj, phAxis) + 1;
            [negLimit, posLimit] = obj.ReturnLimits(['x' 'y' 'z']);
            for i = 1:length(phAxis)
                if ((point(i) < negLimit(phAxis(i))) || (point(i) > posLimit(phAxis(i))))
                    ok = 0;
                    return
                end
            end
            ok = 1;
            % ok = all((point >= negLimit(phAxis)) & (point <= posLimit(phAxis)));
        end

%         function vectorIsInRange(obj, phAxis, points)
%             % Checks if the given points in vector are within the soft (and hard)
%             % limits of the given axis (x,y,z or 1 for x, 2 for y and 3 for z).
%             for i = 1:length(points)
%                 if (PointIsInRange(obj, phAxis, points(i)) ~= true)
%                     fprintf("can not scan! scan points out of range\n")
%                 end
%             end
%         end

        function [negHardLimit, posHardLimit] = ReturnHardLimits(obj, axisName)
            % Return the hard limits of the given axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            phAxis = PrivateGetAxis(obj, axisName) + 1;
            negHardLimit = obj.NEGATIVE_HARD_LIMITS(phAxis);
            posHardLimit = obj.POSITIVE_HARD_LIMITS(phAxis);
        end
        
        function pos = Pos(obj, axisName)
            % Query and return position of axis (x,y,z or 1 for x, 2 for y
            % and 3 for z)
            % Vectorial axis is possible.
            
            phAxis = PrivateGetAxis(obj, axisName);
            pos = zeros(1,length(phAxis));

            for i = 1:length(phAxis)
                posAxis = libpointer("doublePtr",-1);
%                 pause(0.1)
                rc = calllib(obj.LIB_ALIAS, 'ANC_getPosition',obj.Ptr_handle,phAxis(i)-1,posAxis);
                if (rc == 0)
                    pos(i) = posAxis.Value * 1e6;
                else
                    obj.CheckError(rc);
                end
            end
        end

        function vel = Vel(obj, axisName) % need implementation
            % Query and return velocity of axis (x,y,z or 1 for x, 2 for y
            % and 3 for z)
            % Vectorial axis is possible.

            axisName = PrivateGetAxis(obj, axisName);
            vel = zeros(1,length(axisName));

            for i =1:length(axisName)
                velPtr = libpointer('doublePtr',-1);
                rc = calllib(obj.LIB_ALIAS, 'ANC_getAmplitude',obj.Ptr_handle,axisName(i)-1,velPtr);
                CheckError(obj,rc);
                index = find(obj.AmplitudeRange(axisName(i)+1,1:end) == velPtr.Value);
                vel(i) = obj.VelocityArray(axisName(i)+1,index);
            end
        end

        function SetSoftLimits(obj, phAxis, softLimit, negOrPos)
            % Set the new soft limits:
            % if negOrPos = 0 -> then softLimit = lower soft limit
            % if negOrPos = 1 -> then softLimit = higher soft limit
            % This is because each time this function is called only one of
            % the limits updates
            axisIndex = PrivateGetAxis(obj, phAxis);
            if ((softLimit >= obj.NEGATIVE_HARD_LIMITS(axisIndex)) && (softLimit <= obj.POSITIVE_HARD_LIMITS(axisIndex)))
                if negOrPos == 0
                    obj.stageOffset(axisIndex) = obj.NEGATIVE_HARD_LIMITS(axisIndex) - softLimit;
                else
                    obj.stageOffset(axisIndex) = softLimit - obj.POSITIVE_HARD_LIMITS(axisIndex);
                end
            else
                obj.sendError(sprintf('Soft limit %.4f is outside of the hard limits %.4f - %.4f', ...
                    softLimit, obj.NEGATIVE_HARD_LIMITS(axisIndex), obj.POSITIVE_HARD_LIMITS(axisIndex)))
            end
        end

        function SetVelocity(obj, phAxis, vel)
            % Absolute change in velocity (vel) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            % velocity in nm/sec

            phAxis = PrivateGetAxis(obj,phAxis);

            for i = 1:length(phAxis)
                index = interp1(obj.VelocityArray(phAxis(i),1:end),1:length(obj.VelocityArray(phAxis(i),1:end)),vel(i),'nearest','extrap');
                SetAmplitude(obj,phAxis(i),obj.AmplitudeRange(phAxis(i),index));
            end
        end

        function SetAmplitude(obj, phAxis, vel)
            % Sets the DC amplitude parameter for an axis 
            % Absolute change in amplitude (vel) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.

            phAxis = PrivateGetAxis(obj,phAxis);
            for i = 1:length(phAxis)
                rc = calllib(obj.LIB_ALIAS, 'ANC_setAmplitude',obj.Ptr_handle,phAxis(i)-1,vel(i));
                CheckError(obj,rc);
            end
        end

        function VelocityCalibration(obj, phAxis,startPoint, endPoint, startAmp, endAmp)

            obj.VelocityArray = [1:60; 1:60; 1:60];
            
            VelocityGrid = struct('Axis',[],'data',[]);
            VelocityGrid(1).Axis = 'x';
            VelocityGrid(1).data = struct('Amp',[],'range',[],'resolution',[]);
            VelocityGrid(1).data.Amp = struct('Ampval',[],'velF',[],'velB',[]);
            VelocityGrid(2).Axis = 'y';
            VelocityGrid(2).data = struct('Amp',[],'range',[],'resolution',[]);
            VelocityGrid(2).data.Amp = struct('Ampval',[],'velF',[],'velB',[]);
            VelocityGrid(3).Axis = 'z';
            VelocityGrid(3).data = struct('Amp',[],'range',[],'resolution',[]);
            VelocityGrid(3).data.Amp = struct('Ampval',[],'velF',[],'velB',[]);


            phAxis = PrivateGetAxis(obj,phAxis) + 1;
            if (endPoint < startPoint)
                v = endPoint;
                endPoint = startPoint;
                startPoint = v;
            end
            velMatrix = zeros(2*length(obj.VALID_AXES),obj.AmplitudeRange(1,end));
            for i = 1:length(phAxis)
                VelocityGrid(phAxis(i)).data.range = [startPoint,endPoint];
                VelocityGrid(phAxis(i)).data.resolution = 990;

                SetAmplitude(obj,phAxis(i),60); % 60 max amplitude
                SetAxisOutput(obj,phAxis(i),obj.ON,obj.OFF);
                MovePrivate(obj,phAxis(i),startPoint(i));
                dis = endPoint(i) - startPoint(i);
                vel = zeros(2,size(obj.AmplitudeRange(phAxis(i),1:end),2));
                
                for j = startAmp(i):endAmp(i) % loop all amplitude
                    VelocityGrid(phAxis(i)).data.Amp(j - startAmp(i) + 1).Ampval = j;
                    SetAmplitude(obj,phAxis(i),j);
                    posIndex = startPoint;
                    x = [];
                    timer = tic;
                    MovePrivateNoWait(obj,phAxis(i),endPoint(i));
                    while ((endPoint(i)-1)*1e-6 > (Pos(obj,phAxis(i))))
                        tic;
                        if(abs(Pos(obj,phAxis(i)) - posIndex*1e-6) >= VelocityGrid(phAxis(i)).data.resolution*1e-6)
                            posIndex = posIndex + VelocityGrid(phAxis(i)).data.resolution;
                            x(end+1) = VelocityGrid(phAxis(i)).data.resolution / toc;
                        end
                    end
                    T = toc(timer);
                    VelocityGrid(phAxis(i)).data.Amp(j - startAmp(i) + 1).velF = x;
                    vel(1,j) = dis/T;
                    posIndex = endPoint;
                    x = [];
                    timer = tic;
                    MovePrivateNoWait(obj,phAxis(i),startPoint(i));
                    while ((startPoint(i)+1)*1e-6 < Pos(obj,phAxis(i)))
                        tic;
                        if(abs(Pos(obj,phAxis(i)) - posIndex*1e-6) >= VelocityGrid(phAxis(i)).data.resolution*1e-6)
                            posIndex = posIndex - VelocityGrid(phAxis(i)).data.resolution;
                            x(end+1) = VelocityGrid(phAxis(i)).data.resolution / toc;
                        end
                    end
                    T = toc(timer);
                    VelocityGrid(phAxis(i)).data.Amp(j - startAmp(i) + 1).velB = x;
                    vel(2,j) = dis/T;
                end
                obj.VelocityArray(phAxis(i),startAmp(i):endAmp(i)) = vel(1,startAmp(i):endAmp(i));
                velMatrix(2*phAxis(i) - 1:2*phAxis(i),1:end) = vel;
                SetAxisOutput(obj,phAxis(i),obj.OFF,obj.OFF);
            end
            % vel = obj.VelocityArray;
            path = 'G:\My Drive\NV Lab\Setup 8\Calibrations\VelocityCalibration';
            path = append(path,'\',int2str(obj.Temp),'K');

            try
                path1 = append(path,'\',string(datetime("now","Format", "uuuu-MM-dd")));
                path1 = append(path1,'\',string(datetime("now","Format", "HH-mm")),'.mat');
                save(path1,"velMatrix");
            catch
                mkdir(path,string(datetime("now","Format", "uuuu-MM-dd")))
                path = append(path,'\',string(datetime("now","Format", "uuuu-MM-dd")));
                path = append(path,'\',string(datetime("now","Format", "HH-mm")),'.mat');
                save(path,"velMatrix");
            end

        end
        
        function Reconnect(obj)
            % Reconnects the controller.
            obj.CloseConnection();
            obj.Connect();
        end
    
        function Move(obj, axisName, targetPosInMicrons)
            % Absolute change in position (the user enters the target position in microns)
            % of axis (x,y,z or 1 for x, 2 for y and 3 for z).
            % when the target position is reached set the DC output is set to 0V

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
            obj.MovePrivate(axisName, targetPosInMicrons)
        end

        function WaitFor(obj, axisName,event,val)
            % Waits until the event
            
            axisName = PrivateGetAxis(obj, axisName);
            while true

                drawnow % Needed in order to get input from GUI
                if obj.forceStop % Checks if the user pressed the Halt Button
                    HaltPrivate(obj);
                    break;
                end

                switch event
                    case 'MovementDone'
                        if abs(Pos(obj,axisName) - val) < 1
                            break
                        end
                        [~,~,moving,~,~,~,~] = AxisStatus(obj, axisName);
                        if moving == 0
                            break;
                        end
                    case 'EnabledOutput'
                        [~,enabled,~,~,~,~,~] = AxisStatus(obj, axisName);
                        if enabled == 1
                            pause(0.2);
                            break;
                        end
                    otherwise
                        obj.sendError(sprintf('Wrong Input %s', event));
                end
            end
        end

        function [connected,enabled,moving,target,eotFwd,eotBwd,error] = AxisStatus(obj, axisName)
            % get axis status
            axisName = PrivateGetAxis(obj, axisName);
            connected = libpointer('int32Ptr',-1);
            enabled = libpointer('int32Ptr',-1);
            moving = libpointer('int32Ptr',-1);
            target = libpointer('int32Ptr',-1);
            eotFwd = libpointer('int32Ptr',-1);
            eotBwd = libpointer('int32Ptr',-1);
            error = libpointer('int32Ptr',-1);
            rc = calllib(obj.LIB_ALIAS, 'ANC_getAxisStatus',obj.Ptr_handle,axisName-1,connected,enabled,moving,target,eotFwd,eotBwd,error);
            obj.CheckError(rc);
            connected = connected.Value;
            enabled = enabled.Value;
            moving = moving.Value;
            target = target.Value;
            eotFwd = eotFwd.Value;
            eotBwd = eotBwd.Value;
            error = error.Value;
        end

        function RelativeMove(obj, phAxis, change)
            % Relative change in position (pos) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            Move(obj,phAxis,Pos(obj,phAxis) + change);
            pause(0.1)  % to wait for encoders to relax (to end the movement before reading out its position)
        end

        function Halt(obj)
            obj.forceStop = 1;
        end


        function SetAxisOutput(obj , axisNo, enable, autoDisable)
            % Enables or disables the voltage output of an axis.
            % axisNo - Axis number (0 ... 2)
            % enable - Enables (1) or disables (0) the voltage output.
            % autoDisable - If the voltage output is to be deactivated automatically when end of travel is detected.

            axisNo = PrivateGetAxis(obj,axisNo);
            aliasANC = obj.LIB_ALIAS;
            for i=1:length(axisNo)
                rc = calllib(aliasANC, 'ANC_setAxisOutput',obj.Ptr_handle,axisNo(i)-1,enable,autoDisable);
                obj.CheckError(rc);
            end
        end

        function PrepareScanX(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%%%%% ONE DIMENSIONAL X SCAN %%%%%%%%%%%%%%%%%
            % Prepares a scan for x axis, to be called before ScanX.
            % x - A vector with the points to scan, points should have
            % equal distance between them.
            % y/z - The starting points for the other axes.
            % tPixel - Scan time for each pixel.
            % nFlat - Not used
            % nOverRun - Not used
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % vectorIsInRange(obj, 'x', x)

            % if scan is runing
            if (obj.scanRunning == 1)
                warning("Scan is in progress either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.'");
                return;
            end

            obj.ScanAxis = 'x';
            SetAxisOutput(obj , 'x', obj.ON, obj.OFF);
            Move(obj, ['y' 'z'], [y z]); % move to start postion
        end

        function PrepareScanY(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%%%%% ONE DIMENSIONAL X SCAN %%%%%%%%%%%%%%%%%
            % Prepares a scan for x axis, to be called before ScanX.
            % y - A vector with the points to scan, points should have
            % equal distance between them.
            % x/z - The starting points for the other axes.
            % tPixel - Scan time for each pixel.
            % nFlat - Not used
            % nOverRun - Not used
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % vectorIsInRange(obj, 'y', y)

            % if scan is runing
            if (obj.scanRunning == 1)
                warning("Scan is in progress either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.'");
                return;
            end
            
            obj.ScanAxis = 'y';
            SetAxisOutput(obj , 'y', obj.ON, obj.OFF);
            Move(obj, ['x' 'z'], [x z]); % move to start postion
        end

        function PrepareScanZ(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%%%%% ONE DIMENSIONAL X SCAN %%%%%%%%%%%%%%%%%
            % Prepares a scan for x axis, to be called before ScanX.
            % z - A vector with the points to scan, points should have
            % equal distance between them.
            % x/y - The starting points for the other axes.
            % tPixel - Scan time for each pixel.
            % nFlat - Not used
            % nOverRun - Not used
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % vectorIsInRange(obj, 'z', z)
            
            % if scan is runing
            if (obj.scanRunning == 1)
                warning("WARNING PREVIOUS SCAN CANCELLED");
                AbortScan(obj);
                % warning("Scan is in progress either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.'");
            end
            
            obj.ScanAxis = 'z';
            SetAxisOutput(obj , 'z', obj.ON, obj.OFF);
            Move(obj, ['y' 'x'], [y x]); % move to start postion
        end

        function PrepareScanYX(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XY SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xy axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % x/y - Vectors with the points to scan, points should have
            % equal distance between them.
            % z - The starting points for the other axis.
            % tPixel - Scan time for each pixel.
            % nFlat - Not used
            % nOverRun - Not used
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % if scan is runing
            if obj.scanRunning
                warning("Scan is in progress either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.'");
            end

            Move(obj,'z',z);
            obj.ScanAxis = 'yx';
            PrepareScanInTwoDimensions(obj, y, x, nFlat, nOverRun, tPixel);
        end

        function PrepareScanYZ(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL YZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for yz axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % y/z - Vectors with the points to scan, points should have
            % equal distance between them.
            % x - The starting points for the other axis.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % if scan is runing
            if(obj.scanRunning ~= -1)
                warning("Scan is in progress either call ''ScanNextLine'' to continue or ''AbortScan'' to cancel.'");
                return
            end

            Move(obj,'x',x);
            obj.ScanAxis = 'yz';
            PrepareScanInTwoDimensions(obj, y, z, nFlat, nOverRun, tPixel);
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

            if( obj.ScanAxis ~= 'x')
                fprintf("No scan detected.\nFunction can only be called after PrepareScanX!\n");
                return;
            end
            obj.scanRunning = 1;
            % Move(obj, ['y' 'z'], [y z]); % move to start postion
            ScanOneDimension(obj, x, nFlat, nOverRun, tPixel, 'x');
        end

        function ScanY(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%%%%% ONE DIMENSIONAL Y SCAN %%%%%%%%%%%%%%%%%
            % Does a scan for y axis.
            % y - A vector with the points to scan, points should have
            % equal distance between them.
            % x/z - The starting points for the other axes.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            if( obj.ScanAxis ~= 'y')
                fprintf("No scan detected.\nFunction can only be called after PrepareScanY!\n");
                return;
            end
            obj.scanRunning = 1;
            % Move(obj, ['x' 'z'], [x z]); % move to start postion
            ScanOneDimension(obj, y, nFlat, nOverRun, tPixel, 'y');
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

            if( obj.ScanAxis ~= 'z')
                fprintf("No scan detected.\nFunction can only be called after PrepareScanZ!\n");
                return;
            end
            obj.scanRunning = 1;
            % Move(obj, ['x' 'y'], [x y]); % Move to start point
            ScanOneDimension(obj, z, nFlat, nOverRun, tPixel, 'z');
        end

        function ScanOneDimension(obj, scanAxisVector, nFlat, nOverRun, tPixel, scanAxis)
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
            scanAxis = PrivateGetAxis(obj, scanAxis);
            EndPoint = scanAxisVector(end);
            StartPoint = scanAxisVector(1);

            % MovePrivate(obj,scanAxis,StartPoint) % Move to start point

            % slowScan
            if(obj.FastScanEnable == 0)
%                 for i = 1:length(scanAxisVector)
%                     MovePrivate(obj,scanAxis,scanAxisVector(i));
%                     timer = tic;
%                     while (toc(timer) < tPixel)
%                         % wait
%                     end
%                 end


                nidaq = getObjByName(NiDaq.NAME);
                digitalPulseTask = nidaq.prepareDigitalOutputTask(obj.triggerChannel);

                line = str2double(obj.triggerChannel(4:end));     % For example, if the channel is 'PFI3', we want the line to be '3'
                for i = 1:length(scanAxisVector)
                    Move(obj, scanAxis, scanAxisVector(i));
                    nidaq.writeDigitalOnce(digitalPulseTask, 1, line);
                    pause(tPixel);
                    nidaq.writeDigitalOnce(digitalPulseTask, 0, line);
                end
                Move(obj,scanAxis,StartPoint) % Move bake to start Point

            else % FastScan

                % change velocty
                numberOfPixels = length(scanAxisVector) - 1;
                scanLength = EndPoint -StartPoint;
                totalTime = numberOfPixels*tPixel;
                scanVelocity = scanLength/totalTime;
                SetVelocity(obj,scanAxis,scanVelocity)

                MovePrivate(obj,scanAxis,EndPoint)
                Move(obj,scanAxis,StartPoint) % Move bake to start Point
            end
            obj.scanRunning = -1;
        end

        function FastScan(obj, enable)
            %%%%%%%%%%%%%%%%%%%% FastScan %%%%%%%%%%%%%%%%%%%%
            % Changes the scan between the fast & the slow modes.
            % 'enable' - 1 for fast scan, 0 for slow scan.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.FastScanEnable = enable;
        end

        function PrepareScanInTwoDimensions(obj, macroScanAxisVector, normalScanAxisVector, nFlat, nOverRun, tPixel)
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

            obj.macroScanAxis = obj.ScanAxis(1);
            obj.macroNormalScanAxis = obj.ScanAxis(2);
            SetAxisOutput(obj , obj.macroScanAxis, obj.ON, obj.OFF);
            SetAxisOutput(obj , obj.macroNormalScanAxis, obj.ON, obj.OFF);
            obj.macroScanAxisVector = macroScanAxisVector;
            obj.normalScanAxisVector = normalScanAxisVector;
            obj.IndexNormalVector = 1;
            obj.lengthNormalVector = length(obj.normalScanAxisVector);
            obj.lengthMacroVector = length(obj.macroScanAxisVector);
            obj.scanRunning = 1;
            obj.TPixel = tPixel;

            if(obj.FastScanEnable == 1)
                % change velocty
                numberOfPixels = obj.lengthMacroVector - 1;
                scanLength = obj.macroScanAxisVector(end) -obj.macroScanAxisVector(1);
                totalTime = numberOfPixels*tPixel;
                scanVelocity = scanLength/totalTime;
                SetVelocity(obj,scanAxis,scanVelocity)
            end
        end

        function [forwards, done] = ScanNextLine(obj)
            % Scans the next line for the 2D scan, to be used after
            % 'PrepareScanXX'.
            % forwards is set to 1 when the scan is forward and is set to 0
            % when it's backwards
            % DONE IS CURRENTLY NOT IMPLEMENTED ANYWHERE!
            % done is set to 1 after the last line has been scanned.
            % No other commands should be used between 'PrepareScanXX' and
            % until 'ScanNextLine' has returned done, or until 'AbortScan'
            % has been called.

            if (obj.ScanAxis == -1)
                fprintf('No scan detected.\nFunction can only be called after ''PrepareScanXX!''');
                return
            end

            if (obj.IndexNormalVector > obj.lengthNormalVector)
                fprintf('Attempted to scan next line after last line!')
                return
            end

            % move to start points
            MovePrivate(obj,obj.macroScanAxis,obj.macroScanAxisVector(1));
            MovePrivate(obj,obj.macroNormalScanAxis,obj.normalScanAxisVector(obj.IndexNormalVector));

            % slowScan
            nidaq = getObjByName(NiDaq.NAME);
            digitalPulseTask = nidaq.prepareDigitalOutputTask(obj.triggerChannel);
            line = str2double(obj.triggerChannel(4:end));     % For example, if the channel is 'PFI3', we want the line to be '3'

            if(obj.FastScanEnable == 0)
                for i = 1:obj.lengthMacroVector
                    Move(obj, obj.macroScanAxis, obj.macroScanAxisVector(i));
                    nidaq.writeDigitalOnce(digitalPulseTask, 1, line);
                    pause(obj.TPixel);
                    nidaq.writeDigitalOnce(digitalPulseTask, 0, line);
%                     MovePrivate(obj,obj.macroScanAxis,obj.macroScanAxisVector(i));
%                     timer = tic;
%                     while (toc(timer) < obj.TPixel)
%                         % wait
%                     end
                end
                Move(obj,obj.macroScanAxis,obj.macroScanAxisVector(1)) % Move bake to start Point

            else % FastScan
                MovePrivate(obj,obj.macroScanAxis,obj.macroScanAxisVector(end))
                MovePrivate(obj,obj.macroScanAxis,obj.macroScanAxisVector(1)) % Move bake to start Point
            end

            forwards = 1;
            done = 0;
            if(obj.IndexNormalVector == obj.lengthNormalVector)
                done = 1;
                Halt(obj)
                obj.ScanAxis = -1;
                obj.scanRunning = -1;
            else
                obj.IndexNormalVector = obj.IndexNormalVector + 1;
            end
        end

        function AbortScan(obj)
            % Aborts the 2D scan defined by 'PrepareScanXX';
            Halt(obj)
            obj.ScanAxis = -1;
            obj.scanRunning = -1;
        end

        function PrepareRescanLine(obj)
            % Prepares the previous line for rescanning.
            % Scanning is done with "ScanNextLine"
            if (obj.IndexNormalVector == -1)
                error('No scan detected. Function can only be called after ''PrepareScanXX!''');
            elseif (obj.IndexNormalVector == 1)
                error('Scan did not start yet. Function can only be called after ''ScanNextLine!''');
            end

            % Decrease index
            obj.IndexNormalVector = obj.IndexNormalVector - 1;
        end

        function ChangeLoopMode(obj, mode)
            % Changes between closed and open loop.
            % 'mode' should be either 'Open' or 'Closed'.
            % Stage will auto-lock when in open mode, which should increase
            % stability.

            error('ANC stage cannot chnage loop mode!')
        end

        function JoystickControl(obj, enable)
            % Changes the joystick state for all  to the value of
            % 'enable' - 1 to turn Joystick on, 0 to turn it off.
            fprintf('No joystick connected\n');
        end

        function binaryButtonState = ReturnJoystickButtonState(obj)
            % Returns the state of the buttons in 3 bit decimal format.
            % 1 for first button, 2 for second and 4 for the 3rd.
            fprintf('No joystick support for the ANC controller.');
            binaryButtonState = 0;
        end

        function [tiltEnabled, thetaXZ, thetaYZ] = GetTiltStatus(~)
            % Return the status of the tilt control.
            tiltEnabled = 0;
            thetaXZ = 0;
            thetaYZ = 0;
        end

        function success = EnableTiltCorrection(obj, enable)
            % Enables the tilt correction according to the angles.
        end

        function success = SetTiltAngle(obj, thetaXZ, thetaYZ)
            % Sets the tilt angles between Z axis and XY axes.
            % Angles should be in degrees, valid angles are between -5 and 5
            % degrees.
        end

        function maxScanSize = ReturnMaxScanSize(obj, nDimensions)
            % Returns the maximum number of points allowed for an
            % 'nDimensions' scan.
            maxScanSize = obj.MAX_SCAN_SIZE;
        end

        function PrepareScanZY(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL YZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for yz axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % y/z - Vectors with the points to scan, points should have
            %       equal distance between them.
            % x - The starting points for the other axis.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
        end

        function PrepareScanXZ(obj, x, y, z, nFlat, nOverRun, tPixel) %#ok<INUSD>
            %%%%%%%%%%%%%% TWO DIMENSIONAL XZ SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xz axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % x/z - Vectors with the points to scan, points should have
            %       equal distance between them.
            % y - The starting points for the other axis.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end

        function PrepareScanXY(obj, x, y, z, nFlat, nOverRun, tPixel)
            %%%%%%%%%%%%%% TWO DIMENSIONAL XY SCAN MACRO %%%%%%%%%%%%%%
            % Prepare a macro scan for xy axes!
            % Scanning is done by calling 'ScanNextLine'.
            % Aborting via 'AbortScan'.
            % x/y - Vectors with the points to scan, points should have
            % equal distance between them.
            % z - The starting points for the other axis.
            % tPixel - Scan time for each pixel.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end

    end

    methods(Access=private)
        function phAxes = PrivateGetAxis(~,phAxis)
            % the given (physical) axis (x,y,z or 1 for x, 2 for y,
            % and 3 for z).
            % return 1 for x, 2 for y and 3 for z.
            
            phAxes = zeros(size(phAxis));
            for i=1:length(phAxis)
                if (phAxis(i) == 'x')
                    phAxes(i) = 1;
                elseif (phAxis(i) == 'y')
                    phAxes(i) = 2;
                elseif (phAxis(i) == 'z')
                    phAxes(i) = 3;
                elseif (isnumeric(phAxis(i)) && 1 <= phAxis(i) && phAxis(i)<=3)
                    phAxes(i) = phAxis(i);
                else
                    error("ilegal axes");
                end
            end
        end

        function HaltPrivate(obj)
            % Halt all movment of the stages
            for i = 0:length(obj.VALID_AXES)-1
                rc = calllib(obj.LIB_ALIAS, 'ANC_setAxisOutput',obj.Ptr_handle,i,obj.OFF,obj.OFF);
                if rc ~= 0
                    obj.CheckError(rc);
                end
            end
        end

        function MovePrivate(obj, axisName, targetPosInMicrons)
            % Absolute change in position (the user enters the target position in microns)
            % of axis (x,y,z or 1 for x, 2 for y and 3 for z).
            % when the target position is reached leavs the DC output open
            % and dont open DC output
            targetPosInMicrons = targetPosInMicrons*1e-6;
            Axis = PrivateGetAxis(obj, axisName);
            aliasANC = obj.LIB_ALIAS;

            for i=1:length(Axis)
                [negLimit, posLimit] = ReturnLimits(obj, Axis(i));
                if (targetPosInMicrons(i) <= posLimit)  && (targetPosInMicrons(i) >= negLimit) % checking if the target position is in range
                    % the -1 in Axis(i) is because the stage work with 1 for x, 2 for y and 3 for z
                    rc = calllib(aliasANC, 'ANC_setAxisOutput',obj.Ptr_handle,Axis(i)-1,obj.ON,obj.OFF);
                    obj.CheckError(rc);
                    WaitFor(obj,Axis(i),'EnabledOutput');
                    rc = calllib(aliasANC, 'ANC_setTargetPosition', obj.Ptr_handle,Axis(i)-1,targetPosInMicrons(i));
                    obj.CheckError(rc);
                    rc = calllib(aliasANC, 'ANC_setTargetRange', obj.Ptr_handle,Axis(i)-1,1*1e-9);
                    obj.CheckError(rc);
                    rc = calllib(aliasANC, 'ANC_setTargetGround', obj.Ptr_handle,Axis(i)-1,obj.ON);
%                     obj.CheckError(rc);
                    rc = calllib(aliasANC, 'ANC_startAutoMove', obj.Ptr_handle,Axis(i)-1,obj.ON,obj.OFF);
                    obj.CheckError(rc);
                else
                    warning ('The position you enter is outside of limit range!')
                end
            end


            for i=1:length(Axis)
                [negLimit, posLimit] = ReturnLimits(obj, Axis(i));
                if (targetPosInMicrons(i) <= posLimit)  && (targetPosInMicrons(i) >= negLimit) % checking if the target position is in range
                    WaitFor(obj,Axis(i),'MovementDone',targetPosInMicrons*1e6);
                    SetAxisOutput(obj,Axis(i),obj.OFF,obj.OFF);
                end
            end
        end

        function MovePrivateNoWait(obj, axisName, targetPosInMicrons)
            % Absolute change in position (the user enters the target position in microns)
            % of axis (x,y,z or 1 for x, 2 for y and 3 for z).
            % when the target position is reached leavs the DC output open
            % and dont open DC output

            targetPosInMicrons = targetPosInMicrons*1e-6;
            Axis = PrivateGetAxis(obj, axisName);
            aliasANC = obj.LIB_ALIAS;

            for i=1:length(Axis)
                [negLimit, posLimit] = ReturnLimits(obj, Axis(i));
                if (targetPosInMicrons(i) <= posLimit)  && (targetPosInMicrons(i) >= negLimit) %checking if the target position is in range
                    rc = calllib(aliasANC, 'ANC_setTargetPosition',obj.Ptr_handle,Axis(i)-1,targetPosInMicrons(i));
                    obj.CheckError(rc);
                    rc = calllib(aliasANC, 'ANC_setTargetGround',obj.Ptr_handle,Axis(i)-1,obj.OFF);
                    obj.CheckError(rc);
                    rc = calllib(aliasANC, 'ANC_startAutoMove',obj.Ptr_handle,Axis(i)-1,obj.ON,obj.OFF);
                    obj.CheckError(rc);
                else
                    warning ('The position you enter is outside of limit range!')
                end
            end
        end
    end
end
