classdef CameraCapture < EventSender & EventListener & Savable

    % this class connects the physical camera object to the cameradisplay
    % object. Image acquisition and saving happens in this object

    properties
        mImage                %Image data
        mCamera                %camera type
        mcameraimageparams    
        measurementType=1;       % index for MEASUREMENTS_OPTIONS
        mCurrentlyAcquiring = false;


        initialroi
        
        
    end
    
    properties (Constant)
        NAME = 'cameraCapture'
        EVENT_IMAGE_UPDATED = 'ImageUpdated'
        EVENT_ACQUIRE_STARTED = 'AcquiringStarted'
        EVENT_ACQUIRE_FINISHED = 'AcquiringFinished'
        EVENT_ACQUIRING_STOPPED_MANUALLY = 'AcquiringStoppedManually'
        % events can be sent with both EVENT_SCAN_FINISHED and EVENT_SCAN_STOPPED_MANUALLY
        % such events will always have EVENT_SCAN_FINISHED = true,
        %                and will have EVENT_SCAN_STOPPED_MANUALLY = (true or false)
        
        PROPERTY_SCAN_PARAMS = 'scanParameters'
        MEASUREMENT_OPTIONS = {'snapshot', 'continuous'}
    end
    
    methods (Access = private)
        function obj = CameraCapture
            obj@EventSender(CameraCapture.NAME);
            obj@Savable(CameraCapture.NAME);
            obj@EventListener(SaveLoadCatImage.NAME)
            obj.mCamera = getObjByName(Camera.NAME);
        end
    end
    methods
        function sendEventAcquiringFinished(obj)
            obj.sendEvent(struct( ...
                obj.EVENT_ACQUIRE_FINISHED, true, ...
                obj.EVENT_ACQUIRING_STOPPED_MANUALLY, false));
        end
        function sendEventAcquiringStopped(obj)
            obj.sendEvent(struct(...
                obj.EVENT_ACQUIRE_FINISHED, true, ...
                obj.EVENT_ACQUIRING_STOPPED_MANUALLY, true));
        end
        function sendEventAcquiringStarting(obj)
            obj.sendEvent(struct(obj.EVENT_ACQUIRE_STARTED, true));
        end
        function sendEventAcquiringUpdated(obj, ImageResults)
            axis1 = obj.mcameraimageparams.getFirstImageAxisVector;
            axis2 = obj.mcameraimageparams.getSecondImageAxisVector;
            phAxes = {axis1, axis2};
            botLabel = 'x';
            leftLabel = 'y';
            extra = EventExtraImageUpdated(ImageResults, phAxes, botLabel, leftLabel, obj.initialroi);
            
            obj.sendEvent(struct(obj.EVENT_IMAGE_UPDATED, extra));
        end
        
        
    end
       

        
     methods

         function startAcquision(obj)
            obj.mcameraimageparams = obj.mCamera.imgparams.copy;
            obj.initialroi = obj.mcameraimageparams.roi;
            obj.mCurrentlyAcquiring = true;
            obj.sendEventAcquiringStarting();
            
            camera = getObjByName(Spcm.NAME);
            if isempty(camera); throwBaseObjException(Spcm.NAME); end
            camera.setSPCMEnable(true);
            
            if obj.mcameraimageparams.isMWcontrastImg
                %%% Set Frequency Generator
                fg = getObjByName(FrequencyGenerator.getDefaultFgName); 
                fg.amplitude = obj.mcameraimageparams.MWAmplitude;
                fg.frequency = obj.mcameraimageparams.MWFrequency;
                fg.output = 1;
            end
            timerVal = tic;
            camera.prepareReadByTime();
            disp('Initiating Aquisition...');
            try
                kcpsImageMatrix = obj.run(camera);
                
            catch err
                % We couldn't scan. Wrap it up nicely
                camera.setSPCMEnable(false);
                obj.mCurrentlyAcquiring = false;
                if obj.mcameraimageparams.isMWcontrastImg
                    fg = getObjByName(FrequencyGenerator.getDefaultFgName);
                    fg.output = 0;
                end
                
                rethrow(err)
            end
            if obj.mcameraimageparams.isMWcontrastImg
                fg = getObjByName(FrequencyGenerator.getDefaultFgName);
                fg.output = 0;
            end
            
            % Maybe we didn't encounter an error, but the scan still did not happen
            if isempty(kcpsImageMatrix)
                camera.setSPCMEnable(false);
                obj.mCurrentlyScanning = false;
                return
            end
            
            toc(timerVal)
            camera.clearTimeRead;
            camera.setSPCMEnable(false);
            obj.mImage = kcpsImageMatrix;
            
            
            obj.mCurrentlyAcquiring = false;               
            
            if obj.measurementType ==2
                obj.sendEventAcquiringStopped();
            else
                obj.sendEventAcquiringFinished();
            end
            % (At least) two things should happen by this event:
            % 1. ImageScanResult will update
            % 2. SaveLoad will get the new scan, save it into local
            %    struct, and (if needed) will autosave it.
            
        end


        function imagematrix = run(obj, camera)            
            if isempty(camera); throwBaseObjException(Spcm.NAME); end
            numpointsyaxisB = obj.mcameraimageparams.roi(3);
            numpointsxaxisA = obj.mcameraimageparams.roi(4);
            kcpsMatrix = zeros(numpointsxaxisA, numpointsyaxisB, 1+obj.mcameraimageparams.isMWcontrastImg);
            obj.mImage = kcpsMatrix;
            if size(kcpsMatrix, 3) == 2 % MW Contrast
                pg = getObjByName(PulseGenerator.NAME);
            end
            obj.mCurrentlyAcquiring = true;
            try
                switch obj.mcameraimageparams.Avarage_exposures
                    case false
                        switch obj.measurementType
                            case 1
                                for i = 1:size(kcpsMatrix,3)
                                    if i==2
                                        pg.on('MW');
                                    end
                                    kcpsMatrix(:,:,i) = camera.readFromTime;
                                    if i==2
                                        pg.off('MW');
                                    end
                                end
                                imagematrix = kcpsMatrix;
                                obj.sendEventAcquiringUpdated(kcpsMatrix);
                            case 2
                                while obj.mCurrentlyAcquiring
                                    % Creating data to be saved
                                    for i = 1:size(kcpsMatrix,3)
                                        if i==2
                                            pg.on('MW');
                                        end
                                        kcpsMatrix(:,:,i) = camera.readFromTime;
                                        if i==2
                                            pg.off('MW');
                                        end
                                    end
                                    imagematrix = kcpsMatrix;
                                    obj.sendEventAcquiringUpdated(kcpsMatrix);
                                end
                        end
                    case true
                        nframes = obj.mcameraimageparams.nframes;
                        timedelay = obj.mcameraimageparams.timedelay;
                        switch obj.measurementType
                            case 1
                                for j = 1:size(kcpsMatrix,3)
                                    if j==2
                                        pg.on('MW');
                                    end
                                    currentMatrix = camera.readFromTime(1, nframes, timedelay);
                                    kcpsMatrix(:,:,j) = mean(currentMatrix,3);
                                    if j==2
                                        pg.off('MW');
                                    end    
                                end
                                imagematrix = kcpsMatrix;
                                obj.sendEventAcquiringUpdated(kcpsMatrix);
                            case 2
                                while obj.mCurrentlyAcquiring
                                    % Creating data to be saved
                                    for j = 1:size(kcpsMatrix,3)
                                        if j==2
                                            pg.on('MW');
                                        end
                                        currentMatrix = camera.readFromTime(1, nframes, timedelay);
                                        kcpsMatrix(:,:,j) = mean(currentMatrix,3); 
                                        if j==2
                                            pg.off('MW');
                                        end
                                    end
                                    imagematrix = kcpsMatrix;
                                    obj.sendEventAcquiringUpdated(kcpsMatrix);
                                end
                        end
                end
                camera.clearTimeRead;
            catch err
                try
                    camera.clearTimeRead;
                catch
                end
                rethrow(err);
            end
        end
        function stopAcquiring(obj)
             obj.mCurrentlyAcquiring = false;
         end

         function autosaveAfterAcquisition(obj) %#ok<MANU>
            saveLoad = SaveLoad.getInstance(Savable.CATEGORY_IMAGE);
            saveLoad.autoSave();
         end
         function clear(obj)
            if (obj.mCurrentlyAcquiring)
                obj.stopAcquiring();
            end
            
            obj.mImage = nan;
            obj.mCamera = nan;
            obj.mcameraimageparams = nan;
            obj.mCurrentlyAcquiring = false;     % probably redundant; appears in obj.stopScan
         end

         function boolean = isAcquisitionReady(obj)
            boolean = ~isnan(obj.mImage);
        end
     end
     methods (Static)
        function obj = init
            obj = getObjByName(CameraCapture.NAME);
            if isempty(obj)
                obj = CameraCapture;
                addBaseObject(obj);
            end
        end
     end

 %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            % Check if event is "loaded file to SaveLoad" and need to show the image
            if strcmp(event.creator.name, SaveLoadCatImage.NAME) ...
                    && isfield(event.extraInfo, SaveLoad.EVENT_LOAD_SUCCESS_FILE_TO_LOCAL)
                % Need to load the image!
                category = Savable.CATEGORY_IMAGE;
                subcat = Savable.SUB_CATEGORY_DEFAULT;
                saveLoad = event.creator;
                struct = saveLoad.getStructToSavable(obj);
                if ~isempty(struct)
                    obj.loadStateFromStruct(struct, category, subcat);
                end
            end
        end
    end

     %% overriding from Savable
    methods (Access = protected)
        function outStruct = saveStateAsStruct(obj, category, type)
            % Saves the state as struct. if you want to save stuff, make
            % (outStruct = struct;) and put stuff inside. If you dont
            % want to save, make (outStruct = NaN;)
            %
            % category - string. Some objects saves themself only with
            %                    specific category (image/experiments/etc.)
            % type - string.     Whether the objects saves at the beginning
            %                    of the run (parameter) or at its end (result)
            if ~strcmp(category, Savable.CATEGORY_IMAGE)
                outStruct = nan;
                return
            end
            
            outStruct = struct;
            switch type
                case Savable.TYPE_PARAMS
                    outStruct.imageParams = obj.mcameraimageparams.asStruct();
                case Savable.TYPE_RESULTS
                    if isnan(obj.mImage)
                        outStruct = NaN;
                    else
                        outStruct.image = obj.mImage;
                    end
            end
        end
        
        function loadStateFromStruct(obj, savedStruct, category, subCategory)
            % Loads the state from a struct.
            % to support older versions, always check for a value in the
            % struct before using it. View example in the first line.
            if ~strcmp(category, Savable.CATEGORY_IMAGE); return; end
            if ~any(strcmp(subCategory, {Savable.SUB_CATEGORY_DEFAULT})); return; end
                        
            if ~isfield(savedStruct, 'imageParams')
                return
            end

            if ~isfield(savedStruct, 'image')
                savedStruct.image = [];
                obj.sendWarning('No image results found. Loading only image parameters');
            end
            
            obj.mcameraimageparams = CameraImageParams.fromStruct(savedStruct.imageParams);
            
            obj.mImage = savedStruct.image;
            
            obj.sendEventScanUpdated(savedStruct.image);
        end
        
        function string = returnReadableString(~, savedStruct)
            % Return a readable string to be shown. If this object
            % doesn't need a readable string, make (string = NaN;) or
            % (string = '');
            
            string = NaN;
            % for field = {'scan', 'scanParams', 'stageName'} - removed 'scan', for when scan has not yet been saved.
            if ~isfield(savedStruct, 'imageParams')
                return
            end
            params = savedStruct.imageParams;
            roi = params.roi;
            string = sprintf('The ROI width is %d starting at %d \nand its length is %d starting from %d ', ...
               roi(3), roi(1), roi(4), roi(2));
            
        end
    end

end
