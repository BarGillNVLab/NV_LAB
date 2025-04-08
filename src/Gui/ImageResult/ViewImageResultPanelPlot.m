classdef ViewImageResultPanelPlot < GuiComponent
    %VIEWSTAGESCANPANELPLOT panel for plotting the image
    
    properties
        popupStyle
    end
    
    methods
        function obj = ViewImageResultPanelPlot(parent, controller)
            obj@GuiComponent(parent, controller);
            panel = uix.Panel('Parent', parent.component, ...
                'Title', 'Plot Options', ...
                'Padding', 5);
            vboxMain = uix.VBox('Parent', panel, ...
                'Spacing', 5, 'Padding', 0);
            obj.component = vboxMain;
            
            obj.popupStyle = uicontrol(obj.PROP_POPUP{:}, ...
                'Parent', vboxMain, ...
                'String', ImageScanResult.PLOT_STYLE_OPTIONS_2D, ...
                'Callback', @obj.popupStyleCallback);
            uicontrol(obj.PROP_BUTTON{:}, ...
                'Parent', vboxMain, ...
                'String', 'Figure', ...
                'Callback', @obj.btnOpenInFigureCallback);
            
            vboxMain.Heights = [25 -1];
            obj.height = 120;
            obj.width = 120;
            
            obj.update;
        end

        function update(obj)
            % Get data from ImageScanResult, and apply on views
            imageScanResult = getObjByName(ImageScanResult.NAME);
            if isempty(imageScanResult); throwBaseObjException(ImageScanResult.NAME); end
            switch imageScanResult.mDimNumber
                case 1
                    obj.popupStyle.String = ImageScanResult.PLOT_STYLE_OPTIONS_1D;
                case 2
                    obj.popupStyle.String = ImageScanResult.PLOT_STYLE_OPTIONS_2D;
            end
            obj.popupStyle.Value = imageScanResult.plotStyle;
        end
    end
       
    methods (Access = private)
        %%%% Callbacks %%%%        
        function btnOpenInFigureCallback(obj, ~, ~) %#ok<INUSD>
            imageScanResult = getObjByName(ImageScanResult.NAME);
            if isempty(imageScanResult); throwBaseObjException(ImageScanResult.NAME); end
            isVisible = true;
            imageScanResult.copyToFigure(isVisible);
        end
        
        function popupStyleCallback(obj, ~, ~)
            imageScanResult = getObjByName(ImageScanResult.NAME);
            if isempty(imageScanResult); throwBaseObjException(ImageScanResult.NAME); end
            
            imageScanResult.plotStyle = obj.popupStyle.Value;
            imageScanResult.imagePostProcessing;    % Update added layer (including plot style)
        end
    end
    
end