classdef CameraAndor < Camera & EventSender
    % CameraAndor interfaces with Andor SDK3 using native SDK functions
    % Written by Yogev

    %% Constant properties
    properties (Constant, Hidden)
        NEEDED_FIELDS = [Camera.NEEDED_FIELDS_GENERAL, {}];
    end

    % when updating the camera with a new roi the format is [left, top,
    % width, height]. when saving the roi in imageparams the format is
    % [left, bottom, width, height].
    properties (Constant)
        ROI_DEFULT = [1 1 2048 2048];
        MAX_ROI = [1 1 2560 2160];
        UNIT_CONV = 1;                       % ms as default for SDK3
        PIXEL_WIDTH = 6.5;                   % [µm], depends on model
        PIXEL_LENGTH = 6.5;
        EVENT_IMAGE_TAKEN = 'imageacquired';
        EXPOSURE_TIME_LIMITS = [0.00924 1.98e7];   % [ms]
        DEFAULT_EXPOSURE_TIME = 10;
        MAXIMUM_BINNING = 8;
        MAXSENSORTEMPERATURE = 25;      % C
        MINSENSORTEMPERAURE = -50;      %C
    end

    %% Public properties
    properties
        sdkCam              % handle to Andor SDK3 camera object
        currentdata         % latest image acquired
        rc
        DELAY_BETWEEN_TRIGGERS
        dummyparam          % sets properties that dont exist on this camera but exist in other cameras
    end

    %% Constructor
    methods
        function obj = CameraAndor()
            obj@Camera;
            obj@EventSender(Camera.NAME);

            try
                [obj.rc] = AT_InitialiseLibrary();  % hypothetical wrapper class
                [obj.rc,obj.sdkCam] = AT_Open(0);
            catch ME
                error('Failed to initialize Andor camera: %s', ME.message);
            end

            obj.resetToDefault;
            obj.initScanParams;
        end

        function initScanParams(obj)
            obj.imgparams = CameraImageParams;
            obj.stopRead;
            obj.clearMemory;
            obj.setBinning(1);
            obj.setExposureTime(obj.DEFAULT_EXPOSURE_TIME);
            obj.setROI(obj.ROI_DEFULT);
            AT_SetEnumIndex(obj.sdkCam, 'CycleMode', 2);
            obj.setMinDelay;
            [obj.rc] = AT_SetEnumString(obj.sdkCam, 'ElectronicShutteringMode','Global');
            [obj.rc] = AT_SetEnumString(obj.sdkCam, 'PixelReadoutRate','280 MHz');
            [obj.rc] = AT_SetBool(obj.sdkCam,'Overlap',0);
            [obj.rc] = AT_SetEnumIndex(obj.sdkCam, 'SimplePreAmpGainControl', 2);
            [obj.rc] = AT_SetBool(obj.sdkCam, 'SpuriousNoiseFilter', 1);
        end
        function log = IsLoggin(obj)
            [obj.rc, log] = AT_GetBool(obj.sdkCam, 'CameraAcquiring');
        end
    end

    %% Trigger and acquisition
    methods
        function trigType = getTriggerType(obj)
            [obj.rc, currentIndex] = AT_GetEnumIndex(obj.sdkCam, 'TriggerMode');
            [obj.rc, trigType] = AT_GetEnumStringByIndex(obj.sdkCam, 'TriggerMode', currentIndex, 64);
        end

        function setTriggerType(obj, type)
            % setTriggerType Map generic trigger type to specific Andor TriggerMode
            %
            % Supported types: 'manual', 'immediate', 'hardware'
            Type = lower(type);
            if strcmp(Type, 'manual')
                Type = 'software';
            elseif strcmp(Type, 'hardware')
                Type = 'external start';
            end
        
            switch Type
                case 'internal'    
                    triggerIndex = 0;
        
                case 'external level transition' 
                    triggerIndex = 1;
        
                case 'external start' 
                    triggerIndex = 2;
                case 'external exposure' 
                    triggerIndex = 3;
                case 'software' 
                    triggerIndex = 4;
                case 'advanced' 
                    triggerIndex = 5;
                case 'external' 
                    triggerIndex = 6;
        
                otherwise
                    obj.sendError(sprintf('Unsupported trigger type: %s', Type));
            end
            [obj.rc] = AT_SetEnumIndex(obj.sdkCam, 'TriggerMode', triggerIndex);
            AT_CheckWarning(obj.rc);
        end


        function setTriggerRepeats(obj, repeats)
           if AT_IsImplemented(obj.sdkCam,'MetadataEnable'), AT_SetBool(obj.sdkCam,'MetadataEnable', false); end

            % 2) NOW read sizes
            [~,H]  = AT_GetInt(obj.sdkCam,'AOIHeight');
            [~,W]  = AT_GetInt(obj.sdkCam,'AOIWidth');
            [~,St] = AT_GetInt(obj.sdkCam,'AOIStride');
            [obj.rc,imagesize] = AT_GetInt(obj.sdkCam,'ImageSizeBytes'); 
            AT_CheckWarning(obj.rc);
            assert(imagesize>0 && imagesize==St*H, 'Size mismatch—fix AOI/binning/encoding order');
            for i =1:repeats
                AT_QueueBuffer(obj.sdkCam,imagesize);
                AT_CheckWarning(obj.rc);
            end
            [obj.rc] = AT_SetInt(obj.sdkCam, 'FrameCount', repeats);
        end

        function framesPerTrigger(obj, val)
            [obj.rc] = AT_SetInt(obj.sdkCam, 'AccumulateCount', val);
            [obj.rc] = AT_SetInt(obj.sdkCam, 'FrameCount', val);
        end
    end

    %% ROI and exposure
    methods
        function setROI(obj, newROI)
            % ROI must be a vector of length 4: [left, bottom, width, height]
            % newROI must be converted to the format [left, top, width,
            % height] in order to be passed to the camera
            bin = obj.binning;
            newROI = [newROI(1)*bin, newROI(2)*bin, newROI(3), newROI(4)];
            iniXCoor = newROI(1);
            Ybottom = newROI(2);
            width = newROI(3);
            height = newROI(4);
            [obj.rc] = AT_SetInt(obj.sdkCam, 'AOIWidth', width);
            AT_CheckWarning(obj.rc);
            [obj.rc] = AT_SetInt(obj.sdkCam, 'AOIHeight', height);
            AT_CheckWarning(obj.rc);
            [obj.rc] = AT_SetInt(obj.sdkCam, 'AOILeft', iniXCoor);
            AT_CheckWarning(obj.rc);
            [obj.rc] = AT_SetInt(obj.sdkCam, 'AOITop', Ybottom);
            AT_CheckWarning(obj.rc);
            obj.imgparams.roi = newROI;
            check = obj.checkROIInternal;
            if check
                obj.sendEventScanParamsChanged;
            else
                obj.sendError('Roi was not set properly')
            end
        end

        function [x, y, w, h] = getROI(obj)
            roi = obj.imgparams.roi;
            % x= left, y=bottom, w=width, h= height
            x = roi(1); y = roi(2); w = roi(3); h = roi(4);
        end

        function setExposureTime(obj, t)
            % t is in milliseconds
            %exposure time set to the camera must be in seconds
            [obj.rc] = AT_SetFloat(obj.sdkCam, 'ExposureTime', t*1e-3);
            obj.imgparams.exposuretime = t*1e3; %saving the exposure paramaters in microseconds
            obj.sendEventScanParamsChanged;
        end

        function setExposureAuto(obj, state)
            %the camera doesnt have that feature
            obj.dummyparam = state;
        end

        function state = getExposureAuto(obj)
            state = obj.dummyparam;
        end

        function setMinDelay(obj)
            obj.dummyparam = 1;
            [obj.rc, maxframe] = AT_GetFloatMax(obj.sdkCam, 'FrameRate');
            obj.DELAY_BETWEEN_TRIGGERS = ceil((1e6)*(1/maxframe)); % microseconds
        end

        function setBinning(obj, bin)
            switch bin
                case 1
                    binIndex = 0;
                case 2
                    binIndex = 1;
                case 3
                    binIndex = 2;
                case 4
                    binIndex = 3;
                case 8
                    binIndex = 4;
            end
            obj.binning = bin;
            [obj.rc] = AT_SetEnumIndex(obj.sdkCam, 'AOIBinning', binIndex);
            AT_CheckWarning(obj.rc);
            obj.imgparams.binning = bin;
            obj.imgparams.roi = obj.getROIInternal;
            obj.sendEventScanParamsChanged;
        end
    end

    %% Image acquisition
    methods
        function StartRead(obj)
            obj.setTriggerRepeats(obj.triggerRepeats);
            [obj.rc, acq] = AT_GetBool(obj.sdkCam,'CameraAcquiring');
            AT_Command(obj.sdkCam,'AcquisitionStart');  
            AT_CheckWarning(obj.rc);
        end

        function imageData = ImageAcquire(obj, ~)
            check = obj.checkROIInternal;
            if ~check
                obj.sendError('Roi is not set correctly')
            end
%             [obj.rc,imagesize] = AT_GetInt(obj.sdkCam,'ImageSizeBytes'); 
%             AT_CheckWarning(obj.rc);
%             [obj.rc] = AT_QueueBuffer(obj.sdkCam,imagesize);
%             AT_CheckWarning(obj.rc);
            obj.SoftwareTrigger;
            [obj.rc,buf] = AT_WaitBuffer(obj.sdkCam,1000);
            AT_CheckWarning(obj.rc);
            width = obj.imgparams.roi(3);
            height = obj.imgparams.roi(4);
            [obj.rc, stride] = AT_GetInt(obj.sdkCam,'AOIStride');
            AT_CheckWarning(obj.rc);
            imageData =obj.getImage(buf, height, width,stride);
%             imageData = flipud(imageData);
            obj.currentdata = imageData;
            
        end

        function SoftwareTrigger(obj)
            AT_Command(obj.sdkCam, 'SoftwareTrigger');
        end

        function img = read(obj, n, delay)
            obj.setTriggerRepeats(n);
            roi = obj.imgparams.roi;
            [obj.rc, stride] = AT_GetInt(obj.sdkCam,'AOIStride');
            img = zeros(roi(4), roi(3), n);
            [obj.rc, framerate] = AT_GetFloat(obj.sdkCam, 'FrameRate');
            minDelayTime = 1/framerate;
            if delay < minDelayTime
                obj.sendError('delay time must be larger then the minimum time between frames');
            end
            for i = 1:n
                obj.SoftwareTrigger();
                if exist('delay','var')
                    pause(delay/1000);
                else
                    pause(minDelayTime);
                end
            end
            for i =1:n
                [obj.rc,buf] = AT_WaitBuffer(obj.sdkCam,1000);
                AT_CheckWarning(obj.rc);
                img(:,:,i) = obj.getImage(buf, roi(4), roi(3),stride);
                AT_CheckWarning(obj.rc);
            end
        end

        function images = readfromcamera(obj, nframes)
            % for the case an external trigger triggers the camera for
            % scanning
            roi = obj.imgparams.roi;
            [obj.rc, stride] = AT_GetInt(obj.sdkCam,'AOIStride');
            images = zeros(roi(4), roi(3), nframes);
            for i =1:nframes
                [obj.rc,buf] = AT_WaitBuffer(obj.sdkCam,1000);
                AT_CheckWarning(obj.rc);
                images(:,:,i) = obj.getImage(buf,roi(4), roi(3),stride);
                AT_CheckWarning(obj.rc);
            end
        end

        function images = readExperimentData(obj, nframes)
            % for the case an external trigger triggers the camera
            roi = obj.imgparams.roi;
            [obj.rc, stride] = AT_GetInt(obj.sdkCam,'AOIStride');
            images = zeros(roi(4), roi(3), nframes);
            rawBufs = cell(1,nframes);   % store raw buffers first (optional but explicit)

            for k = 1:nframes
                if k ==40
                    g=2;
                end
                [obj.rc, buf] = AT_WaitBuffer(obj.sdkCam, 2000); 
%                 if ~(isa(buf,'uint8') && isequal(size(buf), [169632 1]))
%                     warning('Disregarding frame: buf is %s of size %s, expected 169632x1 uint8.', ...
%                         class(buf), mat2str(size(buf)));
%                     % e.g., continue;  % if inside a loop
%                     % or: frame = []; return;  % if in a function
%                 end
                AT_CheckWarning(obj.rc);
                rawBufs{k} = buf;   % keep raw buffers so extraction is strictly "after"
            end
            for i =1:nframes
%                 [obj.rc,buf] = AT_WaitBuffer(obj.sdkCam,obj.timeout*1e03);
%                 AT_CheckWarning(obj.rc);
                images(:,:,i) = obj.getImage(rawBufs{i},roi(4),roi(3),stride);
                AT_CheckWarning(obj.rc);
            end
        end

        function stopRead(obj)
            AT_Command(obj.sdkCam, 'AcquisitionStop');
        end

        function clearMemory(obj)
            AT_Flush(obj.sdkCam);
        end
        function clearTimeRead(obj)
            obj.stopRead;
            obj.clearMemory;
            obj.framesPerTrigger(1);
        end

        function imageSaveImage(obj, ~, ~)
            img = obj.currentdata;
            imwrite(img, 'andor_image.tif');
        end

        function imageCPP(~, ~, ~)
            % Placeholder for SDK3 CPP processing integration
        end

        function imageUpload(~, ~, ~)
            % Placeholder for image upload
        end

        function prepareRead(obj, ~)
            [obj.rc] = AT_SetEnumString(obj.sdkCam,'SimplePreAmpGainControl','16-bit (low noise & high well capacity)');
            AT_CheckWarning(obj.rc);
            [obj.rc] = AT_SetEnumString(obj.sdkCam,'PixelEncoding','Mono16');
            AT_CheckWarning(obj.rc);
        end

        
    end

    %% Experiment prep
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
            obj.triggerRepeats = nPixels;
            
        end

        function prepareExperiment(obj, nreads, timeout, ~)
            obj.stopRead;
            obj.clearMemory;
            obj.setMinDelay;
            obj.timeout = timeout;
            obj.setTriggerType('external exposure');
            obj.framesPerTrigger(1);
            obj.triggerRepeats = nreads;
                        
        end

        function resetToDefault(obj)
            obj.setExposureTime(obj.DEFAULT_EXPOSURE_TIME);
            obj.setTriggerType('manual');
            obj.framesPerTrigger(1);
            [obj.rc] = AT_SetEnumString(obj.sdkCam,'SimplePreAmpGainControl','16-bit (low noise & high well capacity)');
            obj.setTriggerRepeats(0);
            obj.clearMemory;
            obj.sendEventScanParamsChanged;
        end
    end

    %% Singleton
    methods (Static)
        function obj = getInstance(struct)
            obj = getObjByName(Camera.NAME);
            if isempty(obj)
                missingField = FactoryHelper.usualChecks(struct, CameraAndor.NEEDED_FIELDS);
                if ~isnan(missingField)
                    error('Missing field "%s" for Andor camera.', missingField);
                end
                obj = CameraAndor();
                addBaseObject(obj);
            end
        end
    end

    %% Private
    methods (Access = private)
        function triggerCounter(~, ~, ~)
            % Not used in SDK3 workflow (optional)
        end
        function Roi = getROIInternal(obj)
            [obj.rc,height] = AT_GetInt(obj.sdkCam,'AOIHeight');
            AT_CheckWarning(obj.rc);
            [obj.rc,width] = AT_GetInt(obj.sdkCam,'AOIWidth');  
            AT_CheckWarning(obj.rc);
            [obj.rc,xCoo] = AT_GetInt(obj.sdkCam,'AOILeft');
            AT_CheckWarning(obj.rc);
            [obj.rc,yTop] = AT_GetInt(obj.sdkCam,'AOITop');  
            AT_CheckWarning(obj.rc);
            Roi = [xCoo, yTop, width, height];
        end
        function imageData = getImage(obj, buf,height, width, stride)
            [obj.rc, pixelEncodingIndex] = AT_GetEnumIndex(obj.sdkCam, 'PixelEncoding');
            AT_CheckWarning(obj.rc);
            switch pixelEncodingIndex
                case 0
                    [obj.rc, imageData] = AT_ConvertMono12ToMatrix(buf,height,width,stride);
                case 1
                    [obj.rc, imageData] = AT_ConvertMono12PackedToMatrix(buf,height,width,stride);
                case 2
                    [obj.rc, imageData] = AT_ConvertMono16ToMatrix(buf,height,width,stride);
                case 3
                    [obj.rc, imageData] = AT_ConvertRGB8PackedToMatrix(buf,height,width,stride);
                case 4
                    [obj.rc, imageData] = AT_ConvertMono12CodedToMatrix(buf,height,width,stride);
                case 5
                    [obj.rc, imageData] = AT_ConvertMono12CodedPackedToMatrix(buf,height,width,stride);
                case 6
                    [obj.rc, imageData] = AT_ConvertMono22ParallelToMatrix(buf,height,width,stride);
                case 7 
                    [obj.rc, imageData] = AT_ConvertMono8ToMatrix(buf,height,width,stride);
                case 8 
                    [obj.rc, imageData] = AT_ConvertMono32ToMatrix(buf,height,width,stride);
            end
            imageData = transpose(imageData);
            
        end  
        function check = checkROIInternal(obj)
           roi = obj.getROIInternal;
           [a, b, c, d] = obj.getROI;
           roi2 = [a, b, c, d];
           if roi(1) == roi2(1) && roi(2) == roi2(2) && roi(3) == roi2(3) && roi(4) == roi2(4)
               check = true;
           else
               check = false;
               if roi(1) ~= roi2(1);disp('left coordinate does not match'); end
               if roi(2) ~= roi2(2);disp('bottom coordinate does not match');end
               if roi(3) ~= roi2(3);disp('width coordinate does not match');end
               if roi(4) ~= roi2(4);disp('height coordinate does not match');end
           end
        end                                 
    end
    %%
    methods
        % extra modes of the camera
        % temperature control
        function Cooling(obj, bool)
            % turns sensor cooling on or off depends on bool
            [obj.rc] = AT_SetBool(obj.sdkCam, 'SensorCooling', bool);
        end

        function temperature = readTemperature(obj)
            % returns the current sensor temperature
            [obj.rc, temperature] = AT_GetFloat(obj.sdkCam, 'SensorTemperature');
        end

        function setSensorTemperature(obj, temperature)
            [obj.rc, t] = AT_GetBool(obj.sdkCam, 'SensorCooling');
            if t
                if temperature <= obj.MAXSENSORTEMPERATURE && temperature>= obj.MINSENSORTEMPERAURE
                    [obj.rc] = AT_SetFloat(obj.sdkCam, 'TargetSensorTemperature', temperature);
                else
                    sendError('temperature selected not in range')
                end
            else
                sendError('turn on sensor cooling in order to set the temperature')
            end
        end
        function status = sensorTemperatureStatus(obj)
            [obj.rc, i] = AT_GetEnumIndex(obj.sdkCam, 'TemperatureStatus');
            [obj.rc, status] = AT_GetEnumStringByIndex(obj.sdkCam, 'TemperatureStatus', i, 64);
        end
    end
end
