classdef ViewCameraZScan < GuiComponent
    % this class is for choosing the display of a focal plane search scan with a camera
    
    properties
        radioAverages       % #1
        radioFFT            % #2
        radioBoth            % #3
    end
    
    methods
        function obj = ViewCameraZScan(parent, controller)
            obj@GuiComponent(parent, controller);
            bgMain = uibuttongroup(...
                'Parent', parent.component, ...
                'Title', 'Scan display');
               % 'SelectionChangedFcn',@obj.callbackRadioSelection);
            obj.component = bgMain;
            
            rbHeight = 20; % "rb" stands for "radio button"
            rbWidth = 80;
            paddingFromLeft = 10;
            
            obj.radioAverages = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgMain, ...
                'String', 'Averages', ...
                'Position', [paddingFromLeft 55 rbWidth rbHeight]); % [fromLeft, fromBottom, width, height]
                %'Tag', ImageScanResult.CONTRAST_OPTIONS{1});
            obj.radioFFT = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgMain, ...
                'String', 'FFT', ...
                'Position', [paddingFromLeft 30 rbWidth rbHeight]);  % [fromLeft, fromBottom, width, height]
               % 'Tag', ImageScanResult.CONTRAST_OPTIONS{2});
            obj.radioBoth = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgMain, ...
                'String', 'Both', ...
                'Position', [paddingFromLeft 5 rbWidth rbHeight]); % [fromLeft, fromBottom, width, height]
                %'Tag', ImageScanResult.CONTRAST_OPTIONS{3});
            
            
            obj.height = 100;
            obj.width = 90;
        end
    end
end
        
%         function update(obj)
%             % Executes when image updates
%             % Get values from ImageScanResult
%             imageScanResult = getObjByName(ImageScanResult.NAME);
%             if size(imageScanResult.mData, imageScanResult.mDimNumber+1) == 2 % Contrast Imaging
%                 obj.radioAverages.Enable = 'on';
%                 obj.radioRatio.Enable = 'on';
%                 obj.radioWithout.Enable = 'on';
%                 obj.radioWith.Enable = 'on';
%                 switch imageScanResult.contrastType
%                     case 1
%                         obj.component.SelectedObject = obj.radioAverages;
%                     case 2
%                         obj.component.SelectedObject = obj.radioRatio;
%                     case 3
%                         obj.component.SelectedObject = obj.radioWithout; 
%                     case 4
%                         obj.component.SelectedObject = obj.radioWith;
%                 end
%             else
%                 obj.component.SelectedObject = obj.radioAverages;
%                 obj.radioAverages.Enable = 'off';
%                 obj.radioRatio.Enable = 'off';
%                 obj.radioWithout.Enable = 'off';
%                 obj.radioWith.Enable = 'off';
%             end
%         end
% 
%         %%%% Callbacks %%%%
%         function callbackRadioSelection(obj, ~, event) %#ok<INUSL>
%             imageScanResult = getObjByName(ImageScanResult.NAME);
%             action = event.NewValue.Tag;
%             actionIndex = find(strcmp(action, ImageScanResult.CONTRAST_OPTIONS));
%             imageScanResult.contrastType = actionIndex;
%             imageScanResult.update;
%         end
%     end
% end