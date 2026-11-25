classdef UEeventCamera < Camera & EventSender
    properties(Constant)
        % these two properties are for the anti flicker module of the
        % camera which filters events that happen in a specified frequency
        % band. They are the min and max frequencies we can choose 
        MIN_FLICKER_FREQUENCY   =1;
        FLICKER_FREQUENCY_DEFAULT = 50;
        MAX_FLICKER_FREQUENCY =10000;
        % these two properties define the event rate we can filter. Pixels
        % who stream events to fast or to slow can be filtered
        MIN_EVENT_RATE_THRES=1;
        EVENT_RATE_THRES = 20;
        MAX_EVENT_RATE_THRES=100;
        %These two properties define a delay between consecutive events.
        %The delay is the minimum time between consecutive events
        MIN_TRAIL_EVENT_THRES=1;
        MAX_TRAIL_EVENT_THRES=1;
        DEFAULT_EXPOSURE_TIME = 10;           % default exposure time in ms
        MAXIMUM_BINNING = 1;
        ROI_DEFULT = [0 0 1280 720];
        MAX_ROI = [0 0 1280 720];
        EXPOSURE_TIME_LIMITS = [0.1 10000]     % exposure time boundaries in ms
        DRIVER_LATENCYS = 0.0005;                 % LATENCY IN SECONDS
    end

    properties
        maskedPixels            % holds the coordinates of all masked pixels
        flickerFrequency
        eventRateThreshold
        frameRate
        isRecording
        biases = struct( ...
                        'name', {}, ...
                        'value', {}, ...
                        'min', {}, ...
                        'max', {}, ...
                        'recommendedMin', {}, ...
                        'recommendedMax', {}, ...
                        'modifiable', {}, ...
                        'description', {}, ...
                        'category', {});

        antiFlickerInfo
        antiFlickerEnabled = false;
        antiFlickerBand = [50 60];
        antiFlickerRemoveBand = true;
        
        eventTrailThresholdLimits 
        eventTrailFilterEnabled = false;
        eventTrailFilterMode = 'stc_cut_trail';
        eventTrailFilterThresholdUs = 1000;
    
        eventRateActivityFilterEnabled = false;
    
        % [lowerStart lowerStop upperStart upperStop]
        % Units: events per second.
        eventRateActivityThresholds = [0 0 0 0];
    end

    methods
        function obj = UEeventCamera()
            obj@Camera;
            obj@EventSender(Camera.NAME);
        
            try
                % Initialize the C++/MEX camera object
                ok = UEeventCamera_mex('initialize');
        
                if ~ok
                    error('UEeventCamera:InitializationFailed', ...
                        'UEeventCamera_mex returned false during initialization.');
                end
        
            catch ME
                error('Failed to initialize Event camera: %s', ME.message);
            end
        
            obj.resetToDefault;
            obj.initScanParams;
        end
    end

    %%
    methods
        function initScanParams(obj)
            
            % Store default image parameters
            ImageParams = CameraImageParams;
            ImageParams.roi = UEeventCamera_mex('getROI');
    
            % Event camera specific defaults
            obj.isAcquiring = false;
            obj.exposureAutoState = false;
            ImageParams.binning = 1;
            ImageParams.exposuretime = obj.DEFAULT_EXPOSURE_TIME;
            obj.imgparams = ImageParams;
            obj.frameRate = 30;
            obj.isRecording = false;
            obj.refreshBiases();
            obj.refreshAntiflicker;
            obj.refreshEventTrailThresholdLimits();
            if ~isempty(obj.eventTrailThresholdLimits)
                limits = obj.eventTrailThresholdLimits;
                obj.eventTrailFilterThresholdUs = min(max( ...
                    obj.eventTrailFilterThresholdUs, limits(1)), limits(2));
            end
        end
        
        function resetToDefault(obj)
            obj.flickerFrequency = obj.FLICKER_FREQUENCY_DEFAULT;
            obj.eventRateThreshold = obj.EVENT_RATE_THRES;
            obj.setTriggerType('off');
        end

        function setROI(obj, roi)
            % setROI Set the event-camera hardware ROI.
            %
            % ROI format:
            %       [x y width height]
            %
            % Coordinate convention:
            %       (0,0) is the TOP-LEFT sensor pixel.
            %       x increases to the right.
            %       y increases downward.
            %
            % Example:
            %       obj.setROI([100 50 400 300])
            %
            % The ROI coordinates are zero-based because they are passed directly
            % to the Metavision camera API.
        
            %% Validate basic input
        
            if ~isnumeric(roi) || numel(roi) ~= 4
                error('UEeventCamera:InvalidROI', ...
                    'ROI must be [x y width height].');
            end
        
            roi = double(roi(:).');
        
            if any(~isfinite(roi)) || any(floor(roi) ~= roi)
                error('UEeventCamera:InvalidROI', ...
                    'ROI values must be finite integers.');
            end
        
            x      = roi(1);
            y      = roi(2);
            width  = roi(3);
            height = roi(4);
        
            %% Validate sign / dimensions
        
            if x < 0 || y < 0
                error('UEeventCamera:InvalidROI', ...
                    'ROI x and y must be non-negative.');
            end
        
            if width <= 0 || height <= 0
                error('UEeventCamera:InvalidROI', ...
                    'ROI width and height must be positive.');
            end
        
            %% Get full sensor dimensions
        
            [sensorWidth, sensorHeight] = UEeventCamera_mex('getSize');
        
            %% Make sure ROI stays inside sensor
        
            if x + width > sensorWidth
                error('UEeventCamera:InvalidROI', ...
                    ['ROI exceeds sensor width. ' ...
                     'x + width must be <= %d.'], ...
                     sensorWidth);
            end
        
            if y + height > sensorHeight
                error('UEeventCamera:InvalidROI', ...
                    ['ROI exceeds sensor height. ' ...
                     'y + height must be <= %d.'], ...
                     sensorHeight);
            end
        
            %% Set hardware ROI
        
            ok = UEeventCamera_mex('setROI', roi);
        
            if ~ok
                error('UEeventCamera:ROIError', ...
                    'Failed to set camera ROI.');
            end
        
            %% Update MATLAB-side camera parameters only after success
        
            imageParams = obj.imgparams;
            imageParams.roi = roi;
            obj.imgparams = imageParams;
        
        end
        function setExposureTime(obj, time)
            % time is in ms
            % set the exposure time
            ImageParams = obj.imgparams;
            ImageParams.exposuretime = time;
            obj.imgparams = ImageParams;
        end

        function time = getMinimumAccumulationTime(obj)
            time = obj.EXPOSURE_TIME_LIMITS(1);
        end


        function setBinning(~, ~)
        % set the binning value
        end
%         ImageStart(gCam,handles)
        
        function frame = ImageAcquire(obj)
            % ImageAcquire
            %
            % Acquires a single accumulated event frame.
            %
            % The accumulation time is taken from:
            %
            %     obj.imgparams.exposuretime
            %
            % and passed to the C++ MEX interface.
            %
            % Output:
            %     frame  - int32 matrix containing the accumulated event counts
            %
            % Pixel values:
            %     positive -> more ON events
            %     negative -> more OFF events
            %     zero     -> no net activity
        
            try
        
                if ~obj.isAcquiring
                    error('Camera is not acquiring. Call StartRead first.');
                end
        
                accumulationTimeMs = obj.imgparams.exposuretime;
        
                frame = UEeventCamera_mex('readAccumulatedFrame', accumulationTimeMs);
                TimingHelper.getInstance().addTimestamp('Frame recieved');
            catch ME
        
                error('Failed to acquire Event camera frame: %s', ...
                    ME.message);
        
            end
        end

        function setTriggerType(obj, type)
            if isstring(type) && isscalar(type) && ~ismissing(type)
                type = char(type);
            end
        
            if ~ischar(type) || ~isrow(type)
                error('UEeventCamera:InvalidTriggerType', ...
                    'Trigger type must be manual/off or hardware/external.');
            end
        
            switch lower(strtrim(type))
                case {'manual', 'off'}
                    enable = false;
                    newType = 'off';
                case {'hardware', 'external'}
                    enable = true;
                    newType = 'external';
                otherwise
                    error('UEeventCamera:InvalidTriggerType', ...
                        'Unknown trigger type "%s".', type);
            end
        
            ok = UEeventCamera_mex('setTriggerType', enable);
            if ~ok
                error('UEeventCamera:TriggerError', ...
                    'Failed to set trigger type to "%s".', newType);
            end
        
            obj.triggertype = newType;
        end

        
        function read(~, ~, ~)
        end
        
        function imageSaveImage(~, ~, ~)
        % this function saves the last image
        end
        function imageUpload(~, ~, ~)
        % this function uploads an image
        end
        function clearTimeRead(~)
        end
        function imageCPP(~, ~, ~)
        % this function calls for the CPP functions for the camera
        end

        function prepareExperiment(obj, varargin)
            % Call right before the pulse generator starts the sequence.
            if ~strcmp(obj.triggertype, 'external')
                obj.setTriggerType('external');
            end
            
            obj.clearMemory;
            obj.clearTriggers;
        end

        function prepareRead(~)
            UEeventCamera_mex('initializeFrameBuffer');
        end

        
        function data = readExperimentData(obj, nExpectedPulses)
            % READEXPERIMENTDATA Return the events and triggers of the last sequence run.
            %
            %   data = cam.readExperimentData(nExpectedPulses)
            %
            % nExpectedPulses - number of detector (trigger) pulses in the run,
            %                   detectionPeriodsPerRepeat * repeats. Each pulse
            %                   gives two trigger edges, so exactly
            %                   2*nExpectedPulses edges must arrive.
            %
            % Call after pg.run has returned (the pulse generator waits for
            % the sequence to finish). prepareExperiment empties both buffers
            % before the run, so everything read here belongs to this run.
            %
            % Output:
            %   data.events   - x, y, p (+1 ON / -1 OFF), t (int64, us)
            %   data.triggers - p (1 rising / 0 falling), t (int64, us), id

            validateattributes(nExpectedPulses, {'numeric'}, ...
                {'scalar', 'integer', 'positive'}, 'readExperimentData', 'nExpectedPulses');

            % Let the last USB packets arrive, then read everything once
            pause(obj.DRIVER_LATENCYS);
            data.events   = UEeventCamera_mex('readEvents');
            data.triggers = UEeventCamera_mex('readTriggers');

            nEdges = numel(data.triggers.t);
            if nEdges ~= 2 * nExpectedPulses
                error('UEeventCamera:TriggerCount', ...
                    'Expected %d trigger edges (%d pulses), received %d.', ...
                    2 * nExpectedPulses, nExpectedPulses, nEdges);
            end
        end


        function prepareReadbyStage(~, ~, ~)
        end

        function StartRead(obj)
            % Start or restart event acquisition safely
        
            try
                % Safety: stop an existing acquisition before starting again
                if obj.isAcquiring
                    warning('Event camera is already acquiring. Restarting acquisition...');
                    
                    obj.stopRead();
                    obj.isAcquiring = false;
                    
                    % Give the SDK/MEX callback a moment to shut down cleanly
                    pause(0.05);
                end
        
                ok = UEeventCamera_mex('start');
        
                if ~ok
                    error('UEeventCamera_mex returned false.');
                end
        
                obj.isAcquiring = true;
        
            catch ME
                % Keep MATLAB state consistent if startup fails
                obj.isAcquiring = false;
        
                error('Failed to start Event camera acquisition: %s', ME.message);
            end
        end
        function stopRead(obj)
            % Stop event acquisition
        
            try
                UEeventCamera_mex('stop');
                obj.isAcquiring = false;
        
            catch ME
                error('Failed to stop Event camera acquisition: %s', ME.message);
            end
        end

        function stopExperiment(obj)
            obj.stopRead;
            obj.clearMemory;
            obj.clearTriggers;
        end

        function biases = getBiases(~)
            biases = UEeventCamera_mex('getBiases');
        end
        
        function value = getBias(obj, name)

            if isstring(name)
                name = char(name);
            end
        
            if ~ischar(name)
                error('UEeventCamera:InputError', ...
                    'Bias name must be a character vector or string.');
            end
        
            if isempty(obj.biases)
                error('UEeventCamera:BiasNotAvailable', ...
                    'No bias information is stored. Call refreshBiases first.');
            end
        
            index = find(strcmp({obj.biases.name}, name), 1);
        
            if isempty(index)
                error('UEeventCamera:UnknownBias', ...
                    'Bias "%s" is not available on this camera.', name);
            end
        
            value = obj.biases(index).value;
        end
        
        function ok = setBias(obj, name, value)
        
            if isstring(name)
                name = char(name);
            end
        
            if ~ischar(name)
                error('UEeventCamera:InputError', ...
                    'Bias name must be a character vector or string.');
            end
        
            if ~isnumeric(value) || ~isscalar(value) || ...
                    ~isfinite(value) || floor(value) ~= value
                error('UEeventCamera:InputError', ...
                    'Bias value must be a finite integer scalar.');
            end
        
            ok = UEeventCamera_mex('setBias', name, value);
        
            if ~ok
                error('UEeventCamera:BiasError', ...
                    'Failed to set bias "%s".', name);
            end
            obj.refreshBiases();
        end
        
        function newValue = adjustBias(obj, name, delta)
        
            if isstring(name)
                name = char(name);
            end
        
            if ~ischar(name)
                error('UEeventCamera:InputError', ...
                    'Bias name must be a character vector or string.');
            end
        
            if ~isnumeric(delta) || ~isscalar(delta) || ...
                    ~isfinite(delta) || floor(delta) ~= delta
                error('UEeventCamera:InputError', ...
                    'Bias delta must be a finite integer scalar.');
            end
        
            [ok, newValue] = UEeventCamera_mex( ...
                'adjustBias', name, delta);
        
            if ~ok
                error('UEeventCamera:BiasError', ...
                    'Failed to adjust bias "%s".', name);
            end
            obj.refreshBiases();
        end

        function refreshBiases(obj)
            % Reads the current hardware-bias configuration and stores it locally.
            %
            % obj.biases is an empty struct for a RAW file or a camera without
            % hardware-bias support.
        
            try
                obj.biases = UEeventCamera_mex('getBiases');
        
            catch ME
                warning('UEeventCamera:BiasReadFailed', ...
                    'Could not refresh camera biases: %s', ME.message);
        
                obj.biases = struct( ...
                    'name', {}, ...
                    'value', {}, ...
                    'min', {}, ...
                    'max', {}, ...
                    'recommendedMin', {}, ...
                    'recommendedMax', {}, ...
                    'modifiable', {}, ...
                    'description', {}, ...
                    'category', {});
            end
        end

        function refreshAntiflicker(obj)

            % Read flat structure returned by the MEX interface
            rawInfo = UEeventCamera_mex('getAntiFlickerInfo');
        
            % General module availability
            info.available = rawInfo.available;
        
            % Enable / disable
            info.enabled = struct('value', logical(rawInfo.enabled));
        
            % Low frequency
            info.lowFrequency = struct('value', rawInfo.lowFrequencyHz,'min',...
                rawInfo.minFrequencyHz, 'max',   rawInfo.highFrequencyHz);
        
            % High frequency
            info.highFrequency = struct('value', rawInfo.highFrequencyHz, ...
                'min',   rawInfo.lowFrequencyHz, 'max',   rawInfo.maxFrequencyHz);
        
            % Filtering mode
            info.filteringMode = struct('value', rawInfo.filteringMode);
        
            % Duty cycle
            info.dutyCycle = struct('value', rawInfo.dutyCycle, 'min',   rawInfo.minDutyCycle, ...
                'max',   rawInfo.maxDutyCycle);
        
            % Start threshold
            info.startThreshold = struct('value', rawInfo.startThreshold, 'min',   rawInfo.minStartThreshold, ...
                'max',   rawInfo.maxStartThreshold);
        
            % Stop threshold
            info.stopThreshold = struct('value', rawInfo.stopThreshold, 'min',   rawInfo.minStopThreshold, ...
                'max',   rawInfo.maxStopThreshold);
        
            % Store reorganized structure
            obj.antiFlickerInfo = info;
        
        end

        function setAntiFlickerFeature(obj, feature, newValue)
            % SETANTIFLICKERFEATURE
            % Changes one Anti-Flicker parameter.
            %
            % feature:
            %   'enabled'
            %   'lowFrequency'
            %   'highFrequency'
            %   'filteringMode'
            %   'dutyCycle'
            %   'startThreshold'
            %   'stopThreshold'
        
            if isstring(feature)
                feature = char(feature);
            end
        
            % Make sure feature exists
        
            if ~isfield(obj.antiFlickerInfo, feature)
                error('UEeventCamera:InvalidAntiFlickerFeature', ...
                    'Unknown Anti-Flicker feature "%s".', feature);
            end
        
            featureInfo = obj.antiFlickerInfo.(feature);
        
        
            % -------------------------------------------------------------
            % Validate according to feature
            % --------------------------------------------------------------
        
            switch feature
        
                % Enable / disable
                case 'enabled'
        
                    if ~ValidationHelper.isTrueOrFalse(newValue)
                        error('UEeventCamera:InvalidAntiFlickerValue', ...
                            'Enabled must be true or false.');
                    end
        
                    newValue = logical(newValue);
        
        
                % Filtering mode
                %
                % true  -> BAND_STOP / Band cut
                % false -> BAND_PASS / Band pass
                case 'filteringMode'
        
                    if ~ValidationHelper.isTrueOrFalse(newValue)
                        error('UEeventCamera:InvalidAntiFlickerValue', ...
                            'Filtering mode must be true or false.');
                    end
        
                    newValue = logical(newValue);
        
        
                % Frequencies
                case {'lowFrequency', 'highFrequency'}
        
                    [isInteger, newValue] = ValidationHelper.isValueInteger(newValue);
        
                    if ~isInteger
                        error('UEeventCamera:InvalidAntiFlickerValue', ...
                            '%s must be an integer.', feature);
                    end
        
                    if ~ValidationHelper.isInBorders( ...
                            newValue, ...
                            featureInfo.min, ...
                            featureInfo.max)
        
                        error('UEeventCamera:AntiFlickerOutOfRange', ...
                            '%s must be within [%g, %g].', ...
                            feature, ...
                            featureInfo.min, ...
                            featureInfo.max);
                    end
        
        
                %% Start / stop thresholds
                case {'startThreshold', 'stopThreshold'}
        
                    [isInteger, newValue] = ValidationHelper.isValueInteger(newValue);
        
                    if ~isInteger
                        error('UEeventCamera:InvalidAntiFlickerValue', ...
                            '%s must be an integer.', feature);
                    end
        
                    if ~ValidationHelper.isInBorders( ...
                            newValue, ...
                            featureInfo.min, ...
                            featureInfo.max)
        
                        error('UEeventCamera:AntiFlickerOutOfRange', ...
                            '%s must be within [%g, %g].', ...
                            feature, ...
                            featureInfo.min, ...
                            featureInfo.max);
                    end
        
        
                %% Duty cycle
                case 'dutyCycle'
        
                    % Duty cycle may be non-integer
                    if ~isnumeric(newValue) || ...
                            ~isscalar(newValue) || ...
                            ~isfinite(newValue)
        
                        error('UEeventCamera:InvalidAntiFlickerValue', ...
                            'Duty cycle must be a finite numeric value.');
                    end
        
                    if ~ValidationHelper.isInBorders( ...
                            newValue, ...
                            featureInfo.min, ...
                            featureInfo.max)
        
                        error('UEeventCamera:AntiFlickerOutOfRange', ...
                            'Duty cycle must be within [%g, %g].', ...
                            featureInfo.min, ...
                            featureInfo.max);
                    end
        
        
                otherwise
        
                    error('UEeventCamera:InvalidAntiFlickerFeature', ...
                        'Unknown Anti-Flicker feature "%s".', feature);
            end
        
        
           
            %% -------------------------------------------------------------
            % Send changed feature to MEX
            % --------------------------------------------------------------
        
            ok = UEeventCamera_mex('setAntiFlickerFeature', feature, newValue);
        
            if ~ok
                error('UEeventCamera:AntiFlickerError', ...
                    'Failed to set Anti-Flicker feature "%s".', feature);
            end
        
        
            %% Read actual values back from hardware
        
            obj.refreshAntiflicker();
        
        end

        function refreshEventTrailThresholdLimits(obj)
            try
                obj.eventTrailThresholdLimits = ...
                    UEeventCamera_mex('getEventTrailThresholdLimits');
            catch ME
                if ~strcmp(ME.identifier, 'UEeventCamera:TrailFilterError')
                    rethrow(ME);
                end
        
                % An unavailable optional filter should not block acquisition.
                obj.eventTrailThresholdLimits = [];
                warning('UEeventCamera:TrailLimitsUnavailable', '%s', ME.message);
            end
        end
        
        function ok = setEventTrailFilter(obj, feature, newValue)
            if isstring(feature) && isscalar(feature) && ~ismissing(feature)
                feature = char(feature);
            end
            if ~ischar(feature) || ~isrow(feature)
                error('UEeventCamera:InputError', 'Invalid Event-Trail feature name.');
            end
        
            limits = obj.eventTrailThresholdLimits;
            if isempty(limits)
                error('UEeventCamera:TrailFilterError', ...
                    'Event-Trail threshold limits are unavailable.');
            end
        
            enable = obj.eventTrailFilterEnabled;
            mode = obj.eventTrailFilterMode;
            thresholdUs = obj.eventTrailFilterThresholdUs;
        
            switch feature
                case 'enabled'
                    validateattributes(newValue, {'logical', 'numeric'}, ...
                        {'real', 'finite', 'scalar', 'nonsparse'});
                    if newValue ~= 0 && newValue ~= 1
                        error('UEeventCamera:InputError', ...
                            'Enabled must be true or false.');
                    end
                    enable = logical(newValue);
        
                case 'mode'
                    if isstring(newValue) && isscalar(newValue) && ~ismissing(newValue)
                        newValue = char(newValue);
                    end
                    validModes = {'trail', 'stc_cut_trail', 'stc_keep_trail'};
                    if ~ischar(newValue) || ~isrow(newValue) || ...
                            ~any(strcmpi(newValue, validModes))
                        error('UEeventCamera:InputError', ...
                            'Mode must be trail, stc_cut_trail, or stc_keep_trail.');
                    end
                    mode = lower(newValue);
        
                case 'thresholdUs'
                    validateattributes(newValue, {'numeric'}, ...
                        {'real', 'finite', 'scalar', 'nonsparse', 'integer', ...
                         '>=', limits(1), '<=', limits(2)}, ...
                        'setEventTrailFilter', 'thresholdUs');
                    thresholdUs = double(newValue);
        
                otherwise
                    error('UEeventCamera:InputError', ...
                        'Unknown Event-Trail feature "%s".', feature);
            end
        
            ok = true;
            if enable || strcmp(feature, 'enabled')
                ok = UEeventCamera_mex('setEventTrailFilter', enable, mode, thresholdUs);
                if ~ok
                    error('UEeventCamera:TrailFilterError', ...
                        'Failed to apply the Event-Trail configuration.');
                end
            end
        
            obj.eventTrailFilterEnabled = enable;
            obj.eventTrailFilterMode = mode;
            obj.eventTrailFilterThresholdUs = thresholdUs;
        end

        function ok = setEventRateActivityFilter(obj, enable, lowerStart, lowerStop, upperStart, upperStop)

            thresholds = [ ...
                lowerStart, ...
                lowerStop, ...
                upperStart, ...
                upperStop];
        
            if ~isnumeric(thresholds) || ...
                    any(~isfinite(thresholds)) || ...
                    any(thresholds < 0) || ...
                    any(floor(thresholds) ~= thresholds)
        
                error('UEeventCamera:InputError', ...
                    ['All event-rate thresholds must be non-negative ' ...
                     'integer values in events per second.']);
            end
        
            % Hysteresis must be ordered correctly.
            if lowerStart > lowerStop
                error('UEeventCamera:InputError', ...
                    'lowerStart must be less than or equal to lowerStop.');
            end
        
            if upperStop > upperStart
                error('UEeventCamera:InputError', ...
                    'upperStop must be less than or equal to upperStart.');
            end
        
            ok = UEeventCamera_mex( ...
                'setEventRateActivityFilter', ...
                logical(enable), ...
                lowerStart, ...
                lowerStop, ...
                upperStart, ...
                upperStop);
        
            if ~ok
                error('UEeventCamera:EventRateFilterError', ...
                    'Failed to configure the event-rate activity filter.');
            end
        
            obj.eventRateActivityFilterEnabled = logical(enable);
            obj.eventRateActivityThresholds = thresholds;
        end

    end
      %% Singleton
    methods (Static)
        function obj = getInstance(struct)
            obj = getObjByName(Camera.NAME);
            if isempty(obj)
                missingField = FactoryHelper.usualChecks(struct, CameraAndor.NEEDED_FIELDS);
                if ~isnan(missingField)
                    error('Missing field "%s" for Event camera.', missingField);
                end
                obj = UEeventCamera();
                addBaseObject(obj);
            end
        end

        function clearMemory()
            % Clear internal C++ event buffer
        
            try
                UEeventCamera_mex('clear');
        
            catch ME
                error('Failed to clear Event camera memory: %s', ME.message);
            end
        end

        function triggers = readTriggers()
            triggers = UEeventCamera_mex('readTriggers');
        end

        function clearTriggers()
            UEeventCamera_mex('clearTriggers');
        end
        

        function number = getSerialNumber()
            number = UEeventCamera_mex('getSerialNumber');
        end
    end

      %% overriden from Savable
    methods (Access = protected) 
        function outStruct = saveStateAsStruct(obj, category, type) %#ok<INUSL>
            % Saves the state as struct. if you want to save stuff, make
            % (outStruct = struct;) and put stuff inside. If you dont
            % want to save, make (outStruct = NaN;)
            %
            % category - string. Some objects saves themself only with
            %                    specific category (image/experiments/etc.)
            % type - string.     Whether the objects saves at the beginning
            %                    of the run (parameter) or at its end (result)
            if ~strcmp(type, Savable.TYPE_PARAMS)
                outStruct = NaN;
                return
            end
            
            % Save the three basic camera parameters: ROI, exposure time,
            % binning. Can add more parameters if needed
            imageparams = obj.imgparams;

            outStruct = struct( ...
                'CameraParams', struct( ...
                    'roi', imageparams.roi, ...
                    'exposuretime', imageparams.exposuretime));            
        end
        
        function loadStateFromStruct(obj, savedStruct, ~, ~)

            if ~isfield(savedStruct, 'CameraParams')
                obj.sendWarning('CameraParams field not found.');
                return;
            end
        
            params = savedStruct.CameraParams;
        
            % Physically update camera
            if isfield(params, 'roi')
                obj.setROI(params.roi);
            end
        
            if isfield(params, 'exposuretime')
                obj.setExposureTime(params.exposuretime);
            end
        end
        function string = returnReadableString(obj, savedStruct)

            string = obj.DEFAULT_STRING; 'Camera Parameters';
        
            if ~isfield(savedStruct, 'CameraParams')
                return;
            end
        
            params = savedStruct.CameraParams;
        
            if isfield(params, 'roi')
                string = sprintf('%s\nROI: [%s]', ...
                    string, num2str(params.roi));
            else
                string = sprintf('%s\nROI: NaN', string);
            end
        
            if isfield(params, 'exposuretime')
                string = sprintf('%s\nExposure Time: %g ms', ...
                    string, params.exposuretime/1000);
            else
                string = sprintf('%s\nExposure Time: NaN', string);
            end
        
        end
    end  
end