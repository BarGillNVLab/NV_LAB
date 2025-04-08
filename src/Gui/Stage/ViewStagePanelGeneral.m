classdef ViewStagePanelGeneral < GuiComponent
    %VIEWSTAGESCANSCAN Panel for incorporating a button for "Reset Stage"
    %and the "clossed loop" checkbox
    
    properties
        btnResetStage   % button
        cbxClosedLoop   % checkbox
        
        stageName       % string
    end
    
    methods
        function obj = ViewStagePanelGeneral(parent, controller, stage)
            obj@GuiComponent(parent, controller);
            obj.stageName = stage.name;
            
            %%%% panel init %%%%
            panelGeneral = uix.Panel('Parent', parent.component, 'Title', 'General', 'Padding', 5);
            vboxMain = uix.VBox('Parent', panelGeneral, 'Spacing', 5, 'Padding', 0);
            obj.component = vboxMain;
            
            % Getting closed-loop options
            hasClosedLoop = stage.hasClosedLoop;
            hasOpenLoop = stage.hasOpenLoop;
            
            obj.btnResetStage = uicontrol(obj.PROP_BUTTON{:}, ...
                'Parent', vboxMain, ...
                'String', 'Reset Stage', ...
                'Callback', @obj.btnResetStageCallback);
            obj.cbxClosedLoop = uicontrol(obj.PROP_CHECKBOX{:}, ...
                'Parent', vboxMain, ...
                'String', 'Closed Loop', ...
                'Value', hasClosedLoop, ... % If closed loop is implemented, it is the default
                'Enable', BooleanHelper.boolToOnOff(hasClosedLoop && hasOpenLoop), ...
                'Callback', @obj.cbxClosedLoopCallback);
            
            obj.height = 100;
            obj.width = 105;
        end
        
        %%%% Callbcaks %%%%
        function btnResetStageCallback(obj,~,~)
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            stage.Reconnect;
            stage.sendEventPositionChanged;     % It might have
        end
        
        function cbxClosedLoopCallback(obj,~,~)
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            mode = BooleanHelper.ifTrueElse(obj.cbxClosedLoop.Value, 'Closed', 'Open');
            stage.ChangeLoopMode(mode);
        end
    end
    
end

