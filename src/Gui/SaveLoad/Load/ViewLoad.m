classdef ViewLoad < ViewVBox & EventListener
    %VIEWLOAD Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        btnLoad         % to load file
        btnPrev         % to load prev file in the folder
        btnNext         % to load next file in the folder
        btnLast         % to load last file in the folder
        btnDelete       % to delete the currently loaded file
        radioLoadAuto   % to load from the autosave folder
        radioLoadManual % to load from the folder that "save" saves into
        tvLoadedInfo    % shows the loaded struct in the saveLoad object
        btnLoadToSystem % vector of buttons - to load from the local struct to the system components
        
        category        % string. the category of the saveLoad
        subCategories   % cell of strings. the sub-categories needed for the various "load to system" buttons
    end
    
    methods
        function obj = ViewLoad(parent, controller, saveLoadCategory)
            % saveLoadCategory - string. the category to work with
            
            obj@ViewVBox(parent, controller);
            
            saveLoad = SaveLoad.getInstance(saveLoadCategory);
            obj@EventListener(saveLoad.name);
            obj.category = saveLoadCategory;
            
            %%%% UI elements init   %%%%
            greyOut = {'Enable', 'off'};
            
            hboxLoadImageButtonRow = uix.HBox('Parent', obj.component, 'Spacing', 5);
            obj.btnLoad = uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hboxLoadImageButtonRow, 'string', 'Load...');
            obj.btnPrev = uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hboxLoadImageButtonRow, 'string', '< Previous', greyOut{:});
            obj.btnNext = uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hboxLoadImageButtonRow, 'string', 'Next >', greyOut{:});
            obj.btnLast = uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hboxLoadImageButtonRow, 'string', 'Last >>');
            obj.btnDelete = uicontrol(obj.PROP_BUTTON{:}, 'Parent', hboxLoadImageButtonRow, 'string', 'Delete', greyOut{:});
            hboxLoadImageButtonRow.Widths = [-4 -5 -4 -4 -4];
            
            hboxSecondRow = uix.HBox('Parent', obj.component, 'Spacing', 15);
            
            vboxSecondRowFirstCol = uix.VBox('Parent', hboxSecondRow, 'Spacing', 5);
            loadRadioPanel = uix.Panel('Parent', vboxSecondRowFirstCol, 'Title', 'Load folder', 'Padding', 5);
            vboxRadioButtons = uix.VBox('Parent', loadRadioPanel, 'Spacing', 5);
            obj.radioLoadAuto = uicontrol(obj.PROP_RADIO{:}, 'Parent', vboxRadioButtons, 'string', 'Autosave');
            obj.radioLoadManual = uicontrol(obj.PROP_RADIO{:}, 'Parent', vboxRadioButtons, 'string', 'Last saved');
            % In order to have scrolling in this box, we use a workaround: we define it as an inactive editbox, and set 'Max'-'Min' > 1
            obj.tvLoadedInfo = uicontrol(obj.PROP_EDIT_SMALL{:}, 'Parent', hboxSecondRow, 'String', 'Loaded File Info', ...
                'Enable', 'inactive', 'Min', 0, 'Max', 2);    % These last three name-value pairs SHOULD make it a scrollable textview. Refer to MATLAB doc for more explanations.
            vboxRadioButtons.Heights = [20 20];
            hboxSecondRow.Widths = [-38 -70];
            
            
            %%%% 3rd row: the "load to system!" buttons (inc. callbacks) %%%%
            hbox3rdRow = uix.HBox('Parent', obj.component, 'Spacing', 15);
            labels = obj.getDisplayLoadToSystemButtons(saveLoadCategory);
            subCats = obj.getSubCategoriesForLoadToSystemButtons(saveLoadCategory);
            if length(labels) ~= length(subCats)
                EventStation.anonymousError('Lengths must be same! Coding work must be done here, please. Category: %s', saveLoadCategory)
            end
            len = length(labels);
            obj.btnLoadToSystem = gobjects(1, len);
            for i = 1 : len
                obj.btnLoadToSystem(i) = uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hbox3rdRow, 'string', labels{i}, greyOut{:});
                obj.btnLoadToSystem(i).Callback = @(h,e) obj.handleButtonLoadToSystem(subCats{i});
            end
            
            %%%% Ui components set callbacks  %%%%
            set(obj.radioLoadAuto, 'Callback', @(h,e)obj.handleRadioAuto);
            set(obj.radioLoadManual, 'Callback', @(h,e)obj.handleRadioManual);
            set(obj.btnLoad, 'Callback', @(h,e)obj.handleButtonLoad);
            set(obj.btnDelete, 'Callback', @(h,e)obj.handleButtonDelete);
            set(obj.btnPrev, 'Callback', @(h,e)obj.handleButtonPrev);
            set(obj.btnNext, 'Callback', @(h,e)obj.handleButtonNext);
            set(obj.btnLast, 'Callback', @(h,e)obj.handleButtonLast);
            
            
            
            %%%% Internal properties set values %%%%
            obj.height = 200;
            obj.setHeights([30 100 40]);
            obj.width = 200;
            
            %%%% Set values from the saveLoad %%%%
            obj.refresh();
        end
        
        function cellOfStrings = getDisplayLoadToSystemButtons(~, category)
            % Strings to be displayed in the "load to" buttons, depending
            % on the relevant category.
            % Implement here other buttons for other categories!
            switch category
                case Savable.CATEGORY_IMAGE
                    cellOfStrings = {'To Scan Parameters!', 'To Lasers!'};
                otherwise
                    cellOfStrings = {'To System!'};
            end
        end
        
        function cellOfStrings = getSubCategoriesForLoadToSystemButtons(~, category)
            % Sub-categories matching the "load to" buttons.
            % should be a cell of same length as
            % obj.getDisplayLoadToSystemButtons with the same category
            switch category
                case Savable.CATEGORY_IMAGE
                    cellOfStrings = {Savable.CATEGORY_IMAGE_SUBCAT_STAGE, Savable.CATEGORY_IMAGE_SUBCAT_LASER};
                otherwise
                    cellOfStrings = {Savable.SUB_CATEGORY_DEFAULT};
            end
        end
        
        
        function setAvailableLoads(obj)
            saveLoad = SaveLoad.getInstance(obj.category);
            [allFiles, fileIndex] = saveLoad.availableFiles;
            
            isAnyAvailable = iscell(allFiles) || ischar(allFiles);
            isPrevAvailable = isAnyAvailable && ~isnan(fileIndex) && fileIndex ~= 1;
            isNextAvailable = isAnyAvailable && ~isnan(fileIndex) && fileIndex ~= length(allFiles);
            
            obj.btnLast.Enable = BooleanHelper.boolToOnOff(isAnyAvailable);
            obj.btnPrev.Enable = BooleanHelper.boolToOnOff(isPrevAvailable);
            obj.btnNext.Enable = BooleanHelper.boolToOnOff(isNextAvailable);
            
        end
        
        function handleButtonLoad(obj)
            % Sets the 'Enable' property of the quick loading buttons
            % ('prev', 'next') according to files existing in the folder
            saveLoad = SaveLoad.getInstance(obj.category);
            loadingFolder = saveLoad.mLoadingFolder;
            [fileName,folderName,~] = uigetfile('*.mat', 'Choose file to load...', loadingFolder);
            
            if ~isequal(fileName,0)  % user has not canceled
                saveLoad = SaveLoad.getInstance(obj.category);
                saveLoad.setLoadingFolder(folderName);
                fullPath = [folderName fileName];
                saveLoad.loadFileToLocal(fullPath);
            end
            
            obj.setAvailableLoads;
        end
        
        function handleButtonDelete(obj)
            saveLoad = SaveLoad.getInstance(obj.category);
            filename = saveLoad.mLoadedFileName;
            title = 'Delete file...';
            msg = sprintf('Are you sure you want to delete %s?', filename);
            if QuestionUserOkCancel(title, msg)
                saveLoad.deleteCurrentFile();
            end
            
            obj.setAvailableLoads;
        end
        
        function handleButtonLoadToSystem(obj, subCategory)
            saveLoad = SaveLoad.getInstance(obj.category);
            saveLoad.loadLocalToSystem(subCategory);
        end
        
        function handleButtonPrev(obj)
            saveLoad = SaveLoad.getInstance(obj.category);
            try 
                saveLoad.loadPreviousFile();
            catch e
                err2warning(e)
            end
            
            obj.setAvailableLoads;
        end
        
        function handleButtonNext(obj, ~, ~)
            saveLoad = SaveLoad.getInstance(obj.category);
            try
                saveLoad.loadNextFile();
            catch e
                err2warning(e)
            end
            
            obj.setAvailableLoads;
        end
        
        function handleButtonLast(obj)
            saveLoad = SaveLoad.getInstance(obj.category);
            try
                saveLoad.loadLastFile();
            catch e
                err2warning(e)
            end
            
            obj.setAvailableLoads;
        end
        
        function handleRadioAuto(obj)
            if obj.radioLoadAuto.Value
                saveLoad = SaveLoad.getInstance(obj.category);
                saveLoad.setLoadingFolder('autosave');
            else
                % ignore user pressing off
                obj.radioLoadAuto.Value = 1;
            end
        end
        function handleRadioManual(obj)
            if obj.radioLoadManual.Value
                saveLoad = SaveLoad.getInstance(obj.category);
                saveLoad.setLoadingFolder('manual_saves');
            else
                % ignore user pressing off
                obj.radioLoadManual.Value = 1;
            end
        end
        
        function refresh(obj)
            saveLoad = SaveLoad.getInstance(obj.category);
            if strcmp(saveLoad.mLoadingFolder, saveLoad.PATH_DEFAULT_AUTO_SAVE)
                obj.radioLoadAuto.Value = true;
                obj.radioLoadManual.Value = false;
            else
                obj.radioLoadAuto.Value = false;
                obj.radioLoadManual.Value = true;
            end
            
            % If there is a saved struct, we want to be able to see its string
            loadedStruct = saveLoad.mLocalSaveStruct;
            if isstruct(loadedStruct)
                obj.tvLoadedInfo.String = saveLoad.onlyReadableStrings(loadedStruct);
            end
            
            obj.setAvailableLoads;
        end
        
    end
        
    %% overridden from EventListener
    methods
        %% When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            
            %%%% handle showing the local loaded struct %%%%
            if isfield(event.extraInfo, SaveLoad.EVENT_DELETE_FILE_SUCCESS)
                obj.tvLoadedInfo.String = 'Loaded File Info';
            elseif isfield(event.extraInfo, SaveLoad.EVENT_LOCAL_STRUCT)
                localSavedStruct = event.extraInfo.(SaveLoad.EVENT_LOCAL_STRUCT);
                stringToDisplay = Savable.onlyReadableStrings(localSavedStruct);
                obj.tvLoadedInfo.String = stringToDisplay;
            end
            
            %%%% handle the radio buttons %%%%
            if ~event.isError
                obj.refresh();
            end
            
            %%%% handle the visibility (based on whether a struct loaded) ~~~~
            if isfield(event.extraInfo, SaveLoad.EVENT_STATUS_LOCAL_STRUCT)
                structStatus = event.extraInfo.(SaveLoad.EVENT_STATUS_LOCAL_STRUCT);
                statusesNoFile = {SaveLoad.STRUCT_STATUS_NOT_SAVED, SaveLoad.STRUCT_STATUS_NOTHING};
                if any(strcmp(structStatus, statusesNoFile))
                    obj.btnDelete.Enable = 'off';
                    obj.btnPrev.Enable = 'off';
                    obj.btnNext.Enable = 'off';
                    for btn = obj.btnLoadToSystem; btn.Enable = 'off'; end
                else
                    obj.btnDelete.Enable = 'on';
                    obj.btnPrev.Enable = 'on';
                    obj.btnNext.Enable = 'on';
                    for btn = obj.btnLoadToSystem; btn.Enable = 'on'; end
                end
            end
        end
    end
    
end