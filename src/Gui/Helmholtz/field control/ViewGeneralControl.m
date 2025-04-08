classdef ViewGeneralControl < GuiComponent & EventListener
    
    properties (Constant)
        CONTROL_STATE = {'ON', 'AUTO', 'OFF'};
    end
    
    properties
        btnBtoNV        % button
        cbxOutputOn     % checkbox
        cbxFlipDir      % checkbox
        
        chsControlState
        chsOn
        chsAuto
        chsOff
        dspOutput
        
        helm
    end

    methods
        function obj = ViewGeneralControl(parent, controller)
            expNames = Experiment.getExperimentNames();
            namesToListenTo = {expNames{:}, Helmholtz.NAME}; %#ok<CCAT>
            
            obj@GuiComponent(parent, controller);
            obj@EventListener(namesToListenTo);
            obj.helm = getObjByName('Helmholtz');
            
            %%%% panel init %%%%
            panelMain = uix.Panel('Parent', parent.component, 'Title', 'General Control', 'Padding', 5);
            hboxMain = uix.HBox('Parent', panelMain, 'Spacing', 25, 'Padding', 0);
            
            %%% left check boxes %%%
            obj.chsControlState = uibuttongroup(...
                'Parent', hboxMain, ...
                'Title', 'Control State', ...
                'SelectionChangedFcn', @obj.callbackControlStateSelection);
            chsHeight = 15;
            chsWidth = 70;
            paddingFromLeft = 10;
            obj.chsOn = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.chsControlState, ...
                'String', obj.CONTROL_STATE{1}, ...
                'Position', [paddingFromLeft 45 chsWidth chsHeight], ...  
                'Tag', obj.CONTROL_STATE{1});
            obj.chsAuto = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.chsControlState, ...
                'String', obj.CONTROL_STATE{2}, ...
                'Position', [paddingFromLeft 25 chsWidth chsHeight], ...  
                'Tag', obj.CONTROL_STATE{2});
            obj.chsOff = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.chsControlState, ...
                'String', obj.CONTROL_STATE{3}, ...
                'Position', [paddingFromLeft 5 chsWidth chsHeight], ...  
                'Tag', obj.CONTROL_STATE{3});
            vboxLeftHeightTotal = 3*(chsHeight+10) +35;
            leftSideTotalWidth = 100;

            %%% center output state display %%%
            vboxCenter = uix.VBox('Parent',hboxMain, 'Spacing', 6);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', vboxCenter, 'String', 'OUTPUT:');
            obj.dspOutput = uicontrol(obj.PROP_ON_OFF_DISP{:}, 'Parent', vboxCenter, 'String', 'OFF');
            vboxCenter.Heights = [-1, 70];
            vboxCenterWidth = 70;
            
            %%% empty box %%%
            vboxSpace = uix.VBox('Parent',hboxMain, 'Spacing', 6);
            
            %%% right side %%%
            vboxRight = uix.VBox('Parent',hboxMain, 'Spacing', 6);
            obj.btnBtoNV = uicontrol(obj.PROP_BUTTON_BIG_RED{:}, ...
                    'Parent', vboxRight, ...
                    'String', sprintf('B %s NV', StringHelper.RIGHT_ARROW), ...
                    'TooltipString', 'Set magnetic field direction to the closest NV axis');
            BtoNVbottonH = 60;
            obj.cbxFlipDir = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', vboxRight, 'String', 'Flip Direction', 'FontSize', 10, 'FontWeight', 'bold');
            checkBoxH = 35;
            Heights = [BtoNVbottonH, checkBoxH];
            vboxRight.Heights = Heights;
            vboxRightHeightTotal = sum(Heights) + 30;
            rightSidewidth = 120;
            
            %%%% Set mainHbox widths %%%%
            widthsRelative = [leftSideTotalWidth, vboxCenterWidth, -1, rightSidewidth];
            hboxMain.Widths = widthsRelative;
                
                
            obj.btnBtoNV.Callback = @(h,e) obj.btnBtoNVCallback();
            obj.cbxFlipDir.Callback = @(h,e) obj.cbxFlipDirCallback();
            
            obj.height = vboxRightHeightTotal;
            
            obj.refresh;
        end
        
        function refresh(obj)
            switch obj.helm.helmControl
                case obj.helm.CONTROL_STATE{1}
                    obj.chsControlState.SelectedObject = obj.chsOn;
                case obj.helm.CONTROL_STATE{2}
                    obj.chsControlState.SelectedObject = obj.chsAuto;
                case obj.helm.CONTROL_STATE{3}
                    obj.chsControlState.SelectedObject = obj.chsOff;
            end
            if obj.helm.helmOn
                obj.dspOutput.BackgroundColor = 'green';
                obj.dspOutput.String = 'ON';
            else
                obj.dspOutput.BackgroundColor = 'red';
                obj.dspOutput.String = 'OFF';
            end
            obj.cbxFlipDir.Value = obj.helm.flip;
        end
        
        function callbackControlStateSelection(obj, ~, event) %#ok<INUSL>
            action = event.NewValue.Tag;
            index = find(strcmp(action, obj.CONTROL_STATE));
            obj.helm.control(obj.helm.CONTROL_STATE{index});
        end
        
        function btnBtoNVCallback(obj)
            obj.helm.BtoNV;
        end
        
        function cbxFlipDirCallback(obj)
            obj.helm.flipDirection(obj.cbxFlipDir.Value);
        end
    end

    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if event.isError ...
                    || isfield(event.extraInfo, Helmholtz.EVENT_OUTPUT_STATE_CHANGED) ...
                    || isfield(event.extraInfo, Helmholtz.EVENT_FLIP_STATE_CHANGED) ...
                    || isfield(event.extraInfo, Helmholtz.EVENT_CONTROL_STATE_CHANGED)
                obj.refresh();
            end
        end
    end
end