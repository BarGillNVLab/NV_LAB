classdef ViewPhotodiodeControl < GuiComponent
    %ViewSpcmControl
    %   Detailed explanation goes here
    
    properties
        photodiodeSelection     % we have 3 photodiode: #1: fluorescence, #2: laser sampling, #3: laser block (optional)
        radioPDfluores          % #1
        radioPDfluoresRef       % #1 / (#2 normalized)
        radioPDlaserSample      % #2
        radioPDlaserBlock       % #3
        radioPDboth             % #1 + #2
        
        TypeSelection           % acquisition types for PD #1:
        radioDiff               % diffrential (2 digitizer channels - substruct)
        radioNorm               % normal (1 digitizer channel)
        radioBoth               % present both diffrential channels
        
        cbxLifetime
        edtFrom
        edtTo
    end
    
    methods
        function obj = ViewPhotodiodeControl(parent, controller)
            obj@GuiComponent(parent, controller);
            hboxMain = uix.HBox('Parent', parent, 'Spacing', 5, 'Padding', 0);
            obj.component = hboxMain;
            spcm = getObjByName(Spcm.NAME);
            
            obj.photodiodeSelection = uibuttongroup(...
                'Parent', hboxMain, ...
                'Title', 'Photodiode Control', ...
                'SelectionChangedFcn',@obj.callbackPhotodiodeRadioSelection);
            
            rbHeight = 13; % "rb" stands for "radio button"
            rbWidth = 100;
            paddingFromLeft = 10;
            
            obj.radioPDfluores = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.photodiodeSelection, ...
                'String', 'FL', ...
                'Position', [paddingFromLeft 60 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', PhotoDiodeDigitizerNiDaqControlled.PHOTODIODE_OPTIONS{1});
            obj.radioPDfluoresRef = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.photodiodeSelection, ...
                'String', 'FL norm', ...
                'Position', [paddingFromLeft 35 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', PhotoDiodeDigitizerNiDaqControlled.PHOTODIODE_OPTIONS{2});
            obj.radioPDlaserSample = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.photodiodeSelection, ...
                'String', 'laser sample', ...
                'Position', [paddingFromLeft 10 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', PhotoDiodeDigitizerNiDaqControlled.PHOTODIODE_OPTIONS{3});
            obj.radioPDlaserBlock = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.photodiodeSelection, ...
                'String', 'laser block', ...
                'Position', [paddingFromLeft+rbWidth-5 60 rbWidth+30 rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', PhotoDiodeDigitizerNiDaqControlled.PHOTODIODE_OPTIONS{4});
            obj.radioPDboth = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.photodiodeSelection, ...
                'String', 'FL & laser sample', ...
                'Position', [paddingFromLeft+rbWidth-5 35 rbWidth+30 rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', PhotoDiodeDigitizerNiDaqControlled.PHOTODIODE_OPTIONS{5});
            
            obj.TypeSelection = uibuttongroup(...
                'Parent', hboxMain, ...
                'Title', 'Acquisition Type', ...
                'SelectionChangedFcn',@obj.callbackTypeRadioSelection);
            
            obj.radioDiff = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.TypeSelection, ...
                'String', 'Diffrential', ...
                'Position', [paddingFromLeft 60 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', PhotoDiodeDigitizerNiDaqControlled.TYPE_OPTIONS{1});
            obj.radioNorm = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.TypeSelection, ...
                'String', 'Normal', ...
                'Position', [paddingFromLeft 35 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', PhotoDiodeDigitizerNiDaqControlled.TYPE_OPTIONS{2});
            obj.radioBoth = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.TypeSelection, ...
                'String', 'Diffrential - Both', ...
                'Position', [paddingFromLeft 10 rbWidth+30 rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', PhotoDiodeDigitizerNiDaqControlled.TYPE_OPTIONS{3});
            
            hboxMain.Widths = [-1 130];
            obj.height = 100;
            obj.width = -1;
            
            obj.update()
        end
        
        function update(obj)
            % Executes when spcm updates
            spcm = getObjByName(Spcm.NAME);
            obj.radioPDfluores.Enable = 'on';
            if spcm.availableProperties.(spcm.HAS_LASER_REF)
                obj.radioPDfluoresRef.Enable = 'on';
                if obj.TypeSelection.SelectedObject ~= obj.radioBoth
                    obj.radioPDlaserSample.Enable = 'on';
                    obj.radioPDlaserBlock.Enable = 'on';
                    obj.radioPDboth.Enable = 'on';
                else
                    obj.radioPDlaserSample.Enable = 'off';
                    obj.radioPDlaserBlock.Enable = 'off';
                    obj.radioPDboth.Enable = 'off';
                    if any(spcm.currentChannelGUI == [3 4 5])
                        spcm.currentChannelGUI = 1;
                    end
                end
            else
                obj.radioPDfluoresRef.Enable = 'off';
                obj.radioPDlaserSample.Enable = 'off';
                obj.radioPDlaserBlock.Enable = 'off';
                obj.radioPDboth.Enable = 'off';
            end
            
            obj.radioNorm.Enable = 'on';
            if spcm.availableProperties.(spcm.HAS_DIFF_INPUT)
                obj.radioDiff.Enable = 'on';
                obj.radioBoth.Enable = 'on';
            else
                obj.radioDiff.Enable = 'off';
                obj.radioBoth.Enable = 'off';
            end
            
            obj.radioPDfluores.Value = 0;
            obj.radioPDfluoresRef.Value = 0;
            obj.radioPDlaserSample.Value = 0;
            obj.radioPDlaserBlock.Value = 0;
            obj.radioPDboth.Value = 0;
            switch spcm.currentChannelGUI
                case 1
                    obj.radioPDfluores.Value = 1;
                    obj.photodiodeSelection.SelectedObject = obj.radioPDfluores;
                case 2
                    obj.radioPDfluoresRef.Value = 1;
                    obj.photodiodeSelection.SelectedObject = obj.radioPDfluoresRef;
                case 3
                    obj.radioPDlaserSample.Value = 1;
                    obj.photodiodeSelection.SelectedObject = obj.radioPDlaserSample;
                case 4
                    obj.radioPDlaserBlock.Value = 1;
                    obj.photodiodeSelection.SelectedObject = obj.radioPDlaserBlock;
                case 5
                    obj.radioPDboth.Value = 1;
                    obj.photodiodeSelection.SelectedObject = obj.radioPDboth;
            end
            
            obj.radioDiff.Value = 0;
            obj.radioNorm.Value = 0;
            obj.radioBoth.Value = 0;
            switch spcm.diffrentialInputGUI
                case 1
                    obj.radioDiff.Value = 1;
                    obj.TypeSelection.SelectedObject = obj.radioDiff;
                case 2
                    obj.radioNorm.Value = 1;
                    obj.TypeSelection.SelectedObject = obj.radioNorm;
                case 3
                    obj.radioBoth.Value = 1;
                    obj.TypeSelection.SelectedObject = obj.radioBoth;
            end
        end
        
        %%%% Callbacks %%%%
        function callbackPhotodiodeRadioSelection(obj, ~, event)
            spcm = getObjByName(Spcm.NAME);
            action = event.NewValue.Tag;
            actionIndex = find(strcmp(action, PhotoDiodeDigitizerNiDaqControlled.PHOTODIODE_OPTIONS));
            spcm.currentChannelGUI = actionIndex;
            obj.update();
        end
        
        function callbackTypeRadioSelection(obj, ~, event)
            spcm = getObjByName(Spcm.NAME);
            action = event.NewValue.Tag;
            actionIndex = find(strcmp(action, PhotoDiodeDigitizerNiDaqControlled.TYPE_OPTIONS));
            spcm.diffrentialInputGUI = actionIndex;
            obj.update();
        end
        
        function callbackStartEndSelection(obj, ~, ~)
            spcm = getObjByName(Spcm.NAME);
            if ~ValidationHelper.isValueInteger(obj.edtFrom.String)
                obj.edtFrom.String = spcm.startRead;
                EventStation.anonymousError('Only integer numbers can be accepted! Reverting.');
            end
            if ~ValidationHelper.isValueInteger(obj.edtTo.String)
                obj.edtTo.String = spcm.endRead;
                EventStation.anonymousError('Only integer numbers can be accepted! Reverting.');
            end
            if ~ValidationHelper.isInBorders(str2double(obj.edtFrom.String), 1, spcm.endRead)
                obj.edtFrom.String = spcm.startRead;
                EventStation.anonymousError('Start can''t be lower than 1 or higher than end! Reverting.');
            end
            if ~ValidationHelper.isInBorders(str2double(obj.edtTo.String), spcm.startRead, spcm.nBins)
                obj.edtTo.String = spcm.endRead;
                EventStation.anonymousError('End can''t be lower than start or too high! Reverting.');
            end
            spcm.startRead = round(str2double(obj.edtFrom.String));
            spcm.endRead = round(str2double(obj.edtTo.String));
        end
    end
end