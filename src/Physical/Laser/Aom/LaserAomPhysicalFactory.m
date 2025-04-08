classdef LaserAomPhysicalFactory
    %LASERAOMPHYSICALFACTORY Creates the laser part for a laser.
    %   Has only one method: createFromStruct()
    
    properties (Constant)
        NEEDED_FIELDS = {'classname'};
    end
    
    methods (Static)
        function aomPhysicalPart = createFromStruct(name, struct)
            if isempty(struct)
                aomPhysicalPart = [];
                return
            end
            
            missingField = FactoryHelper.usualChecks(struct, LaserSourcePhysicalFactory.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Trying to create an AOM part for laser "%s", encountered missing field - "%s". Aborting',...
                    name, missingField);
            end
            
            partName = sprintf('%s aom_part', name);
            
            switch lower(struct.classname)
                case 'dummy'
                    aomPhysicalPart = AomDummy(partName);
                    return
                case 'nidaq'
                    aomPhysicalPart = AomNiDaqControlled.create(partName, struct);
                    return
                case 'nidaqdouble'
                    aomPhysicalPart = AomDoubleNiDaqControlled.create(partName, struct);
                otherwise
                    EventStation.anonymousError( ...
                        'Can''t create a %s-class AOM part for laser "%s" - unknown classname! Aborting.', ...
                        struct.classname, name);
            end
        end
                    
                    
    end
    
end