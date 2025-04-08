classdef ViewHBox < GuiComponent
    %VIEWHBOX GUI component with built-in HBox component
    
    properties
    end
    
    methods
        function obj = ViewHBox(parent, controller, padding, spacing)
            if ~exist('padding', 'var')
                padding = 0;    % Space from box to other components
            end
            if ~exist('spacing', 'var')
                spacing = 5;    % Space between components in the box
            end
            
            obj@GuiComponent(parent, controller);
            obj.component = uix.HBox('Parent', parent.component, 'Padding', padding, 'Spacing', spacing);
        end
        
        function setWidths(obj, widths)
            set(obj.component, 'Widths', widths);
        end
    end
    
end