classdef FactoryHelper
    %FACTORYHELPER Facilitates "factory" architecture
    %   When creating a new object, we might want to make sure we have all
    %   we need for that purpose. This check is conceptualized as a
    %   "factory" for the object, and should use this class
    
    properties
    end
    
    methods (Static)
        function missingField = usualChecks(struct, neededFields)
            % Checks for the needed fields in the struct
            % neededFields - cell array of character vectors. For example:
            %     {'nickname', 'classname', 'directControl', 'aomControl'}
            %
            % returns - the first missing field (if exists) or NaN
            
            if ~exist('struct', 'var')
                missingField = 'Entire struct';
                return
            end
            for i = 1 : length(neededFields)
                if ~isfield(struct, neededFields{i})
                    missingField = neededFields{i};
                    return;
                end
            end
            missingField = NaN;
        end
        
        function newStruct = supplementStruct(Struct, optionalFields)
            % Checks for optional fields in the struct.
            % optionalFields - cell array of character vectors. Names of
            % optional fields in struct
            % 
            % returns - the same struct, with empty fields for previously
            % unavailable ones
            for i = 1:length(optionalFields)
                f = optionalFields{i};
                if ~isfield(Struct, f)
                    Struct.(f) = [];
                end
            end
            newStruct = Struct;
        end
    end
    
end

