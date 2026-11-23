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


        % event camera parameters
        eventMap
        bufferSize = 1000;
        videoBuffer
        recordVideo=0;
        writeIndex            % Position where the next image is written
        frameCount            % Number of valid images currently stored
        startrecording = 0;
        fig
        hIm
        hEventAxes
        
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
        PATH_DEFAULT_STREAM_SAVE = sprintf('%sSetup %s\\eventVideo\\', ...
            PathHelper.getPathToNvLab(), JsonInfoReader.setupNumber);
        
    end
    
    methods (Access = private)
        function obj = CameraCapture
            obj@EventSender(CameraCapture.NAME);
            obj@Savable(CameraCapture.NAME);
            obj@EventListener(SaveLoadCatImage.NAME)
            obj.mCamera = getObjByName(Camera.NAME);
            if isa(obj.mCamera,'UEeventCamera')
                obj.SetEventMapDefault();
            end
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
                if isa(obj.mCamera,'UEeventCamera')
                    obj.recordVideo = 0;
                    obj.mCamera.StartRead();
                    
                    obj.initializeEventFigure();
                    kcpsImageMatrix = obj.eventStreaming(); 
                    
                else
                    kcpsImageMatrix = obj.run(camera);
                end
                
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
                                        pg.on({'MW', 'greenLaser'});
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
                                            pg.on({'MW', 'greenLaser'});
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
                                        pg.on({'MW', 'greenLaser'});
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
                                            pg.on({'MW', 'greenLaser'});
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

        function kcpsImageMatrix = eventStreaming(obj)
             % FPS measurement
            fpsTimer = tic;
            totalTimer = tic;
        
            intervalFrames = 0;
            totalFrames = 0;
            while obj.mCurrentlyAcquiring
                if ~isvalid(obj.fig)
                    break;
                end
          
                % Acquire frame
                rawFrame = obj.mCamera.ImageAcquire();
                intervalFrames = intervalFrames + 1;
                totalFrames = totalFrames + 1;
                
                if obj.recordVideo
                    obj.videoBuffer(:, :, obj.writeIndex) = rawFrame;
                    obj.writeIndex = mod(obj.writeIndex, obj.bufferSize) + 1;
                    obj.frameCount = min(obj.frameCount + 1, obj.bufferSize);
                end
            
                set(obj.hIm, 'CData', rawFrame);
            
                drawnow limitrate 
                elapsed = toc(fpsTimer);

                if elapsed >= 10
        
                    fps = intervalFrames / elapsed;
        
                    fprintf('Event stream FPS: %.2f\n', fps);
        
                    % Reset interval measurement
                    intervalFrames = 0;
                    fpsTimer = tic;
                end
                
            end
            obj.mCamera.stopRead();
            kcpsImageMatrix = rawFrame;
            obj.sendEventAcquiringUpdated(rawFrame);
            if obj.recordVideo
                obj.saveVideo();
                obj.recordVideo = 0;
            end
            obj.mCamera.clearTimeRead();
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

        function SetEventMapDefault(obj)
            % to do later add an option to change the map
            nColors = 256;
            halfN = nColors / 2;
            
            neg = [ ...
                linspace(1,0,halfN)' ...
                linspace(1,0,halfN)' ...
                linspace(1,0,halfN)' ];          % white -> black
            
            pos = [ ...
                zeros(halfN,1) ...
                zeros(halfN,1) ...
                linspace(0,1,halfN)' ];          % black -> blue
            
            obj.eventMap = [neg; pos];
        end

        function initializeEventFigure(obj)

            rawFrame = obj.mCamera.ImageAcquire();
        
            if isempty(obj.fig) || ~isvalid(obj.fig)
        
                obj.fig = uifigure( ...
                    'Name', 'Event Camera Display', ...
                    'WindowStyle', 'alwaysontop', ...
                    'Position', [100 100 900 550]);
        
                % Make axes occupy almost the whole figure
                obj.hEventAxes = uiaxes(obj.fig, ...
                    'Units', 'normalized', ...
                    'Position', [0.03 0.07 0.90 0.88]);
        
                % Display first frame
                obj.hIm = imagesc(obj.hEventAxes, rawFrame);
        
                axis(obj.hEventAxes, 'image');
                axis(obj.hEventAxes, 'tight');
        
                colormap(obj.hEventAxes, obj.eventMap);
                clim(obj.hEventAxes, [-1 1]);
        
                % Keep title
                title(obj.hEventAxes, 'Streaming');
        
                % Keep colorbar
                cb = colorbar(obj.hEventAxes);
                cb.Location = 'eastoutside';
        
                drawnow;
        
            else
        
                obj.hIm.CData = rawFrame;
                obj.fig.Visible = 'on';
        
            end
        end

        function startRecording(obj)
            roi = obj.mCamera.imgparams.roi;
            W = roi(3);
            H = roi(4);
            obj.videoBuffer = zeros(H, W, obj.bufferSize, 'int32');
            obj.recordVideo = 1;
            obj.startrecording = 1;
            obj.writeIndex = 1;
            obj.frameCount = 0;
        end

        function stopRecording(obj)
            obj.startrecording = 0;
        end

        function saveVideo(obj)
            % Save the FIFO event-frame buffer as an MP4.
            %
            % The saved video uses exactly the same:
            %   - colormap
            %   - color limits
            % as the live event display.
            %
            % Frames are written oldest -> newest.
        
            % Validate buffer
            if isempty(obj.videoBuffer) || obj.frameCount == 0
                error('No frames are available in the video buffer.');
            end
        
            % Validate display
            if isempty(obj.fig) || ~isvalid(obj.fig) || ...
               isempty(obj.hIm) || ~isvalid(obj.hIm)
        
                error('Initialize the event figure before saving a video.');
            end
        
            % Get axes containing the event image
            ax = ancestor(obj.hIm, 'axes');
        
            if isempty(ax) || ~isvalid(ax)
                error('Could not find the event-display axes.');
            end
        
            % Get EXACT display settings from the axes
            cmap = colormap(ax);
            cLimits = clim(ax);
        
            if cLimits(1) == cLimits(2)
                error('Invalid color limits.');
            end
        
            % Create save directory
            saveFolder = obj.PATH_DEFAULT_STREAM_SAVE;
        
            if ~isfolder(saveFolder)
                mkdir(saveFolder);
            end
        
            % Generate filename
            fileName = "eventVideo_" + ...
                string(datetime("now", ...
                "Format", "yyyyMMdd_HHmmss")) + ".mp4";
        
            videoPath = fullfile(saveFolder, fileName);
        
            % Get FIFO frames in chronological order
            if obj.frameCount < obj.bufferSize
        
                % Buffer has not wrapped yet
                frameIndices = 1:obj.frameCount;
        
            else
        
                % Buffer is full:
                % writeIndex points to the next location that will be overwritten.
                % Therefore it is also the oldest frame.
                frameIndices = mod( ...
                    (obj.writeIndex - 1) + (0:obj.bufferSize - 1), ...
                    obj.bufferSize) + 1;
            end
        
            % Create MP4 writer
            writer = VideoWriter(videoPath, 'MPEG-4');
        
            % Use camera/display frame rate if available
            if isprop(obj.mCamera, 'frameRate') && ...
               ~isempty(obj.mCamera.frameRate) && ...
               obj.mCamera.frameRate > 0
        
                writer.FrameRate = obj.mCamera.frameRate;
            else
                writer.FrameRate = 30;
            end
        
            % Important for sparse event-camera images
            writer.Quality = 100;
        
            open(writer);
        
            % Precompute mapping information
            nColors = size(cmap, 1);
        
            cMin = cLimits(1);
            cMax = cLimits(2);
        
            try
        
                % Write buffered frames
                for k = 1:numel(frameIndices)
        
                    i = frameIndices(k);
        
                    % Keep original event values until color conversion
                    frame = double(obj.videoBuffer(:, :, i));
        
                    % Match imagesc(...), clim(...)
                    scaledFrame = (frame - cMin) ./ (cMax - cMin);
        
                    % Clip values outside CLim
                    scaledFrame = min(max(scaledFrame, 0), 1);
        
                    % Convert normalized values to colormap indices
                    colorIndex = ...
                        1 + round(scaledFrame * (nColors - 1));
        
                    % Convert indexed event image -> RGB
                    rgbFrame = reshape( ...
                        cmap(colorIndex(:), :), ...
                        size(frame, 1), ...
                        size(frame, 2), ...
                        3);
        
                    % Convert [0,1] RGB -> uint8
                    rgbFrame = uint8(round(rgbFrame * 255));
        
                    writeVideo(writer, rgbFrame);
                end
        
            catch ME
        
                close(writer);
                rethrow(ME);
            end
        
            close(writer);
        
            fprintf('Video saved successfully:\n%s\n', videoPath);
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
