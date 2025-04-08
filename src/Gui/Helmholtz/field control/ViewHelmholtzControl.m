classdef ViewHelmholtzControl < ViewVBox

    methods
        function obj = ViewHelmholtzControl(parent, controller)
            vMainPanel = ViewExpandablePanel(parent, controller, 'Magnetic Field Control');
            obj@ViewVBox(vMainPanel, controller);
            obj.component.Spacing = 5;
            obj.component.Padding = 5;
            
            vbox = ViewVBox(obj, controller, 0, 16);
            vGeneral = ViewGeneralControl(vbox, controller);
            vBsphere = ViewBsphereControl(vbox, controller);
            vBcart = ViewBcartControl(vbox, controller);
            vCurrent = ViewCurrentControl(vbox, controller);
            boxes = {vGeneral, vBsphere, vBcart, vCurrent};
            
            vbox.height = sum(cellfun(@(p) p.height, boxes));
%             vbox.setHeights([-1, vBsphere.height, vBcart.height, vCurrent.height]);
            vbox.setHeights([vGeneral.height, vBsphere.height, vBcart.height, vCurrent.height]);
            vbox.width = max(cellfun(@(p) p.width, boxes));
            
            obj.height = vbox.height;
            obj.width = vbox.width;
            
        end
    end 


end