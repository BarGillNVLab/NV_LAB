classdef ViewGeneralDiamondControl < GuiComponent & EventListener

    properties (Constant)
        AXES = {'Rotate', 'Theta', 'Phi'};
    end
    
    properties
        btnNVtoB            % button
        dontChangeIndex     % the chosen axis index for don't change
        
        popupNormal           % edit-text 
        popupEdge             % edit-text 
        
        chsDontChange
        chsRotate           % choose list
        chsThete            % choose list
        chsPhi              % choose list
        
        vAxes
        helm
    end
    
    methods
        function obj = ViewGeneralDiamondControl(parent, controller)
            expNames = Experiment.getExperimentNames();
            namesToListenTo = {expNames{:}, Helmholtz.NAME}; %#ok<CCAT>
            
            obj@GuiComponent(parent, controller);
            obj@EventListener(namesToListenTo);
            obj.helm = getObjByName('Helmholtz');
            
            %%%% panel init %%%%
            panelMain = uix.Panel('Parent', parent.component, 'Title', 'Diamond Placement Control', 'Padding', 5);
            vboxMain = uix.VBox('Parent', panelMain, 'Spacing', 25, 'Padding', 0);
            
            %%%% normal and edge vectors %%%%
            hboxUp = uix.HBox('Parent',vboxMain, 'Spacing', 6); % will contain the grid and "step"
            uicontrol(obj.PROP_LABEL{:}, 'Parent', hboxUp, 'String', 'Normal:');
            obj.popupNormal = uicontrol(obj.PROP_POPUP{:}, ...
                'Parent', hboxUp, ...
                'String', obj.helm.NORMAL_OPTIONS, ...
                'Callback', @obj.popupNormalCallback);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', hboxUp, 'String', 'Edge:');
            obj.popupEdge = uicontrol(obj.PROP_POPUP{:}, ...
                'Parent', hboxUp, ...
                'String', obj.helm.EDGE_OPTIONS, ...
                'Callback', @obj.popupEdgeCallback);
            hboxUp.Widths = [-1 -1 -1 -1];
            hboxUpHeightNoSpacing = 30;
            hboxUpWidthNoSpacing = 200;
            
            
            %%%% NV to B box %%%%
            hboxCenter = uix.HBox('Parent',vboxMain, 'Spacing', 6); % will contain the grid and "step"

            % empty box
            vboxLeft = uix.VBox('Parent',hboxCenter, 'Spacing', 6);
            
            % don't rotate choose
            obj.chsDontChange = uibuttongroup(...
                'Parent', hboxCenter, ...
                'Title', 'Don''t change', ...
                'SelectionChangedFcn',@obj.callbackDontChangeSelection);
            chsHeight = 15;
            chsWidth = 70;
            paddingFromLeft = 10;
            obj.chsRotate = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.chsDontChange, ...
                'String', obj.AXES{1}, ...
                'Position', [paddingFromLeft 45 chsWidth chsHeight], ...  
                'Tag', obj.AXES{1});
            obj.chsThete = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.chsDontChange, ...
                'String', obj.AXES{2}, ...
                'Position', [paddingFromLeft 25 chsWidth chsHeight], ...  
                'Tag', obj.AXES{2});
            obj.chsPhi = uicontrol(obj.PROP_RADIO{:}, 'Parent', obj.chsDontChange, ...
                'String', obj.AXES{3}, ...
                'Position', [paddingFromLeft 5 chsWidth chsHeight], ...  
                'Tag', obj.AXES{3});
            vboxRightHeigthNoSpacing = 3*(chsHeight+10) +20;
            leftSideTotalWidth = 100;

            % Nv to B buttom
            vboxRight = uix.VBox('Parent',hboxCenter, 'Spacing', 6);
            obj.btnNVtoB = uicontrol(obj.PROP_BUTTON_BIG_RED{:}, ...
                'Parent', vboxRight, ...
                'String', sprintf('NV %s B', StringHelper.RIGHT_ARROW), ...
                'TooltipString', 'Set the diamond placement, while the closest NV aligned to the magnetic field');
            heights = [-2];
            vboxRight.Heights = heights;
            rightSideTotalWidth = 120;
            
            %%%% hbox center
            hboxCenter.Widths = [-1, rightSideTotalWidth, leftSideTotalWidth];
            hboxDownWidthNoSpacing = rightSideTotalWidth + leftSideTotalWidth + 30;
            hboxDownHeightNoSpacing = vboxRightHeigthNoSpacing;
            
            %%% component down %%%
            obj.component = uicontainer('parent', vboxMain);
            obj.vAxes = axes('Parent', obj.component, 'ActivePositionProperty', 'outerposition');
            fig = imread('diamond angles.png');
            image(obj.vAxes, fig);
            axis(obj.vAxes, 'off');
            
            %%%% Set mainVbox widths %%%%
            heighsMain = [hboxUpHeightNoSpacing, hboxDownHeightNoSpacing, 150];
            heighsRelative = heighsMain * -1 ;
            vboxMain.Heights = heighsRelative;
            vboxMainWidth = max([hboxUpWidthNoSpacing, hboxDownWidthNoSpacing]);
            
            %%%% Callbacks %%%%
            obj.btnNVtoB.Callback = @(h,e) obj.btnNVtoBCallback();
            
            %%%% Internal values %%%%
            obj.width = vboxMainWidth;
            obj.height =sum(heighsMain) + 30;
            
            obj.refresh();
        end
        
        function refresh(obj)
            obj.popupNormal.Value = find(strcmp(obj.helm.NORMAL_OPTIONS, obj.helm.normal));
            obj.popupEdge.Value = find(strcmp(obj.helm.EDGE_OPTIONS, obj.helm.edge));
            switch obj.helm.dontChange
                case obj.helm.DIAMOND_AXES{1}
                    obj.chsDontChange.SelectedObject = obj.chsRotate;
                case obj.helm.DIAMOND_AXES{2}
                    obj.chsDontChange.SelectedObject = obj.chsThete;
                case obj.helm.DIAMOND_AXES{3}
                    obj.chsDontChange.SelectedObject = obj.chsPhi;
            end
        end
        
        function btnNVtoBCallback(obj)
            obj.helm.NVtoB(obj.AXES{obj.dontChangeIndex});
        end
        
        function callbackDontChangeSelection(obj, ~, event) %#ok<INUSL>
            action = event.NewValue.Tag;
            index = find(strcmp(action, obj.AXES));
            obj.helm.dontChange = obj.helm.DIAMOND_AXES{index};
        end
        
        
        function popupNormalCallback(obj,~,~)
            obj.helm.normal = obj.helm.NORMAL_OPTIONS{obj.popupNormal.Value};
        end
        
        function popupEdgeCallback(obj,~,~)
            obj.helm.edge = obj.helm.EDGE_OPTIONS{obj.popupEdge.Value};
        end
        
    end

    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if event.isError ...
                    || isfield(event.extraInfo, Helmholtz.EVENT_DIAMOND_PROPERTIES_CHANGED)
                obj.refresh();
            end
        end
    end
    
    
end