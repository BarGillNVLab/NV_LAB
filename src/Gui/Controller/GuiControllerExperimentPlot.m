classdef GuiControllerExperimentPlot < GuiController
    %GUICONTROLLEREXPERIMENTPLOT Gui Controller for an experiment plot +
    %stop button
    
    properties
        expName
    end
    
    methods
        function obj = GuiControllerExperimentPlot(expName)
            shouldConfirmOnExit = true;
            openOnlyOne = true;
            windowName = sprintf('%s - Plot', expName);
            
            obj = obj@GuiController(windowName, shouldConfirmOnExit, openOnlyOne);
            obj.expName = expName;
        end
        
        function view = getMainView(obj, figureWindowParent)
            % This function should get the main View of this GUI.
            % can call any view constructor with the params:
            % parent=figureWindowParent, controller=obj
            view = ViewExperimentPlot(obj.expName, figureWindowParent, obj);
        end
        
        function onAboutToStart(obj)
            % Callback. Things to run right before the window will be drawn
            % to the screen.
            % Child classes can override this method
            obj.moveToMiddleOfScreen();
        end
        
        function onClose(obj)
            % Callback. Things to run when need to close the GUI.
            
            % If the experiment is running, we want to inform the user
            exp = getObjByName(obj.expName);
            if exp.isRunning
                EventStation.anonymousWarning('The window closed, but %s is still running', obj.expName);
            end
        end
    end
    
end

