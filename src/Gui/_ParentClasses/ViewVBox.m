classdef ViewVBox < GuiComponent
    %VIEWVBOX GUI component with built-in VBox component
    
    properties
    end
    
    methods
        function obj = ViewVBox(parent, controller, padding, spacing)
            if ~exist('padding', 'var')
                padding = 0;    % Space from box to other components
            end
            if ~exist('spacing', 'var')
                spacing = 5;    % Space between components in the box
            end
            
            obj@GuiComponent(parent, controller);
            obj.component = uix.VBox('Parent', parent.component, 'Padding', padding, 'Spacing', spacing);
        end
        
        function setHeights(obj, heights)
            set(obj.component, 'Heights', heights);
        end
    end
    
end