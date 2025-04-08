classdef ViewDiamondPlacement < ViewVBox

    methods
        function obj = ViewDiamondPlacement(parent, controller)
            vMainPanel = ViewExpandablePanel(parent, controller, 'Diamond Placement Control');
            obj@ViewVBox(vMainPanel, controller);
            obj.component.Spacing = 5;
            obj.component.Padding = 5;
            
            vbox = ViewVBox(obj, controller, 0, 16);
            vGeneral = ViewGeneralDiamondControl(vbox, controller);
            vPlacement = ViewPlacementControl(vbox, controller);
            
            vbox.height = vGeneral.height + vPlacement.height + 50;
            vbox.setHeights([vGeneral.height, vPlacement.height]);
            vbox.width = max([vGeneral.width, vPlacement.width]);
            
            obj.height = vbox.height;
            obj.width = vbox.width;
            
        end
    end 


end