classdef (Abstract) Savable < BaseObject
    %SAVABLE object that can be saved to (and loaded from) a file
    
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %      copy & paste the code below for child classes!       %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %     %% overriding from Savable
    %     methods (Access = protected)
    %         function outStruct = saveStateAsStruct(obj, category, type) %#ok<MANU>
    %             % Saves the state as struct. if you want to save stuff, make
    %             % (outStruct = struct;) and put stuff inside. If you dont
    %             % want to save, make (outStruct = NaN;)
    %             %
    %             % category - string. Some objects saves themself only with
    %             %                    specific category (image/experiments/etc.)
    %             % type - string.     Whether the objects saves at the beginning
    %             %                    of the run (parameter) or at its end (result)
    %
    %             outStruct = NaN;
    %         end
    %
    %         function loadStateFromStruct(obj, savedStruct, category, subCategory) %#ok<INUSD>
    %             % loads the state from a struct.
    %             % to support older versoins, always check for a value in the
    %             % struct before using it. view example in the first line.
    %             % category - a string, some savable objects will load stuff
    %             %            only for the 'image_lasers' category and not for
    %             %            'image_stages' category, for example
    %             % subCategory - string. could be empty string
    %
    %
    %
    %             if isfield(savedStruct, 'some_value')
    %                 obj.my_value = savedStruct.some_value;
    %             end
    %         end
    %
    %         function string = returnReadableString(obj, savedStruct)
    %             % return a readable string to be shown. if this object
    %             % doesn't need a readable string, make (string = NaN;) or
    %             % (string = '');
    %
    %             string = NaN;
    %         end
    %     end
    
    
    
    properties (Constant)
        TYPE_PARAMS = 'parameters';
        TYPE_RESULTS = 'results';
        
        CATEGORY_IMAGE = 'image';
        CATEGORY_IMAGE_SUBCAT_STAGE = 'image_stage';
        CATEGORY_IMAGE_SUBCAT_LASER = 'image_laser';
        
        CATEGORY_EXPERIMENTS = 'experiments';
        
        CATEGORY_TRACKER = 'tracker';
        
        SUB_CATEGORY_DEFAULT = '';  % default sub-category is empty string
        
        TIMESTAMP_FORMAT = 'yyyymmdd_HHMMSS';
        PROPERTY_CATEGORY = 'savable___category';
        PROPERTY_TIMESTAMP_START = 'savable___start_timestamp';
        PROPERTY_TIMESTAMP_END = 'savable___end_timestamp';
        CHILD_PROPERTY_READABLE_STRING = 'readable_string';
    end
    
    methods (Access = protected, Abstract)
        saveStateAsStruct(obj, category, type)
        % Saves the state as struct.
        % Override this function to save.
        % To save, you should return a new struct with your properties.
        % If you don't want to save anything, return NaN.
        %
        % category - a string. Some savable objects will save stuff
        %                       only for the 'image' category and not for
        %                       'Experiments' category, for example.
        % type - string. Whether the objects saves at the beginning
        %                       of the run (parameter) or at its end (result)
        %
        loadStateFromStruct(obj, savedStruct, category, subCategory)
        % loads the state from a struct previousely saved.
        % override this function to load
        % category - a string, some savable objects will load stuff
        %            only for the 'image_lasers' category and not for
        %            'image_stages' category, for example
        %
        
        returnReadableString(obj, savedStruct)
        % returns a string representation of the struct. can return empty
        % string or NaN if no readable string is needed
    end
    
    methods (Access = protected)
        function obj = Savable(name)
            % name - the object name
            obj@BaseObject(name);
            Savable.addSavable(obj);
        end
    end
    
    methods
        % destructor
        function delete(obj)
            if JsonInfoReader.getJson.debugMode
                fprintf('Deleting savable object "%s" of class %s\n', obj.name, class(obj));
            end
            Savable.removeSavable(obj);
        end
    end

    methods (Access = protected)
        % This function allows removing objects which are savable, but
        % saved somewhere else.
        % !! Caution !! Misusing this function might lead to loss of
        %               valuable data
        function dontSaveMe(obj)
            Savable.removeSavable(obj);
        end
    end
    
    
    methods (Static, Access = {?SaveLoad})
        function savableObjects = getAllSavableObjects()
            persistent allObjects
            if isempty(allObjects)
                allObjects = CellContainer;
            end
            savableObjects = allObjects;
        end
    end
    
    methods (Static, Access = private)
        function addSavable(savableObject)
            % Make sure there is no other object with the same name
            Savable.removeSavable(savableObject)
            % Add the new object
            allObjects = Savable.getAllSavableObjects();
            allObjects.cells{end + 1} = savableObject;
        end
        
        function removeSavable(savableObject)
            allObjects = Savable.getAllSavableObjects();
            objectsToKeep = cellfun(@(x) ~strcmp(x.name, savableObject.name), allObjects.cells);
            allObjects.cells = allObjects.cells(objectsToKeep);
        end
    end
    
    methods (Static, Hidden)
        function longString = onlyReadableStrings(loadedStruct)
            % Extract all the readable strings
            fields = fieldnames(loadedStruct);
            longString = '';
            if isfield(loadedStruct, Savable.PROPERTY_TIMESTAMP_END)
                % Add timestamp
                timeString = loadedStruct.(Savable.PROPERTY_TIMESTAMP_END);
                time = datenum(timeString, Savable.TIMESTAMP_FORMAT);
                longString = sprintf('Scan time: %s\n', datestr(time));
            end
            for i = 1 : length(fields)
                fieldCell = fields(i);
                field = fieldCell{:};
                value = loadedStruct.(field);
                if isstruct(value) && isfield(value, Savable.CHILD_PROPERTY_READABLE_STRING)
                    % Found a value with a readable string! Extract the readable string...
                    readableString = value.(Savable.CHILD_PROPERTY_READABLE_STRING);
                    longString = sprintf('%s%s\n', longString, readableString);
                end
            end
            if ~isempty(longString)
                longString(end) = [];  % remove the last "\n"
            end
            
        end
        
        function smallStruct = extractSpecificSavableStruct(savableObject, bigStructToLoadFrom)
            % Extracts the part of the big struct that the savable object
            % has written
            % Output: the small part of the struct, or nan if this
            % savable hasn't written anything
            nameToLoad = matlab.lang.makeValidName(savableObject.name);
            if isfield(bigStructToLoadFrom, nameToLoad)
                smallStruct = bigStructToLoadFrom.(nameToLoad);
            else
                smallStruct = nan;
            end
        end
    end
    
end