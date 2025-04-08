classdef ViewSpcmControl < GuiComponent
    %ViewSpcmControl
    %   Detailed explanation goes here
    
    properties
        CounterSelection
        radioCount1         % #1
        radioCount2         % #2
        radioCountBoth      % #3
        radioCountSum       % #4
        radioAlt            % #5
        
        TypeSelection
        radioCounter        % #1
        radioLifetime       % #2
        radioG2             % #3
        
        cbxLifetime
        edtFrom
        edtTo
    end
    
    methods
        function obj = ViewSpcmControl(parent, controller)
            obj@GuiComponent(parent, controller);
            hboxMain = uix.HBox('Parent', parent, 'Spacing', 5, 'Padding', 0);
            obj.component = hboxMain;
            spcm = getObjByName(Spcm.NAME);
            
            obj.CounterSelection = uibuttongroup(...
                'Parent', hboxMain, ...
                'Title', 'SPCM Control', ...
                'SelectionChangedFcn',@obj.callbackCounterRadioSelection);
            
            rbHeight = 15; % "rb" stands for "radio button"
            rbWidth = 90;
            paddingFromLeft = 10;
            
            obj.radioCount1 = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.CounterSelection, ...
                'String', 'SPCM 1', ...
                'Position', [paddingFromLeft 60 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', SpcmTimeTaggerControlledNiDaqEnabled.COUNT_OPTIONS{1});
            obj.radioCount2 = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.CounterSelection, ...
                'String', 'SPCM 2', ...
                'Position', [paddingFromLeft 35 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', SpcmTimeTaggerControlledNiDaqEnabled.COUNT_OPTIONS{2});
            obj.radioCountBoth = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.CounterSelection, ...
                'String', 'SPCM 1 & 2', ...
                'Position', [paddingFromLeft 10 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', SpcmTimeTaggerControlledNiDaqEnabled.COUNT_OPTIONS{3});
            obj.radioCountSum = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.CounterSelection, ...
                'String', 'SPCM Sum', ...
                'Position', [paddingFromLeft+rbWidth-5 60 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', SpcmTimeTaggerControlledNiDaqEnabled.COUNT_OPTIONS{4});
            obj.radioAlt = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.CounterSelection, ...
                'String', 'PMT', ...
                'Position', [paddingFromLeft+rbWidth-5 35 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', SpcmTimeTaggerControlledNiDaqEnabled.COUNT_OPTIONS{5});
            
            obj.TypeSelection = uibuttongroup(...
                'Parent', hboxMain, ...
                'Title', 'Counter Type', ...
                'SelectionChangedFcn',@obj.callbackTypeRadioSelection);
            
            obj.radioCounter = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.TypeSelection, ...
                'String', 'Counter', ...
                'Position', [paddingFromLeft 60 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', SpcmCounter.TYPE_OPTIONS{1});
            obj.radioLifetime = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.TypeSelection, ...
                'String', 'Lifetime', ...
                'Position', [paddingFromLeft 35 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', SpcmCounter.TYPE_OPTIONS{2});
            obj.radioG2 = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.TypeSelection, ...
                'String', 'G2', ...
                'Position', [paddingFromLeft 10 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', SpcmCounter.TYPE_OPTIONS{3});
            
            bgStartEnd = uix.Panel(...
                'Parent', hboxMain, ...
                'Title', 'Timing Control');
            vboxStartEnd = uix.VBox('Parent', bgStartEnd, 'Spacing', 5, 'Padding', 0);
            obj.cbxLifetime = uicontrol(obj.PROP_CHECKBOX{:}, ...
                'Parent', vboxStartEnd, ...
                'String', 'Histogram', ...
                'Value', spcm.hasLifetimeCapability, ...
                'Enable', BooleanHelper.boolToOnOff(spcm.hasLifetimeCapability), ...
                'Callback', @obj.callbackLifetimeCheckbox);
            
            hboxStartEndStart = uix.HBox('Parent', vboxStartEnd, 'Spacing', 5, 'Padding', 0);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', hboxStartEndStart, 'String', 'Start');
            obj.edtFrom = uicontrol(obj.PROP_EDIT{:}, 'Parent', hboxStartEndStart, 'String', spcm.startRead, ...
                'Enable', BooleanHelper.boolToOnOff(spcm.hasLifetimeCapability), 'Callback', @obj.callbackStartEndSelection);
            
            hboxStartEndEnd = uix.HBox('Parent', vboxStartEnd, 'Spacing', 5, 'Padding', 0);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', hboxStartEndEnd, 'String', 'End');
            obj.edtTo = uicontrol(obj.PROP_EDIT{:}, 'Parent', hboxStartEndEnd, 'String', spcm.endRead, ...
                'Enable', BooleanHelper.boolToOnOff(spcm.hasLifetimeCapability), 'Callback', @obj.callbackStartEndSelection);
            
            hboxMain.Widths = [190 90 -1];
            obj.height = 100;
            obj.width = -1;
            
            obj.update()
        end
        
        function update(obj)
            % Executes when spcm updates
            spcm = getObjByName(Spcm.NAME);
            if spcm.hasG2()
                obj.radioCount2.Enable = 'on';
                obj.radioCountBoth.Enable = 'on';
                obj.radioCountSum.Enable = 'on';
                obj.radioG2.Enable = 'on';
            else
                obj.radioCount2 = 'off';
                obj.radioCountBoth = 'off';
                obj.radioCountSum = 'off';
                obj.radioG2.Enable = 'off';
            end
            if spcm.hasAltCount()
                obj.radioAlt.Enable = 'on';
            else
                obj.radioAlt.Enable = 'off';
            end
            if spcm.hasLifetime()
                obj.radioLifetime.Enable = 'on';
                obj.edtFrom.Enable = 'on';
                obj.edtTo.Enable = 'on';
            else
                obj.radioLifetime.Enable = 'off';
                obj.edtFrom.Enable = 'off';
                obj.edtTo.Enable = 'off';
            end
            
            obj.radioCount1.Value = 0;
            obj.radioCount2.Value = 0;
            obj.radioCountBoth.Value = 0;
            obj.radioCountSum.Value = 0;
            obj.radioAlt.Value = 0;
            switch spcm.currentCounter
                case 1
                    obj.radioCount1.Value = 1;
                    obj.CounterSelection.SelectedObject = obj.radioCount1;
                case 2
                    obj.radioCount2.Value = 1;
                    obj.CounterSelection.SelectedObject = obj.radioCount2;
                case 3
                    obj.radioCountBoth.Value = 1;
                    obj.CounterSelection.SelectedObject = obj.radioCountBoth;
                case 4
                    obj.radioCountSum.Value = 1;
                    obj.CounterSelection.SelectedObject = obj.radioCountSum;
                case 5
                    obj.radioAlt.Value = 1;
                    obj.CounterSelection.SelectedObject = obj.radioAlt;
            end
        end
        
        %%%% Callbacks %%%%
        function callbackCounterRadioSelection(obj, ~, event)
            spcm = getObjByName(Spcm.NAME);
            action = event.NewValue.Tag;
            actionIndex = find(strcmp(action, SpcmTimeTaggerControlledNiDaqEnabled.COUNT_OPTIONS));
            spcm.currentCounter = actionIndex;
            obj.update();
        end
        
        function callbackTypeRadioSelection(obj, ~, event)
            counter = getObjByName(SpcmCounter.NAME);
            action = event.NewValue.Tag;
            actionIndex = find(strcmp(action, SpcmCounter.TYPE_OPTIONS));
            counter.currentType = actionIndex;
            counter.sendEventDataUpdated();
            obj.update();
        end
        
        function callbackLifetimeCheckbox(obj, ~, ~)
            spcm = getObjByName(Spcm.NAME);
            spcm.bLifetime = obj.cbxLifetime.Value;
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