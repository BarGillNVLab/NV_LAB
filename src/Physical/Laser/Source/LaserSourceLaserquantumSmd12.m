classdef LaserSourceLaserquantumSmd12 < LaserPartAbstract & SerialControlled
    %LASERSOURCELASERQUANTUMSMD12 Laser Quantum SMD12 laser controller, via RS232
    
    properties
        canSetEnabled = true;
        canSetValue = true;
    end
       
    properties (Access = private)
        valueInternal % Keeps Laser power even when it is off
    end
    
    properties (Constant, Hidden)
        %%%% Commands %%%%
        COMMAND_ON = 'ON'
        COMMAND_OFF = 'OFF'
        COMMAND_ON_QUERY = 'STATUS?'
        
        COMMAND_POWER_FORMAT_SPEC = 'POWER=%4.2f'
        COMMAND_POWER_QUERY = 'POWER?'
        
        NEEDED_FIELDS = {'port'};
        
        POWER_VALUE_DEFAULT = 6 %mW
    end
    
    methods (Access = private)
        % constructor
        function obj = LaserSourceLaserquantumSmd12(name, port)
            obj@LaserPartAbstract(name);
            obj@SerialControlled(port);

            obj.minValue = 0;
            obj.maxValue = 120;
            obj.valueInternal = obj.POWER_VALUE_DEFAULT;
            obj.units = 'mW';
            
            obj.baudRate = 9600;
            obj.stopBits = 1;
            obj.terminator = 'CR/LF';
            
            obj.commDelay = 0.05;
            try
                obj.open;
            catch err
                % We can't communicate with the laser, so what's the point?
                obj.delete
                rethrow(err)
            end
        end
    end
       
    methods
        function delete(obj)
            isEnabled = obj.getEnabledRealWorld;
            if isEnabled % We try to turn the laser off, and we tell the user, whatever happens
                try
                    obj.isEnabled = false;
                    msg = sprintf('Turning off %s, upon deletion', obj.name);
                    obj.sendWarning(msg)
                catch err
                    msg = sprintf('Could not turn off %s upon deletion!', obj.name);
                    obj.sendWarning(msg);
                    err2warning(err);
                end
            end
        end
    end
    
    %% Interact with physical laser. Be careful!
    methods (Access = protected)
        function setEnabledRealWorld(obj, newBoolValue)
            % Validating value is assumed to have been done
            if newBoolValue
                obj.query(obj.COMMAND_ON);
            else
                obj.query(obj.COMMAND_OFF);
            end
        end
        
        function setValueRealWorld(obj, newValue)
            % Validating value is assumed to have been done
            commandPower = sprintf(obj.COMMAND_POWER_FORMAT_SPEC, newValue);
            obj.query(commandPower);
            
            % Save value for when laser is turned off
            obj.valueInternal = newValue;
        end
        
        function val = getValueRealWorld(obj)
            isOn = obj.getEnabledRealWorld;
            if isOn
                regex = '(\d+\.\d+)mW'; % a value of the form ##.###mW
                val = str2double(obj.query(obj.COMMAND_POWER_QUERY, regex));
            else
                % The laser gives 0 if it is off.
                val = obj.valueInternal;
            end
        end
        
        function val = getEnabledRealWorld(obj)
            str = obj.query(obj.COMMAND_ON_QUERY);
            if isempty(str)
                val = false;
%                 warning('Cannot Connect with %s\n', obj.name)
            elseif contains(str, 'DISABLED')
                val = false;
            elseif contains(str, 'ENABLED')
                val = true;
            else
                warning('Problem in query!!')
            end
        end
    end
    
    %% Factory
    methods (Static)
        function obj = create(name, jsonStruct)
            missingField = FactoryHelper.usualChecks(jsonStruct, LaserSourceLaserquantumSmd12.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'While trying to create a source part for laser "%s", could not find "%s" field. Aborting', ...
                    name, missingField);
            end
            
            port = jsonStruct.port;
            obj = LaserSourceLaserquantumSmd12(name, port);
        end
    end
    
end

