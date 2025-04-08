classdef ViewStagePanelTiltCorrection < GuiComponent & EventListener
    %VIEWPANELTILTCORRECTION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        cbxEnable           % checkbox in the "tilt correction" section
        btnTiltCalculator   % the "calcaultor" button
        edtThetaX           % input text
        edtThetaY           % input text
        
        stageName           % string
        tiltPoint1 = nan;   % point for the calculator
        tiltPoint2 = nan;   % point for the calculator
        tiltPoint3 = nan;   % point for the calculator
    end
        
    methods
        function obj = ViewStagePanelTiltCorrection(parent, controller, stage)
            obj@GuiComponent(parent, controller);
            obj@EventListener(stage.name);
            obj.stageName = stage.name;
            if ~stage.tiltAvailable
                EventStation.anonymousError('This should not have happenned');
            end
            
            
            %%%% panel init %%%%
            panelMain = uix.Panel('Parent', parent.component, 'Title', 'Tilt Correction', 'Padding', 5);
            %%%% tilt correction %%%%
            
            gridTilt = uix.Grid('Parent', panelMain, 'Spacing', 5);
            obj.cbxEnable = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', gridTilt, 'String', 'Enable'); % Tilt Correction
            
            hboxThetaX = uix.HBox('Parent', gridTilt, 'Spacing', 0, 'Padding', 0);
            labelStr = '<html><body style="background-color:black;"><font color="white" size=4>&nbsp;&theta<sub>XZ</sub>&nbsp;</body></html>';
            jLabel = javaObjectEDT('javax.swing.JLabel',labelStr);
            javacomponent(jLabel,[100,100,20,20],hboxThetaX);
            % uicontrol(obj.PROP_LABEL{:}, 'Parent', hboxThetaX, 'String', 'ThetaX');  % label
            obj.edtThetaX = uicontrol(obj.PROP_EDIT{:}, 'Parent', hboxThetaX);
            hboxThetaX.Widths = [32 -1];
            
            obj.btnTiltCalculator = uicontrol(obj.PROP_BUTTON{:}, 'Parent', gridTilt, 'String', 'Calculator');
            
            hboxThetaY = uix.HBox('Parent', gridTilt, 'Spacing', 0, 'Padding', 0);
            % uicontrol(obj.PROP_LABEL{:}, 'Parent', hboxThetaY, 'String', 'ThetaY');  % label
            labelStr = '<html><body style="background-color:black;"><font color="white" size=4>&nbsp;&theta<sub>YZ</sub>&nbsp;</body></html>';
            jLabel = javaObjectEDT('javax.swing.JLabel',labelStr);
            javacomponent(jLabel,[100,100,20,20],hboxThetaY);
            obj.edtThetaY = uicontrol(obj.PROP_EDIT{:}, 'Parent', hboxThetaY);
            hboxThetaY.Widths = [32 -1];
            
            tiltWidth = 100;
            set(gridTilt, 'Widths', [-1 -1] , 'Heights', [-1 -1]);
            
            %%%% callbacks %%%%
            obj.cbxEnable.Callback = @(e,h) obj.cbxEnabledCallback;
            obj.btnTiltCalculator.Callback = @(e,h) obj.btnTiltCalculatorCallback;
            obj.edtThetaX.Callback = @(e,h) obj.edtThetaCallback;
            obj.edtThetaY.Callback = @(e,h) obj.edtThetaCallback;
            
            %%%% internal values %%%%
            obj.height = 90;
            obj.width = tiltWidth + 15;
            
            %%%% init all data %%%%
            obj.refresh();
        end
        
        function refresh(obj)
            % todo update from stage
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
                
            if ~stage.tiltAvailable
                return  % Nothing to do here
            end
            [tiltEnabled, thetaXZ, thetaYZ] = stage.GetTiltStatus();
            obj.cbxEnable.Value = tiltEnabled;
            obj.edtThetaX.String = StringHelper.formatNumber(thetaXZ);
            obj.edtThetaY.String = StringHelper.formatNumber(thetaYZ);
            
            obj.colorifybyCheckbox();
        end
        
        function cbxEnabledCallback(obj)
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            stage.enableTiltCorrection(obj.cbxEnable.Value);
        end
        
        function btnTiltCalculatorCallback(obj)
            gui = GuiControllerTiltCalculator(obj);
            gui.start();
        end
        
        function edtThetaCallback(obj)
            isError = false;
            
            string = obj.edtThetaX.String;
            if ~ValidationHelper.isStringValueInBorders(string, ClassStage.TILT_MIN_LIM_DEG, ClassStage.TILT_MAX_LIM_DEG)
                EventStation.anonymousWarning('Theta X value not in range! Reverting.\nRange possible: [%d, %d]', ClassStage.TILT_MIN_LIM_DEG, ClassStage.TILT_MAX_LIM_DEG);
                isError = true;
            end
                
            string = obj.edtThetaY.String;
            if ~ValidationHelper.isStringValueInBorders(string, ClassStage.TILT_MIN_LIM_DEG, ClassStage.TILT_MAX_LIM_DEG)
                EventStation.anonymousWarning('Theta Y value not in range! Reverting.\nRange possible: [%d, %d]', ClassStage.TILT_MIN_LIM_DEG, ClassStage.TILT_MAX_LIM_DEG);
                isError = true;
            end
            
            if isError
                stage = getObjByName(obj.stageName);
                if ~isempty(stage)
                    % We can recover the old values
                    [~, thetaXZ, thetaYZ] = stage.GetTiltStatus();
                    obj.edtThetaX.String = StringHelper.formatNumber(thetaXZ);
                    obj.edtThetaY.String = StringHelper.formatNumber(thetaYZ);
                else
                    EventStation.anonymousError('Could not find %s! Could not revert.', obj.stageName);
                end
                return
            end
            
            thetaXZ = str2double(obj.edtThetaX.String);
            thetaYZ = str2double(obj.edtThetaY.String);
            stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
            stage.setTiltAngle(thetaXZ, thetaYZ);
        end
        
        function colorifybyCheckbox(obj)
            cbxIsOff = ~obj.cbxEnable.Value;
            obj.recolor([obj.edtThetaX, obj.edtThetaY], cbxIsOff)
        end
    end
    
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if isfield(event.extraInfo, ClassStage.EVENT_TILT_CHANGED) ...
                    || event.isError
                
                obj.refresh();
            end
        end
    end
end



