classdef ViewImageResultPanelBinning < GuiComponent
    %ViewImageResultPanelBinning
    %   Detailed explanation goes here
    
    properties
        radioKcps       % #1
        radioLifetime   % #2
    end
    
    methods
        function obj = ViewImageResultPanelBinning(parent, controller)
            obj@GuiComponent(parent, controller);
            %             panel = uix.Panel('Parent', parent.component,'Title','Colormap', 'Padding', 5);
            bgMain = uibuttongroup(...
                'Parent', parent.component, ...
                'Title', 'Image', ...
                'SelectionChangedFcn',@obj.callbackRadioSelection);
            obj.component = bgMain;
            
            rbHeight = 15; % "rb" stands for "radio button"
            rbWidth = 70;
            paddingFromLeft = 10;
            
            obj.radioKcps = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgMain, ...
                'String', 'kcps', ...
                'Position', [paddingFromLeft 60 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', ImageScanResult.IMAGE_OPTIONS{1});
            obj.radioLifetime = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgMain, ...
                'String', 'Lifetime', ...
                'Position', [paddingFromLeft 35 rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', ImageScanResult.IMAGE_OPTIONS{2});
            
            obj.height = 100;
            obj.width = 90;
        end
        
        function update(obj)
            % Executes when image updates
            % Get values from ImageScanResult
            imageScanResult = getObjByName(ImageScanResult.NAME);
            if ~isempty(imageScanResult.mHist)
                obj.radioLifetime.Enable = 'on';
            else
                obj.radioLifetime.Enable = 'off';
            end
            switch imageScanResult.imageType
                case 1
                    obj.component.SelectedObject = obj.radioKcps;
                case 2
                    obj.component.SelectedObject = obj.radioLifetime;
            end
        end
        
        %%%% Callbacks %%%%
        function callbackRadioSelection(obj, ~, event) %#ok<INUSL>
            imageScanResult = getObjByName(ImageScanResult.NAME);
            action = event.NewValue.Tag;
            actionIndex = find(strcmp(action, ImageScanResult.IMAGE_OPTIONS));
            imageScanResult.imageType = actionIndex;
            imageScanResult.update;
        end
    end
end