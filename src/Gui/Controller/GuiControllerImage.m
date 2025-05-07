classdef GuiControllerImage < GuiController
    %GUICONTROLLERIMAGE Gui Controller for the image GUI
    %   
    properties
        dummuMode
        iscamera      % a flag to indicate if the setup has a camera
    end
    
    methods
        function obj = GuiControllerImage(iscamera, dummyMode)
            if ~exist("dummyMode", "var")
                dummyMode = 0;
            end
            shouldConfirmOnExit = true;
            openOnlyOne = true;
            windowName = 'ImageNVC_touch_new';
            obj = obj@GuiController(windowName, shouldConfirmOnExit, openOnlyOne);
            obj.dummuMode = dummyMode;
            obj.iscamera = iscamera;
        end
        
        function view = getMainView(obj, figureWindowParent)
            % This function should get the main View of this GUI.
            % It can call any view constructor with the params:
            % parent=figureWindowParent, controller=obj
            if ~obj.dummuMode
                if ~ obj.iscamera
                    view = ViewMainImage(figureWindowParent, obj);
                else
                    view = ViewMainImageCamera(figureWindowParent, obj);
                end
            else
                
            end
        end
        
        function onStarted(obj)
            obj.windowMinHeight = 1;
            obj.windowMinWidth = 1;
        end
        
        function onClose(obj)
            % Callback. Things to run when need to close the GUI.
            imageScanResult = getObjByName(ImageScanResult.NAME);
            if ~isempty(imageScanResult)
                imageScanResult.checkGraphicAxes;       % Tell it that vAxes are no longer available (without being EventSender)
            else
                % Could not find ImageScanResult, so nothing needs updating.
            end
%             StageControlEvents.sendCloseConnection;
                        % requires GUI for closing connection demand
        end
    end
    
end

