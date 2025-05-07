classdef Camera < BaseObject & EventSender
    
    
    properties (Constant, Hidden)
        NAME = 'camera'
        NEEDED_FIELDS_GENERAL = {'type', 'address'};
    end

    properties (Constant)
        EVENT_CAMERA_PARAMS_CHANGED = 'cameraParamsChanged';
    end

    
    properties (Access = public)
        binning = 1         % The number of pixels to sum together. For N the binning is N*N pixels
        timeout
        triggertype         % type of trigger the camera has daq/ pulsestreamer
        imgparams           % CameraImageParams object (roi, exposuretime, Avarage_exposures, nframes, timedelay, isMWcontrastImg, MWAmplitude, MWFrequency)
        isAcquiring         % Boolean. true during continious aquiring
        exposureAutoState
        

%         imageSize
%         stride
%         trigger
%         fps                 % the Frames Per Second we want to shoot
%         vid                 % the video
%         src                 % the source that we thke the video from
%         Image_data          % the Image data it self
%         location = ''       % the location that we would like to put the image to
%         file_name = ''      % the file name that we would like to give the data
    end


    methods

        function obj = Camera()
            obj@BaseObject(Camera.NAME)
            obj@EventSender(Camera.NAME);
            
        end
        
        

        function sendEventScanParamsChanged(obj)
            obj.sendEvent(struct(obj.EVENT_CAMERA_PARAMS_CHANGED, true));
        end

        function set.imgparams(obj, newValue)
            % Validates the input, sets the newValue, sends an event
            if isa(newValue, 'CameraImageParams')
                obj.imgparams = newValue;
                obj.sendEventScanParamsChanged();
            else
                obj.sendWarning('Can only assign object of type "StageScanParams"! Ignoring');
            end
        end
        
    end
    


    methods (Abstract)
        
        initScanParams(obj)   
            
        setROI(obj, newROI);
        % set the ROI

        setExposureTime(obj, t);
        % set the exposure time

        setBinning(obj, bin)
        % set the binning value

%         ImageStart(gCam,handles)
        
        ImageAcquire(obj,what)
        % this function starts the image acquring
        
        SoftwareTrigger(obj)

        prepareRead(obj, NumberOfImages)

        read(obj, n, detectionDuration)

        stopRead(obj)
        
        imageSaveImage(obj, what, handles)
        % this function saves the last image
        
        imageUpload(obj, what, handels)
        % this function uploads an image

        imageCPP(obj, what, handles)
        % this function calls for the CPP functions for the camera

    end

    


    methods (Static)
        function obj = create
            jsonStruct = JsonInfoReader.getJson();
            cameraStruct = jsonStruct.spcm;
            switch lower(cameraStruct.type)
                case 'dummy'
                    obj = CameraDummy.getInstance(cameraStruct);
                case 'basler'
                    obj = CameraBasler.getInstance(cameraStruct);
                case 'andor'
                    obj = CameraAndor.getInstance(cameraStruct);
                otherwise
                    EventStation.anonymousWarning('Could not create Camera of type %s!', type)
            end
        end
    end


end