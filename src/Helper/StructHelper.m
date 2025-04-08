classdef StructHelper
    %STRUCTHELPER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Constant)
        WHITESPACES_STRUCT_DISP_AMNT = 4
        
        MERGE_OVERRIDE = 'override';
        MERGE_SKIP = 'skip';
    end
    
    methods (Static)
        function string = structAsString(inputStruct)
            % Returns a string repr. of the input struct, which can hold
            % some nested structures inside.
            %
            % inputStruct - one struct. not array.
            %
            string = StructHelper.recGetStructOut(inputStruct, 0);
        end
        
        function struc = setAllFields(struc, newValue)
            fNames = fieldnames(struc);
            for i = 1:length(fNames)
                f = fNames{i};
                struc.(f) = newValue;
            end
        end
        
        function structCombined = merge(structOld, structNew, collisionBehavior)
            % Merges two structs by the following algorithm: Take 1st
            % struct, and add any field from 2nd struct which is not a
            % duplicate
            if ~exist('collisionBehavior','var') || strcmp(collisionBehavior,StructHelper.MERGE_SKIP)
                shouldSkip = true;
            else
                shouldSkip = false;
            end
            
            validateattributes(structOld,{'struct'},{'nonempty'},'','structOld');
            validateattributes(structNew,{'struct'},{'nonempty'},'','structNew');
            
            % Preparing to scan fields of new struct
            nameCellNew = fieldnames(structNew);
            nCollisions = 0;
            n = length(nameCellNew);
            
            % Create new struct
            structCombined = structOld;
            for i = 1:n     % try pushing new fields into old struct
                str = nameCellNew{i};
                if isfield(structCombined,str)
                    if shouldSkip
                        continue
                    else % override
                    end
                    nCollisions = nCollisions + 1;
                end
                structCombined.(str) = structNew.(str);
            end
            
            if nCollisions==0; return; end  % Nothing else to do here
            
            % Warnings, if any fields were skipped:
            % Grammar is important (to me)
            switch nCollisions
                case 1
                    numString = 'One field';
                    verbString = 'was';
                case n
                    numString = 'All of the fields';
                    verbString = 'were';
                otherwise
                    numString = sprintf('%d fields', nCollisions);
                    verbString = 'were';
            end
            actionString = BooleanHelper.ifTrueElse(shouldSkip, 'skipped', 'overridden');
            
            warning('%s in the new array already existed in the old one, and %s %s.', ...
                numString, verbString, actionString)
        end
        
        function fieldNames = getUniqueFieldNames(varargin)
            % Gets some structs, and returns the unique names of all fields
            % in the structs.
            isInputStruct = cellfun(@(x) isstruct(x), varargin);
            assert(all(isInputStruct), 'Cannot get field names of non-structs!');
            
            structs = varargin;
            fieldNamesCells = cellfun(@(x) fields(x), structs, 'UniformOutput', false);
            fieldNamesWithRepitions = vertcat(fieldNamesCells{:});
            fieldNames = unique(fieldNamesWithRepitions);
        end
    end
    
    methods (Static, Access = private)
        function string = recGetStructOut(inputStruct, whitespaecesAmount)
            % Recuresively get the struct out as a string
            % 
            % inputStruct        - the struct to display
            % whitespaecesAmount - the amount od whitespaces to show before
            %                      every line
            %
            fields = fieldnames(inputStruct);
            string = '';
            whitespaces = repmat(sprintf(' '), 1,whitespaecesAmount);
            for i = 1 : length(fields)
                fieldCell = fields(i);
                field = fieldCell{:};
                value = inputStruct.(field);
                if ischar(value)
                    fieldStr = value;
                elseif islogical(value)
                    if value
                        fieldStr = 'true';
                    else
                        fieldStr = 'false';
                    end
                elseif isnumeric(value)
                    fieldStr = num2str(value);
                elseif isstruct(value)
                    fieldStr = sprintf('\n%s', StructHelper.recGetStructOut(value, whitespaecesAmount + StructHelper.WHITESPACES_STRUCT_DISP_AMNT));
                else
                    fieldStr = 'ERROR: UNKNOWN!';
                end
                line = sprintf('%s%s : %s\n', whitespaces, field, fieldStr);
                string = sprintf('%s%s', string, line);
            end
            
            string = string(1 : end - 1);  % remove last end-line ('\n')     
        end
    end
end

