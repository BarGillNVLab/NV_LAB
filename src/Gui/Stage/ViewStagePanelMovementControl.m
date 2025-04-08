classdef ViewStagePanelMovementControl < GuiComponent & EventListener
    %VIEWSTAGESCANSCAN Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        btnMoveLeft         % 1x3 button
        btnMoveRight        % 1x3 button
        btnMoveStageToFixedPos  % button
        
        btnSendToFixed      % button
        btnMoveToBlue       % button
        isBlueMovingAvailable   % logical
        
        edtSteps            % edit-text 
        btnHaltStage        % button
        cbxJoystick         % checkbox

        tvCurPos            % 1x3 text-view for current position
        edtCurPos           % 1x3 edit-input for current position input
        hboxCurPos          % 1x3 vbox that holds those ^ 2 views
        
        edtCurPosValue      % 1x3 double that holds the values in edtCurPos. 
                            % when an edt is visible, this always holds the
                            % numeric value shown. if it's invisible, this
                            % always stores Infinity
        
        stageName           % string
        stageAxes           % string. example: "xy"    end
    end
    
    methods
        function obj = ViewStagePanelMovementControl(parent, controller, stage)
            expNames = Experiment.getExperimentNames();
            namesToListenTo = {stage.name, expNames{:}, StageScanner.NAME}; %#ok<CCAT>
            
            obj@GuiComponent(parent, controller);
            obj@EventListener(namesToListenTo);
            obj.stageName = stage.name;
            obj.stageAxes = stage.availableAxes;
            axesLen = length(obj.stageAxes);
            
            %%%% panel init %%%%
            panelMain = uix.Panel('Parent', parent.component, 'Title', 'Movement Control', 'Padding', 5);
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
            
            % 1st column: xyz labels
            for i = 1: axesLen
                uicontrol(obj.PROP_LABEL{:}, 'Parent', gridLeftSide, 'String', upper(obj.stageAxes(i)));
            end
            
            % 2nd column: arrow left
            obj.btnMoveLeft = gobjects(1, axesLen);
            for i = 1: axesLen
                obj.btnMoveLeft(i) = uicontrol(obj.PROP_BUTTON{:}, ...
                    'Parent', gridLeftSide, ...
                    'String', StringHelper.LEFT_ARROW, ...
                    'FontSize', 20);
            end
            
            % 3rd column: current position
            obj.tvCurPos = gobjects(1, axesLen);
            obj.edtCurPos = gobjects(1, axesLen);
            obj.hboxCurPos = gobjects(1, axesLen);
            obj.edtCurPosValue = inf * ones(1, axesLen);
            canScan = stage.isScannable;
            % ^ We want a local copy of this value 
            for i = 1: axesLen
                obj.hboxCurPos(i) = uix.HBox('Parent', gridLeftSide, 'Padding', 0, 'Spacing', 0);
                obj.tvCurPos(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', obj.hboxCurPos(i));
                obj.edtCurPos(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', obj.hboxCurPos(i), ...
                    'ForegroundColor', 'blue', 'BackgroundColor', [0.8 0.9 1]);     % Blue over light blue
                obj.showEdtCurPos(i, false);   % hide the edit-input until it's needed - when user inputs data
            end
            
            % 4th column: arrow right
            obj.btnMoveRight = gobjects(1, axesLen);
            for i = 1: axesLen
                obj.btnMoveRight(i) = uicontrol(obj.PROP_BUTTON{:}, ...
                    'Parent', gridLeftSide, ...
                    'String', StringHelper.RIGHT_ARROW, ...
                    'FontSize', 20);
            end
            gridWidths = [20 35 70 35];
            gridWithdsRel = -1*gridWidths;
            heightGridTotalNoSpacing = 90;
            lineHeight = heightGridTotalNoSpacing / axesLen;
            gridHeights = lineHeight * ones(1, axesLen);
            set(gridLeftSide, 'Widths', gridWithdsRel, 'Heights', gridHeights);
            gridLeftHeightTotal = heightGridTotalNoSpacing + 5 * axesLen;
            gridLeftWidthTotal = sum(gridWidths) + 4 * length(gridWidths);
            
            %%%% vbox left - all inner components are ready %%%%
            vboxLeft.Heights = [stepHeightNoSpacing heightGridTotalNoSpacing+10];
            vboxLeftHeightTotal = gridLeftHeightTotal + stepHeightNoSpacing + 42;
            
            
            %%%% buttons (fix, query, halt) & joystick %%%%
            vboxRight = uix.VBox('Parent',hboxMain, 'Spacing', 6);
            obj.btnMoveToBlue = uicontrol(obj.PROP_BUTTON{:}, ...
                'Parent', vboxRight, ...
                'String', 'Move To Blue', ...
                'Enable', 'off', ...       % the starting state - off
                'TooltipString', 'Move stage to the position appearing in blue');
            if canScan        % Stage is scannable
                obj.btnSendToFixed = uicontrol(obj.PROP_BUTTON{:}, ...
                    'Parent', vboxRight, ...
                    'String', sprintf('Current %s Fixed', StringHelper.RIGHT_ARROW), ...
                    'TooltipString', 'Set fixed position to actual stage position');
                heights = [-5 -5 -5];
            else
                heights = [-2 -2];
            end
            obj.btnHaltStage = uicontrol(obj.PROP_BUTTON_BIG_RED{:}, ...
                'Parent', vboxRight, ...
                'String', 'Halt Stages');
            if stage.hasJoystick
                obj.cbxJoystick = uicontrol(obj.PROP_CHECKBOX{:}, ...
                    'Parent', vboxRight, ...
                    'String', 'Joystick');
                joystickHeight = 15;
                heights = [heights joystickHeight];
            end
            vboxRight.Heights = heights;
            rightSideTotalWidth = 120;
            
            %%%% Set mainHbox widths %%%%
            widthsMain = [gridLeftWidthTotal, rightSideTotalWidth];
            widthsRelative = widthsMain * -1 ;
            hboxMain.Widths = widthsRelative;
            
            %%%% Callbacks %%%%
            obj.edtSteps.Callback = @(h,e) obj.edtStepSizeCallback();
            obj.btnMoveStageToFixedPos.Callback = @(h,e) obj.btnMoveStageToFixedPosCallback();
            obj.btnHaltStage.Callback = @(h,e) StageControlEvents.sendHalt;
            obj.cbxJoystick.Callback = @(h,e) obj.cbxJoystickCallback;
            
            obj.btnMoveToBlue.Callback = @(h,e) obj.btnMoveToBlueCallback();
            obj.isBlueMovingAvailable = false; % By default
            if canScan
                obj.btnSendToFixed.Callback = @(h,e) obj.btnSendToFixedNonScanableCallback();
            end
            
            for i = 1:axesLen
                obj.tvCurPos(i).Callback = @(h,e) obj.tvCurPosCallback(i);
                obj.edtCurPos(i).Callback = @(h,e) obj.checkEdtCurPosValue(i);
                
                isLeft = true;
                obj.btnMoveLeft(i).Callback = @(h,e) obj.btnMoveCallback(i, isLeft);
                obj.btnMoveRight(i).Callback = @(h,e) obj.btnMoveCallback(i, ~isLeft);
            end
            
            
            %%%% Internal values %%%%
            obj.width = sum(widthsMain) + (hboxMain.Spacing -3) * length(widthsMain);
            obj.height = vboxLeftHeightTotal;
            
            obj.refresh();
        end
        
        function refresh(obj)
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            obj.edtSteps.String = StringHelper.formatNumber(stage.stepSize);
            currentPosition = stage.Pos(obj.stageAxes);
            for i = 1: length(obj.stageAxes)
                obj.tvCurPos(i).String = StringHelper.formatNumber(currentPosition(i));
            end
            
            obj.checkMovementEnabled;
            
            drawnow % If we are in mid-operation
        end
        
        function edtStepSizeCallback(obj)
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            stepSizeString = obj.edtSteps.String;
            try
                if ~ValidationHelper.isStringValueANumber(stepSizeString)
                    error('Step size must be a valid number! Reverting.');
                end
                if ~ValidationHelper.isStringValueInBorders(stepSizeString, stage.STEP_MINIMUM_SIZE, inf)
                    error('step size must be >= minimum step-size! reverting.\nminimum step-size: %d, wanted step size: %s', stage.STEP_MINIMUM_SIZE, stepSizeString);
                end
            catch err
                obj.edtSteps.String = StringHelper.formatNumber(stage.stepSize);
                EventStation.anonymousError(err.message);
            end
            
            stage.stepSize = str2double(stepSizeString);
        end
        
        function btnMoveCallback(obj,index,trueForLeftFalseForRight)
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            phAxis = ClassStage.getAxis(obj.stageAxes(index));
            step = BooleanHelper.ifTrueElse(trueForLeftFalseForRight,-1,1)*stage.stepSize;
            stage.relativeMove(phAxis, step);
        end
        
        function btnMoveStageToFixedPosCallback(obj)
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            stage.moveByScanParams();
        end
        
        function btnSendToFixedNonScanableCallback(obj)
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            stage.sendPosToScanParams();
            obj.refresh;
        end
        
        function btnMoveToBlueCallback(obj)
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            isBeingGrayed = true;
            for i = 1 : length(obj.stageAxes)
                obj.btnMoveLeft(i).Enable = 'off';
                obj.recolor(obj.tvCurPos(i),isBeingGrayed)
                obj.btnMoveRight(i).Enable = 'off';
            end
            
            for i = 1 : length(obj.stageAxes)
                phAxis = ClassStage.getAxis(obj.stageAxes(i));
                pos = obj.edtCurPosValue(i); 
                if pos ~= inf
                    stage.move(phAxis, pos);
                    obj.clearEdtCurPos(i);
                end 
            end
            
            isBeingGrayed = false;
            for i = 1 : length(obj.stageAxes)
                obj.btnMoveLeft(i).Enable = 'on';
                obj.recolor(obj.tvCurPos(i),isBeingGrayed)
                obj.btnMoveRight(i).Enable = 'on';
            end
            
            % We are now finished moving. Waiting for new Input.
            obj.isBlueMovingAvailable = false;
            obj.btnMoveToBlue.Enable = 'off';
        end
        
        function tvCurPosCallback(obj, index)
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            phAxis = ClassStage.getAxis(obj.stageAxes(index));
            [limNeg, limPos] = stage.ReturnLimits(phAxis);
            if ValidationHelper.isStringValueInBorders(obj.tvCurPos(index).String, limNeg, limPos)
                obj.edtCurPos(index).String = obj.tvCurPos(index).String;
                obj.showEdtCurPos(index, true);
                obj.checkEdtCurPosValue(index);
                obj.isBlueMovingAvailable = true;
                obj.refresh
            else
                EventStation.anonymousWarning('Position must be a number, and within limits! Current limits: [%d, %d]', limNeg, limPos)
            end
            
            stage = getObjByName(obj.stageName);
            phAxis = ClassStage.getAxis(obj.stageAxes(index));
            pos = stage.Pos(phAxis);
            obj.tvCurPos(index).String = pos;
        end
        
        function cbxJoystickCallback(obj)
            % Enables or disable the joystick according to the GUI settings.
            % While the joystick is on, updates the location every ~300ms.
            stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
            jstick = getObjByName(Joystick.NAME);
                if isempty(jstick); throwBaseObjException(Joystick.NAME); end
            stageScanner = getObjByName(StageScanner.NAME);
            
            isEnabled = obj.cbxJoystick.Value;
            % Don't let other things interrupt
            if strcmp(stageScanner.mStageName, obj.stageName) ...
                    && stageScanner.mCurrentlyScanning
                stageScanner.stopScan;
            end
            jstick.isEnabled = isEnabled;
            
            obj.checkMovementEnabled;
            % Once we have this ^ we can safely turn on joystick control
            stage.JoystickControl(isEnabled);
            

            stage.sendEventPositionChanged;
            while jstick.isEnabled
                jstick.buttonAction;
                stage.sendEventPositionChanged;
                drawnow();
            end
            
            % ^ what a mish mash. todo: sort it out.
        end
        
        function showEdtCurPos(obj, index, shouldShow)
            % Sets the view of the obj.edtCurPos edit-input
            % shouldShow - boolean (logical) - the new state
            % index - the index axis
            if shouldShow
                obj.hboxCurPos(index).Widths = [-1 -1];
%                 uicontrol(obj.edtCurPos(index)); % also request focus
            else
                obj.hboxCurPos(index).Widths = [-1 0];
            end
        end
        
        function checkEdtCurPosValue(obj, index)
            % Checks that string in obj.edtCurPos has a valid value.
            % Reverts the value if not valid based on obj.edtCurPosValue
            % or updates obj.edtCurPosValue based on the edt
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
                
            phAxis = ClassStage.getAxis(obj.stageAxes(index));
            [limNeg, limPos] = stage.ReturnLimits(phAxis);
            if ValidationHelper.isStringValueInBorders(obj.edtCurPos(index).String, limNeg, limPos)
                obj.edtCurPosValue(index) = str2double(obj.edtCurPos(index).String);
            elseif isempty(obj.edtCurPos(index).String)
                % Delete it
                obj.clearEdtCurPos(index);
                % Make sure to update the button as well:
                if all(obj.edtCurPosValue == inf)
                    obj.isBlueMovingAvailable = false;
                    obj.btnMoveToBlue.Enable = 'off';
                end
                return
            else
                EventStation.anonymousWarning('Value must be a number between %d and %d! Reverting.', limNeg, limPos)
            end
            obj.edtCurPos(index).String = StringHelper.formatNumber(obj.edtCurPosValue(index));
        end
        
        function clearEdtCurPos(obj, index)
            % Clears the GUI from the edit-input, also clears the
            % value stored as a numeric value
            obj.edtCurPos(index).String = '';
            obj.edtCurPosValue(index) = inf;
            obj.showEdtCurPos(index, false);
            set(gcf, 'CurrentObject', gcf);
            % ^ removes the focus from the edt and sets the focus to the
            % current figure itself
        end
        
        function checkMovementEnabled(obj)
            % Enables or disables (Greys out) the movement control buttons.
            % Control can be either 'On' or 'Off'
            
            isEnabled = true; % will be false if ANY of the checks gives false, and true otherwise

            % We want to enable movement only if
            %  * we're in closed loop
            stage = getObjByName(obj.stageName);
            isStageExist = ~isempty(stage);
            isLoopClosed = strcmp(stage.loopMode, 'Closed');
            isEnabled = isEnabled && isStageExist && isLoopClosed;
            %  * stage scanner is not running
            scanner = getObjByName(StageScanner.NAME);
            isEnabled = isEnabled && ~scanner.mCurrentlyScanning;
            %  * joystick is off
            if stage.hasJoystick
                jstick = getObjByName(Joystick.NAME);
                if ~isempty(jstick)
                    isEnabled = isEnabled && ~jstick.isEnabled;
                else
                    % This is not the main event, but it's not bad to tell
                    % the user that there is an upcoming problem
                    EventStation.anonymousWarning('Joystick was supposed to be found, but wasn''t!')
                end
            end
            %  * current Experiment is not running
            exp = getObjByName(Experiment.current);
            if ~isempty(exp) && ~isa(exp, 'SpcmCounter') 
                isEnabled = isEnabled && ~exp.isRunning;
            end
            
            
            % Now we use it to set enabled as on/off
            onOffString = BooleanHelper.boolToOnOff(isEnabled);
            ax = ClassStage.getAxis(obj.stageAxes);
            for i = 1:length(ax)
                obj.btnMoveLeft(i).Enable = onOffString;
                obj.btnMoveRight(i).Enable = onOffString;
            end
            
            isMoveAvailable = obj.isBlueMovingAvailable && isEnabled;
            obj.btnMoveToBlue.Enable = BooleanHelper.boolToOnOff(isMoveAvailable);
        end
            
    end
    
    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if event.isError ...
                    || isfield(event.extraInfo, ClassStage.EVENT_STEP_SIZE_CHANGED) ...
                    || isfield(event.extraInfo, ClassStage.EVENT_POSITION_CHANGED)
                obj.refresh();
            elseif isfield(event.extraInfo, ClassStage.EVENT_STAGE_AVAILABLITY_CHANGED) ...
                    || isfield(event.extraInfo, StageScanner.EVENT_SCAN_STARTED) ...
                    || isfield(event.extraInfo, StageScanner.EVENT_SCAN_FINISHED) ...
                    || isfield(event.extraInfo, Experiment.EVENT_EXP_PAUSED) ...
                    || isfield(event.extraInfo, Experiment.EVENT_EXP_RESUMED)
                obj.checkMovementEnabled;
            end
        end
    end
    
end

