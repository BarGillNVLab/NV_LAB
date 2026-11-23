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

            if isa(camera, 'UEeventCamera')
                roi = ViewRegionofInterest(main, controller, camera);
                accumulationTime = viewAccumulationTime(main, controller, camera);
                biasPanel = ViewExpandablePanel(main, controller, 'Biases Settings');
                biases = viewBiases(biasPanel, controller, camera);
                flickerpanel = ViewExpandablePanel(main, controller, 'AntiFlicker Settings');
                flick = viewAntiFlicker(flickerpanel, controller, camera);
                eventtrailPanel = ViewExpandablePanel(main, controller, 'Event Trail Filter');
                eventTrail = viewEventTrailFilter(eventtrailPanel, controller, camera);
                main.height = [roi.height+40, accumulationTime.height+20, biases.height+30, flick.height+30, eventTrail.height + 30];
                main.setHeights([roi.height+40 accumulationTime.height+20 biases.height+30 flick.height+30, eventTrail.height + 30]);
                main.width = max([roi.width biases.width flick.width eventTrail.width]);
            else

            
                roi = ViewRegionofInterest(main, controller, camera);
                exposur = Viewexposure(main, controller, camera);  
                mw = ViewMWContrast(main, controller);
                if isa(camera, 'CameraAndor')
                    temperature = ViewAndorSensorTemperature(main, controller);
                    main.height = [roi.height+40, exposur.height+30, mw.height, temperature.height];
                    main.setHeights([-roi.height -exposur.height mw.height temperature.height]);
                    main.width = max([roi.width exposur.width mw.width temperature.width]);
                else
                    main.height = [roi.height+40, exposur.height+30, mw.height];
                    main.setHeights([-roi.height -exposur.height mw.height]);
                    main.width = max([roi.width exposur.width mw.width]);
                end
            end
                
            
            % Adjust the size of the entire layout
            
           
            obj.height = sum(main.height)+40;
            obj.width = main.width+40;
        end
    end
end