classdef ViewExpectedESR < ViewVBox
    methods
        function obj = ViewExpectedESR(parent, controller)
            vMainPanel = ViewExpandablePanel(parent, controller, 'Expected ESR Plot');
            obj@ViewVBox(vMainPanel, controller);
            obj.component.Spacing = 5;
            obj.component.Padding = 5;
            
            vImage = ViewESRPlot(obj, controller);
            obj.height = vImage.height + 10;
            obj.width = vImage.width + 10;
        end
    end 
end