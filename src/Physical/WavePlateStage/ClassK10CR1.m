classdef ClassK10CR1 < handle
    % Wrapper class for controlling Thorlabs K10CR1 Cage Rotator using Kinesis DLL in MATLAB
    %   Detailed explanation goes here
    

        properties (Constant)
        % DLL paths (Update if Kinesis is installed elsewhere)
        DeviceManagerDLL = 'C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.DeviceManagerCLI.dll';
        GenericMotorDLL  = 'C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.GenericMotorCLI.dll';
        IntegratedStepperMotorDLL = 'C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.IntegratedStepperMotorsCLI.dll';
        % Controller configuration
        SerialNumber = '55422884';     % Change to match your device
        PollingInterval = 250;         % in milliseconds
        Timeout = 60000;               % in milliseconds
        end

    properties
        device
    end
    
    methods
        function obj = ClassK10CR1()
            %CLASSK10CR1 Construct an instance of this class
         % --- Load DLLs ---
            NET.addAssembly(obj.DeviceManagerDLL);
            NET.addAssembly(obj.GenericMotorDLL);
            NET.addAssembly(obj.IntegratedStepperMotorDLL);

            import Thorlabs.MotionControl.DeviceManagerCLI.*
            import Thorlabs.MotionControl.IntegratedStepperMotorsCLI.*

            % --- Initialize and connect device ---
            DeviceManagerCLI.BuildDeviceList();
%             obj.device = KCubeInertialMotor.CreateKCubeInertialMotor(obj.SerialNumber);
%             obj.device.Connect(obj.SerialNumber);
%             obj.device.WaitForSettingsInitialized(5000);
%             obj.device.StartPolling(obj.PollingInterval);
%             obj.device.EnableDevice();
%             pause(1);  % Allow hardware time to respond

        end

        function delete(obj)
            % --- Clean up and disconnect ---
            if ~isempty(obj.device)
                try
%                     obj.device.StopPolling();
%                     obj.device.Disconnect();
                catch
                    warning('Failed to disconnect the K10CR1 device.')
                end
            end
        end
        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
    end
end




    methods
        function obj = ClassKim101()
            % --- Load DLLs ---
            NET.addAssembly(obj.DeviceManagerDLL);
            NET.addAssembly(obj.GenericMotorDLL);
            NET.addAssembly(obj.InertialMotorDLL);

            import Thorlabs.MotionControl.DeviceManagerCLI.*
            import Thorlabs.MotionControl.KCube.InertialMotorCLI.*

            % --- Initialize and connect device ---
            DeviceManagerCLI.BuildDeviceList();
            obj.device = KCubeInertialMotor.CreateKCubeInertialMotor(obj.SerialNumber);
            obj.device.Connect(obj.SerialNumber);
            obj.device.WaitForSettingsInitialized(5000);
            obj.device.StartPolling(obj.PollingInterval);
            obj.device.EnableDevice();
            pause(1);  % Allow hardware time to respond

            % --- Get enums for channel and jog direction ---
            asm = obj.device.GetType().Assembly;
            obj.channels = asm.GetType('Thorlabs.MotionControl.KCube.InertialMotorCLI.InertialMotorStatus+MotorChannels').GetEnumValues();
            obj.jogDirections = asm.GetType('Thorlabs.MotionControl.KCube.InertialMotorCLI.InertialMotorJogDirection').GetEnumValues();
        end

        function delete(obj)
            % --- Clean up and disconnect ---
            if ~isempty(obj.device)
                try
                    obj.device.StopPolling();
                    obj.device.Disconnect();
                catch
                    warning('Failed to disconnect the KIM101 device.')
                end
            end
        end

        function pos = getPosition(obj,channel)
            % --- Return current position of the mirror (in device units) ---
            pos = obj.device.GetPosition(obj.channels.GetValue(channel));
        end

        function setPositionToZero(obj,channel)
            % this sets the virtual position! THIS DOES NOT MOVE THE MIRROR
            obj.device.SetPositionToZero(obj.channels.GetValue(channel))
        end
        
        function setStepSize(obj,channel,stepSize)
            params = obj.device.GetJogParameters(obj.channels.GetValue(channel));
            params.JogStepFwd = stepSize;
            params.JogStepRev = stepSize;
            obj.device.SetJogParameters(obj.channels.GetValue(channel),params)
        end

        function stepsize = getStepSize(obj,channel)
            params = obj.device.GetJogParameters(obj.channels.GetValue(channel));
            stepsize = params.JogStepFwd;
        end

        function setJogSpeed(obj,channel,speed)
            obj.device.SetJogVelocity(obj.channels.GetValue(channel),speed);
        end

        function jog(obj,channel,direction) %0 forward , 1 backward
            obj.device.Jog(obj.channels.GetValue(channel),obj.jogDirections.GetValue(direction),obj.Timeout);
        end

        function moveBy(obj,channel, position)
            % --- Move mirror by a step (jog), direction = 0 (forward), 1 (backward) ---
            obj.device.MoveBy(obj.channels.GetValue(channel), position, obj.Timeout);
        end
    end
end
