classdef ViewCameraResult < ViewVBox
    %VIEWSTAGESCAN this view shows the scan results of the imaging
    %   consists of a header part and the image (axes) part 
    % the same purpose as ViewImageResult
    
    properties
        vHeader % the options view
        vImage  % the image view
    end
    
    methods
        function obj = ViewCameraResult(parent, controller, minImageSize)
            if ~exist('minImageSize', 'var'); minImageSize = []; end
            obj@ViewVBox(parent, controller);
            obj.vHeader = ImageOptions(obj, controller);
            %obj.vHeader.startListeningTo(ImageScanResult.NAME);     % This will ensure that header actions will occur after image has updated
            obj.vImage = ViewCameraResultImage(obj, controller, minImageSize);
            
            obj.height = obj.vHeader.height + obj.vImage.height + 10;
            obj.width = max([obj.vHeader.width, obj.vImage.width]) + 10;
            if ~isempty(minImageSize); obj.width = 600; end
            
            obj.setHeights([obj.vHeader.height, -1]);
        end
    end
end
