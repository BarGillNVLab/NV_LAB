classdef SaveLoad < Savable & EventSender
    %SAVELOAD Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        mNotes = ''                      % string. Notes to be saved and loaded
        mCategory                        % string. Category that this SaveLoad object works with
        mLocalSaveStruct = NaN;          % struct. Last saved\loaded struct
        mLocalStructStatus = '';         % string. Status of the local struct ('loaded' \ 'saved' \ 'autosaved' \ 'not saved!')
        mLoadedFileName = NaN;           % string. Last file that was saved\loaded\to-be-saved. only file name - not full path!
        mLoadedFileFullPath = NaN;       % string. Last file that was saved\loaded\to-be-saved. full path.
        mSavingFolder                    % string. Used for saving
        mLoadingFolder                   % string. Used by obj.previous(), obj.next() and obj.last()
                                         %         Usually (always?) points to PATH_DEFAULT_AUTO_SAVE, or to mSavingFolder
                                         
        notesStatus                      % string. Whether the notes are saved on current file.
    end
    
    properties (Dependent)
        isStructLoaded
    end
    
    properties (Constant)
        EVENT_DELETE_FILE_SUCCESS = 'fileDeletedSuccessfully';
        EVENT_SAVE_SUCCESS_LOCAL_TO_FILE = 'fileSavedSuccessfully';
        EVENT_LOAD_SUCCESS_FILE_TO_LOCAL = 'fileLoadedSuccessfullyToLocalStruct';
        EVENT_LOAD_SUCCESS_LOCAL_TO_SYSTEM = 'localStructLoadedSuccessfullyToSystem';
        
        EVENT_ERR_NO_INTERNAL_BUFFER = 'errNoInternalBufferYet';
        EVENT_ERR_FNF = 'errFileNotFound';
        EVENT_ERR_SUFFIX_INVALID = 'errInvalidSuffix';
        EVENT_ERR_FILE_EXIST = 'errFileExist';
        EVENT_ERR_FILE_INVALID = 'errFileInvalid';
        
        EVENT_FILENAME = 'fileName';
        EVENT_FOLDER = 'folder';
        EVENT_STATUS_LOCAL_STRUCT = 'localStruct_status';
        EVENT_LOCAL_STRUCT = 'localStruct';
        
        PATH_DEFAULT_SAVE = sprintf('%sControl code\\Saves\\Setup %s\\_Manual\\', ...
            PathHelper.getPathToNvLab(), JsonInfoReader.setupNumber);
        PATH_DEFAULT_AUTO_SAVE = sprintf('%sControl code\\Saves\\Setup %s\\_AutoSave\\', ...
            PathHelper.getPathToNvLab(), JsonInfoReader.setupNumber);
        PATH_SAVE_BACKUP = SaveLoad.PATH_DEFAULT_AUTO_SAVE;   % For now, keep it the same
        SAVE_FILE_SUFFIX = '.mat';
        
        STRUCT_STATUS_NOT_SAVED = 'not yet saved!';
        STRUCT_STATUS_SAVED = 'saved';
        STRUCT_STATUS_AUTO_SAVED = 'autosaved';
        STRUCT_STATUS_LOADED = 'loaded';
        STRUCT_STATUS_NOTHING = 'empty';
        
        NAME_PATTERN_BASE_OBJECT = 'SaveLoad_%s';
    end
    
    
    methods (Static, Sealed)
        function obj = getInstance(category)
            % This method gets the relevant SaveLoad object based on the
            % needed mCategory, so that calling
            %     SaveLoad.getInstance('image')
            % will return a SaveLoad different than calling
            % SaveLoad.getInstance('experiments')
            %
            % category - string

            saveLoadName = SaveLoad.getInstanceName(category);
            obj = getObjByName(saveLoadName);
            if isempty(obj)     % it hasn't been created yet
                obj = SaveLoad(category);
            end
        end
        
        function saveLoadName = getInstanceName(category)
            saveLoadName = sprintf(SaveLoad.NAME_PATTERN_BASE_OBJECT, category);
        end
        
        function init
            % Initialize the relevant SaveLoad objects.
            % Currently, two are special enough to need init() -
            % 1. One for category Image; it is a derived class as it
            %    has different behavior - it needs to listen to the
            %    StageScanner to save the scans.
            % 2. One for category Experiments: Similarly, it needs to
            %    listen to class Experiment.
            
            slImage = getObjByName(SaveLoadCatImage.NAME);
            if isempty(slImage) % i.e. no available object
                SaveLoadCatImage;	% init this object
            end
            
            slExp = getObjByName(SaveLoadCatExp.NAME);
            if isempty(slExp)   % i.e. no available object
                SaveLoadCatExp;
            end
        end
    end
    
    methods (Access = protected)
        function obj = SaveLoad(category)
            name = SaveLoad.getInstanceName(category);
            obj@EventSender(name);
            obj@Savable(name);
            BaseObject.addObject(obj);  % so it can be reached by BaseObject.getByName()
            
            obj.mCategory = category;
            obj.mSavingFolder = obj.PATH_DEFAULT_SAVE;  % to be overridden later by the user, if needed...
            obj.mLoadingFolder = obj.PATH_DEFAULT_AUTO_SAVE;      % to be overridden later by the user, if needed...
            obj.notesStatus = obj.STRUCT_STATUS_NOTHING;
        end
    end
    
    methods
        function setNotes(obj, newNotes, saveToFileOptionalBoolean)
            shouldSaveToFile = exist('saveToFileOptionalBoolean', 'var') && saveToFileOptionalBoolean;
            if (ischar(newNotes))
                if ~strcmp(newNotes, obj.mNotes)
                    obj.mNotes = newNotes;
                    obj.notesStatus = obj.STRUCT_STATUS_NOT_SAVED;
                    if isstruct(obj.mLocalSaveStruct)
                        % Update the struct (and the file if needed)
                        obj.mLocalSaveStruct.(obj.name) = obj.saveStateAsStruct(obj.mCategory,obj.TYPE_RESULTS);
                        if shouldSaveToFile
                            obj.saveNotesToFile;
                        end
                    else 
                        obj.sendEvent(struct('notes', newNotes));
                    end
                end
            else
                obj.sendWarning('newNotes parameter is not a character array! Ignoring');
            end
        end
        
        function setFileName(obj, newFileName)
            % change the file name to save the struct when needed, using obj.autoSave()
            % newFileName - only the file name, not full path!
            
            if ~ischar(newFileName)
                obj.sendWarning('''newFileName'' can only be a string!');
                return;
            end
            
            if ~endsWith(newFileName, obj.SAVE_FILE_SUFFIX)
                newFileName = sprintf('%s%s', newFileName, obj.SAVE_FILE_SUFFIX);
            end
            obj.mLoadedFileName = newFileName;
            obj.sendEvent(struct(obj.EVENT_FILENAME, obj.mLoadedFileName));
        end
        
        function setLoadingFolder(obj, newLoadingFolderString)
            % Set the loading folder to be 'autosave' or another path
            % if newLoadingFolderString == 'autosave':
            %       loading folder will point to PATH_DEFAULT_AUTO_SAVE
            % else if newLoadingFolderString == 'manual_saves':
            %       loading folder will point to obj.mSavingFolder
            % else, the loading folder will point to the new value
            %       AND WILL CHANGE obj.mSavingFolder AS WELL, so 
            %       that next calls to obj.save() will save in the same folder!
            if ~ischar(newLoadingFolderString)
                obj.sendWarning('Please call saveLoad.setmLoadingFolder() only will folder full path! Only strings will be accepted');
                return
            end
            
            newLoadingFolderString = PathHelper.appendBackslashIfNeeded(newLoadingFolderString);
            
            
            if strcmp(newLoadingFolderString, 'autosave\') || ...
                    strcmp(newLoadingFolderString, obj.PATH_DEFAULT_AUTO_SAVE)
                obj.mLoadingFolder = obj.PATH_DEFAULT_AUTO_SAVE;
            elseif strcmp(newLoadingFolderString, 'manual_saves\')
                obj.mLoadingFolder = obj.mSavingFolder;
            elseif PathHelper.isFolderExists(newLoadingFolderString)
                obj.mLoadingFolder = newLoadingFolderString;
                newLoadingFolderString;
            else
                obj.sendWarning(sprintf('Can''t set loading folder - path is not a folder! %s', newLoadingFolderString));
            end
            obj.sendEvent(struct(obj.EVENT_FOLDER, obj.mLoadingFolder));
        end
        
        function outStruct = saveAllObjects(obj, type)
            % Saves all the savable objects to a struct.
            % this struct will look like that:
            % (savable object name) ---> (inner struct. info this savable wants to save)
            % whitespaces are not premitted in struct properties, so they
            % are replaced with underscores.
            % For example, a simple struct could look like that:
            %
            %   struct with fields:
            %       red_laser: [1ª1 struct]
            %       NI_DAQ: [1ª1 struct]
            %
            % category - a string
            %
            category = obj.mCategory;
            switch type
                % We conceptualize an experiment as a black box, with some
                % parameters as the input, and some results as the output.
                % We therefore want to save in one of two cases:
                case Savable.TYPE_PARAMS
                    % at the beginning of an experiment, we save all
                    % starting parameters (even if we try to change
                    % them during run time, towards a new experiment, we
                    % want only the old ones to be saved).
                    % Every time we start a new experiment, we discard the
                    % previous parameters, just in case they changed.
                    outStruct = struct();
                    outStruct.(Savable.PROPERTY_CATEGORY) = category;
                case Savable.TYPE_RESULTS
                    % at the end of the experiment (either when it
                    % completed the measurement, or after it was manually
                    % stopped). We now want to save only the results
                    % (== data).
                    outStruct = obj.mLocalSaveStruct;
            end
            
            allObjects = Savable.getAllSavableObjects();
            for i = 1 : length(allObjects.cells)
                savableObject = allObjects.cells{i};
                try
                    objectStruct = savableObject.saveStateAsStruct(category,type);
                    if isstruct(objectStruct)
                        % Readable string - get the string
                        readableString = savableObject.returnReadableString(objectStruct);
                        if ischar(readableString) && ~isempty(readableString)
                            objectStruct.(Savable.CHILD_PROPERTY_READABLE_STRING) = readableString;
                        end

                        % Property name - replace all spaces with underscores
                        nameToSave = matlab.lang.makeValidName(savableObject.name);
                        if isfield(outStruct, nameToSave)
                            % If object was already saved in the parameter stage, merge structs
                            outStruct.(nameToSave) = StructHelper.merge(objectStruct, outStruct.(nameToSave));
                        else
                            outStruct.(nameToSave) = objectStruct;
                        end
                    end
                catch MException
                    obj.sendWarning(sprintf('Could not save data from %s, because an error has occurred', savableObject.name))
                    err2warning(MException)
                end
            end
            
            % Create timestamp, according to the type of save
            switch type
                case Savable.TYPE_PARAMS
                    % An experiment starts now
                    outStruct.(Savable.PROPERTY_TIMESTAMP_START) = datestr(now, Savable.TIMESTAMP_FORMAT);
                case Savable.TYPE_RESULTS
                    % Now it ends
                    outStruct.(Savable.PROPERTY_TIMESTAMP_END) = datestr(now, Savable.TIMESTAMP_FORMAT);
            end
        end
        
        function loadAllObjects(obj, structToLoadFrom, category, subCategory)
            % Loads all the savable objects from a struct.
            %
            % category - string
            % subCategory - string. could be empty string
            % 
            % structToLoadFrom - this struct should look like that:
            % (savable object name) ---> (inner struct: info this object saved before)
            % whitespaces are not premitted in struct properties, so they
            % are replaced with underscores
            % for example, a simple struct could look like that:
            %
            %   struct with fields:
            %       red_laser: [1ª1 struct]
            %       NI_DAQ: [1ª1 struct]
            %
            if JsonInfoReader.getJson.debugMode
                fprintf('Loading! Category: %s, Sub-category: %s\n', category, subCategory)
            end
            allObjects = Savable.getAllSavableObjects();
            for i = 1 : length(allObjects.cells)
                savableObject = allObjects.cells{i};
                try
                    nameToLoad = matlab.lang.makeValidName(savableObject.name); % Replace all spaces with underscores
                    if isfield(structToLoadFrom, nameToLoad)
                        savableObject.loadStateFromStruct(structToLoadFrom.(nameToLoad), category, subCategory);
                    end
                catch MException
                    obj.sendWarning(sprintf('Could not load data for %s, because an error has occurred', savableObject.name));
                    err2warning(MException)
                end
            end
        end
        
        function outputStructToSave = postProcessLocalSaveStruct(obj, inputStructToSave) %#ok<INUSL>
            % To be overridden by image/expriment, if needed
            outputStructToSave = inputStructToSave;
        end
        
        function saveParamsToLocalStruct(obj)
            % Saves the parameters of the experiment to the local struct
            structToSave = obj.saveAllObjects(Savable.TYPE_PARAMS);
            obj.mLocalSaveStruct = obj.postProcessLocalSaveStruct(structToSave);
            obj.mLocalStructStatus = SaveLoad.STRUCT_STATUS_NOT_SAVED;
            if ischar(obj.mNotes) && ~isempty(obj.mNotes) % We have notes, but they are unsaved, by definition
                obj.notesStatus = obj.STRUCT_STATUS_NOT_SAVED;
            end
            
            % Parse filename (needed only locally, for now)
            if strcmp(obj.mCategory, Savable.CATEGORY_IMAGE)
                namePrefix = Savable.CATEGORY_IMAGE;
            else
                % The prefix will be the name of the current (running)
                % Experiment
                namePrefix = Experiment.current;
            end
            obj.mLoadedFileName = sprintf('%s_%s.mat', namePrefix, structToSave.(Savable.PROPERTY_TIMESTAMP_START));
            
            eventStruct = struct(... 
                obj.EVENT_STATUS_LOCAL_STRUCT, obj.mLocalStructStatus, ...
                obj.EVENT_LOCAL_STRUCT, obj.mLocalSaveStruct);
            obj.sendEvent(eventStruct);
        end
        
        function saveResultsToLocalStruct(obj)
            % Get struct
            structToSave = obj.saveAllObjects(Savable.TYPE_RESULTS);
            obj.mLocalSaveStruct = structToSave;
            
            eventStruct = struct(... 
                obj.EVENT_STATUS_LOCAL_STRUCT, obj.mLocalStructStatus, ...
                obj.EVENT_LOCAL_STRUCT, obj.mLocalSaveStruct, ...
                obj.EVENT_FILENAME, obj.mLoadedFileName);
            obj.sendEvent(eventStruct);
        end
        
        function saveLocalStructToFile(obj, fileFullPath, differentStatusOptional)
            % Saves the local struct into an outer file
            % fileFullPath - string
            % differentStatusOptional - string. If exists, the status will
            %                           be this argument
            %                           (default is 'saved')

            myStruct = obj.mLocalSaveStruct;
            if ~isstruct(myStruct)
                errorMsg = sprintf('No local struct has been loaded\\saved. Nothing to save!\nConsider calling obj.saveParamsToLocalStruct() or obj.loadFileToLocal()');
                obj.sendError(errorMsg);
            end
            
            if ~endsWith(fileFullPath, SaveLoad.SAVE_FILE_SUFFIX)
                errorMsg = sprintf('Incorrect file suffix! (suffix needed: "%s", file to save: "%s"', obj.SAVE_FILE_SUFFIX, fileFullPath);
                obj.sendError(errorMsg, struct(SaveLoad.EVENT_ERR_SUFFIX_INVALID, true, SaveLoad.EVENT_FILENAME, fileFullPath));
            end
            
            if PathHelper.isFileExists(fileFullPath)
                % warningMsg = sprintf('file already exists! overriding... %s', fileFullPath);
                % obj.sendWarning(warningMsg, struct(SaveLoad.EVENT_ERR_FILE_EXIST, true, SaveLoad.EVENT_FILENAME, fileFullPath));
                % un-needed as per Yoav's request
            end
                                   
            obj.mLoadedFileName = PathHelper.getFileNameFromFullPathFile(fileFullPath);
            obj.mLoadedFileFullPath = fileFullPath;
            obj.createFolderIfNeeded(fileFullPath);
            save(fileFullPath, 'myStruct');
            
            if exist('differentStatusOptional', 'var') && ...
                    ischar(differentStatusOptional) && ...
                    ~isempty(differentStatusOptional)
                
                obj.mLocalStructStatus = differentStatusOptional;
                
            else
                obj.mLocalStructStatus = obj.STRUCT_STATUS_SAVED;
            end
            
            if ~isempty(obj.mNotes)
                obj.notesStatus = obj.STRUCT_STATUS_SAVED;
            end
            
            folder = PathHelper.getFolderFromFullPathFile(fileFullPath);
            
            structEvent = struct();
            structEvent.(SaveLoad.EVENT_FILENAME) = obj.mLoadedFileName;
            structEvent.(SaveLoad.EVENT_FOLDER) = folder;
            structEvent.(SaveLoad.EVENT_SAVE_SUCCESS_LOCAL_TO_FILE) = true;
            structEvent.(obj.EVENT_STATUS_LOCAL_STRUCT) = obj.mLocalStructStatus;
            obj.sendEvent(structEvent);
        end
        
        function saveNotesToFile(obj)
            if strcmp(obj.notesStatus, obj.STRUCT_STATUS_NOT_SAVED)
                obj.saveLocalStructToFile(obj.mLoadedFileFullPath, obj.mLocalStructStatus);
            else
                ME = MException('', 'Should this have happenned?');
                warningToDev(ME);
                % For now, do nothing. Maybe should throw warning
            end
        end
        
        function autoSave(obj)
            % Saves the experiment results the local struct into a file
            % in the AUTOSAVE folder
            
            if isnan(obj.mLoadedFileName)
                % We don't have anything to save
                warning('Nothing was saved!')
                return
            end
            
            filename = obj.mLoadedFileName;
            fullPath = sprintf('%s%s', obj.PATH_DEFAULT_AUTO_SAVE, filename);
            
            newStructStatus = obj.STRUCT_STATUS_AUTO_SAVED;
            obj.saveLocalStructToFile(fullPath, newStructStatus);
        end
        
        function save(obj)
            % Saves the struct to a file (with the already predefined
            % obj.mLoadedFileName as name) in the obj.mSavingFolder
            
            obj.mSavingFolder = obj.PATH_DEFAULT_SAVE;  % to be overridden later by the user, if needed...
            filename = obj.mLoadedFileName;
            fullPath = sprintf('%s%s', obj.mSavingFolder, filename);
            obj.saveLocalStructToFile(fullPath);
        end
        
        function saveAs(obj, fileFullPath)
            % Changes the saving folder and the filename, and than saves the file
            folderAndFile = PathHelper.splitFullPathToFolderAndFile(fileFullPath);
            
            folder = folderAndFile{1};
            obj.mSavingFolder = folder;
            obj.setLoadingFolder(folder);
            
            fileName = folderAndFile{2};
            obj.setFileName(fileName);
            
            obj.saveLocalStructToFile(fileFullPath);
        end
        
        function saveBackup(obj)
            % Normal saving saves the new filename, so that later saves
            % will be done in the same file. We therefore can't use
            % the usual save, and we duplicate the saving mechanism here.
            
            myStruct = obj.mLocalSaveStruct;
            if ~isstruct(myStruct)
                return
            end
            
            fullPath = sprintf('%s%s', obj.PATH_SAVE_BACKUP, 'temp.mat');
            obj.createFolderIfNeeded(fullPath);
            save(fullPath, 'myStruct');
        end
            
        
        function success = loadLocalToSystem(obj, subCategoryOptional)
            % Loads the local struct into the system
            % subCategoryOptional - string. Subcategory to load to
            if ~isstruct(obj.mLocalSaveStruct)
                warningMsg = 'No local struct has been loaded\saved. Nothing to save! Consider calling obj.saveParamsToLocalStruct() or obj.loadFileToLocal()';
                obj.sendWarning(warningMsg);
                success = false;
                return
            end
            
            if exist('subCategoryOptional', 'var')
                subCat = subCategoryOptional;
            else
                subCat = Savable.SUB_CATEGORY_DEFAULT;
            end
            
            obj.loadAllObjects(obj.mLocalSaveStruct, obj.mCategory, subCat);
            obj.sendEvent(struct(obj.EVENT_LOAD_SUCCESS_LOCAL_TO_SYSTEM, true));
            success = true;
        end
        
        function success = loadFileToLocal(obj, fileFullPath, shouldSendErrorsOptional)
            % Loads a file to the local struct
            % fileFullPath - string. file path, including file name
            % shouldSendErrorsOptional - optional boolean. If true, errors
            %                            will be sent via obj.sendWarning() 
            %
            sendWarnings = exist('shouldSendErrorsOptional', 'var') && shouldSendErrorsOptional;
            loadedStruct = obj.tryLoadingStruct(fileFullPath, sendWarnings);
            if ~isstruct(loadedStruct)
                success = false;
                return
            end
            
            obj.mLocalSaveStruct = loadedStruct;
            obj.mLoadedFileName = PathHelper.getFileNameFromFullPathFile(fileFullPath);
            obj.mLoadedFileFullPath = fileFullPath;
            obj.mLocalStructStatus = obj.STRUCT_STATUS_LOADED;
            
            structEvent = struct();
            structEvent.(SaveLoad.EVENT_LOAD_SUCCESS_FILE_TO_LOCAL) = true;
            structEvent.(SaveLoad.EVENT_FILENAME) = obj.mLoadedFileName;
            structEvent.(obj.EVENT_LOCAL_STRUCT) = obj.mLocalSaveStruct;
            structEvent.(obj.EVENT_STATUS_LOCAL_STRUCT) = obj.mLocalStructStatus;
            
            % Handle the notes
            if isfield(obj.mLocalSaveStruct, obj.name) ...
                    && isfield(obj.mLocalSaveStruct.(obj.name), 'mNotes')
                obj.setNotes(obj.mLocalSaveStruct.(obj.name).mNotes)
                obj.notesStatus = obj.STRUCT_STATUS_LOADED;
            end
            
            obj.sendEvent(structEvent);
            success = true;
        end
        
        function clearLocal(obj)
            % Used after deleting last file in current folder
            
            % Save temporarily the full Path
            fullPath = obj.mLoadedFileFullPath;
            
            % Empty local struct
            obj.mLoadedFileFullPath = NaN;
            obj.mLoadedFileName = NaN;
            obj.mLocalSaveStruct = NaN;
            obj.mLocalStructStatus = obj.STRUCT_STATUS_NOTHING;
            obj.notesStatus = obj.STRUCT_STATUS_NOTHING;
            
            % Tell the world
            structEvent = struct();
            structEvent.file_full_path = fullPath;
            structEvent.(SaveLoad.EVENT_DELETE_FILE_SUCCESS) = true;
            structEvent.(obj.EVENT_STATUS_LOCAL_STRUCT) = obj.mLocalStructStatus;
            obj.sendEvent(structEvent);
        end
        
        
        function [allFiles, fileIndex] = availableFiles(obj)
            % Finds all relevant available files, and returns the Index of
            % the current file
            %
            % allFiles - the files in the current folder. Will return -1
            %            if there is no loaded file.
            % isPrev - whether there is a previous file.
            % isNext - whether there is a following file.
            
            % Initialize all results as false (unless otherwise proven)
            allFiles = NaN;
            fileIndex = NaN;
            
            irrelevant = {obj.STRUCT_STATUS_NOT_SAVED, obj.STRUCT_STATUS_NOTHING};
            
            if any(strcmp(obj.mLocalStructStatus, irrelevant))
                % The local struct is EITHER empty OR not saved
                return
            end
            currentFileFullPath = obj.mLoadedFileFullPath;
            
            folder = obj.mLoadingFolder;
            allFiles = PathHelper.getAllFilesInFolder(folder, obj.SAVE_FILE_SUFFIX);
            if isempty(allFiles)
                return
            end
            
            ispresent = cellfun(@(string) strcmp(currentFileFullPath, string), allFiles);
            % if file was not found in folder, make it load the last file
            % (fileIndex will be 1 beyond last file, as it will load the file BEFORE fileIndex)
            if ~any(ispresent)
                return
            else
                fileIndex = find(ispresent == 1);
            end
        end
        
        function loadPreviousFile(obj)
            % Load the previous file to the one currently in use.
            % Go through the files in the folder, until finding some file
            % that matches the terms:
            %        @ finishes with '.mat'
            %        @ has same mCategory as obj.mCategory
            
            [allFiles, fileIndex] = obj.availableFiles;
            
            if ~iscell(allFiles) && ~ischar(allFiles) || isempty(allFiles)
                % => We couldn't load list of files
                obj.sendError('Can''t load previous - no file has been loaded, so there''s no previous file!');
            elseif isempty(allFiles)
                obj.sendError('Empty folder - can''t load file!');
            elseif isnan(fileIndex)
                fileIndex = length(allFiles) + 1;   % The following loop will go from the last file backwards
            elseif fileIndex == 1
                obj.sendError('First file is loaded - no previous file exists!');
            end
            
            start = fileIndex - 1;
            step = -1;
            end_ = 1;
            for index = start : step : end_
                % loop through and load the first with matching terms
                loaded = obj.loadFileToLocal(allFiles{index});
                if loaded
                    return
                end
            end
            obj.sendError('Can''t load previous - none of the previous files is loadable.');
        end
        
        function loadNextFile(obj)
            % load the next file to the one currently in use.
            % go through the files in the folder, until finding some file
            % that matches the terms:
            %        @ finishes with '.mat'
            %        @ has same mCategory as obj.mCategory
           [allFiles, fileIndex] = obj.availableFiles;
            
            if ~iscell(allFiles) && ~ischar(allFiles) || isempty(allFiles)
                % => We couldn't load list of files
                obj.sendError('Can''t load next - no file has been loaded, so there''s no next file!');
            elseif isempty(allFiles)
                obj.sendError('Empty folder - can''t load file!');
            elseif isnan(fileIndex)
                fileIndex = 0;   % The following loop will go from the first file onwards
            elseif fileIndex == length(allFiles)
                obj.sendError('Last file is loaded - next file has not been created (yet)!');
            end
            
            for index = fileIndex + 1 : length(allFiles)
                % loop through and load the first with matching terms
                loaded = obj.loadFileToLocal(allFiles{index});
                if loaded
                    return
                end
            end
            obj.sendError('Can''t load next - none of the following files is loadable.');
            
        end
        
        function loadLastFile(obj)
            % Load the last file in the folder of this loaded file
            % go through the files in the folder, until finding some file
            % that matches the terms:
            %        @ finishes with '.mat'
            %        @ has same mCategory as obj.mCategory
            folder = obj.mLoadingFolder;
            disp(folder)
            allFiles = PathHelper.getAllFilesInFolder(folder, obj.SAVE_FILE_SUFFIX);
            if isempty(allFiles)
                obj.sendError('Empty folder, can''t load file!');
            end
            
            start = length(allFiles);
            step = -1;
            end_ = 1;
            for index = start : step : end_
                % loop through and load the first with matching terms
                loaded = obj.loadFileToLocal(allFiles{index});
                if loaded
                    return
                end
            end
            obj.sendError('This folder has not even ONE file good enough to load.\nSorry!');
            
        end
        
        function deleteCurrentFile(obj)
            % Deletes the current file and cleans the struct
            
            illegalStates = {obj.STRUCT_STATUS_NOT_SAVED, obj.STRUCT_STATUS_NOTHING};
            if any(strcmp(obj.mLocalStructStatus, illegalStates))
                obj.sendError('Can''t delete file - not yet saved! Ignoring');
            end
            
            if ~ischar(obj.mLoadedFileFullPath)
                % check that obj.mLoadedFileFullPath is even present
                % obj.mLoadedFileFullPath obtains value in
                % obj.saveLocalStructToFile() and in obj.loadFileToLocal()
                
                obj.sendError('Can''t delete file - no file saved! Ignoring');
            end
            
            if ~PathHelper.isFileExists(obj.mLoadedFileFullPath)
                obj.sendError(sprintf('Can''t delete file - file does not exist! Ignoring\n(file name: %s)', obj.mLoadedFileFullPath));
            end
            
            % Delete m-file. When applicable, delete also png image and fig file.
            % (Ideally, ImageScanResult should have deleted the last two,
            % but it has a lot of overhead (sending event, etc.), so probably not.
            fullPath = obj.mLoadedFileFullPath;
            delete(fullPath);
            strippedFullPath = PathHelper.removeDotSuffix(fullPath);
            fullPathPng = [strippedFullPath, '.', ImageScanResult.IMAGE_FILE_SUFFIX];
            delete(fullPathPng);
            fullPathFig = [strippedFullPath, '.', ImageScanResult.FIGURE_FILE_SUFFIX];
            delete(fullPathFig);

            % When a file is deleted, we need to decide what should be the
            % next local struct. Try loading an available file from the
            % current folder: first try previous, then try next. If all
            % else fails, clear struct.
            try
                obj.loadPreviousFile;
            catch   % Could not find any previous file
                try
                    obj.loadNextFile;
                catch % Could not find any next file, either
                    
                    % Tell user what's going on
                    folder = obj.mLoadingFolder;
                    allFiles = PathHelper.getAllFilesInFolder(folder, obj.SAVE_FILE_SUFFIX);
                    if isempty(allFiles)
                        obj.sendWarning('Congratulations! The folder is now empty.');
                    else
                        obj.sendWarning('Congartulations! You have removed all loadable filed from the folder.');
                    end
                    
                    % "Load" an empty struct
                    obj.clearLocal;
                end
            end
        end
    end
    
    methods (Access = private)
        function createFolderIfNeeded(obj, fileFullPath)
            folderFileCellArray = PathHelper.splitFullPathToFolderAndFile(fileFullPath);
            [folder, ~] = folderFileCellArray{:};
            [status, msg] = mkdir(folder);
            if status ~= 1
                obj.sendWarning(msg)
            end
        end
        
        function loadedStruct = tryLoadingStruct(obj, fileFullPath, shouldSendErrors)
            % Try to load a struct from a file
            %
            % fileFullPath - string. Full path of the file
            % shouldSendErrors - logical. If true, errors will be sent via
            %                    obj.sendWarning()
            %
            % returns - the loaded struct if succeeded, NaN if failed
            loadedStruct = NaN;
            
            if ~PathHelper.isFileExists(fileFullPath)
                warningMsg = sprintf('File does not exist! %s', fileFullPath);
                if shouldSendErrors
                    obj.sendWarning(warningMsg, struct(SaveLoad.EVENT_ERR_FNF, true, obj.EVENT_FILENAME, fileFullPath));
                end
                return
            end
            

            if ~endsWith(fileFullPath, SaveLoad.SAVE_FILE_SUFFIX)
                if shouldSendErrors
                    folderAndFilename = PathHelper.splitFullPathToFolderAndFile(fileFullPath);
                    fileName = folderAndFilename{2};
                    warningMsg = sprintf(...
                        'Incorrect file suffix! Ignoring.\n(Suffix needed:"%s", file to load: "%s"', ...
                        obj.SAVE_FILE_SUFFIX, ...
                        fileName);
                    
                    obj.sendWarning(warningMsg, struct(SaveLoad.EVENT_ERR_SUFFIX_INVALID, true, obj.EVENT_FILENAME, fileFullPath));
                end
                return
            end
            
            structToLoad = load(fileFullPath);
            if ~isfield(structToLoad, 'myStruct')
                if shouldSendErrors
                    obj.sendWarning('Can''t find the reserved field ''myStruct'' in the file to load. Aborting', ...
                        struct(obj.EVENT_ERR_FILE_INVALID, true, obj.EVENT_FILENAME, fileFullPath))
                end
                return
            end
            structToLoad = structToLoad.myStruct;
            structCategory = structToLoad.(Savable.PROPERTY_CATEGORY);
            if ~strcmp(structCategory, obj.mCategory)
                if shouldSendErrors
                    obj.sendWarning(sprintf('Can''t load file - mCategory mismatch! Ignoring.\n(file mCategory: "%s", SaveLoad mCategory: "%s"', structCategory, obj.mCategory));
                end
                clear structToLoad
                return
            end
            
            loadedStruct = structToLoad;
        end
    end
    
    %% getters
    methods
        function out = get.isStructLoaded(obj)
            out = isstruct(obj.mLocalSaveStruct);
        end
        
        function structOfThisSavable = getStructToSavable(obj, savable)
            % A savable can access this method to get their part in the
            % SaveLoad local struct. 
            % Input:    savable - the savable object requesting
            % Output:   structOfThisSavable - the local struct or NaN if not exists
            if ~isstruct(obj.mLocalSaveStruct)
                structOfThisSavable = nan;
                return;
            end
            
            structOfThisSavable = Savable.extractSpecificSavableStruct(savable, obj.mLocalSaveStruct);
        end
    end
    
    %% overriden from Savable
    methods (Access = protected)
        function outStruct = saveStateAsStruct(obj, category, ~)
            % saves the state as struct.
            if strcmp(category, obj.mCategory)
                outStruct = struct('mNotes', obj.mNotes);
            else
                outStruct = NaN;
            end
        end
        
        function loadStateFromStruct(obj, savedStruct, category, subCategory) %#ok<INUSD>
            % loads the state from a struct previousely saved.
            % if the category fits, always load, no matter what is the sub-category
            if ~strcmp(obj.mCategory, category); return; end
            
            if isfield(savedStruct, 'mNotes') && ischar(savedStruct.mNotes)
                obj.mNotes = savedStruct.mNotes;
                obj.sendEvent(struct('mNotes', obj.mNotes));
            end
        end
        
        function string = returnReadableString(obj, savedStruct) %#ok<INUSD>
            string = NaN;
        end
    end
    
    
end

