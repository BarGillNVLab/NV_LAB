classdef GuiControllerSpcmCounter < GuiController
    %GUICONTROLLERSPCMCOUNTER Gui Controller for the SPCM counter
    
    methods
        function obj = GuiControllerSpcmCounter()
            Setup.init;
            shouldConfirmOnExit = false;
            openOnlyOne = true;
            windowName = 'SPCM Counter';
            obj = obj@GuiController(windowName, shouldConfirmOnExit, openOnlyOne);
        end
        
        function view = getMainView(obj, figureWindowParent)
            % This function should get the main View of this GUI.
            parent = figureWindowParent;
            controller = obj;
            view = ViewSpcmCounter(parent, controller, 'isStandalone', true);
        end
        
        function onAboutToStart(obj)
            % Callback. Things to run right before the window will be drawn
            % to the screen.
            % Child classes can override this method
            obj.moveToMiddleOfScreen();
        end
        
        function onClose(obj) %#ok<MANU>
            % Callback. Things to run when need to close the GUI.
%             
%             % If the counter is running, we want to turn it off
%             spcmCounter = getObjByName(SpcmCounter.NAME);
%             if spcmCounter.stopFlag; return; end
%             EventStation.anonymousWarning('SPCM Counter is now turned off');
%             spcmCounter.pause;
%             spcmCounter.reset;
        end
    end
    
end