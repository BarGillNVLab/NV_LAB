classdef ViewImageResultPanelCursor < GuiComponent
    %VIEWSTAGESCANPANELPLOT panel for the cursor
    %   Detailed explanation goes here
    
    properties
        radioMarker     % #1
        radioZoom       % #2
        radioLocation   % #3
    end
    
    methods
        function obj = ViewImageResultPanelCursor(parent, controller)
            obj@GuiComponent(parent, controller);
            %             panel = uix.Panel('Parent', parent.component,'Title','Colormap', 'Padding', 5);
            bgMain = uibuttongroup(...
                'Parent', parent.component, ...
                'Title', 'Cursor', ...
                'SelectionChangedFcn',@obj.callbackRadioSelection);
            obj.component = bgMain;
            
            rbHeight = 15; % "rb" stands for "radio button"
            rbWidth = 70;
            paddingFromLeft = 10;
            
            obj.radioMarker = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgMain, ...
                'String', 'Marker', ...
                'Position', [paddingFromLeft 60 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', ImageScanResult.CURSOR_OPTIONS{1});
            obj.radioZoom = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgMain, ...
                'String', 'Zoom', ...
                'Position', [paddingFromLeft 35 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', ImageScanResult.CURSOR_OPTIONS{2});
            obj.radioLocation = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgMain, ...
                'String', 'Move to', ...
                'Position', [paddingFromLeft 10 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', ImageScanResult.CURSOR_OPTIONS{3});
            
            obj.height = 100;
            obj.width = 90;
        end
        
        function update(obj)
            % Executes when image updates
            obj.component.SelectedObject = obj.radioMarker;
        end
        
        %%%% Callbacks %%%%
        function callbackRadioSelection(obj, ~, event)
            imageScanResult = getObjByName(ImageScanResult.NAME);
            if isempty(imageScanResult); throwBaseObjException(ImageScanResult.NAME); end
            
            action = event.NewValue.Tag;
            imageScanResult.updateDataCursor(action);
            if event.NewValue == obj.radioZoom
                obj.backToMarker
            end
        end
    end
    
    methods (Access = private)
        function backToMarker(obj)
            % When other operations finish, we want to return the cursor to
            % "marker" mode, both visually and functionally
            obj.radioMarker.Value = true;
            
            imageScanResult = getObjByName(ImageScanResult.NAME);
            if isempty(imageScanResult); throwBaseObjException(ImageScanResult.NAME); end
            
            action = imageScanResult.CURSOR_OPTIONS{1};
            imageScanResult.updateDataCursor(action);    % functionally
        end
    end
end
