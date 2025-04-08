classdef IQSwitchNidaqControlled < IQSwitch
    % Wrapper for I2 and Q2 channels, using niDaq and I/Q switches
    
    properties (Constant)
        NEEDED_FIELDS = {'I2', 'Q2'}
        
        MAX_AMPLITUDE = 0.5;    % in volts
        ANGLE_SHIFT = -135;     % use to tile to the regular IQ frame
    end
    
    properties (Access = private)        
       I
       Q
    end
    
    methods
        % Constructor
        function obj = IQSwitchNidaqControlled(I2Address, Q2Address)
            % Create a struct for each NiDaq channel, and register it in
            % the Daq.
            obj@IQSwitch;
            
            % I2 channel
            S = struct('channel', I2Address, 'minVal', -obj.MAX_AMPLITUDE, 'maxVal', obj.MAX_AMPLITUDE);
            obj.I = NiDaqControlledAnalogChannel.create('I2 voltage', S);
            
            % Q2 channel (almost identical)
            S.channel = Q2Address;
            obj.Q = NiDaqControlledAnalogChannel.create('Q2 voltage', S);

        end
    end    
    methods
        function setIValue(obj, newValue)
            obj.I.setValue(newValue)
        end
        
        function setQValue(obj, newValue)
            obj.Q.setValue(newValue)
        end
    end
    
    methods (Static)
        function obj = create(jsonStruct)
            missingField = FactoryHelper.usualChecks(jsonStruct, IQSwitchNidaqControlled.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(['While trying to create an I2/Q2 part,', ...
                    'could not find "%s" field. Aborting'], ...
                    missingField);
            end
            
            I2Address = jsonStruct.I2;
            Q2Address = jsonStruct.Q2;
            obj = IQSwitchNidaqControlled(I2Address, Q2Address);
            
        end
    end
end