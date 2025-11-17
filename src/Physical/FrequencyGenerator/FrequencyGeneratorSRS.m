classdef FrequencyGeneratorSRS < FrequencyGenerator
    %FREQUENCYGENERATORSRS SRS frequency genarator class
    
    properties (Constant, Hidden)
        TYPE = 'srs';
%         NAME = 'srsFrequencyGenerator';
        
        NEEDED_FIELDS = {'address', 'port', 'serialNumber', 'minFrequency', 'maxFrequency', 'minAmplitude', 'maxAmplitude'}
        OPTIONAL_FIELDS = {'keepOn'};
    end
       
    properties (Access = private)
        t       % tcpip object/ serial object
    end
    
    methods (Access = private)
        function obj = FrequencyGeneratorSRS(name, address, port, frequencyLimits, amplitudeLimits, keepOn)
            % All models are the same in regards to controlling them, but
            % the limitations on the amplitude and on the allowed frequencies may vary.
            obj@FrequencyGenerator(name, frequencyLimits, amplitudeLimits, keepOn);
            if startsWith(string(address), "COM", 'IgnoreCase', true) && ~isempty(regexp(address, "^COM\d+$", "once"))
                baud = 115200;                    % set as needed
                obj.t = serialport(char(address), baud); % creates the connection
                % configureTerminator(s,"LF");    % optional
                % writeline(s,"*IDN?");           % example
            else
                % address does not start with COM -> handle other transport types here
            obj.t = tcpip(address, port);
            end
            
            obj.initialize;
        end
    end
       
    methods
        function connect(obj)
            if strcmp(obj.t.Status, 'closed')
                fopen(obj.t);
            end
        end

        function disconnect(obj)
            if strcmp(obj.t.Status, 'open')
                fclose(obj.t);
            end
        end

        function delete(obj)
            obj.disconnect;
            delete(obj.t)
        end

        function sendCommand(obj, command)
            % Actually sends command to hardware
            obj.connect() % Only happens if it is closed
            fprintf(obj.t, command);
        end
        
        function value = readOutput(obj, what)
            % Get value returned from object
            value = fscanf(obj.t, '%s');
            switch what
                case {'frequency', 'freq', 'f'}
                    value = num2str(str2double(value)/1e6);  % convert Hz to MHz
            end
        end
    end
    
    %%
    methods (Static)
        function obj = getInstance(struct)
            missingField = FactoryHelper.usualChecks(struct, ...
                FrequencyGeneratorSRS.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Trying to create an SRS frequency generator, encountered missing field - "%s". Aborting',...
                    missingField);
            end
            struct = FactoryHelper.supplementStruct(struct, FrequencyGeneratorSRS.OPTIONAL_FIELDS);
            
            name = [FrequencyGeneratorSRS.TYPE, '-', struct.serialNumber];
            frequencyLimits = [struct.minFrequency, struct.maxFrequency];
            amplitudeLimits = [struct.minAmplitude, struct.maxAmplitude];
            keepOn = struct.keepOn;
            obj = FrequencyGeneratorSRS(name, struct.address, struct.port, frequencyLimits, amplitudeLimits, keepOn);

            addBaseObject(obj);
        end
        
        function command = createCommand(what, value, channel) %#ok<INUSD>
           switch lower(what)
               case {'enableoutput', 'output', 'enabled', 'enable'}
                   name = 'ENBR';
               case {'frequency', 'freq'}
                   name = 'FREQ';
                   if ~strcmp(value, '?')
                       value = value*1e6; % convert MHz to Hz
                   end
               case {'amplitude', 'ampl', 'amp'}
                   name = 'AMPR';
               case {'phase'}
                   name = 'PHAS';   % phase is in deg
               otherwise
                   error('Unknown command type %s', what)
           end
           
           if isnumeric(value)
               value = num2str(value);
           end
           command = [name, value];
       end
    end
end