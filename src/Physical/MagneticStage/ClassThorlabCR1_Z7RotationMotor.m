classdef ClassThorlabCR1_Z7RotationMotor < handle
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    properties (Dependent = true)
        Position %in deg.
        OnTarget
        type
    end
    
    properties (Access = private) 
        figureHandle
        activeX
        channel  = 0; %This must be of type double
        setPosition 
    end
    
    methods        
        function obj = ClassThorlabCR1_Z7RotationMotor(serial)
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
           obj.figureHandle = figure;
           set(obj.figureHandle,'name',name)
           obj.activeX = actxcontrol('MGMOTOR.MGMotorCtrl.1',[0,0,300,300]);
           obj.activeX.StartCtrl;
           set(obj.activeX, 'HWSerialNum', serial);
           obj.setPosition = obj.Position;
           set(obj.figureHandle, 'Visible','Off')
        end
        function x = get.type(obj)
            x = 'rotation';
        end
        function Position = get.Position(obj)
            [~,Position]=obj.activeX.GetPosition(obj.channel,0); 
        end
        function OnTarget = get.OnTarget(obj)         
            if mod(abs(obj.Position - obj.setPosition),360)<1e-2 || abs(360 - obj.Position - obj.setPosition)<1e-2 % is second one needed?
                OnTarget = 1;
            else
                OnTarget = 0;
            end            
        end
        function Home(obj,~)
            warning(['Homing thorlabs rotation motor has no real effect,'...
            'apart from setting current this position to zero.'...
            ' Consider manually alingning it to it''s true zero first'])
            OK = obj.activeX.MoveHome(obj.channel,false);
            if OK
                error('Homing problem')
            end
        end
            
        function Close(obj)
            close(obj.figureHandle)
        end

        function t = Timeout(obj, newPosition)
            V = obj.activeX.GetVelParams_MaxVel(obj.channel);
            newPosition = mod(newPosition,360);
            t = V*min([mod(obj.Position - newPosition,360), ...
                mod(newPosition - obj.Position,360)])*2;
        end
        function Move(obj,newPosition)
            newPosition = rem( newPosition , 360); % the stage will do this automatically            
            newPosition = single(newPosition);
            obj.setPosition = newPosition;
            [OK] = obj.activeX.MoveAbsoluteRot(obj.channel, newPosition, 0, 3, false); % 0 - no effect for channel = 0; 3 - move to the angle in the fastest way (not positive or negative move, as will be done for 1,2). False - return a value uppon execution 
            if OK
               obj.setPosition = obj.Position;
               error('Thorlab stage error %f', OK) 
            end
        end
        function Stop(obj)
            obj.activeX.StopImmediate(obj.channel);
            if ~obj.OnTarget
                warning('Motor stopped at %s deg, before reaching desired position %s mm',...
                    num2str(obj.Position) , num2str(obj.setPosition))
                obj.setPosition = obj.Position;
            end
        end
    end    
end

