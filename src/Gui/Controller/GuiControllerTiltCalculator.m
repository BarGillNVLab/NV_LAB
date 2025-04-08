classdef GuiControllerTiltCalculator < GuiController
    %GUICONTROLLERTILTCALCULATOR Gui Controller for the tilt calculator
    %   
    
    properties
        stageConnector  % object which has those properties: stageName, tiltPoint1, tiltPoint2, tiltPoint3
    end
       
    methods
        function obj = GuiControllerTiltCalculator(stageConnector)
            % stageConnector - object which has those properties: stageName, tiltPoint1, tiltPoint2, tiltPoint3
            shouldConfirmOnExit = false;
            windowName = sprintf('Tilt Calculator - %s', stageConnector.stageName);
            openOnlyOne = true;  
            % even that many instances of this GUI can be opened (for
            % multiple stages),  every stage can open just a single
            % instance of a GuiControllerTiltCalculator! 
            % this means that every stage will have its own unique GUI for
            % tilt-calculating with its own numbers stored inside
            
            obj = obj@GuiController(windowName, shouldConfirmOnExit, openOnlyOne);
            obj.startPosition = [792 449]; % was in old code file
            obj.stageConnector = stageConnector;
        end
        
        function view = getMainView(obj, figureWindowParent)
            % this function should get the main View of this GUI.
            % can call any view constructor with the params:
            % parent=figureWindowParent, controller=obj
            view = ViewMainTiltCalculator(figureWindowParent, obj, obj.stageConnector);
        end
    end
    
end

