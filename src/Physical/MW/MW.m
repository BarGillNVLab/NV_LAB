classdef MW
    %MWGATE 
    
    properties (Constant)
        NEEDED_FIELDS = {'MW'};
        OPTIONAL_FIELDS = {'I', 'Q'};
        OPTIONAL_FIELDS2 = {'IQ2'};
        OPTIONAL_FIELDS3 = {'MW2'};
        OPTIONAL_FIELDS4 = {'AWG'};
        OPTIONAL_FIELDS5 = {'MW3'};
        OPTIONAL_FIELDS6 = {'MW4'};
        OPTIONAL_FIELDS7 = {'SGT'};
        OPTIONAL_FIELDS8 = {'TRIGGER'};
    end
    
    methods (Static)
        function create(mwStruct)
            %%% Part 1: creating switches 
            % Every Setup has to have a MW switch
            nFields = MW.NEEDED_FIELDS;
            missingField = FactoryHelper.usualChecks(mwStruct, nFields);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Can''t initialize Microwave - needed field "%s" was not found in initialization struct!', ...
                    missingField);
            end
            
            % Some setups have I & Q switches, as well
            if isnan(FactoryHelper.usualChecks(mwStruct, MW.OPTIONAL_FIELDS))
                % usualChecks() returning nan means these fileds exist
                nFields = [nFields, MW.OPTIONAL_FIELDS];
            end
            
            % Some setups have MW2, as well
            if isnan(FactoryHelper.usualChecks(mwStruct, MW.OPTIONAL_FIELDS3))
                % usualChecks() returning nan means these fileds exist
                nFields = [nFields, MW.OPTIONAL_FIELDS3];
            end
            
            % Some setups have MW3, as well
            if isnan(FactoryHelper.usualChecks(mwStruct, MW.OPTIONAL_FIELDS5))
                % usualChecks() returning nan means these fileds exist
                nFields = [nFields, MW.OPTIONAL_FIELDS5];
            end
            
            % Some setups have MW4, as well
            if isnan(FactoryHelper.usualChecks(mwStruct, MW.OPTIONAL_FIELDS6))
                % usualChecks() returning nan means these fileds exist
                nFields = [nFields, MW.OPTIONAL_FIELDS6];
            end
            
            % Some setups have AWG, as well
            if isnan(FactoryHelper.usualChecks(mwStruct, MW.OPTIONAL_FIELDS4))
                % usualChecks() returning nan means these fileds exist
                nFields = [nFields, MW.OPTIONAL_FIELDS4];
            end

             % Some setups have R&S SGT100A, as well
            if isnan(FactoryHelper.usualChecks(mwStruct, MW.OPTIONAL_FIELDS7))
                % usualChecks() returning nan means these fileds exist
                nFields = [nFields, MW.OPTIONAL_FIELDS7];
            end

            % Some setups have R&S SGT100A, as well and use triggering from the PG
            if isnan(FactoryHelper.usualChecks(mwStruct, MW.OPTIONAL_FIELDS8))
                % usualChecks() returning nan means these fileds exist
                nFields = [nFields, MW.OPTIONAL_FIELDS8];
            end
            
            % Actually creating the switches
            for j = 1:length(nFields)
                S = mwStruct.(nFields{j});
                
                switch lower(S.classname)
                    case {'pulsegenerator', 'pulsestreamer', 'pulseblaster'}
                        SwitchPgControlled.create(S.switchChannelName, S);
                    otherwise
                        EventStation.anonymousError(...
                            'Can''t create a %s-class fast switch - unknown classname! Aborting.', ...
                            S.classname);
                end
            end
            
            %%% Part 2: Creating an IQ2, if needed
            if isnan(FactoryHelper.usualChecks(struct, MW.OPTIONAL_FIELDS2))
                IQ2Struct = struct.IQ2;
                switch lower(IQ2Struct.classname)
                    case 'nidaq'
                        IQSwitchNidaqControlled.create(IQ2Struct);
                    otherwise
                        EventStation.anonymousError(...
                            'Can''t create a %s-class IQ2 - unknown classname! Aborting.', ...
                            S.classname);
                end
            end
        end
    end
end