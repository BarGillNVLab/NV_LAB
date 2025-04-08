classdef LaserSwitchPhysicalFactory
    %LASERSWITCHPHYSICSFACTORY creates the fast switch for a laser
    %   has only one method: createFromStruct()
    
    properties (Constant)
        NEEDED_FIELDS = {'switchChannelName'}
        OPTIONAL_FIELD_IS_ENABLED = {'isEnabled'}
        OPTIONAL_FIELDS_DELAY = {'onDelay', 'offDelay'}
    end
    
    methods (Static)
        function switchPhysicalPart = createFromStruct(name, struct)
            if isempty(struct) || strcmp(struct.classname, 'dummy')
                switchPhysicalPart = [];
                return
            end
            
            missingField = FactoryHelper.usualChecks(struct, LaserSwitchPhysicalFactory.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Trying to create a fast switch for laser "%s", encountered missing field - "%s". Aborting',...
                    name, missingField);
            end
            
            partName = sprintf('%s fast switch', name);
            
            switch lower(struct.classname)
                case {'pulsegenerator', 'pulsestreamer', 'pulseblaster'}
                    switchPhysicalPart = SwitchPgControlled.create(partName, struct);
                otherwise
                    EventStation.anonymousError(...
                        'Can''t create a %s-class fast switch for laser "%s" - unknown classname! Aborting.', ...
                        struct.classname, name);
            end
            % check for optional field "isEnabled" and set it correctly
            if isnan(FactoryHelper.usualChecks(struct, LaserSwitchPhysicalFactory.OPTIONAL_FIELD_IS_ENABLED))
                % usualChecks() returning nan means everything ok
                switchPhysicalPart.isEnabled = struct.isEnabled;
            end
        end
                    
                    
    end
    
end