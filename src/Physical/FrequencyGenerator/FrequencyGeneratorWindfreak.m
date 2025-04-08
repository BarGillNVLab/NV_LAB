classdef FrequencyGeneratorWindfreak < FrequencyGenerator & SerialControlled
    %FREQUENCYGENERATORWINDFREAK Windfreak frequency generator class
    % includes, for now, synthHD & synthNV
    
    properties (Constant, Hidden)
        TYPE = {'synthhd', 'synthnv'};
        TYPE_HD = 'synthhd';
        TYPE_NV = 'synthnv';
        NV_HIGH_PWR_MODE_CMD = 'h1';
        NV_LOW_PWR_MODE_CMD = 'h0';
        NV_HIGH_MAX = 17.5;
        NV_HIGH_MIN = -14;
        NV_LOW_MAX = -21;
        NV_LOW_MIN = -52.5;
        NV_PWR_FACTOR = 2;
        
        NEEDED_FIELDS = {'address', 'serialNumber', 'minFrequency', 'maxFrequency', 'minAmplitude', 'maxAmplitude'}
        OPTIONAL_FIELDS = {'keepOn'};
    end
    
    methods (Access = private)
        function obj=FrequencyGeneratorWindfreak(name, address, frequencyLimits, amplitudeLimits, keepOn)
            obj@FrequencyGenerator(name, frequencyLimits, amplitudeLimits, keepOn);
            obj@SerialControlled(address);
            
            obj.initialize;


           InstrObject.Timeout = 1; % change timeout to 1s , defult is 10s
        end
    end

    methods
        function connect(obj)
            obj.open(); % SerialControlled
        end

        function disconnect(obj)
            obj.close(); % SerialControlled
        end

        function delete(obj)
            delete@SerialControlled(obj); % Just to make it implicit
        end
        
        function sendCommand(obj, command)
            % Actually sends command to hardware
            sendCommand@SerialControlled(obj, command) % Just to make it implicit
        end
        
        function value = readOutput(obj, what) %#ok<INUSD>
            % Get value returned from object
            value = obj.readAll(); % SerialControlled
        end
        
        function command = createCommand(obj, what, value, channel)
            if contains(obj.name, FrequencyGeneratorWindfreak.TYPE_HD) % HD has two channels
                switch channel
                    case {'A', 1}
                        channel = 'C0';
                    case {'B', 2}
                        channel = 'C1';
                    otherwise % Default is first channel
                        channel = 'C0';
                end
         
                command = obj.createCommandHD(what, value, channel);
%                 sendCommand(obj, 'C0f?r?W?C1f?r?W?')
%                 obj.readOutput()
                
            else % synthNV
%                 channel = '';
                command = obj.createCommandNV(what, value);
            end
            
%             switch lower(what)
%                 case {'enableoutput', 'output', 'enable'}
%                     name = 'r';
%                 case {'frequency', 'freq', 'f'}
%                     name = 'f';
%                 case {'amplitude', 'ampl', 'a'}
%                     name = 'W';
%                 otherwise
%                     error('Unknown command type %s', what)
%             end
% 
%             if isnumeric(value)
%                value = num2str(value);
%             end
            
%             command = [channel, name, value];
        end
        
        function commandNV = createCommandNV(obj, what, value)
                        
            % what - command type
            switch lower(what)
                case {'enableoutput', 'output', 'enable'}
                    name = 'o';
                case {'frequency', 'freq', 'f'}
                    name = 'f';
                case {'amplitude', 'ampl', 'a'}
                    value = obj.setPowerNV(value);
                    name = 'a';
                otherwise
                    error('Unknown command type %s', what)
            end
            
            % value
            if isnumeric(value)
               value = num2str(value);
            end
            
            commandNV = [name, value];
            
        end
        
        function power = setPowerNV(obj, pwr)
        % the Synth NV has two power modes, high is -14dBm to +17.5dBm low
        % is -53dBm to -21.5dBm with 64 power levels, 0 is minimum, 63 is
        % maximum, notice there is a gap of -14dBm to -21.5dBm we can't use
        
            if pwr > obj.NV_HIGH_MIN
                obj.sendCommand(obj.NV_HIGH_PWR_MODE_CMD);
                power = obj.NV_PWR_FACTOR * (pwr + abs(obj.NV_HIGH_MIN));
            elseif pwr > obj.NV_LOW_MAX
                obj.sendCommand(obj.NV_HIGH_PWR_MODE_CMD);
                power = 0;                            
            elseif pwr <= obj.NV_LOW_MAX
                obj.sendCommand(obj.NV_LOW_PWR_MODE_CMD);
                power = obj.NV_PWR_FACTOR * (pwr + abs(obj.NV_LOW_MIN));
            end
            
        end
        
        function commandHD = createCommandHD(obj, what, value, channel)
            
%             % channel
%             switch channel
%                 case {'A', 1}
%                     channel = 'C0';
%                 case {'B', 2}
%                     channel = 'C1';
%                 otherwise % Default is first channel
%                     channel = 'C0';
%             end
            
            % what - command type
            switch lower(what)
                case {'enableoutput', 'output', 'enable'}
                    name = 'r';
                case {'frequency', 'freq', 'f'}
                    name = 'f';
                case {'amplitude', 'ampl', 'a'}
                    name = 'W';
                case {'phase', 'p'}
                    name = '~';
                otherwise
                    error('Unknown command type %s', what)
            end
            
            % value
            if isnumeric(value)
               value = num2str(value);
            end
            
            commandHD = [channel, name, value];
            
        end
    end
    
    methods (Static)
        function obj = getInstance(struct)
            type = struct.type;     % We already know it exists
            
            missingField = FactoryHelper.usualChecks(struct, ...
                FrequencyGeneratorWindfreak.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Trying to create a %s frequency generator, encountered missing field - "%s". Aborting',...
                    type, missingField);
            end
            struct = FactoryHelper.supplementStruct(struct, FrequencyGeneratorWindfreak.OPTIONAL_FIELDS);
            
            name = [lower(type), '-', struct.serialNumber];
            frequencyLimits = [struct.minFrequency, struct.maxFrequency];
            amplitudeLimits = [struct.minAmplitude, struct.maxAmplitude];
            keepOn = struct.keepOn;

            obj = FrequencyGeneratorWindfreak(name, struct.address, frequencyLimits, amplitudeLimits, keepOn);
            addBaseObject(obj);
        end
    end
end