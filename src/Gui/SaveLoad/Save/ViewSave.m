classdef ViewSave < GuiComponent & EventListener
    %VIEWSAVE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        btnSave;        % button
        btnSaveAs;      % button
        btnUpdate       % button
        edtNotes;       % edit-text. Contains "notes"
        
        category;       % category to save to. Mostly 'image' or 'experiment'
    end
    
    methods
        % constructor
        function obj = ViewSave(parent, controller, category)
            %%%%% Get object to work with %%%%
            saveLoadPhysical = SaveLoad.getInstance(category);
            
            %%%% Constructors %%%%        
            obj@EventListener(saveLoadPhysical.name);
            obj@GuiComponent(parent, controller);
            
            %%%% Ui components init %%%%
            boxPanel = parent.component;
            vboxSaveImage = uix.VBox('Parent', boxPanel, 'Spacing', 5);
            saveImage1stRow = uix.HBox('Parent', vboxSaveImage, 'Spacing', 5);
            saveImage2stRow = uix.HBox('Parent', vboxSaveImage, 'Spacing', 5);
            
            obj.btnSave = uicontrol(obj.PROP_BUTTON{:}, 'Parent', saveImage1stRow, 'string', 'Save');
            obj.btnSaveAs = uicontrol(obj.PROP_BUTTON{:}, 'Parent', saveImage1stRow, 'string', 'Save As');
            uix.Empty('Parent', saveImage1stRow);  % space
            obj.btnUpdate = uicontrol(obj.PROP_BUTTON{:}, 'Parent', saveImage1stRow, 'string', 'Update Save');
            saveImage1stRow.Widths = [-4 -5 -1 -5];
            
            uicontrol(obj.PROP_LABEL{:}, 'Parent', saveImage2stRow, 'String', 'Notes:'); % 'Notes' label
            obj.edtNotes = uicontrol(obj.PROP_EDIT{:}, 'Parent', saveImage2stRow);
            saveImage2stRow.Widths = [-1 -4];
            
            vboxSaveImage.Heights = [35 25];
            
            %%%% UI components set callbacks %%%%
            set(obj.edtNotes, 'Callback', @obj.edtNotesCallback);
            set(obj.btnSave, 'Callback', @obj.btnSaveCallback);
            set(obj.btnSaveAs, 'Callback', @obj.btnSaveAsCallback);
            set(obj.btnUpdate, 'Callback', @obj.btnUpdateCallback);
            
            %%%% Set internal values %%%%
            obj.height = 70;
            obj.width = 400;
            obj.category = category;
            
            %%%% Init. values from the saveLoad object %%%%
            obj.refresh(saveLoadPhysical);
        end
        
        function respondToInputNotes(obj, ~, ~)
            saveLoad = SaveLoad.getInstance(obj.category);
            saveLoad.setNotes(obj.edtNotes.String);
        end
        
        %%%% Callbacks %%%%
        function edtNotesCallback(obj, ~, ~)
            obj.respondToInputNotes;
            saveLoad = SaveLoad.getInstance(obj.category);
            obj.refresh(saveLoad);
        end
        
        function btnSaveCallback(obj, ~, ~)
            obj.respondToInputNotes(); % Let the notes get into the saveload obj.
            saveLoad = SaveLoad.getInstance(obj.category);
            saveLoad.save();
        end
                
        function btnSaveAsCallback(obj, ~, ~)
            obj.respondToInputNotes(); % Let the notes get into the saveload obj.
            
            [fileName, fullPathFolder, ~] = uiputfile('.mat', 'Save As...');
            if ~ischar(fileName) || ~ischar(fullPathFolder)
                % User pressed cancel
                return
            end
            fullPathFolder = PathHelper.appendBackslashIfNeeded(fullPathFolder);
            
            saveLoad = SaveLoad.getInstance(obj.category);
            saveLoad.saveAs([fullPathFolder fileName]);
        end
        
        function btnUpdateCallback(obj, ~, ~)
            saveLoad = SaveLoad.getInstance(obj.category);
            saveLoad.saveNotesToFile;
        end
        
        %%%% end (Callbacks) %%%%
        
        function refresh(obj, saveLoadObject)
            % Refresh the view on the screen
            %
            % saveLoadObject - saveLoad object to take info from
            
            obj.edtNotes.String = saveLoadObject.mNotes;
            status = saveLoadObject.notesStatus;
            obj.edtNotes.ForegroundColor = ViewSaveLoad.statusColor(status);
        end
    end
        
        
    % overridden from EventListener
    methods
        % When events happen, this function jumps.
        %
        % event is the event sent from the EventSender
        function onEvent(obj, event) %#ok<INUSD>
            saveLoad = SaveLoad.getInstance(obj.category);
            obj.refresh(saveLoad);
        end
    end
    
end

