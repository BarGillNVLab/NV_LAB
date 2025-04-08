classdef ViewStagePanelLimits < GuiComponent & EventListener
    %VIEWSTAGESCANSCAN Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        edtLower            % 1x3 edit-text
        edtUpper            % 1x3 edit-text
        cbxAxis             % 1x3 checkbox
        cbxUpperLim         % checkbox
        cbxLowerLim         % checkbox
        btnSetToMax         % button
        btnSetToCurPos      % button
        btnSetToAround      % button
        edtSetAround        % edit-text
                
        stageName           % string
        stageAxes           % string. example: "xy"
    end
    
    properties (Constant)
        SET_AROUND_DEFAULT_STRING = '10';
        LIM_LOWER = 0;
        LIM_UPPER = 1;
    end
    
    methods
        function obj = ViewStagePanelLimits(parent, controller, stage)
            obj@GuiComponent(parent, controller);
            obj@EventListener(stage.name);
            obj.stageName = stage.name;
            obj.stageAxes = stage.availableAxes;
            
            axesLen = length(obj.stageAxes);
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            %%%% panel init %%%%
            panelLimits = uix.Panel('Parent', parent.component, 'Title', 'Stage Limits', 'Padding', 5);
            hboxMain = uix.HBox('Parent', panelLimits, 'Spacing', 6, 'Padding', 0);
            
            %%%% the left side grid %%%%
            gridLeftSide = uix.Grid('Parent', hboxMain, 'Spacing', 5);
            
            % 1st column: labels
            uix.Empty('Parent', gridLeftSide);
            for i = 1: axesLen
                uicontrol(obj.PROP_LABEL{:}, 'Parent', gridLeftSide, 'String', upper(obj.stageAxes(i)));
            end
            
            % 2nd column: lower lim
            uicontrol(obj.PROP_LABEL{:}, 'Parent', gridLeftSide, 'String', 'Lower');
            obj.edtLower = gobjects(1,axesLen);
            for i = 1: axesLen
                phAxis = ClassStage.getAxis(obj.stageAxes(i));
                [limNeg, ~] = stage.ReturnLimits(phAxis);
                obj.edtLower(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', gridLeftSide, 'String', limNeg);
            end
            
            % 3rd column: upper lim
            uicontrol(obj.PROP_LABEL{:}, 'Parent', gridLeftSide, 'String', 'Upper');
            obj.edtUpper = gobjects(1,axesLen);
            for i = 1: axesLen
                phAxis = ClassStage.getAxis(obj.stageAxes(i));
                [~, limPos] = stage.ReturnLimits(phAxis);
                obj.edtUpper(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', gridLeftSide, 'String', limPos);
            end
            
            gridWidths = [15 50 50];
            gridHeights = [25  25 * ones(1, axesLen)];
            set(gridLeftSide, 'Widths', gridWidths, 'Heights', gridHeights);
            gridAllWidth = sum(gridWidths) + 5*length(gridWidths);
            gridAllHeight = sum(gridHeights) + 5*length(gridHeights);
            
            %%%% seperation view %%%%
            uix.Empty('Parent', hboxMain);
            widthEmpty = 1;
            
            %%%% "set to" %%%%
            vboxSetTo = uix.VBox('Parent', hboxMain, 'Spacing', 5, 'Padding', 0);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', vboxSetTo, 'String', 'Set To');
            obj.btnSetToMax = uicontrol(obj.PROP_BUTTON{:}, 'Parent', vboxSetTo, 'String', 'Max');
            obj.btnSetToCurPos = uicontrol(obj.PROP_BUTTON{:}, 'Parent', vboxSetTo, 'String', 'Current Position');
            
            hboxSetToAround = uix.HBox('Parent', vboxSetTo, 'Spacing', 5, 'Padding', 0);
            obj.btnSetToAround = uicontrol(obj.PROP_BUTTON{:}, 'Parent', hboxSetToAround, 'String', 'Around');
            obj.edtSetAround = uicontrol(obj.PROP_EDIT{:}, 'Parent', hboxSetToAround, 'String', obj.SET_AROUND_DEFAULT_STRING);
            hboxSetToAround.Widths = [-4 -3];
            vboxSetTo.Heights = [25 25 25 25];
            vboxSetToHeight = sum(vboxSetTo.Heights) + length(vboxSetTo.Heights)*11;
            widthSetTo = 120;
            
            %%%% axis selection %%%%
            vboxAxisSelection = uix.VBox('Parent', hboxMain, 'Spacing', 5, 'Padding', 0);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', vboxAxisSelection, 'String', 'Axis');
            obj.cbxAxis = gobjects(1,axesLen);
            for i = 1: axesLen
                obj.cbxAxis(i) = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', vboxAxisSelection, 'String', obj.stageAxes(i));
            end
            vboxAxisSelection.Heights = [25, -1 * ones(1,axesLen)];
            widthAxisSelection  = 35;
            
            %%%% "choose limits" %%%%
            vboxChooseLimits = uix.VBox('Parent', hboxMain, 'Spacing', 5, 'Padding', 0);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', vboxChooseLimits, 'String', 'Choose Limits', 'FontSize', 6);
            obj.cbxUpperLim = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', vboxChooseLimits, 'String', 'Upper');
            obj.cbxLowerLim = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', vboxChooseLimits, 'String', 'Lower');
            vboxChooseLimits.Heights = [25 -1 -1];
            widthChooseLimits = 70;
            
            %%%% back to the main hbox %%%%
            hboxMain.Widths = [gridAllWidth widthEmpty widthSetTo widthAxisSelection widthChooseLimits];
            
            %%%% callbacks for lower+upper edit-text fields %%%%
            for i = 1 : axesLen
                obj.edtLower(i).Callback = @(h,e) obj.edtLowerLimitCallback(i);
                obj.edtUpper(i).Callback = @(h,e) obj.edtUpperLimitCallback(i);
            end
            
            %%%% callbacks for buttons %%%%
            obj.btnSetToAround.Callback = @(h,e) obj.btnSetToAroundCallback;
            obj.btnSetToCurPos.Callback = @(h,e) obj.btnSetToCurPosCallback;
            obj.btnSetToMax.Callback = @(h,e) obj.btnSetToMaxCallback;
            
            %%%% init internal values (to be used from the outside %%%%
            obj.height = max(vboxSetToHeight, gridAllHeight);
            obj.width = sum(hboxMain.Widths) + 8 * length(hboxMain.Widths);
            
            %%%% show the info %%%%
            obj.refresh();
        end
        
        function refresh(obj)
            % refresh the info shown in the GUI based on values from the
            % stage
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
                        
            for i = 1 : length(stage.availableAxes)
                phAxis = ClassStage.getAxis(stage.availableAxes(i));
                [limNeg, limPos] = stage.ReturnLimits(phAxis);

                obj.edtLower(i).String = StringHelper.formatNumber(limNeg);
                obj.edtUpper(i).String = StringHelper.formatNumber(limPos);
            end
        end
        
        function edtLowerLimitCallback(obj, index)
            % index - int. [1 to length(obj.stageAxes)] which view was changed
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            phAxis = ClassStage.getAxis(obj.stageAxes(index));
            [limNeg, limPos] = stage.ReturnLimits(phAxis);
            [negHardLimit, posHardLimit] = stage.ReturnHardLimits(phAxis);
            try
                if ~ValidationHelper.isStringValueANumber(obj.edtLower(index).String)
                    error('Lower Limit should be a number! Reverting.')
                end
                
                lowerLimEdt = str2double(obj.edtLower(index).String);
                if~ValidationHelper.isInBorders(lowerLimEdt, negHardLimit, posHardLimit)
                    error('Lower Limit is not in hard limits! Reverting.\nhard limits: [%d, %d]', negHardLimit, posHardLimit);
                end
                
                if lowerLimEdt > limPos
                    error('Lower Limit can''t be bigger than upper limit! Reverting.\upper limit: %d, wanted lower limit: %d', limPos, lowerLimEdt);
                end
            catch err
                obj.edtLower(index).String = StringHelper.formatNumber(limNeg);
                EventStation.anonymousError(err.message);
            end
            
            stage.setLim(lowerLimEdt, phAxis, obj.LIM_LOWER);
            % if succeeded, an event will call us again
        end
        
        function edtUpperLimitCallback(obj, index)
            % index - int. [1 to length(obj.stageAxes)] which view was changed
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            phAxis = ClassStage.getAxis(obj.stageAxes(index));
            [limNeg, limPos] = stage.ReturnLimits(phAxis);
            [negHardLimit, posHardLimit] = stage.ReturnHardLimits(phAxis);
            try
                if ~ValidationHelper.isStringValueANumber(obj.edtUpper(index).String)
                    error('Upper Limit should be a number! Reverting.')
                end
                
                upperLimEdt = str2double(obj.edtUpper(index).String);
                if~ValidationHelper.isInBorders(upperLimEdt, negHardLimit, posHardLimit)
                    error('Upper Limit is not in hard limits! Reverting.\nhard limits: [%d, %d]', negHardLimit, posHardLimit);
                end
                
                if upperLimEdt < limNeg
                    error('Upper Limit can''t be lower than Lower limit! Reverting.\lower limit: %d, wanted upper limit: %d', limNeg, upperLimEdt);
                end

            catch err
                obj.edtUpper(index).String = StringHelper.formatNumber(limPos);
                EventStation.anonymousError(err.message);
            end
            
            stage.setLim(upperLimEdt, phAxis, obj.LIM_UPPER);
            % if succeeded, an event will call us again
        end
        
        function btnSetToAroundCallback(obj)
            % sets the stage limits to be around the value in the edit-text field
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            around = obj.edtSetAround.String;
            if ~ValidationHelper.isStringValueANumber(around)
                obj.edtSetAround.String = obj.SET_AROUND_DEFAULT_STRING;
                EventStation.anonymousError('"around" should be a number! Reverting...');
            end
            around = str2double(around);
            
            for i = 1 : length(obj.stageAxes)
                phAxis = ClassStage.getAxis(obj.stageAxes(i));
                curPosition = stage.Pos(phAxis);
                if obj.cbxAxis(i).Value
                    if obj.cbxLowerLim.Value % set the lower lim
                        zeroForLower = 0;
                        stage.setLim(curPosition - around, phAxis, zeroForLower);
                    end
                    if obj.cbxUpperLim.Value % set the upper lim
                        oneForUpper = 1;
                        stage.setLim(curPosition + around, phAxis, oneForUpper);
                    end
                end
            end
        end
        
        function btnSetToCurPosCallback(obj)
            % sets the stage limits to the current stage position
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            for i = 1 : length(obj.stageAxes)
                phAxis = ClassStage.getAxis(obj.stageAxes(i));
                curPos = stage.Pos(phAxis);
                if obj.cbxAxis(i).Value
                    if obj.cbxLowerLim.Value % set the lower lim
                        stage.setLim(curPos, phAxis, obj.LIM_LOWER);
                    end
                    if obj.cbxUpperLim.Value % set the upper lim
                        stage.setLim(curPos, phAxis, obj.LIM_UPPER);
                    end
                end
            end
        end
        
        function btnSetToMaxCallback(obj)
            % sets the stage limits to their maximum avaliability
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            for i = 1 : length(obj.stageAxes)
                phAxis = ClassStage.getAxis(obj.stageAxes(i));
                [limHardNeg, limHardPos] = stage.ReturnHardLimits(phAxis);
                if obj.cbxAxis(i).Value
                    if obj.cbxLowerLim.Value % set the lower lim
                        stage.setLim(limHardNeg, phAxis, obj.LIM_LOWER);
                    end
                    if obj.cbxUpperLim.Value % set the upper lim
                        stage.setLim(limHardPos, phAxis, obj.LIM_UPPER);
                    end
                end
            end
        end
    end
    
    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if event.isError || isfield(event.extraInfo, ClassStage.EVENT_LIM_CHANGED)
                obj.refresh();
            end
        end
    end
end

