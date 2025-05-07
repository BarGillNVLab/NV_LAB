classdef AomPSControlled < LaserPartAbstract 

    properties
        agChannel;   % can be 0 or 1

        canSetEnabled = false;
        canSetValue = true;
        valueInternal
    end
    
    properties (Constant)
        NEEDED_FIELDS = {'channel'};
        OPTIONAL_FIELDS = {'minVal', 'maxVal'};
        DEFUALT_VALUE = 0.5;
    end



     methods
        % Constructor
        function obj = AomPSControlled(name, agChannel, minVal, maxVal)
            obj@LaserPartAbstract(name, minVal, maxVal, NiDaq.UNITS)
            obj.agChannel = extractChannelNumber(agChannel);
            
            % Initialize
            obj.setValueRealWorld(0);
        end
    end
    
    methods (Access = protected)
        function setValueRealWorld(obj, newValue)
            pg = getObjByName(PulseGenerator.NAME);
            pg.chooseAnalogOutput(obj.agChannel, newValue);
            
            obj.valueInternal = newValue;   % backup, for NiDaq reset
        end
        
        function value = getValueRealWorld(obj)
            
            value = obj.DEFUALT_VALUE;
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
            jsonStruct = FactoryHelper.supplementStruct(jsonStruct, AomPSControlled.OPTIONAL_FIELDS);
            
            agChannel = jsonStruct.channel;
            minVal = jsonStruct.minVal;
            maxVal = jsonStruct.maxVal;
            obj = AomPSControlled(name, agChannel, minVal, maxVal);
        end
    end
    
end