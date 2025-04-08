classdef ViewPlotHeader < GuiComponent & EventListener

    properties (Constant)
        AXES = {'Azimutal', 'Vertical'};
    end
    
    properties
        helm
        
        btnMoveLeft         % 1x2 button
        btnMoveRight        % 1x2 button
        btnOpenInFig        % button
        edtCurAng           % 1x2 edit-input for current angles
    end
    
    methods
        function obj = ViewPlotHeader(parent, controller)
            expNames = Experiment.getExperimentNames();
            namesToListenTo = {expNames{:}, Helmholtz.NAME}; %#ok<CCAT>

            obj@GuiComponent(parent, controller);
            obj@EventListener(namesToListenTo);
            obj.helm = getObjByName('Helmholtz');
            
            %%%% panel init %%%%
            panelMain = uix.Panel('Parent', parent.component, 'Title', 'Sutup Plot view', 'Padding', 5);
            hboxMain = uix.HBox('Parent', panelMain, 'Spacing', 25, 'Padding', 0);
            
            %%%% the left side grid %%%%
            gridLeftSide = uix.Grid('Parent', hboxMain, 'Spacing', 5);

            % 1st column: axes labels
            for i = 1:2
                uicontrol(obj.PROP_LABEL{:}, 'Parent', gridLeftSide, 'String', obj.AXES{i});
            end
            
            % 2nd column: arrow left
            obj.btnMoveLeft = gobjects(1, 2);
            for i = 1:2
                obj.btnMoveLeft(i) = uicontrol(obj.PROP_BUTTON{:}, ...
                    'Parent', gridLeftSide, ...
                    'String', StringHelper.LEFT_ARROW, ...
                    'FontSize', 20);
            end
            
            % 3rd column: current view angles
            obj.edtCurAng = gobjects(1, 2);
            for i = 1:2
                obj.edtCurAng(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', gridLeftSide);
            end
            
            % 4th column: arrow right
            obj.btnMoveRight = gobjects(1, 2);
            for i = 1:2
                obj.btnMoveRight(i) = uicontrol(obj.PROP_BUTTON{:}, ...
                    'Parent', gridLeftSide, ...
                    'String', StringHelper.RIGHT_ARROW, ...
                    'FontSize', 20);
            end
            
            % grid properties
            gridWidths = [70 35 70 35];
            gridWithdsRel = -1*gridWidths;
            heightGridTotalNoSpacing = 90;
            lineHeight = heightGridTotalNoSpacing / 3;
            gridHeights = lineHeight * ones(1, 2);
            set(gridLeftSide, 'Widths', gridWithdsRel, 'Heights', gridHeights);
            gridLeftHeightTotal = heightGridTotalNoSpacing + 5 * 2;
            gridLeftWidthTotal = sum(abs(gridWidths)) + 4 * length(gridWidths);

            %%%% 'open in figure' button %%%%
            vboxRight = uix.VBox('Parent',hboxMain, 'Spacing', 6);
            obj.btnOpenInFig = uicontrol(obj.PROP_BUTTON_BIG_BLUE{:}, ...
                'Parent', vboxRight, ...
                'String', 'Open In Figure');
            heights = [-2];
            vboxRight.Heights = heights;
            rightSideTotalWidth = 150;
            
            %%%% Set mainHbox widths %%%%
            widthsMain = [gridLeftWidthTotal, rightSideTotalWidth];
            hboxMain.Widths = [gridLeftWidthTotal, rightSideTotalWidth];
            
            %%%% Internal values %%%%
            obj.width = sum(widthsMain) + (hboxMain.Spacing -3) * length(widthsMain);
            obj.height = gridLeftHeightTotal;
            
            for i = 1:2
                obj.btnMoveLeft(i).Callback = @(h,e) obj.btnMoveCallback(i, 1);
                obj.btnMoveRight(i).Callback = @(h,e) obj.btnMoveCallback(i, 0);
                obj.edtCurAng(i).Callback =  @(h,e) obj.edtAngCallback(i);
            end
            obj.btnOpenInFig.Callback =  @(h,e) obj.btnOpenInFigCallback(i);
            obj.refresh;
        end
        
        function refresh(obj)
            for i = 1:2
                obj.edtCurAng(i).String = StringHelper.formatNumber(obj.helm.viewAng(i));
            end
        end
        
        function btnMoveCallback(obj, index, trueForLeftFalseForRight)
            step = BooleanHelper.ifTrueElse(trueForLeftFalseForRight,-1,1) * obj.helm.VIEW_ANGLE_STEP;
            obj.helm.viewAng(index) = obj.helm.viewAng(index) + step;
        end
        
        function edtAngCallback(obj, index)
            angle = obj.helm.viewAng;
            angle(index) = str2double(obj.edtCurAng(index).String);
            obj.helm.viewAng = angle;
        end
        
        function btnOpenInFigCallback(obj,~,~)
            figure;
            gAxes = axes(gcf);
            obj.helm.plotSetup(gAxes);
        end
    end
    
    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if event.isError ...
                    || isfield(event.extraInfo, Helmholtz.EVENT_VIEW_ANGLE_CHANGED)
                obj.refresh();
            end
        end
    end
end