classdef ViewSaveLoad < GuiComponent & EventListener
    %VIEWSAVELOAD View to save and load
    %   Contains ViewSave and ViewLoad
    
    properties
        saveView    % the child view
        tvFileName  % shows the file name with status
        loadView    % the child view
        
        categoryToSave  % string. the category to save ('image', 'experiments', etc...)
    end
    
    properties (Constant)
        DELAY_BG_COLOR_BACK_SEC = 0.2;
        GREEN_BG_COLOR = [0.1 1 0.1];
        RED_BG_COLOR = [1 0.1 0.1];
        
        COLOR_DEFAULT = [0 0 0];            % black
        COLOR_UNSAVED = [1 0.1 0.1];        % red
        COLOR_SAVED = [0.1 0.1 1];          % blue
        COLOR_AUTOSAVED = [0.1 0.8 0.1];    % medium-dark green
    end
    
    methods
        % constructor
        function obj = ViewSaveLoad(parent, controller, categoryToSave)
            % categoryToSave - string. Which category you should save
            % (mostly 'image' or 'experiments')
            
            panel = ViewExpandablePanel(parent, controller, 'Save & Load Image');
            obj@GuiComponent(panel, controller);
            
            saveLoad = SaveLoad.getInstance(categoryToSave);
            obj@EventListener(saveLoad.name);
            
            vbox = uix.VBox('Parent', panel.component, 'Spacing', 5, 'Padding', 5);
            obj.component = vbox;
            obj.categoryToSave = categoryToSave;
            
            
            obj.saveView = ViewSave(obj, controller, categoryToSave);
            obj.tvFileName = uicontrol(obj.PROP_TEXT_NORMAL{:}, 'Parent', obj.component, 'String', 'File Name - ');
            obj.loadView = ViewLoad(obj, controller, categoryToSave);
            heights = [obj.saveView.height, 20, obj.loadView.height];
            widths = [obj.saveView.width, obj.loadView.width];
            
            set(vbox, 'Heights', heights);
            set(vbox, 'Padding', 5);
            set(vbox, 'Spacing', 5);
            
            obj.height = sum(heights) + length(heights) * 8;
            obj.width = max(widths);
            panel.height = obj.height;
            
            % Dispaly current file name and status
            saveload = SaveLoad.getInstance('image');
            fileName = saveload.mLoadedFileName;
            status = saveload.mLocalStructStatus;
            obj.refresh(fileName, status);
        end
        
        function refresh(obj, fileName, status)
            if isnan(fileName)
                % No new file could be loaded
                toDisplay = sprintf('File Name -');
            elseif ischar(fileName) && ischar(status)
                toDisplay = sprintf('File Name - %s (%s)', fileName, status);
            elseif ischar(fileName)
                toDisplay = sprintf('File Name - %s', fileName);
            elseif ischar(status)
                toDisplay = sprintf('File Name - %s', status);
            end
            obj.tvFileName.String = toDisplay;
            obj.tvFileName.ForegroundColor = obj.statusColor(status);
        end
    end
    
    
    methods
        %% When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            
            if event.isError
                return
            end
            
            % Get filename and status
            if isfield(event.extraInfo, SaveLoad.EVENT_STATUS_LOCAL_STRUCT)
                status = event.extraInfo.(SaveLoad.EVENT_STATUS_LOCAL_STRUCT);
            else
                status = NaN;
            end
            
            if isfield(event.extraInfo, SaveLoad.EVENT_FILENAME)
                fileName = PathHelper.getFileNameFromFullPathFile(event.extraInfo.(SaveLoad.EVENT_FILENAME));
            else
                fileName = NaN;
            end
            
            noNewFile = isfield(event.extraInfo, SaveLoad.EVENT_DELETE_FILE_SUCCESS);
            
            % Change display, if needed
            if ischar(fileName) || ischar(status) || noNewFile
                obj.refresh(fileName, status)
            end
            
        end
    end
    
    methods (Static)
        function RGB = statusColor(status)
            % Returns appropriate color for status
            RGB =  ViewSaveLoad.COLOR_DEFAULT;
            if ~ischar(status); return; end
            switch status
                case SaveLoad.STRUCT_STATUS_SAVED
                    RGB = ViewSaveLoad.COLOR_SAVED;
                case SaveLoad.STRUCT_STATUS_AUTO_SAVED
                    RGB = ViewSaveLoad.COLOR_AUTOSAVED;
                case SaveLoad.STRUCT_STATUS_NOT_SAVED
                    RGB = ViewSaveLoad.COLOR_UNSAVED;
            end
        end
    end
end

