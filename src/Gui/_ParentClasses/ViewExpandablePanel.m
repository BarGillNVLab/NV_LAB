classdef ViewExpandablePanel < GuiComponent
    %VIEWHBOX Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Hidden, Constant)
        SIZE_MIN = 23;
    end
    properties
        maxSize = -1;
        isMinimized = false;
        parentComponent;
        
        undockFcn = [];
    end
    
    methods
        function obj = ViewExpandablePanel(parent, controller, textToDisplay, undockFcnOptional)
            %%%% init the ui controller %%%%
            obj@GuiComponent(parent, controller);
            obj.component = uix.BoxPanel('Parent', parent.component, ...
                'Title', textToDisplay);
            obj.parentComponent = parent.component;
            
            %%%% init minimize callback %%%%
            if exist('undockFcnOptional', 'var')
                obj.undockFcn = undockFcnOptional;
            end
            set(obj.component, 'MinimizeFcn', {@obj.callbackMinimize} );
        end
        
        function callbackMinimize(obj, ~, ~, ~)
            if (obj.isMinimized)
                height = obj.maxSize;
                delta = obj.maxSize - ViewExpandablePanel.SIZE_MIN;
            else
                height = ViewExpandablePanel.SIZE_MIN;
                obj.maxSize = obj.getHeight(obj.component);
                delta = ViewExpandablePanel.SIZE_MIN - obj.maxSize;
            end
            position = get(obj.component, 'Position');
            pLeft = position(1);
            pBottom = position(2);
            pWidth = position(3);
            pOldHeight = position(4);
            newPosition = [pLeft, pBottom - delta, pWidth, height];
            set(obj.component, 'Position', newPosition);
            
            obj.updateSizePropogate(delta);
            obj.isMinimized = ~obj.isMinimized;
            obj.component.Minimized = obj.isMinimized;
        end
        
        function updateSizePropogate(obj, objHeightDelta)
            % objHeightDelta - the change in the height, to be propogated
            component = obj.component;
            parent = obj.component.Parent;
            while isa(parent, 'uix.VBox')
                % Find the index of component inside parent
                componentIndex = length(parent.Children) + 1 - find(parent.Children == component);
                
                heights = parent.Heights;
                curHeight = heights(componentIndex);
                if (curHeight ~= -1)
                    heights(componentIndex) = heights(componentIndex) + objHeightDelta;
                    set(parent, 'Heights', heights);
                end
                
                component = parent;
                parent = component.Parent;
            end
        end
    end
       
    methods % Undocking
        function set.undockFcn(obj, fcn)
            assert(isa(fcn, 'function_handle'))
            obj.undockFcn = fcn;
            set(obj.component, 'DockFcn', {@obj.callbackUndock} );
        end
        
        function callbackUndock(obj, ~, ~)
            obj.callbackMinimize();
            obj.undockFcn();
        end
    end
    
end