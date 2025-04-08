classdef ViewMagneticField < ViewVBox
    methods
        function obj = ViewMagneticField(parent, controller)
            vMainPanel = ViewExpandablePanel(parent, controller, 'Magnetic Field Plot');
            obj@ViewVBox(vMainPanel, controller);
            obj.component.Spacing = 5;
            obj.component.Padding = 5;
            
            vHeader = ViewPlotHeader(obj, controller);
            vImage = ViewFieldPlot(obj, controller);
            
            obj.height = vImage.height + vHeader.height + 10;
            obj.width = max([vImage.width, vHeader.width]) + 10;
            obj.setHeights([vHeader.height, -1]);
        end
    end 
end