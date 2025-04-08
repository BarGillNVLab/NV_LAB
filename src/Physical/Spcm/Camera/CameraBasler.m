classdef CameraBasler < Camera & EventSender
    % The connetion to this camera is using Matlab Image Acquisition Toolbox 

    properties (Constant, Hidden)
        NEEDED_FIELDS = [Camera.NEEDED_FIELDS_GENERAL, {}];
    end

    properties (Constant)
        ROI_DEFULT = [0 0 1920 1200];
        MAX_ROI = [0 0 1936 1216];
        UNIT_CONV = 1e3;                % us of the general code to Basler camera ms units
        PIXEL_WIDTH = 5.86;    % pixel physical width [micrometeres]
        PIXEL_LENGTH = 5.86;   % pixel physical length [micrometeres]
%         PIXEL_SIZE = obj.PIXEL_WIDTH*obj.PIXEL_LENGTH;
        EVENT_IMAGE_TAKEN = 'imageacquired';
        EXPOSURE_TIME_LIMITS = [0.02 1e04]; % exposure time limits in milliseconds
        DEFAULT_EXPOSURE_TIME = 10;
    end

    properties
        vid     % video input object
        src     % video source object
%         IsAcquiring
%         stride
%         trigger
%         fps
%         src
%         Image_data
%         CPPB_on
%         CPP_count
%         CPP_go
%         CPP
%         CPP_rect_Position
%         CPP_rect
        vidParams
    end

    methods
        function obj = CameraBasler(address)
            % Constructor: Initializes the Basler camera
            obj@Camera;
            obj@EventSender(Camera.NAME);
            try
                obj.vid = videoinput(address.adaptor, address.device_id, address.format);
            catch
                warning('Could not find any camera.');
                return;
            end
            obj.src = getselectedsource(obj.vid);
            obj.vid.ReturnedColorspace = 'grayscale';
            obj.src.ExposureAuto = 'Off';
            obj.src.ExposureTime = obj.DEFAULT_EXPOSURE_TIME * obj.UNIT_CONV;
            obj.src.BinningVerticalMode = 'Sum';
            obj.src.BinningHorizontalMode = 'Sum';
            obj.vidParams = get(obj.vid);
            obj.initScanParams;
            
%             obj.imgparams.exposureTime = obj.src.ExposureTime;
        end

       

        %% Set functions:
        function initScanParams(obj)
            obj.imgparams = CameraImageParams;
            obj.setBinning(1);
            obj.setExposureTime(obj.DEFAULT_EXPOSURE_TIME);
            obj.setROI(obj.ROI_DEFULT);
        end




        function setROI(obj, newROI)
            % Set the region of interest (ROI)
            if length(newROI) ~= 4
                error('ROI must be a vector of length 4: [x_init, y_init, width, hight]');
            end
            obj.vid.ROIPosition = newROI;
            obj.imgparams.roi = newROI;
            obj.sendEventScanParamsChanged;
        end

        function setExposureTime(obj, t)
            obj.src.ExposureAuto = 'Off';
            obj.src.ExposureTime = t*obj.UNIT_CONV;
            obj.imgparams.exposuretime = t*obj.UNIT_CONV;
            obj.sendEventScanParamsChanged;
        end

        function setBinning(obj, bin)
            % Set the binning factor
            cameraOn = islogging(obj.vid);
            if cameraOn
                stop(obj.vid);
            end
            obj.src.BinningHorizontal = bin;
            obj.src.BinningVertical = bin;
            obj.binning = bin;
            if cameraOn
                start(obj.vid);
            end
            obj.imgparams.roi = obj.vid.ROIPosition;
            obj.sendEventScanParamsChanged;
        end

        %% Acquiring functions

        function StartRead(obj)
            start(obj.vid);
        end

        function imageData = ImageAcquire(obj)
            % Start image acquisition
            imageData = getsnapshot(obj.vid);
        end

        function SoftwareTrigger(obj)
            % Trigger camera acquisition via software
            trigger(obj.vid);
        end

        function prepareRead(~, ~)
            % Prepare for reading images (placeholder for future use)
        end

        function avimg = read(obj, numFrames, timedelay)
            % Read acquired images
            img = zeros(obj.vid.VideoResolution(2), obj.vid.VideoResolution(1), numFrames);
            if exist("timedelay", "var")
                for i = 1:numFrames
                    img(:,:,i) = getdata(obj.vid);
                    pause(timedelay/1000);
                end
            else
                img(:,:,:) = getdata(obj.vid,numFrames);
            end
            avimg = mean(img,3);
        end

        function stopRead(obj)
            % Stop image acquisition
            stop(obj.vid);
        end

        function imageSaveImage(obj, filename)
            % Save the last acquired image
            img = getdata(obj.vid);
            imwrite(img, filename);
        end

        function imageUpload(~, ~)
            % Placeholder for image upload functionality
        end

        function imageCPP(~, ~)
            % Placeholder for CPP image processing functionality
        end

    end

%%
    methods (Static, Access = public)
        function obj = getInstance(struct)
            % Returns a singelton instance.
            obj = getObjByName(Camera.NAME);
            if isempty(obj)
                % None exists, so we create a new one
                missingField = FactoryHelper.usualChecks(struct, CameraBasler.NEEDED_FIELDS);
                if ~isnan(missingField)
                    error('Error while creating a camera object: missing field "%s"!', missingField);
                end

                address = struct.address;
                obj = CameraBasler(address);
                addBaseObject(obj);
            end
        end
    end
end