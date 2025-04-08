classdef GuiControllerExperiment < GuiController
    %GUICONTROLLEREXPERIMENT Gui Controller for an experiment 
    
    properties
        expName
    end
    
    methods
        function obj = GuiControllerExperiment(expName)
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
            view = ViewExperimentPlot(obj.expName, figureWindowParent, obj);   % to be changed in the future
        end
        
        function onAboutToStart(obj)
            % Callback. Things to run right before the window will be drawn
            % to the screen.
            % Child classes can override this method
            obj.moveToMiddleOfScreen();
            datacursormode(obj.figureWindow);
        end
        
        function onClose(obj)
            % Callback. Things to run when need to close the GUI.
            
            exp = getObjByName(obj.expName);

            if ~isempty(exp) 
                exp.checkGraphicAxes;   % Tell the Experiment that vAxes are no longer available for plotting
                
                if exp.isRunning
                    % this requires informing the user
                    EventStation.anonymousWarning('The window closed, force closing %s', obj.expName);
                    exp.emergencyStop();
                end
            end
        end
    end
    
end

