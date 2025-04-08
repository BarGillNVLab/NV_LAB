classdef ViewEmpty < handle
    %VIEWVBOX GUI component with empty content
    % Useful for treating a uix.empty like other GuiComponents, where they
    % are interchangeable.
    % Does not inherit from GuiComponent, because it is much much simpler.
    
    properties (SetAccess = private)
        component
    end
    properties (Dependent)
        height
        width
    end
    
    methods
        function obj = ViewEmpty(parent)
            obj@handle;
            obj.component = uix.Empty('Parent', parent.component);
        end
        
        function w = get.width(obj)
            w = GuiComponent.getWidth(obj.component);
        end
        function h = get.height(obj)
            h = GuiComponent.getHeight(obj.component);
        end
    end
    
end