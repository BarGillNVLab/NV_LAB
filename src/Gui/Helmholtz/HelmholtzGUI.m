classdef HelmholtzGUI < GuiController

    methods
        function obj = HelmholtzGUI()
            shouldConfirmOnExit = true;
            openOnlyOne = true;
            windowName = 'Helmholtz_GUI';
            obj = obj@GuiController(windowName, shouldConfirmOnExit, openOnlyOne);
        end
        
        function view = getMainView(obj, figureWindowParent)
            % This function should get the main View of this GUI.
            % It can call any view constructor with the params:
            % parent=figureWindowParent, controller=obj
            view = viewHelmholtz(figureWindowParent, obj);
        end
        
        function onStarted(obj)
            obj.windowMinHeight = 1;
            obj.windowMinWidth = 1;
        end
        
        function onClose(obj)
            % Callback. Things to run when need to close the GUI.
            helm = getObjByName('Helmholtz');
            helm.close;
        end
    end
    
end


