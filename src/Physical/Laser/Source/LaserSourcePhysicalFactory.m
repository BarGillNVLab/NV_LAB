classdef LaserSourcePhysicalFactory
    %LASERSOURCEPHYSICSFACTORY creates the source part for a laser
    %   has only one method: createFromStruct()
    
    properties (Constant)
        NEEDED_FIELDS = {'classname'};
    end
    
    methods (Static)
        function laserPhysicalPart = createFromStruct(name, struct)
            if isempty(struct)
                laserPhysicalPart = [];
                return
            end
            
            missingField = FactoryHelper.usualChecks(struct, LaserSourcePhysicalFactory.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Trying to create a source for laser "%s", encountered missing field - "%s". Aborting',...
                    name, missingField);
            end
            
            partName = sprintf('%s source', name);
            
            switch lower(struct.classname)
                case 'dummy'
                    laserPhysicalPart = LaserSourceDummy.create(partName, struct);
                    return
                case 'pdl 810'
                    laserPhysicalPart = LaserSourcePDL810.create(partName, struct);
                case 'onefive katana 05'
                    laserPhysicalPart = LaserSourceOnefiveKatana05.create(partName, struct);
                    case 'onefive katana 08'
                    laserPhysicalPart = LaserSourceOnefiveKatana08.create(partName, struct);
                case 'laserquantum smd 12'
                    laserPhysicalPart = LaserSourceLaserquantumSmd12.create(partName, struct);
                case 'swabian dlnsec'
                    laserPhysicalPart = LaserSourceSwabianDLNsec.create(partName, struct);
                otherwise
                    EventStation.anonymousError(...
                        'Can''t create a %s-class laser part for laser "%s" - unknown classname! Aborting.', ...
                        struct.classname, name);
            end
        end
                    
    end
    
end