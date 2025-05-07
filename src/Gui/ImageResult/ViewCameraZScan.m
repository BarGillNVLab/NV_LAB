classdef ViewCameraZScan < GuiComponent
    % this class is for choosing the display of a focal plane search scan with a camera
    
    properties
        radioAverages       % #1
        radioFocusGrade            % #2
    end
    
    methods
        function obj = ViewCameraZScan(parent, controller)
            obj@GuiComponent(parent, controller);
            bgMain = uibuttongroup(...
                'Parent', parent.component, ...
                'Title', 'Scan display', 'SelectionChangedFcn', @obj.callbackRadioSelection);
            obj.component = bgMain;
            
            rbHeight = 35; % "rb" stands for "radio button"
            rbWidth = 80;
            paddingFromLeft = 10;
            
            obj.radioAverages = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgMain, ...
                'Style', 'radiobutton','String','<html><center>Average<br>Counts</center></html>', ...
                'Position', [paddingFromLeft 45 rbWidth rbHeight], 'Tag', ImageScanResult.SCAN_OPTIONS{1}); % [fromLeft, fromBottom, width, height]
                %'Tag', ImageScanResult.CONTRAST_OPTIONS{1});
            obj.radioFocusGrade = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgMain, ...
                 'Style', 'radiobutton', 'String', '<html><center>Focus<br>Grade</center></html>', ...
                'Position', [paddingFromLeft 5 rbWidth rbHeight], 'Tag', ImageScanResult.SCAN_OPTIONS{2});  % [fromLeft, fromBottom, width, height]
               % 'Tag', ImageScanResult.CONTRAST_OPTIONS{2});
            
            obj.height = 100;
            obj.width = 100;
        end
        
        function update(obj)
            % Executes when image updates
            % Get values from ImageScanResult
            imageScanResult = getObjByName(ImageScanResult.NAME);
            switch imageScanResult.scanType
                case 1
                    obj.component.SelectedObject = obj.radioAverages;
                case 2
                    obj.component.SelectedObject = obj.radioFocusGrade;
               
            end
            
        end

        %%%% Callbacks %%%%
        function callbackRadioSelection(obj, ~, event) %#ok<INUSL>
            imageScanResult = getObjByName(ImageScanResult.NAME);
            action = event.NewValue.Tag;
            actionIndex = find(strcmp(action, ImageScanResult.SCAN_OPTIONS));
            imageScanResult.scanType = actionIndex;
            imageScanResult.update;
        end
    end
end