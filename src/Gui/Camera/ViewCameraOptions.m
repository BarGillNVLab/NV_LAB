classdef ViewCameraOptions < ViewVBox
    properties
    end
    
    methods
        function obj = ViewCameraOptions(parent, controller)
            % Create an expandable panel for the whole column
            panel = ViewExpandablePanel(parent, controller, 'Camera Options');
            obj@ViewVBox(panel, controller);
            camera = getObjByName(Camera.NAME);
            %%%% ui component init %%%%
            obj.component.Spacing = 5;
            obj.component.Padding = 5;
            
            % Create main vertical box layout
           
           
            main = ViewVBox(obj, controller, 0, 8);            
            

            %bottom left hbox
            
            roi = ViewRegionofInterest(main, controller, camera);
            exposur = Viewexposure(main, controller, camera);  
            mw = ViewMWContrast(main, controller);
            
            
            main.height = [roi.height+40, exposur.height+30, mw.height];
            main.setHeights([-roi.height -exposur.height mw.height]);
            main.width = max([roi.width exposur.width mw.width]);
            
            
            % Adjust the size of the entire layout
            
           
            obj.height = sum(main.height)+40;
            obj.width = main.width+40;
        end
    end
end