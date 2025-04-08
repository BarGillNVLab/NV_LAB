classdef ViewBsphereControl < GuiComponent & EventListener

    properties (Constant)
        AXES = {'Brho', 'Btheta', 'Bphi'};
        AXES_STR = {'B_{\theta}', 'B_{\rho}', 'B_{\phi}'};
    end
    
    properties
        btnMoveLeft         % 1x3 button
        btnMoveRight        % 1x3 button
        
        btnMoveToBlue       % button
        isBlueMovingAvailable   % logical
        
        edtSteps            % edit-text 
        
        
        tvCurB            % 1x3 text-view for current fiekd
        edtCurB           % 1x3 edit-input for current field input
        hboxCurB          % 1x3 vbox that holds those ^ 2 views
        lowerLimLbl       % 1x3 changed lable
        upperLimLbl       % 1x3 changed lable
        
        edtCurBValue      % 1x3 double that holds the values in edtCurB. 
                            % when an edt is visible, this always holds the
                            % numeric value shown. if it's invisible, this
                            % always stores Infinity
        
%         axes                % string. example: "xy"    end
        helm
    end
    
    methods
        function obj = ViewBsphereControl(parent, controller)
            expNames = Experiment.getExperimentNames();
            namesToListenTo = {expNames{:}, Helmholtz.NAME}; %#ok<CCAT>
            
            obj@GuiComponent(parent, controller);
            obj@EventListener(namesToListenTo);
            obj.helm = getObjByName('Helmholtz');
            
            %%%% panel init %%%%
            panelMain = uix.Panel('Parent', parent.component, 'Title', 'Magnetic Field Control - Spherical (Gauss & Degrees)', 'Padding', 5);
            hboxMain = uix.HBox('Parent', panelMain, 'Spacing', 25, 'Padding', 0);
            vboxLeft = uix.VBox('Parent',hboxMain, 'Spacing', 6); % will contain the grid and "step"

            %%%% step %%%%
            hboxStep = uix.HBox('Parent', vboxLeft, 'Spacing', 5);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', hboxStep, 'String', 'Step:');
            obj.edtSteps = uicontrol(obj.PROP_EDIT{:}, 'Parent', hboxStep);
            hboxStep.Widths = [-1 -1];
            stepHeightNoSpacing = 25;
            
            %%%% the left side grid %%%%
            gridLeftSide = uix.Grid('Parent', vboxLeft, 'Spacing', 5);
            
            % 1st column: axes labels
            for i = 1: 3
                uicontrol(obj.PROP_LABEL{:}, 'Parent', gridLeftSide, 'String', obj.AXES{i});
            end
            
            % 2nd column: lower limits
            obj.lowerLimLbl = gobjects(1, 3);
            lowerLim = obj.helm.BsphereLowerLimits;
            for i = 1:3
                obj.lowerLimLbl(i) = uicontrol(obj.PROP_CHANGED_LABEL{:}, 'Parent', gridLeftSide, 'String', lowerLim(i));
            end
            
            % 3rd column: arrow left
            obj.btnMoveLeft = gobjects(1, 3);
            for i = 1:3
                obj.btnMoveLeft(i) = uicontrol(obj.PROP_BUTTON{:}, ...
                    'Parent', gridLeftSide, ...
                    'String', StringHelper.LEFT_ARROW, ...
                    'FontSize', 20);
            end
            
            % 4th column: current position
            obj.tvCurB = gobjects(1, 3);
            obj.edtCurB = gobjects(1, 3);
            obj.hboxCurB = gobjects(1, 3);
            obj.edtCurBValue = inf * ones(1, 3);
            % ^ We want a local copy of this value 
            for i = 1:3
                obj.hboxCurB(i) = uix.HBox('Parent', gridLeftSide, 'Padding', 0, 'Spacing', 0);
                obj.tvCurB(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', obj.hboxCurB(i));
                obj.edtCurB(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', obj.hboxCurB(i), ...
                    'ForegroundColor', 'blue', 'BackgroundColor', [0.8 0.9 1]);     % Blue over light blue
                obj.showEdtCurB(i, false);   % hide the edit-input until it's needed - when user inputs data
            end
            
            % 5th column: arrow right
            obj.btnMoveRight = gobjects(1, 3);
            for i = 1: 3
                obj.btnMoveRight(i) = uicontrol(obj.PROP_BUTTON{:}, ...
                    'Parent', gridLeftSide, ...
                    'String', StringHelper.RIGHT_ARROW, ...
                    'FontSize', 20);
            end
            
            % 6th column: upper limits
            obj.upperLimLbl = gobjects(1, 3);
            upperLim = obj.helm.BsphereUpperLimits;
            for i = 1:3
                obj.upperLimLbl(i) = uicontrol(obj.PROP_CHANGED_LABEL{:}, 'Parent', gridLeftSide, 'String', upperLim(i));
            end
            
            % grid properties
            gridWidths = [50 60 35 70 35 60];
            gridWithdsRel = -1*gridWidths;
            heightGridTotalNoSpacing = 90;
            lineHeight = heightGridTotalNoSpacing / 3;
            gridHeights = lineHeight * ones(1, 3);
            set(gridLeftSide, 'Widths', gridWithdsRel, 'Heights', gridHeights);
            gridLeftHeightTotal = heightGridTotalNoSpacing + 5 * 3;
            gridLeftWidthTotal = sum(gridWidths) + 4 * length(gridWidths);

            %%%% vbox left - all inner components are ready %%%%
            vboxLeft.Heights = [stepHeightNoSpacing, heightGridTotalNoSpacing+10];
            vboxLeftHeightTotal = gridLeftHeightTotal + stepHeightNoSpacing + 42;
            
            %%%% 'move to' button %%%%
            vboxRight = uix.VBox('Parent',hboxMain, 'Spacing', 6);
            obj.btnMoveToBlue = uicontrol(obj.PROP_BUTTON{:}, ...
                'Parent', vboxRight, ...
                'String', 'Change To Blue', ...
                'Enable', 'off', ...       % the starting state - off
                'TooltipString', 'Move stage to the position appearing in blue');
            heights = [-2];
            vboxRight.Heights = heights;
            rightSideTotalWidth = 120;
            
            %%%% Set mainHbox widths %%%%
            widthsMain = [gridLeftWidthTotal, rightSideTotalWidth];
            widthsRelative = widthsMain * -1 ;
            hboxMain.Widths = widthsRelative;
            
            
            %%%% Callbacks %%%%
            obj.edtSteps.Callback = @(h,e) obj.edtStepSizeCallback();
            obj.btnMoveToBlue.Callback = @(h,e) obj.btnMoveToBlueCallback();
            obj.isBlueMovingAvailable = false; % By default
            
            for i = 1:3
                obj.tvCurB(i).Callback = @(h,e) obj.tvCurBCallback(i);
                obj.edtCurB(i).Callback = @(h,e) obj.checkEdtCurBValue(i);
                
                isLeft = true;
                obj.btnMoveLeft(i).Callback = @(h,e) obj.btnMoveCallback(i, isLeft);
                obj.btnMoveRight(i).Callback = @(h,e) obj.btnMoveCallback(i, ~isLeft);
                
                obj.lowerLimLbl(i).Callback = @(h,e) obj.limEdtCallback();
                obj.upperLimLbl(i).Callback = @(h,e) obj.limEdtCallback();
            end
            
            
            %%%% Internal values %%%%
            obj.width = sum(widthsMain) + (hboxMain.Spacing -3) * length(widthsMain);
            obj.height = vboxLeftHeightTotal;
            
            obj.refresh();
        end
        
        function refresh(obj)
            obj.edtSteps.String = StringHelper.formatNumber(obj.helm.stepSize);;
            currentB = obj.helm.Bsphere;   
            lowerLim = obj.helm.BsphereLowerLimits;
            upperLim = obj.helm.BsphereUpperLimits;
            for i = 1:3
                obj.tvCurB(i).String = StringHelper.formatNumber(currentB(i));
                obj.lowerLimLbl(i).String = lowerLim(i);
                obj.upperLimLbl(i).String = upperLim(i);
            end
            obj.btnMoveToBlue.Enable = 'on';
            drawnow % If we are in mid-operation
        end
        
        function edtStepSizeCallback(obj)
            stepSizeString = obj.edtSteps.String;
            try
                if ~ValidationHelper.isStringValueANumber(stepSizeString)
                    error('Step size must be a valid number! Reverting.');
                end
            catch err
                obj.edtSteps.String = StringHelper.formatNumber(obj.helm.stepSize);
                EventStation.anonymousError(err.message);
            end
            obj.helm.stepSize = str2double(stepSizeString);
        end
        
        function btnMoveCallback(obj, index, trueForLeftFalseForRight)
            step = BooleanHelper.ifTrueElse(trueForLeftFalseForRight,-1,1)*obj.helm.stepSize;
            obj.helm.relativeBsphereStep(index, step);
        end
        
        function btnMoveToBlueCallback(obj)
            isBeingGrayed = true;
            for i = 1:3
                obj.btnMoveLeft(i).Enable = 'off';
                obj.recolor(obj.tvCurB(i),isBeingGrayed)
                obj.btnMoveRight(i).Enable = 'off';
            end
            for i = 1:3
                pos = obj.edtCurBValue(i); 
                if pos ~= inf
                    obj.helm.set(obj.AXES{i}, pos);
                    obj.clearEdtCurB(i);
                end 
            end
            isBeingGrayed = false;
            for i = 1:3
                obj.btnMoveLeft(i).Enable = 'on';
                obj.recolor(obj.tvCurB(i),isBeingGrayed)
                obj.btnMoveRight(i).Enable = 'on';
            end
            % We are now finished moving. Waiting for new Input.
            obj.isBlueMovingAvailable = false;
            obj.btnMoveToBlue.Enable = 'off';
        end
        
        function tvCurBCallback(obj, index)
            lowerLim = obj.helm.BsphereLowerLimits;
            upperLim = obj.helm.BsphereUpperLimits;
            limNeg = lowerLim(index);
            limPos = upperLim(index);
            if ValidationHelper.isStringValueInBorders(obj.tvCurB(index).String, limNeg, limPos)
                obj.edtCurB(index).String = obj.tvCurB(index).String;
                obj.showEdtCurB(index, true);
                obj.checkEdtCurBValue(index);
                obj.isBlueMovingAvailable = true;
                obj.refresh
            else
                EventStation.anonymousWarning('Position must be a number, and within limits! Current limits: [%d, %d]', limNeg, limPos)
            end
            obj.tvCurB(index).String = obj.helm.Bsphere(index);
        end
        
        function limEdtCallback(obj)
            error('Unable to change the field limits. Defined by the current limits in the json file')
        end
        
        function showEdtCurB(obj, index, shouldShow)
            % Sets the view of the obj.edtCurPos edit-input
            % shouldShow - boolean (logical) - the new state
            % index - the index axis
            if shouldShow
                obj.hboxCurB(index).Widths = [-1 -1];
            else
                obj.hboxCurB(index).Widths = [-1 0];
            end
        end
        
        function checkEdtCurBValue(obj, index)
            % Checks that string in obj.edtCurB has a valid value.
            % Reverts the value if not valid based on obj.edtCurBValue
            % or updates obj.edtCurBValue based on the edt
            lowerLim = obj.helm.BsphereLowerLimits;
            upperLim = obj.helm.BsphereUpperLimits;
            limNeg = lowerLim(index);
            limPos = upperLim(index);
            if ValidationHelper.isStringValueInBorders(obj.edtCurB(index).String, limNeg, limPos)
                obj.edtCurBValue(index) = str2double(obj.edtCurB(index).String);
            elseif isempty(obj.edtCurB(index).String)
                % Delete it
                obj.clearEdtCurB(index);
                % Make sure to update the button as well:
                if all(obj.edtCurBValue == inf)
                    obj.isBlueMovingAvailable = false;
                    obj.btnMoveToBlue.Enable = 'off';
                end
                return
            else
                EventStation.anonymousWarning('Value must be a number between %d and %d! Reverting.', limNeg, limPos)
            end
            obj.edtCurB(index).String = StringHelper.formatNumber(obj.edtCurBValue(index));
        end
        
        function clearEdtCurB(obj, index)
            % Clears the GUI from the edit-input, also clears the
            % value stored as a numeric value
            obj.edtCurB(index).String = '';
            obj.edtCurBValue(index) = inf;
            obj.showEdtCurB(index, false);
            set(gcf, 'CurrentObject', gcf);
            % ^ removes the focus from the edt and sets the focus to the
            % current figure itself
        end
        
    end

    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if event.isError ...
                    || isfield(event.extraInfo, Helmholtz.EVENT_STEP_SIZE_CHANGED) ...
                    || isfield(event.extraInfo, Helmholtz.EVENT_MAGNETIC_FIELD_CHANGED)
                obj.refresh();
            end
        end
    end
    
    
end