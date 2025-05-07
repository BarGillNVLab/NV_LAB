classdef PlotOptions < GuiComponent & EventListener

    properties
        popupTypes  % popup/dropdown-menu. Chooses names of the available colormaps
        cbxAuto     % checkbox. Wheteher the colormap is auto-scaled
        edtMin      % edit-input. Minimum value of colormap
        edtMax      % edit-input. Maximum value of colormap
        zoomwindow       %zoom window button
        zomout           %zoom out button
        updateroi        %update roi button
        
        initialROI
        roi
        imagedata
        
    end
    methods
        function obj = PlotOptions(parent, controller)
            obj@GuiComponent(parent, controller);
            obj@EventListener;
            plotOptions = uix.Panel('Parent', parent.component, 'Title', 'Plot Options', 'Padding', 5);
            hboxMain = uix.HBox('Parent', plotOptions, 'Spacing', 0, 'Padding', 0);

            leftColumn = uix.VBox('Parent', hboxMain, 'Spacing', 0, 'Padding', 0);
            % color map column
            colormap1stRow = uix.HBox('Parent', leftColumn, 'Spacing', 5);
            obj.popupTypes = uicontrol(obj.PROP_POPUP{:}, ...
                'Parent', colormap1stRow, ...
                'String', CameraDisplay.COLORMAP_OPTIONS);% ,  'Callback', @obj.popupTypesCallback
            uix.Empty('Parent', colormap1stRow); 
            obj.cbxAuto = uicontrol(obj.PROP_CHECKBOX{:}, ...
                'Parent', colormap1stRow, ...
                'String', 'Auto', ...
                'Value', true); %'Callback', @obj.cbxAutoCallback
            colormap1stRow.Widths = [-1 15 50];
            uix.Empty('parent', leftColumn)
            colormap2ndRow = uix.HBox('Parent', leftColumn, 'Spacing', 5);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', colormap2ndRow, ...
                'String', 'Min');  % Label
            obj.edtMin = uicontrol(obj.PROP_EDIT{:}, ...
                'Parent', colormap2ndRow, ...
                'String', 0); % , ...   'Callback', @obj.edtMinCallback
            uicontrol(obj.PROP_LABEL{:}, 'Parent', colormap2ndRow, ...
                'String', 'Max');  % Label
            obj.edtMax = uicontrol(obj.PROP_EDIT{:}, ...
                'Parent', colormap2ndRow, ...
                'String', 1);% 'Callback', @obj.edtMaxCallback
            colormap2ndRow.Widths =  [-1 -1 -1 -1];
            
            leftColumn.Heights = [25 10 50];
            leftColumnheight = 100;
            leftColumnwidth = 200;
            % end color map column
            uix.Empty('parent', hboxMain);
            % zoom column
            rightcolumn = uix.VBox('Parent', hboxMain, 'Spacing', 5, 'Padding', 0);
            
            obj.zoomwindow = uicontrol(obj.PROP_BUTTON{:}, 'Parent', rightcolumn, 'String', 'Zoom Window');
            uix.Empty('parent', rightcolumn)
            obj.zomout = uicontrol(obj.PROP_BUTTON{:}, 'Parent', rightcolumn, 'String', 'Zoom Out');
            uix.Empty('parent', rightcolumn)
            obj.updateroi = uicontrol(obj.PROP_BUTTON{:}, 'Parent', rightcolumn, 'String', 'Update ROI');

            rightcolumn.Heights = [25 2 25 2 25];
            rightcolumnwidth = 140;
            rightcolumnheight = sum(rightcolumn.Heights)+20;


          
            hboxMain.Widths = [leftColumnwidth -1 rightcolumnwidth];
            hboxMainheight = max(leftColumnheight, rightcolumnheight);

            obj.height = hboxMainheight+20;
            obj.width = sum(hboxMain.Widths)+5;

            % Callbacks

            obj.zoomwindow.Callback = @(h,e) obj.ZoomWindow;
            obj.zomout.Callback = @(h,e) obj.ZoomOut;
            obj.updateroi.Callback = @(h,e) obj.UpdateROI;
            obj.cbxAuto.Callback = @(h,e) obj.cbxAutoCallback;
            obj.popupTypes.Callback = @(h,e) obj.popupTypesCallback;
            obj.edtMin.Callback = @(h,e) obj.edtMinCallback;
            obj.edtMax.Callback = @(h,e) obj.edtMaxCallback;


            try
            obj.update;     % It might not succeed if there is no image
            catch
                % There is nothing we can do, for now
            end
        end


        % Callback Functions

        function ZoomWindow(obj)
            cameradisplay = getObjByName(CameraDisplay.NAME);
            if isempty(cameradisplay); throwBaseObjException(CameraDisplay.NAME); end

            cameradisplay.updateDataCursor('Zoom');
            obj.roi = cameradisplay.roi;

            obj.backToMarker;
        end

        function ZoomOut(obj)
            cameradisplay = getObjByName(CameraDisplay.NAME);
            if isempty(cameradisplay); throwBaseObjException(CameraDisplay.NAME); end

            cameradisplay.ZoomOut();
            obj.roi = [];
            obj.backToMarker;
        end

        function UpdateROI(obj)
            if ~isempty(obj.roi)
                camera = getObjByName(Camera.NAME);
                obj.roi = round(obj.roi/4)*4;
                camera.setROI(obj.roi);
            else
                error('UpdateROI:InvalidROI', 'ROI is empty or invalid. Please set a valid ROI before updating.');
            end
        end


        
        function update(obj)
            % Get values from CameraDisplay
            camerdisplay = obj.getCameraDisplay();
            obj.popupTypes.Value = camerdisplay.colormapType;

            obj.cbxAuto.Value = camerdisplay.colormapAuto;

            minVal = camerdisplay.colormapLimits(1);
            obj.edtMin.String = StringHelper.formatNumber(minVal,2);

            maxVal = camerdisplay.colormapLimits(2);
            obj.edtMax.String = StringHelper.formatNumber(maxVal,2);
            obj.imagedata = camerdisplay.mData;
            xaxis = cameradisplay.mFirstAxis;
            yaxis = cameradisplay.mSecondAxis;
            obj.initialROI = [xaxis(1) yaxis(1) xaxis(end)-xaxis(1) yaxis(end)-yaxis(1)];
        end
                    % 
                    % 
                    % 
        %%%% Callbacks %%%%
        function popupTypesCallback(obj, ~, ~)
            colormapType = obj.popupTypes.Value;

            cameradisplay = obj.getCameraDisplay();
            cameradisplay.colormapType = colormapType;
            cameradisplay.imagePostProcessing;    % which now updates added layer (including colormap)
        end
                    % 
        function cbxAutoCallback(obj, ~, ~)
            cameradisplay = obj.getCameraDisplay();
            cameradisplay.colormapAuto = obj.cbxAuto.Value;
            if cameradisplay.colormapAuto
                if cameradisplay.isDataAvailable
                    % Update added layer (including colormap)
                    cameradisplay.imagePostProcessing;
                    % Now get the calculated limits from ImageSR
                    limits = cameradisplay.colormapLimits;    % = [minVal maxVal]
                    obj.edtMin.String = StringHelper.formatNumber(limits(1),2);
                    obj.edtMax.String = StringHelper.formatNumber(limits(2),2);
                else
                    obj.edtMin.String = 0;
                    obj.edtMax.String = 1;
                end
            end
        end
                    % 
        function edtMinCallback(obj, ~, ~)
            cameradisplay = obj.getCameraDisplay();
            limits = cameradisplay.colormapLimits;     % = [minVal maxVal]

            if ~ValidationHelper.isStringValueANumber(obj.edtMin.String)
                obj.edtMin.String = StringHelper.formatNumber(limits(1),2); % = minVal
                EventStation.anonymousWarning('Minimum colormap value must be a number! Reverting.')
                return
            else
                newMinVal = str2double(obj.edtMin.String);
                if newMinVal > limits(2) % == maxVal
                    obj.edtMin.String = StringHelper.formatNumber(limits(1),2); % = minVal
                    EventStation.anonymousWarning('Minimum colormap value can''t be larger than Maximum! Reverting.')
                    return
                end
            end
    
            obj.cbxAuto.Value = false;
            cameradisplay.colormapAuto = false;
            cameradisplay.colormapLimits(1) = newMinVal;
            cameradisplay.imagePostProcessing;    % Updates added layer (including colormap)
        end
    
        function edtMaxCallback(obj, ~, ~)
            cameradisplay = obj.getCameraDisplay();
            limits = cameradisplay.colormapLimits;     % = [minVal maxVal]

            if ~ValidationHelper.isStringValueANumber(obj.edtMax.String)
                obj.edtMax.String = StringHelper.formatNumber(limits(2),2); % = maxVal
                EventStation.anonymousWarning('Maximum colormap value must be a number! Reverting.')
                return
            else
                newMaxVal = str2double(obj.edtMax.String);
                if newMaxVal < limits(1) % == minVal
                    obj.edtMax.String = StringHelper.formatNumber(limits(2),2); % = maxVal
                    EventStation.anonymousWarning('Maximum colormap value can''t be smaller than Minimum! Reverting.')
                    return
                end
            end

            obj.cbxAuto.Value = false;
            cameradisplay.colormapAuto = false;
            cameradisplay.colormapLimits(2) = newMaxVal;
            cameradisplay.imagePostProcessing;    % Updates added layer (including colormap)
        end
    end



                    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if strcmp(event.creator.name, CameraDisplay.NAME)
                if isfield(event.extraInfo, CameraDisplay.EVENT_IMAGE_UPDATED) || ...
                        event.isError
                    obj.update;
                end
            end
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