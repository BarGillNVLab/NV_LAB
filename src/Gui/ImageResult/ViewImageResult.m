classdef ViewImageResult < ViewVBox
    %VIEWSTAGESCAN this view shows the scan results of the imaging
    %   consists of a header part and the image (axes) part 
    
    properties
        vHeader % the options view
        vImage  % the image view
    end
    
    methods
        function obj = ViewImageResult(parent, controller, minImageSize, camera)
            if ~exist('minImageSize', 'var'); minImageSize = []; end
            if ~exist('camera', 'var'); camera = []; end
            obj@ViewVBox(parent, controller);
            obj.vHeader = ViewImageResultHeader(obj, controller, camera);
            obj.vHeader.startListeningTo(ImageScanResult.NAME);     % This will ensure that header actions will occur after image has updated
            obj.vImage = ViewImageResultImage(obj, controller, minImageSize);
            
            obj.height = obj.vHeader.height + obj.vImage.height + 10;
            obj.width = max([obj.vHeader.width, obj.vImage.width]) + 10;
            if ~isempty(minImageSize); obj.width = 600; end
            
            obj.setHeights([obj.vHeader.height, -1]);
        end
    end
end

