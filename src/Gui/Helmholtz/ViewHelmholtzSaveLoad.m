classdef ViewHelmholtzSaveLoad < GuiComponent
    %VIEWSAVELOAD View to save and load
    %   Contains ViewSave and ViewLoad
    
    properties
        btnSave        % button
        btnSaveAs      % button
        btnLoad        % button
        
        tvFileName  % shows the file name with status
        
        helm
    end
    
    properties (Constant)
        BASE_FILE_NAME = 'helmholtz_setup_';
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
        function obj = ViewHelmholtzSaveLoad(parent, controller)
            panel = ViewExpandablePanel(parent, controller, 'Save & Load setup properties');
            obj@GuiComponent(panel, controller);
            obj.helm = getObjByName('Helmholtz');

            vboxSave = uix.VBox('Parent', panel.component, 'Spacing', 5, 'Padding', 5);
            
            saveLoadRow = uix.HBox('Parent', vboxSave, 'Spacing', 5);
            obj.btnSave = uicontrol(obj.PROP_BUTTON{:}, 'Parent', saveLoadRow, 'string', 'Save');
            obj.btnSaveAs = uicontrol(obj.PROP_BUTTON{:}, 'Parent', saveLoadRow, 'string', 'Save As');
            uix.Empty('Parent', saveLoadRow);  % space
            obj.btnLoad = uicontrol(obj.PROP_BUTTON{:}, 'Parent', saveLoadRow, 'string', 'Load');
            saveLoadRow.Widths = [-4 -4 -2 -4];
            
            obj.tvFileName = uicontrol(obj.PROP_TEXT_NORMAL{:}, 'Parent', vboxSave, 'String', 'File Name: helmholtz_setup_');
            vboxSave.Heights = [50, 25];
            
            
            obj.btnSave.Callback = @obj.btnSaveCallback;
            obj.btnSaveAs.Callback = @obj.btnSaveAsCallback;
            obj.btnLoad.Callback = @obj.btnLoadCallback;
            
            obj.height = sum( vboxSave.Heights)+50;
            obj.width = 300;

            obj.refresh;
        end
        
        function refresh(obj)
            filename = ['File Name: ', obj.BASE_FILE_NAME, datestr(now, '20yymmdd_HHMMSS')];
            obj.tvFileName.String = filename;
        end
        
        function btnSaveCallback(obj,~,~)
            filename = [obj.BASE_FILE_NAME, datestr(now, '20yymmdd_HHMMSS'), '.mat'];
            fullPath = sprintf('%s%s', SaveLoad.PATH_DEFAULT_AUTO_SAVE, filename);
            obj.helm.save(fullPath);
        end
        
        function btnSaveAsCallback(obj,~,~)
            [fileName, fullPathFolder, ~] = uiputfile('.mat', 'Save As...');
            fullPath = [fullPathFolder, fileName];
            obj.helm.save(fullPath);
        end
        
        function btnLoadCallback(obj,~,~)
            [fileName, folderName,~] = uigetfile('*.mat', 'Choose file to load...');
            fullPath = [folderName, fileName];
            obj.helm.load(fullPath);
        end
        
    end
    
    %%
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

