classdef ClassStanda8SMC4 < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    properties (Dependent = true)
        Position %in deg.
        OnTarget
    end
    
    properties (SetAccess = private)
        device_id = []
    end
    
    properties
        maxPosition
        minPosition
        travelRange
        maxSpeed
        type
        units
   end
    
    properties (Access = private)    
        setPosition 
        speed
        leadScrewPitch
        % units               % m  for m"m, d for degrees
        counts_per_turn     % encoder counts per turn
        steps_per_turn      % without encoder we use motor steps per turn
        isEncoder           % beelean. if there is encoder in the stage
    end
    
    methods        
        function obj = ClassStanda8SMC4(id)
            %COM: device COM number (char of value)
            % remove type (make it dependent) - use units --> this will be read from the stage!!!!!!!!!!!!
            obj.Connect(id)
            fprintf('connected to stage in com %d\n', id)
            try
                % Engine settings:
                engine_settings_t = struct('NomVoltage',1,'NomCurrent',1,'NomSpeed',1,...
                    'uNomSpeed',1,'EngineFlags',1,'Antiplay',1,'MicrostepMode',1','StepsPerRev',1);
                [err,engine_settings_t] = calllib('libximc','get_engine_settings', obj.device_id, engine_settings_t); %see 6.1.4.52
                obj.testErr(err)
                obj.steps_per_turn = engine_settings_t.StepsPerRev;
                
                % Stage settings:
                stage_settings_t = struct('LeadScrewPitch',2,'Units',100,'MaxSpeed',50,'TravelRange',360,...
                    'SupplyVoltageMin',12,'SupplyVoltageMax',36,'MaxCurrentConsumption',0,...
                    'HorizontalLoadCapacity',0,'VerticalLoadCapacity',0);
                [err,stage_settings_t] = calllib('libximc','get_stage_settings', obj.device_id, stage_settings_t); %see 6.1.4.74
                obj.testErr(err)
                obj.leadScrewPitch = stage_settings_t.LeadScrewPitch;
                obj.units = char(stage_settings_t.Units);               %m for mm, d for degree
                obj.travelRange = stage_settings_t.TravelRange;
                
                % Feedback settings (in presence of encoder):
%                 encoder_information_t = struct('Manufacturer', 0, 'PartNumber', 0);
%                 [err,encoder_information_t] = calllib('libximc','get_encoder_information', obj.device_id, encoder_information_t);
%                 obj.testErr(err)
%                 obj.isEncoder = encoder_information_t.Manufacturer ~= 0;
%                 if obj.isEncoder
                    feedback_settings_t = struct('IPS',0,'FeedbackType',7,'FeedbackFlags',7);%,'CountsPerTurn',7); %'IPS' = 0 is used so that CountsPerTurn can be used - as advised in the manual
                    [err,feedback_settings_t] = calllib('libximc','get_feedback_settings', obj.device_id, feedback_settings_t); %see 6.1.4.52
                    obj.testErr(err)
                    obj.counts_per_turn = feedback_settings_t.IPS;
%                 end
                obj.isEncoder = feedback_settings_t.FeedbackType ~= 5;
                switch obj.units
                    case 'm'
                        obj.type = 'linear';
                    case 'd'
                        obj.type = 'rotation';
                    otherwise
                        obj.type = 'unknown';
                end

                % speed and Borders:
                stage_edges_t = struct('BorderFlags',1,'EnderFlags',11,'LeftBorder',0,'uLeftBorder',0,...
                    'RightBorder',10,'uRightBorder',100);
                [err,stage_edges_t] = calllib('libximc','get_edges_settings', obj.device_id, stage_edges_t);
                obj.testErr(err)
                move_settings_calb_t = struct('Speed', 0, 'Accel', 0, 'Decel', 0, 'AntiplaySpeed', 0);
                [err,move_settings_calb_t] = calllib('libximc','get_move_settings', obj.device_id, move_settings_calb_t);
                obj.testErr(err)
                obj.speed = obj.CountsToValue(move_settings_calb_t.Speed);
                
                switch obj.type
                    case 'linear'
                        obj.maxSpeed = stage_settings_t.MaxSpeed;
                        obj.maxPosition = obj.CountsToValue(stage_edges_t.RightBorder);
                        obj.minPosition = obj.CountsToValue(stage_edges_t.LeftBorder);
                        %  obj.maxSpeed = 2.5; %mm/s; Obsereved
                        obj.maxPosition = -1;
                        obj.minPosition = -49;
                    case 'rotation'
                        obj.maxSpeed = 10; %deg/s; Observed
                        obj.maxPosition = 361; %not doing anything with these values
                        obj.minPosition = -361; %not doing anything with these values
                    case 'unknown'                  % spscific stage with a problem - should be delete after fixing!! Yachel 05.09.21
                        obj.steps_per_turn = 200;
                        obj.leadScrewPitch = 0.25;
                        obj.units = 'm';
                        obj.travelRange = 50;
                        obj.isEncoder = 0;
                        obj.speed = 1.25;
                        obj.maxSpeed = 5;
                        obj.maxPosition = -1; % old value: 28 
                        obj.minPosition = -49; % old value: 2
                        obj.type = 'linear';
                    otherwise
                        error('unknown stage type')
                end
            catch errr
                obj.Close();
                rethrow(errr)
            end
        end
        function testErr(obj,err)
            if err ~= 0
                error('error %d was found on connection to standa stage', err)                
            end            
        end
        function Connect(obj, COM)
            %set device ID and connect to it            
            if isa(COM, 'char')
                str2double(COM)
            end
            %load librery if neded
            if ~libisloaded('libximc')
                %addpath(fullfile(pwd,'../../ximc/win64/wrappers/matlab/'))
                %addpath(fullfile(pwd,'../../ximc/win64/'));
                %path = sprintf('%sControl code\\%s\\Physical\\MagneticStage\\ximc-2.9.14\\ximc\\win64\\', PathHelper.getPathToNvLab(), PathHelper.SetupMode);
                [notfound,warnings] = loadlibrary('win64\libximc.dll', @ximcm) %%% added 'win64\' by Ty Zabelotsky 27/03/22
                disp('libximc is now loaded')
            else
                disp('libximc is already loaded')
            end
            % connect to device
            device_name = sprintf('xi-com:\\\\.\\COM%d',COM);
            if ~isempty(obj.device_id)
                disp('STANDA devise already connected. Disconnecting and reconnecting')
                obj.Close()
            end
            obj.device_id = calllib('libximc','open_device', device_name);
            if isempty(obj.device_id)
                error('Could not connect to stage at COM %d', COM);
            end
        end
        
        function Position = get.Position(obj)
            Position = struct('Position',1,'uPosition', 1, 'EncPosition', 1);
            [~,Position] = calllib('libximc','get_position', obj.device_id, Position);
            Position = obj.CountsToValue(Position.Position + Position.uPosition/256);	
        end
        
        function OnTarget = get.OnTarget(obj)
            OnTarget = 0;
            state = GetStatus(obj);
            currentPosition = obj.CountsToValue(state.CurPosition + state.uCurPosition/256);
            switch obj.type
                case 'linear'
                    if state.MoveSts == 0 ...
                            && abs(currentPosition - obj.setPosition) < 1e-3
                        OnTarget = 1;
                        return
                    end
                case 'rotation'
                    if state.MoveSts == 0 ...
                            && abs(currentPosition - obj.setPosition)<1e-2 || abs(360 - currentPosition - obj.setPosition)<1e-2 %to be on the safe side...
                        OnTarget = 1;
                        return
                    end
                otherwise
                    error('Unknown stage type')
            end
        end
        
        function value = CountsToValue(obj,counts)                 
            if obj.isEncoder
                value = counts*obj.leadScrewPitch/obj.counts_per_turn;  
            else
                value = counts*obj.leadScrewPitch/obj.steps_per_turn;  
            end                
        end
        
        function counts = ValueToCounts(obj,value)            
            %take into acount rem(value , 360)
            if strcmp(obj.type,'rotation')
                value = rem(value , 360);
                value = value -360*(value>180) +360*(value<-180);
            end
            if obj.isEncoder
                counts = value/obj.leadScrewPitch*obj.counts_per_turn;
            else
                counts = value/obj.leadScrewPitch*obj.steps_per_turn;
            end
        end
        function Home(obj) %#ok<MANU>
            disp(['Use XIlab for this. make sure it homes in the right direction,'...
                ', so that nothig gets smashed. Reading the lablog on it can help:',...
                'Controlling the standa motors using MATLAB; stage home and zero'])            
        end       
        function Close(obj)
            %% disconnect device
            device_id_ptr = libpointer('int32Ptr', obj.device_id);
            calllib('libximc','close_device', device_id_ptr);
            obj.device_id = [];
            disp('STANDA stage disconnected - remove me when time comes')
        end

        function t = Timeout(obj, newPosition)            
            position = obj.Position;
            switch obj.type
                case 'linear'
                    t = obj.maxSpeed*abs(position - newPosition);
                case 'rotation'
                    t = obj.maxSpeed*min([mod(position - newPosition,360), ...
                        mod(newPosition - position,360)])*2;
                otherwise 
                    error('Unknown type')
            end
            t = t * 10;
        end  
        
        function Move(obj,newPosition)
            if newPosition > obj.maxPosition || newPosition < obj.minPosition
                error('The position %f is out not in range. Set between %f and %f',...
                    newPosition,obj.minPosition, obj.maxPosition)
            end
            obj.setPosition = newPosition;
            setPositionPoints = floor(obj.ValueToCounts(newPosition));
            set_uPosition = round((obj.ValueToCounts(newPosition) - setPositionPoints) * 256);
            if set_uPosition == 256
                setPositionPoints = setPositionPoints + 1;
                set_uPosition = 0;
            end
            try
                if ~obj.OnTarget % need to move
            %        currentPos = obj.Position;                    
                    [err] = calllib('libximc','command_move', obj.device_id, setPositionPoints, set_uPosition);% send move command
                    obj.testErr(err);
           %         timeout = obj.Timeout(currentPos - obj.setPosition);
           %         now = tic;
           %         while toc(now) < timeout
           %             drawnow
           %             if obj.OnTarget
           %                 return
           %             end
           %             pause(0.05)
           %         end
           %         error('Timeout encountered!')
                end
           catch err
           %     try
           %         obj.setPosition = obj.Position;
           %         obj.Stop
           %     end
%                rethrow(err)
                eee=0;
           end
            
        end
%         function StartedMoving(obj)
%             %This can be used after sending a move command - to see it
%             %started moving, while also testing for a stop flag?
%             for k = 1:4 % no good reason for this duration. It seems to start moving after 0.1-0.2 s
%                 state_s = ximc_get_status(device_id); %this takes about 0.0015 s
%                 if state_s.MoveSts
%                     break
%                 else
%                     pause(0.1)
%                 end
%             end
%             if state_s.MoveSts == 0
%                 error('STANDA stage did not start moving after move command')
%             end
%         end

        function Stop(obj)
            calllib('libximc','command_sstp', obj.device_id);
            if ~obj.OnTarget
                warning('Motor stopped at %s, before reaching desired position %s',...
                    num2str(obj.Position) , num2str(obj.setPosition))
                obj.setPosition = obj.Position;
            end
        end
        
        function setSpeed(obj, newSpeed)
                move_settings_calb_t = struct('Speed', 0, 'Accel', 0, 'Decel', 0, 'AntiplaySpeed', 0);
                [err,move_settings_calb_t] = calllib('libximc','get_move_settings', obj.device_id, move_settings_calb_t);
                obj.testErr(err)
                
                move_settings_calb_t.Speed = obj.ValueToCounts(newSpeed);
                calllib('libximc','set_move_settings', obj.device_id, move_settings_calb_t);
                obj.speed = newSpeed;
        end
        
        function [ res_struct ] = GetStatus(obj)
            % here is a trick.
            % we need to init a struct with any real field from the header.
            dummy_struct = struct('Flags',999);
            parg_struct = libpointer('status_t', dummy_struct);
            [err, res_struct] = calllib('libximc','get_status', obj.device_id, parg_struct);
            obj.testErr(err);
        end
    end    
end

