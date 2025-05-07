classdef CountsperPixel < GuiComponent
    properties
        ccplbl         % ccp button
        runccp         % run ccp button
        ccpboxbtn      % ccpbox button
        stpccp         % stop ccp button
    end
    methods
        function obj = CountsperPixel(parent, controller)
            % Call the superclass constructor
            obj@GuiComponent(parent, controller);

            % Create the main vertical box container
            panel = uix.Panel('Parent', parent.component, 'Title', 'Counts Per Pixel', 'Padding', 5);
            mainVBox = uix.VBox('Parent',panel, 'Spacing', 0, 'Padding', 0);

            % Add a text box for the "CPP" display at the top
            obj.ccplbl = uicontrol(obj.PROP_LABEL{:}, ...
                                    'Parent', mainVBox, ...
                                    'String', 'CPP', ...
                                    'FontSize', 10, ...
                                    'HorizontalAlignment', 'center');

            uix.Empty('parent', mainVBox);

            
            

            % Add the "Run CPP" button to the horizontal box
            obj.runccp = uicontrol(obj.PROP_BUTTON{:}, ...
                                   'Parent', mainVBox, ...
                                   'String', 'Run CPP');
            uix.Empty('parent', mainVBox);

            % Add the "CPP Box" button to the horizontal box
            obj.ccpboxbtn = uicontrol(obj.PROP_BUTTON{:}, ...
                                      'Parent', mainVBox, ...
                                      'String', 'CPP Box');
            uix.Empty('parent', mainVBox);

            % Add the "Stop CPP" button to the horizontal box
            obj.stpccp = uicontrol(obj.PROP_BUTTON{:}, ...
                                   'Parent', mainVBox, ...
                                   'String', 'Stop CPP');

            
            mainVBox.Heights = [30 10 25 5 25 5 25];
            
            obj.height = sum(mainVBox.Heights) + 5;
            obj.width = 130;


            obj.ccpboxbtn.Callback = @(h,e) obj.CPPBoxCallback;
            obj.runccp.Callback = @(h,e) obj.RunCPPCallback;
            obj.stpccp = @(h,e) obj.StopCPPCallback;
        end
            % Callback functions can be implemented here as needed


            function RunCPPCallback(obj)
                cameradisplay = obj.getCameraDisplay;
                cameradisplay.RunCPP
                cameradisplay.runCPP = true;
                obj.ccplbl.String = num2str(cameradisplay.CPP);
                obj.backToMarker;
            end

            function CPPBoxCallback(obj)
                cameradisplay = obj.getCameraDisplay;
                cameradisplay.CPPBox;
                obj.backToMarker
            end

            function StopCPPCallback(obj)
                cameradisplay = obj.getCameraDisplay;
                if ~cameradisplay.RunCPP
                    obj.ccplbl.String = 'CPP';
                    return
                end
                cameradisplay.RunCPP = false;
            end



    end
    methods (Static)
        function isr = getCameraDisplay
            isr = getObjByName(CameraDisplay.NAME);
            if isempty(isr)
                throwBaseObjException(CameraDisplay.NAME);
            end
        end
    end

    methods (Access = private)
        function backToMarker(~)
            % When other operations finish, we want to return the cursor to
            % "marker" mode, both visually and functionally
            
            cameradisplay = getObjByName(CameraDisplay.NAME);
            if isempty(cameradisplay); throwBaseObjException(CameraDisplay.NAME); end
            
            action = cameradisplay.CURSOR_OPTIONS{1};
            cameradisplay.updateDataCursor(action);    % functionally
        end
    end
end
