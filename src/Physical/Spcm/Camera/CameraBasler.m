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
        MAXIMUM_BINNING = 4;
    end

    properties
        vid     % video input object
        src     % video source object
        currentdata
        allData
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
        
    end

    methods
        function obj = CameraBasler(address)
            % Constructor: Initializes the Basler camera
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
            obj.vid.FramesPerTrigger = 1;
            obj.setExposureAuto(0);
            obj.src.ExposureTime = obj.DEFAULT_EXPOSURE_TIME * obj.UNIT_CONV;
            obj.src.BinningVerticalMode = 'Sum';
            obj.src.BinningHorizontalMode = 'Sum';
            triggerconfig(obj.vid, 'manual');
            obj.allData ={};
            obj.initScanParams;
            
%             obj.imgparams.exposureTime = obj.src.ExposureTime;
        end

       

        %% Set & Get functions:
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




        function setROI(obj, newROI)
            % Set the region of interest (ROI)
            if length(newROI) ~= 4
                error('ROI must be a vector of length 4: [x_init, y_init, width, hight]');
            end
            try
                set(obj.vid,'ROIPosition',  newROI);
                v = get(obj.vid);
                ROI = getfield(v,'ROIPosition');
                if ROI ~= newROI
                    obj.imgparams.roi = ROI;
                else
                    obj.imgparams.roi = newROI;
                end
                obj.sendEventScanParamsChanged;
                
            catch
                obj.sendError('ROI implemntation was unsuccessful');
            end
        end

        function [x_init, y_init, width, hight] = getROI(obj)
            [x_init, y_init, width, hight] = obj.imgparams.roi;
        end

        function setExposureTime(obj, t)
            obj.setExposureAuto(0);
            obj.src.ExposureTime = t*obj.UNIT_CONV;
            obj.imgparams.exposuretime = t*obj.UNIT_CONV;
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
        
%         function [width, length] = get

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
                    obj.src.TriggerSelector = 'FrameStart';     % Trigger one frame per signal
                    obj.src.TriggerMode = 'On';
                otherwise
                    obj.sendError(['Trigger type %s does not exist', Type])
            end
        end

        function setBinning(obj, bin)
            % Set the binning factor
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
            roi = [xOffset yOffset nwidth nlength];
            obj.setROI(roi);
            obj.imgparams.binning = bin;
            obj.sendEventScanParamsChanged;
        end

        function on = IsLoggin(obj)
            log = obj.vid.Logging;
            if strcmp(log, 'on')
                on = 1;
            elseif strcmp(log, 'off')
                on = 0;
            end
        end

        function setTriggerRepeats(obj, repeats)
            obj.vid.TriggerRepeat = repeats;
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
            if strcmp(obj.vid.Running, 'off')
                start(obj.vid);
            end
            trigger(obj.vid);
            
        end

        function framesPerTrigger(obj, framespertrigger)
            obj.vid.FramesPerTrigger = framespertrigger;
        end

        function prepareRead(~, ~)
            % Prepare for reading images (placeholder for future use)
        end

        function img = read(obj, numFrames, timedelay)
            % Read acquired images
            img = zeros(obj.imgparams.roi(4), obj.imgparams.roi(3), numFrames);
            try
                if exist("timedelay", "var")
                    for i = 1:numFrames
                        if strcmp(obj.vid.Running, 'off')
                            start(obj.vid);
                        end
                        trigger(obj.vid);
                        img(:,:,i) = getdata(obj.vid);
%                         if strcmp(obj.src.ExposureAuto, 'Continuous')
%                             obj.setExposureTime(obj.src.ExposureTime);
%                         end
                        pause(timedelay/1000);
                    end
                else
                    img(:,:,:) = getdata(obj.vid,numFrames);
                end
            catch
                obj.sendError('Image Aquisition was unsuccessful');
            end
        end

        function images = readfromcamera(obj, nframes)
            try
                disp(obj.vid.FramesAvailable);
                images = getdata(obj.vid, nframes);
            catch ME
                disp(getReport(ME))
            end 
        end


        function stopRead(obj)
            % Stop image acquisition
            stop(obj.vid);
        end

        function clearMemory(obj)
            flushdata(obj.vid);
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

        % helper
        function newOffset = offset_calculation(obj, newBinning, initialOffset)
        %OFFSET_CALCULATION Adjusts ROI offset when binning changes
        %
        %   newOffset = offset_calculation(initialBinning, newBinning, initialOffset)
        %
        %   Inputs:
        %       initialBinning - initial binning factor (e.g., 1, 2, 4)
        %       newBinning     - new binning factor (e.g., 2, 4)
        %       initialOffset  - original offset in pixels
        %
        %   Output:
        %       newOffset      - new offset, adjusted for binning and rounded to nearest multiple of 4
        
            % Validate input
            initialBinning = obj.imgparams.binning;
            if initialBinning <= 0 || newBinning <= 0
                error('Binning values must be positive.');
            end
        
            % Scale the offset according to binning change
            scaledOffset = initialOffset * initialBinning / newBinning;
        
            % Round down to the nearest multiple of 4
            newOffset = floor(scaledOffset / 4) * 4;
        end

        function newDimension = roi_dimension_calculation(obj, newBinning, initialDimension)
        %ROI_DIMENSION_CALCULATION Adjusts ROI width or height when binning changes
        %
        %   newDimension = roi_dimension_calculation(initialBinning, newBinning, initialDimension)
        %
        %   Inputs:
        %       initialBinning    - original binning factor (e.g., 1, 2, 4)
        %       newBinning        - new binning factor
        %       initialDimension  - original ROI width or height
        %
        %   Output:
        %       newDimension      - new ROI dimension, scaled and rounded down to nearest multiple of 4
        
            % Validate input
            initialBinning = obj.imgparams.binning;
            if initialBinning <= 0 || newBinning <= 0
                error('Binning values must be positive.');
            end
        
            % Scale the dimension according to binning change
            scaledDimension = initialDimension * initialBinning / newBinning;
        
            % Round down to the nearest multiple of 4
            newDimension = floor(scaledDimension / 4) * 4;
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