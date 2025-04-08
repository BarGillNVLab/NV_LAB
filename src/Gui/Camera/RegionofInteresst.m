classdef RegionofInteresst < GuiComponent & EventSender & EventListener

    % Class for creating the Region of Interest (ROI) of the camera

    properties
        edtmin             % 1x2 input text
        edtmax             % 1x2 input text
        setroitodefault    % button
        defaultRoi

        camera
    end

    

    methods
        function obj = RegionofInteresst(parent, controller, camera)
            % Constructor for RegionofInteresst

            obj@GuiComponent(parent, controller);
            obj@EventSender(sprintf('%s%s', camera.NAME, ' _ panel ROI params'));
            obj@EventListener(camera.NAME);

            % ROI panel initialization
            panel = uix.Panel('Parent', parent.component, 'Title', 'Region of Interest', 'Padding', 5);
            hboxMain = uix.HBox('Parent', panel, 'Spacing', 0, 'Padding', 0);
            gridROIParams = uix.Grid('Parent', hboxMain, 'Spacing', 5);
            obj.camera = camera;
            obj.defaultRoi = obj.camera.ROI_DEFULT;

            % First Column - Labels
            uix.Empty('Parent', gridROIParams);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', gridROIParams, 'String', 'X');
            uicontrol(obj.PROP_LABEL{:}, 'Parent', gridROIParams, 'String', 'Y');

            % Second Column - "min"
            uicontrol(obj.PROP_LABEL{:}, 'Parent', gridROIParams, 'String', 'Min');  % label
            obj.edtmin = gobjects(1, 2);
            for i = 1:2
                obj.edtmin(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', gridROIParams);
            end

            % Third Column - "max"
            uicontrol(obj.PROP_LABEL{:}, 'Parent', gridROIParams, 'String', 'Max'); % label
            obj.edtmax = gobjects(1, 2);
            for i = 1:2
                obj.edtmax(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', gridROIParams);
            end

            % Adjust grid layout
            gridROIParams.Widths = [25 60 60];
            gridROIParams.Heights = [25 25 25];

            % Calculate grid dimensions
            gridAllWidth = sum(gridROIParams.Widths)+15;
            gridAllHeight = sum(gridROIParams.Heights) + 5 * (length(gridROIParams.Heights) - 1);
            
            uix.Empty('parent', hboxMain);
            dummywidth =-1;
            % Default ROI section
            vboxDefROI = uix.VBox('Parent', hboxMain, 'Spacing', 5, 'Padding', 0);
            

            % Default Image Size label
            r = strcat(num2str(obj.defaultRoi(3)), ' x ', num2str(obj.defaultRoi(4)));
            
            uicontrol(obj.PROP_LABEL{:}, 'Parent', vboxDefROI, 'String', 'Default ROI:', 'FontSize', 8);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', vboxDefROI, 'String',  r, 'FontSize', 8);

            uix.Empty('parent',vboxDefROI);
            % Set ROI to Default button
            obj.setroitodefault = uicontrol(obj.PROP_BUTTON{:}, 'Parent', vboxDefROI, 'String', '<html><center>Set ROI<br>to Default</center></html>', 'FontSize', 8); 

            % Set widths to match gridROIParams           
            

            % Adjust layout dimensions
            vboxDefROI.Heights = [20 20 5 50];
            vboxDefROIwidth = 150;
            defROIHeight = sum(vboxDefROI.Heights) + 5 * (length(vboxDefROI.Heights) - 1);

            hboxMain.Widths = [gridAllWidth dummywidth vboxDefROIwidth];
            

            % Set overall dimensions
            obj.height = max(gridAllHeight, defROIHeight);
            obj.width = gridAllWidth+vboxDefROIwidth+30;

            % Callback functions (if any) can be added here
            for i=1 : 2
                set(obj.edtmin(i), 'Callback', @(h,e)obj.edtMinCallback(i));
                set(obj.edtmax(i), 'Callback', @(h,e)obj.edtMaxCallback(i));
            end
            obj.setroitodefault.Callback = @(h,e) obj.setRoiDefault;
            obj.refresh;
        end

        function edtMinCallback(obj, index)
           
            imageParams = obj.camera.imgparams;
            roi = imageParams.roi;
            temp = roi(index);
            axes = 'xy';
            viewMin = obj.edtmin(index);
            if ~ValidationHelper.isStringValueANumber(viewMin.String)
                viewMin.String = roi(index);
                obj.sendError('Only numbers can be accepted! Reverting.');
            end
            min = str2double(viewMin.String);
            lowerBound = 0;
            upperBound = obj.camera.MAX_ROI(index+2);
            if ~ValidationHelper.isInBorders(min, lowerBound, upperBound)
                warningMsg = sprintf( ...
                    '"from" (index: %s) is not in bounds! Reverting.\n(bounds: [%d, %d])', ...
                    axes(index), ...
                    lowerBound, ...
                    upperBound);
                min = roi(index);
                obj.sendWarning(warningMsg);
            elseif min == roi(index)+roi(index+2)
                warningMsg = sprintf( ...
                    'roi the %s axis starts and ends at the same point!', ...
                    axes(index));
                obj.sendWarning(warningMsg)
            end
             [viewMin.String, roi(index)] = StringHelper.formatNumber(min);
             shift = temp - roi(index);
             roi(index+2) = roi(index+2)+ shift;
             obj.camera.setROI(roi);
        end

        function edtMaxCallback(obj, index)
           
            imageParams = obj.camera.imgparams;
            roi = imageParams.roi;
            axes = 'xy';
            viewMax = obj.edtmax(index);
            if ~ValidationHelper.isStringValueANumber(viewMax.String)
                viewMax.String = roi(index)+roi(index+2);
                obj.sendError('Only numbers can be accepted! Reverting.');
            end
            max = str2double(viewMax.String);
            lowerBound = 0;
            upperBound = obj.camera.MAX_ROI(index+2);
            if ~ValidationHelper.isInBorders(max, lowerBound, upperBound)
                warningMsg = sprintf( ...
                    '"from" (index: %s) is not in bounds! Reverting.\n(bounds: [%d, %d])', ...
                    axes(index), ...
                    lowerBound, ...
                    upperBound);
                max = roi(index)+roi(index+2);
                obj.sendWarning(warningMsg);
            elseif max <= roi(index)
                warningMsg = sprintf( ...
                    'roi the %s axis max must be larger than min', ...
                    axes(index));
                obj.sendWarning(warningMsg)
            end
             [viewMax.String, te] = StringHelper.formatNumber(max);
             roi(index+2) = te-roi(index);
             obj.camera.setROI(roi);
        end

        function setRoiDefault(obj)
            obj.edtmax(1).String = num2str(obj.defaultRoi(1)+obj.defaultRoi(3));
            obj.edtmax(2).String = num2str(obj.defaultRoi(2)+obj.defaultRoi(4));
            obj.edtmin(1).String = num2str(obj.defaultRoi(1));
            obj.edtmin(2).String = num2str(obj.defaultRoi(2));
            obj.camera.setROI(obj.defaultRoi);
        end


        function refresh(obj)
            
            imageParams = obj.camera.imgparams;
            
            for i = 1 : 2
                obj.edtmin(i).String = imageParams.roi(i);
                obj.edtmax(i).String = imageParams.roi(i)+imageParams.roi(i+2);
                
            end
        end
    end
     %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if event.isError || isfield(event.extraInfo, Camera.EVENT_CAMERA_PARAMS_CHANGED)
                obj.refresh()
            end
        end
    end
end
