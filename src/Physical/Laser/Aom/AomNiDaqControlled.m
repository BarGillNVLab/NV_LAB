classdef AomNiDaqControlled < LaserPartAbstract & NiDaqControlled
    %AOMNIDAQCONTROLLED Laser controlled by NiDaq
    
    properties
        niDaqChannel;

        canSetEnabled = false;
        canSetValue = true;
        
        valueInternal
    end
    
    properties (Constant)
        NEEDED_FIELDS = {'channel'};
        OPTIONAL_FIELDS = {'minVal', 'maxVal'};
    end
    
    methods
        % Constructor
        function obj = AomNiDaqControlled(name, niDaqChannel, minVal, maxVal)
            obj@LaserPartAbstract(name, minVal, maxVal, NiDaq.UNITS)
            obj@NiDaqControlled(name, niDaqChannel, minVal, maxVal);
            obj.niDaqChannel = niDaqChannel;
            
            % Initialize
            obj.valueInternal = obj.getValueRealWorld;
        end
    end
    
    methods (Access = protected)
        function setValueRealWorld(obj, newValue)
            niDaq = getObjByName(NiDaq.NAME);
            niDaq.writeVoltage(obj.name, newValue);
            
            obj.valueInternal = newValue;   % backup, for NiDaq reset
        end
        
        function value = getValueRealWorld(obj)
            nidaq = getObjByName(NiDaq.NAME);
            value = nidaq.readVoltage(obj.name);
        end
    end
    
    methods
        function onNiDaqReset(obj, niDaq) %#ok<INUSD>
            % This function jumps when the NiDaq resets
            % Each component can decide what to do
            obj.value = round(obj.valueInternal, 2);
        end
    end
    
    methods (Static)
        function obj = create(name, jsonStruct)
            missingField = FactoryHelper.usualChecks(jsonStruct, AomNiDaqControlled.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(['While trying to create an AOM part for laser "%s",', ...
                    'could not find "%s" field. Aborting'], ...
                    name, missingField);
            end
            
            % We want to get either values set in json, or empty variables
            % (which will be handled by NiDaqControlled constructor):
            jsonStruct = FactoryHelper.supplementStruct(jsonStruct, AomNiDaqControlled.OPTIONAL_FIELDS);
            
            niDaqChannel = jsonStruct.channel;
            minVal = jsonStruct.minVal;
            maxVal = jsonStruct.maxVal;
            obj = AomNiDaqControlled(name, niDaqChannel, minVal, maxVal);
        end
    end
    
end