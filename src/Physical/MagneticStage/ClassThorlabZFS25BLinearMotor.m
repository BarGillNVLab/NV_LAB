classdef ClassThorlabZFS25BLinearMotor < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    properties (Dependent = true)
        Position
        OnTarget        
        maxPosition
        minPosition
        type
    end
    
    properties (Access = private) 
        figureHandle
        maxPositionPrivate;
        minPositionPrivate;
        activeX
        channel  = 0; %This must be of type double
        setPosition 
    end
    methods
        function obj = ClassThorlabZFS25BLinearMotor(serial)
           % Starts a class event. Serial is written on the MotorController. Will open an ActiveX link 
           switch class(serial)
               case 'double'
                   %Do nothing
               case 'char'
                   serial = num2str(serial);
               otherwise
                   error('unknown input type %s for serial input', class(serial))
           end
           name = sprintf('ThorlabCR1_Z7RotationMotor %u activeX control',serial);
           h = get(0,'Children'); % get a list of all figures
           if ~isempty(find(strcmp({h(:).Name},name),1)) % look for an open activeX control
               close(h(strcmp({h(:).Name},name))) % prevent duplicants
               disp('prev. opened activeX control was closed. opening a new one') 
           end
           obj.figureHandle = figure;%('Position',[10 10 .1 .1]);
           set(obj.figureHandle,'name',name)
           obj.activeX = actxcontrol('MGMOTOR.MGMotorCtrl.1',[0,0,300,300]);
           obj.activeX.StartCtrl;
           set(obj.activeX, 'HWSerialNum', serial);
           obj.setPosition = obj.Position;
           set(obj.figureHandle, 'Visible','Off')
           obj.maxPositionPrivate = obj.activeX.GetStageAxisInfo_MaxPos(0);
           obj.minPositionPrivate = obj.activeX.GetStageAxisInfo_MinPos(0);
        end
        function Home(obj,name)
            %% This will open up a dialog figure before homing
            if nargin < 2
                name = '';
            end
            h = figure('units','pixels',...
                'position',[300 300 300 100]);
            uicontrol('style','text','position',[5 50 290 40],'string',sprintf('Home %s stage? This will move stage to its true zero, and may break things on the way...',name))
            uicontrol('style','push',...
                'unit','pix',...
                'position',[10 15 280 30],...
                'fontsize',12,...
                'fontweight','bold',...
                'string',sprintf('I know what I''m doing, Home %s',name),...
                'callback',@pb_call);
            function pb_call(varargin)                
                delete(h)
                OK = obj.activeX.MoveHome(obj.channel,false);
                if OK
                    error('Homing problem')
                end
            end
                        
        end
        function x = get.type(obj)
            x = 'linear';
        end
        function Position = get.Position(obj)
            [~,Position]=obj.activeX.GetPosition(obj.channel,0); 
        end
        function OnTarget = get.OnTarget(obj)         
            if abs(obj.Position - obj.setPosition)<1e-3
                OnTarget = 1;
            else
                OnTarget = 0;
            end            
        end
        function maxPosition = get.maxPosition(obj)
            maxPosition = obj.maxPositionPrivate;
        end
        function minPosition = get.minPosition(obj)
            minPosition = obj.minPositionPrivate;
        end
        
        function Close(obj)
            close(obj.figureHandle)
        end

        function t = Timeout(obj, newPosition)
            V = obj.activeX.GetVelParams_MaxVel(obj.channel);
            t = V*(abs(obj.Position - newPosition)+2) *100; % 10 was used - and was too short (small changes?). 0.5 added to allow for small changes
        end
        function Move(obj,newPosition)
            if newPosition > obj.maxPositionPrivate || newPosition < obj.minPositionPrivate
                error('The position %f is out not in range. Set between %f and %f',...
                    newPosition,obj.minPositionPrivate, obj.maxPositionPrivate)
            end
            newPosition = single(newPosition);
            obj.setPosition = newPosition;
            obj.activeX.SetAbsMovePos(obj.channel,single(newPosition));
            [OK] = obj.activeX.MoveAbsolute(obj.channel,false); %true – returns a value upon move complete; false – returns value upon move start         
            if OK
               obj.setPosition = obj.Position;
               error('Thorlab stage error %f', OK) 
            end
        end
        function Stop(obj)
            obj.activeX.StopImmediate(obj.channel);
            if ~obj.OnTarget
                warning('Motor stopped at %s mm, before reaching desired position %s mm',...
                    num2str(obj.Position) , num2str(obj.setPosition))
                obj.setPosition = obj.Position;
            end
        end
    end    
end

