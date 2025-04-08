classdef ViewImageMW < GuiComponent
    %VIEWSTAGESCANPANELPLOT panel for the cursor
    %   Detailed explanation goes here
    
    properties
        radioDifference   % #1
        radioRatio          % #2
        radioWithout        % #3
        radioWith           % #4
    end
    
    methods
        function obj = ViewImageMW(parent, controller)
            obj@GuiComponent(parent, controller);
            %             panel = uix.Panel('Parent', parent.component,'Title','Colormap', 'Padding', 5);
            bgMain = uibuttongroup(...
                'Parent', parent.component, ...
                'Title', 'MW Contrast', ...
                'SelectionChangedFcn',@obj.callbackRadioSelection);
            obj.component = bgMain;
            
            rbHeight = 15; % "rb" stands for "radio button"
            rbWidth = 70;
            paddingFromBottom = 10;
            
            obj.radioDifference = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgMain, ...
                'String', 'Diff', ...
                'Position', [3*rbWidth+20 paddingFromBottom rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', ImageScanResult.CONTRAST_OPTIONS{1});
            obj.radioRatio = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgMain, ...
                'String', 'Ratio', ...
                'Position', [2*rbWidth+15 paddingFromBottom rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', ImageScanResult.CONTRAST_OPTIONS{2});
            obj.radioWithout = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgMain, ...
                'String', 'Without', ...
                'Position', [rbWidth+10 paddingFromBottom rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', ImageScanResult.CONTRAST_OPTIONS{3});
            obj.radioWith = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgMain, ...
                'String', 'With', ...
                'Position', [5 paddingFromBottom rbWidth rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'Tag', ImageScanResult.CONTRAST_OPTIONS{4});
            
            obj.height = 40;
            obj.width = 320;
        end
        
        % function update(obj)
        %     % Executes when image updates
        %     % Get values from ImageScanResult
        %     imageScanResult = getObjByName(ImageScanResult.NAME);
        %     if size(imageScanResult.mData, imageScanResult.mDimNumber+1) == 2 % Contrast Imaging
        %         obj.radioDifference.Enable = 'on';
        %         obj.radioRatio.Enable = 'on';
        %         obj.radioWithout.Enable = 'on';
        %         obj.radioWith.Enable = 'on';
        %         switch imageScanResult.contrastType
        %             case 1
        %                 obj.component.SelectedObject = obj.radioDifference;
        %             case 2
        %                 obj.component.SelectedObject = obj.radioRatio;
        %             case 3
        %                 obj.component.SelectedObject = obj.radioWithout; 
        %             case 4
        %                 obj.component.SelectedObject = obj.radioWith;
        %         end
        %     else
        %         obj.component.SelectedObject = obj.radioDifference;
        %         obj.radioDifference.Enable = 'off';
        %         obj.radioRatio.Enable = 'off';
        %         obj.radioWithout.Enable = 'off';
        %         obj.radioWith.Enable = 'off';
        %     end
        % end
        % 
        %%%% Callbacks %%%%
        % function callbackRadioSelection(obj, ~, event) %#ok<INUSL>
        %     imageScanResult = getObjByName(ImageScanResult.NAME);
        %     action = event.NewValue.Tag;
        %     actionIndex = find(strcmp(action, ImageScanResult.CONTRAST_OPTIONS));
        %     imageScanResult.contrastType = actionIndex;
        %     imageScanResult.update;
        % end
    end
end