classdef GuiControllerTryViews < GuiController
    %GUICONTROLLERTRYNEWVIEWS Gui Controller for testing new views
    %   
    
    properties
    end
       
    methods
        function obj = GuiControllerTryViews()
            Setup.init;
            shouldConfirmOnExit = false;
            windowName = 'Gui Tester for Views';
            openOnlyOne = true;  
            % even that many instances of this GUI can be opened (for
            % multiple stages),  every stage can open just a single
            % instance of a GuiControllerTiltCalculator! 
            % this means that every stage will have its own unique GUI for
            % tilt-calculating with its own numbers stored inside
            
            obj = obj@GuiController(windowName, shouldConfirmOnExit, openOnlyOne);
        end
        
        function view = getMainView(obj, figureWindowParent)
            % this function should get the main View of this GUI.
            % can call any view constructor with the params:
            % parent=figureWindowParent, controller=obj

            % For trackables we need to first create a working experiment
            stageName = 'stage coarse';
            stage = getObjByName(stageName);
            view = ViewStage(figureWindowParent, obj, stage);
        end
        
        function onAboutToStart(obj)
            % callback. things to run right before the window will be drawn
            % to the screen.
            % child classes can override this method
            obj.moveToMiddleOfScreen();
        end
        
        function onSizeChanged(obj, newX0, newY0, newWidth, newHeight)
            % callback. thigs to run when the window size is changed
            % child classes can override this method
            fprintf('width: %d, height: %d\n', newWidth, newHeight);
        end

    end
    
end