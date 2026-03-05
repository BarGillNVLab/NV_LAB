classdef CameraBasler < Camera & EventSender
    % The connection to this camera uses the MATLAB Image Acquisition Toolbox

    %% Constant properties
    properties (Constant, Hidden)
        NEEDED_FIELDS = [Camera.NEEDED_FIELDS_GENERAL, {}];
    end

    properties (Constant)
        ROI_DEFULT = [0 0 1920 1200];
        MAX_ROI = [0 0 1936 1216];
        UNIT_CONV = 1e3;                      % us to ms conversion for Basler camera
        PIXEL_WIDTH = 5.86;                   % pixel width in micrometers
        PIXEL_LENGTH = 5.86;                  % pixel length in micrometers
        EVENT_IMAGE_TAKEN = 'imageacquired';
        EXPOSURE_TIME_LIMITS = [0.02 1e04];   % exposure time limits in ms
        DEFAULT_EXPOSURE_TIME = 10;           % default exposure time in ms
        MAXIMUM_BINNING = 4;
        DELAY_BETWEEN_TRIGGERS = 5000;        % minimum delay of 5 ms between triggers (in us)
    end

    %% Public properties
    properties
        vid             % video input object
        src             % video source object
    end

    %% Constructor and setup methods
    methods
        function obj = CameraBasler(address)
            imaqreset;
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
            obj.resetToDefault;
            obj.vid.FramesPerTrigger = 1;
            obj.setExposureAuto(0);
            obj.src.ExposureTime = obj.DEFAULT_EXPOSURE_TIME * obj.UNIT_CONV;
            obj.src.BinningVerticalMode = 'Sum';
            obj.src.BinningHorizontalMode = 'Sum';
            triggerconfig(obj.vid, 'manual');
            obj.initScanParams;
            obj.vid.UserData = struct('TriggerCount', 0);
            obj.vid.TriggerFcn = @(src, event) obj.triggerCounter(src, event);
        end

        function initScanParams(obj)
            obj.imgparams = CameraImageParams;
            cameraOn = islogging(obj.vid);
            if cameraOn
                stop(obj.vid);
            end
            obj.setBinning(1);
            obj.setExposureTime(obj.DEFAULT_EXPOSURE_TIME);
            obj.setROI(obj.ROI_DEFULT);
        end

        function on = IsLoggin(obj)
            log = obj.vid.Logging;
            if strcmp(log, 'on')
                on = 1;
            elseif strcmp(log, 'off')
                on = 0;
            end
        end


    end

    %% Trigger and acquisition settings
    methods
        function trigType = getTriggerType(obj)
            trigType = obj.vid.TriggerType;
        end

        function setTriggerType(obj, type)
            cameraOn = islogging(obj.vid);
            isrunning = obj.vid.Running;
            if cameraOn || strcmp(isrunning, 'on')
                stop(obj.vid);
            end

            Type = lower(type);
            switch Type
                case 'manual'
                    triggerconfig(obj.vid, Type);
                    obj.src.TriggerMode = 'Off';
                    obj.src.TriggerSource = 'Software';
                    obj.src.TriggerSelector = 'FrameStart';
                case 'immediate'
                    triggerconfig(obj.vid, Type);
                    obj.src.TriggerSelector = 'FrameStart';
                    obj.src.TriggerMode = 'Off';
                case 'hardware'
                    triggerconfig(obj.vid, Type, 'DeviceSpecific', 'DeviceSpecific');
                    obj.src.TriggerSource = 'Line1';
                    obj.src.TriggerSelector = 'FrameStart';
                    obj.src.TriggerMode = 'On';
                otherwise
                    obj.sendError(['Trigger type %s does not exist', Type])
            end
        end

        function setTriggerRepeats(obj, repeats)
            obj.triggerRepeats = repeats;
            obj.vid.TriggerRepeat = repeats;
        end

        function framesPerTrigger(obj, framespertrigger)
            obj.vid.FramesPerTrigger = framespertrigger;
        end
    end

    %% ROI and exposure settings
    methods
        function setROI(obj, newROI)
            if length(newROI) ~= 4
                error('ROI must be a vector of length 4: [x_init, y_init, width, height]');
            end
            try
                set(obj.vid,'ROIPosition', newROI);
                v = get(obj.vid);
                ROI = v.ROIPosition;
                if ROI ~= newROI
                    obj.imgparams.roi = ROI;
                else
                    obj.imgparams.roi = newROI;
                end
                obj.sendEventScanParamsChanged;
            catch
                obj.sendError('ROI implementation was unsuccessful');
            end
        end

        function [x_init, y_init, width, height] = getROI(obj)
            ROIdata = obj.imgparams.roi;
            x_init = ROIdata(1);
            y_init = ROIdata(2);
            width = ROIdata(3);
            height = ROIdata(4);
        end

        function setExposureTime(obj, t)
            % exposure time set to the camera must be in microseconds
            obj.setExposureAuto(0);
            obj.src.ExposureTime = t * obj.UNIT_CONV;
            obj.imgparams.exposuretime = t * obj.UNIT_CONV;
            obj.sendEventScanParamsChanged;
        end

        function setExposureAuto(obj, state)
            if state
                obj.src.ExposureAuto = 'Continuous';
                obj.exposureAutoState = 1;
            else
                obj.src.ExposureAuto = 'Off';
                obj.exposureAutoState = 0;
            end
        end

        function state = getExposureAuto(obj)
            state = obj.exposureAutoState;
        end

        function setBinning(obj, bin)
            cameraOn = islogging(obj.vid);
            ROI = obj.imgparams.roi;
            ibin = obj.imgparams.binning;
            if cameraOn
                stop(obj.vid);
            end

            obj.src.BinningHorizontal = bin;
            obj.src.BinningVertical = bin;
            start(obj.vid);
            dummy = getsnapshot(obj.vid);
            stop(obj.vid);
            if cameraOn
                start(obj.vid);
            end

            nlength = obj.roi_dimension_calculation(bin, ROI(4));
            nwidth = obj.roi_dimension_calculation(bin, ROI(3));
            xOffset = obj.offset_calculation(bin, ROI(1));
            yOffset = obj.offset_calculation(bin, ROI(2));
            roi = [xOffset, yOffset, nwidth, nlength];
            obj.setROI(roi);
            obj.imgparams.binning = bin;
            obj.sendEventScanParamsChanged;
        end

        function newOffset = offset_calculation(obj, newBinning, initialOffset)
            initialBinning = obj.imgparams.binning;
            scaledOffset = initialOffset * initialBinning / newBinning;
            newOffset = floor(scaledOffset / 4) * 4;
        end

        function newDimension = roi_dimension_calculation(obj, newBinning, initialDimension)
            initialBinning = obj.imgparams.binning;
            scaledDimension = initialDimension * initialBinning / newBinning;
            newDimension = floor(scaledDimension / 4) * 4;
        end
    end

    %% Image acquisition
    methods
        function StartRead(obj)
            start(obj.vid);
        end

        function imageData = ImageAcquire(obj)
            imageData = getsnapshot(obj.vid);
        end

        function SoftwareTrigger(obj)
            if strcmp(obj.vid.Running, 'off')
                start(obj.vid);
            end
            trigger(obj.vid);
        end

        function img = read(obj, numFrames, timedelay)
            img = zeros(obj.imgparams.roi(4), obj.imgparams.roi(3), numFrames);
            try
                if exist("timedelay", "var")
                    for i = 1:numFrames
                        if strcmp(obj.vid.Running, 'off')
                            start(obj.vid);
                        end
                        trigger(obj.vid);
                        img(:,:,i) = getdata(obj.vid);
                        pause(timedelay/1000);
                    end
                else
                    img(:,:,:) = getdata(obj.vid, numFrames);
                end
            catch
                obj.sendError('Image Acquisition was unsuccessful');
            end
        end

        function images = readfromcamera(obj, nframes)
            % for the case an external trigger triggers the camera
            try
                images = getdata(obj.vid, nframes);
            catch ME
                disp(getReport(ME));
            end
        end

        function images = readExperimentData(obj, nframes)
            if obj.IsLoggin
                obj.stopRead;
            end
            try
                images = getdata(obj.vid, nframes);
                images = flipud(images);
            catch ME
                disp(getReport(ME));
            end
        end

        function stopRead(obj)
            stop(obj.vid);
        end

        function clearMemory(obj)
            flushdata(obj.vid);
        end

        function imageSaveImage(obj, filename)
            img = getdata(obj.vid);
            imwrite(img, filename);
        end
        function imageCPP(~,~)
             % Placeholder for CPP image processing functionality

        end
        function imageUpload(~, ~)
           % Placeholder for image upload functionality
        end
        function prepareRead(~,~)
               % Prepare for reading images (placeholder for future use)

        end
        function clearTimeRead(obj)
            obj.stopRead;
            cameraprop = obj.imgparams;
            if cameraprop.exposuretime ~= obj.src.ExposureTime
                cameraprop.exposuretime = obj.src.ExposureTime;
                obj.camera.sendEventScanParamsChanged;
            end
        end
    end

    %% Experiment preparation
    methods
        function prepareReadbyStage(obj, nPixels, timeout, pixelTime)
            obj.timeout = timeout;
            pixelTime = pixelTime*1e03;  % pixel time in millisec
            exposureTime = obj.imgparams.exposuretime*1e-3;
            if exposureTime > pixelTime
                obj.setExposureTime(obj.pixelTime-0.25*obj.pixelTime);
            end
            obj.setTriggerType('hardware');
            obj.framesPerTrigger(1);
            obj.setTriggerRepeats(nPixels);
            
        end
        
        function prepareExperiment(obj, nreads, timeout)
            if isrunning(obj.vid)
                stop(obj.vid);
            end
            trigtype = obj.getTriggerType;
            if ~strcmpi(trigtype, 'hardware')
                obj.setTriggerType('hardware');
            end
            obj.src.TriggerActivation = 'RisingEdge';
            obj.framesPerTrigger(1);
            obj.src.ExposureMode = 'TriggerWidth';
            obj.setTriggerRepeats(nreads);
            obj.vid.Timeout = timeout;
            obj.clearMemory;
            fprintf('[INFO] Camera is ready for hardware triggering (%d reads, %gs timeout).\n', nreads, timeout);
        end

        function resetToDefault(obj)
            % Reset camera parameters to default
            cameraOn = islogging(obj.vid);
            if cameraOn
                stop(obj.vid);
            end
            obj.setExposureAuto(0);
            obj.src.ExposureMode = 'Timed';
            obj.setExposureTime(obj.DEFAULT_EXPOSURE_TIME);
            obj.setTriggerType('manual');
            obj.framesPerTrigger(1);
            obj.setTriggerRepeats(0);
            obj.clearMemory;
            obj.sendEventScanParamsChanged;
            fprintf('[INFO] Camera parameters have been reset to default.\n');
        end
    end

    %% Singleton getter
    methods (Static, Access = public)
        function obj = getInstance(struct)
            obj = getObjByName(Camera.NAME);
            if isempty(obj)
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

    %% Private methods
    methods (Access = private)
        function triggerCounter(obj, ~, ~)
            data = get(obj.vid, 'UserData');
            if isfield(data, 'TriggerCount')
                data.TriggerCount = data.TriggerCount + 1;
            else
                data.TriggerCount = 1;
            end
            set(obj.vid, 'UserData', data);
        end
    end
end
