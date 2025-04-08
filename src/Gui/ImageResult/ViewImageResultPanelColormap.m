classdef ViewImageResultPanelColormap < GuiComponent
    %VIEWSTAGESCANPANELPLOT panel for coloring the image
    %   Detailed explanation goes here
    
    properties
        popupTypes  % popup/dropdown-menu. Chooses names of the available colormaps
        cbxAuto     % checkbox. Wheteher the colormap is auto-scaled
        edtMin      % edit-input. Minimum value of colormap
        edtMax      % edit-input. Maximum value of colormap
    end
    
    methods
        function obj = ViewImageResultPanelColormap(parent, controller)
            obj@GuiComponent(parent, controller);
            panel = uix.Panel('Parent', parent.component, 'Title', 'Colormap', 'Padding', 5);
            vboxMain = uix.VBox('Parent', panel, 'Spacing', 5, 'Padding', 0);
            obj.component = vboxMain;
            
            colormap1stRow = uix.HBox('Parent', vboxMain, 'Spacing', 5);
            obj.popupTypes = uicontrol(obj.PROP_POPUP{:}, ...
                'Parent', colormap1stRow, ...
                'String', ImageScanResult.COLORMAP_OPTIONS, ...
                'Callback', @obj.popupTypesCallback);
            uix.Empty('Parent', colormap1stRow);
            obj.cbxAuto = uicontrol(obj.PROP_CHECKBOX{:}, ...
                'Parent', colormap1stRow, ...
                'String', 'Auto', ...
                'Value', true, ...
                'Callback', @obj.cbxAutoCallback);
            colormap1stRow.Widths = [-1 15 50];
            
            colormap2ndRow = uix.HBox('Parent', vboxMain, 'Spacing', 5);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', colormap2ndRow, ...
                'String', 'Min');  % Label
            obj.edtMin = uicontrol(obj.PROP_EDIT{:}, ...
                'Parent', colormap2ndRow, ...
                'String', 0, ...
                'Callback', @obj.edtMinCallback);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', colormap2ndRow, ...
                'String', 'Max');  % Label
            obj.edtMax = uicontrol(obj.PROP_EDIT{:}, ...
                'Parent', colormap2ndRow, ...
                'String', 1, ...
                'Callback', @obj.edtMaxCallback);
            colormap2ndRow.Widths =  [-1 -1 -1 -1];
            
            vboxMain.Heights = [25 -1];
            obj.height = 100;
            obj.width = 160;
            
            try
                obj.update;     % It might not succeed if there is no image
            catch
                % There is nothing we can do, for now
            end
        end
        
        function update(obj)
            % Get values from ImageScanResult
            imageScanResult = obj.getImageScanResult();
            obj.popupTypes.Value = imageScanResult.colormapType;
            
            obj.cbxAuto.Value = imageScanResult.colormapAuto;
            
            minVal = imageScanResult.colormapLimits(1);
            obj.edtMin.String = StringHelper.formatNumber(minVal,2);
            
            maxVal = imageScanResult.colormapLimits(2);
            obj.edtMax.String = StringHelper.formatNumber(maxVal,2);
        end
           
        
        
        %%%% Callbacks %%%%
        function popupTypesCallback(obj, ~, ~)
            colormapType = obj.popupTypes.Value;
            
            imageScanResult = obj.getImageScanResult();
            imageScanResult.colormapType = colormapType;
            imageScanResult.imagePostProcessing;    % which now updates added layer (including colormap)
        end
        
        function cbxAutoCallback(obj, ~, ~)
            imageScanResult = obj.getImageScanResult();
            imageScanResult.colormapAuto = obj.cbxAuto.Value;
            if imageScanResult.colormapAuto
                if imageScanResult.isDataAvailable
                    % Update added layer (including colormap)
                    imageScanResult.imagePostProcessing;
                    % Now get the calculated limits from ImageSR
                    limits = imageScanResult.colormapLimits;    % = [minVal maxVal]
                    obj.edtMin.String = StringHelper.formatNumber(limits(1),2);
                    obj.edtMax.String = StringHelper.formatNumber(limits(2),2);
                else
                    obj.edtMin.String = 0;
                    obj.edtMax.String = 1;
                end
            end
        end
        
        function edtMinCallback(obj, ~, ~)
            imageScanResult = obj.getImageScanResult();
            limits = imageScanResult.colormapLimits;     % = [minVal maxVal]
            
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
            imageScanResult.colormapAuto = false;
            imageScanResult.colormapLimits(1) = newMinVal;
            imageScanResult.imagePostProcessing;    % Updates added layer (including colormap)
        end
        
        function edtMaxCallback(obj, ~, ~)
            imageScanResult = obj.getImageScanResult();
            limits = imageScanResult.colormapLimits;     % = [minVal maxVal]
            
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
            imageScanResult.colormapAuto = false;
            imageScanResult.colormapLimits(2) = newMaxVal;
            imageScanResult.imagePostProcessing;    % Updates added layer (including colormap)
        end
    end
    
    methods (Static)
        function isr = getImageScanResult
            isr = getObjByName(ImageScanResult.NAME);
            if isempty(isr)
                throwBaseObjException(ImageScanResult.NAME);
            end
        end
    end
    
end