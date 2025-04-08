classdef NiDaqControlledAnalogChannel < NiDaqControlled
    % A single NiDaq analog channel, for instrument control
    
    properties
        valueInternal
    end
    
    properties (Constant)
        NEEDED_FIELDS = {'channel', 'minVal', 'maxVal'};
        OPTIONAL_FIELDS = {};
    end
    
    methods
        % Constructor
        function obj = NiDaqControlledAnalogChannel(name, niDaqChannel, minVal, maxVal)            
            obj@NiDaqControlled(name, niDaqChannel, minVal, maxVal);            
            obj.valueInternal = obj.getValue; 
        end        
    end
    
    methods
        function setValue(obj, newValue)
            niDaq = getObjByName(NiDaq.NAME);
            niDaq.writeVoltage(obj.name, newValue);            
            obj.valueInternal = newValue;   % backup, for NiDaq reset
        end
        
        function value = getValue(obj)
            nidaq = getObjByName(NiDaq.NAME);
            value = nidaq.readVoltage(obj.name);
        end
    end
    
    methods %(Access = protected)
        function onNiDaqReset(obj, niDaq) %#ok<INUSD>
            % This function jumps when the NiDaq resets
            % Each component can decide what to do
            
            % We reload the previous value of the daq channel into the daq
            obj.setValue(obj.valueInternal)
        end
    end
    
    methods (Static)
        function obj = create(name, jsonStruct)
            missingField = FactoryHelper.usualChecks(jsonStruct, NiDaqControlledAnalogChannel.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(['While trying to create a NiDaq channel "%s",', ...
                    'could not find "%s" field. Aborting'], ...
                    name, missingField);
            end
            
            niDaqChannel = jsonStruct.channel;
            minVal = jsonStruct.minVal;
            maxVal = jsonStruct.maxVal;
            
            obj = NiDaqControlledAnalogChannel(name, niDaqChannel, minVal, maxVal);
        end
    end
    
end