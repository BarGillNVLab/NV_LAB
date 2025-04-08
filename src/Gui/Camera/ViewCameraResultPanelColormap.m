classdef StartStop < GuiComponent
    %VIEWSTAGESCANPANELPLOT panel for coloring the image
    %   Detailed explanation goes here
    
    properties
        startbtn                % start button
        stopbtn                 %stop button
    end
    
    methods
        function obj = StartStop(parent, controller)
            obj@GuiComponent(parent, controller);
            panel = uix.Panel('Parent', parent.component, 'Title', 'Image aquision', 'Padding', 5);
            vboxMain = uix.VBox('Parent', panel, 'Spacing', 5, 'Padding', 0);
            obj.component = vboxMain;
            obj.startbtn = uicontrol(obj.PROP_BUTTON_BIG_GREEN{:}, 'Parent',vboxMain, );

            
            
            vboxMain.Heights = [25 -1];
            obj.height = 100;
            obj.width = 160;
            
            
        end
        
    end
    
end