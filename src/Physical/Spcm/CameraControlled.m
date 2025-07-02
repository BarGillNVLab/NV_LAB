classdef CameraControlled < Spcm & NiDaqControlled
    
    properties (Access = protected)
        % Backup, for NiDaq reset
        isEnabled   % logical
        exposureInitState

        % For time measure
        voltageIntegrationTime
        nTimeIntegration
        voltageTimeTask
        
        
        % For scanning
        nScanIntegration
        scanningStageName
        pixelTime
        
        % For ExperimentCameraControlled
        nExpIntegration
        expTimeoutTime
        measureExpTask
        triggerType
        
        % Channel Names
        niDaqGateChannelName            % torn on the photodiode power supply
        
    end
    
    properties
        camera              % camera object
    end
    
    properties (Constant, Hidden)
        NEEDED_FIELDS = [Spcm.SPCM_NEEDED_FIELDS];
        OPTIONAL_FIELDS = {};
    end
    
    methods
        function obj = CameraControlled(name)
            % Contructor, creates the object and registers the channels in the DAQ.
            obj@Spcm(name);
            obj@NiDaqControlled([], [], [], []);
            obj.camera = Camera.create();
            obj.availableProperties.(obj.HAS_CAMERA) = true;
        end
    end
    
    methods % Integrator functions
        function setSPCMEnable(obj, newBooleanValue)
        end
        
    %%% Read by time %%%
        function prepareReadByTime(obj)
            % Prepare the Integrator to a scan by timer, with integration time of
            % integrationTime in seconds.
%             obj.camera.prepareAcquisition(exposureTime);
            obj.camera.setTriggerType('manual');
            obj.camera.StartRead;

        end
        
        function image = readFromTime(obj, averageExposures, nframes, timeDelay)
            if ~exist("averageExposures", "var")
                image = obj.camera.ImageAcquire();
                return
            end
            if averageExposures
                image = obj.camera.read(nframes, timeDelay);
            else
                image = obj.camera.ImageAcquire();
            end
        end

        function clearTimeRead(obj)
            % Clears the task for reading voltage by time.
            obj.camera.stopRead;
            cameraprop = obj.camera.imgparams;
            if cameraprop.exposuretime ~= obj.camera.src.ExposureTime
                cameraprop.exposuretime = obj.camera.src.ExposureTime;
                obj.camera.sendEventScanParamsChanged;
            end
        end
    %%% End (by time) %%%
    
    
    %%% By Stage %%%
    function prepareCountByStage(obj, stageName, nPixels, timeout, isFastScan, pixelTime)
            % Prepare the camera to a scan by a stage. Before a multiline
            % scan, this should be called only once.
            
            if ~ValidationHelper.isValuePositiveInteger(nPixels)
                obj.sendError('Can''t prepare for reading %s points, only positive integers allowed! Igonring');
            end
            pg = getObjByName(PulseGenerator.NAME);
            pg.Off('detector');
            obj.nScanIntegration = nPixels;
            obj.scanningStageName = stageName;
            obj.camera.timeout = timeout;
            obj.pixelTime = pixelTime*1e03;  % pixel time in millisec
            obj.exposureInitState = obj.camera.getExposureAuto;
            exposureTime = obj.camera.imgparams.exposuretime*1e-3;
            if exposureTime > obj.pixelTime
                obj.camera.setExposureTime(obj.pixelTime-0.25*obj.pixelTime);
            end
            obj.camera.setTriggerType('hardware');
            obj.camera.framesPerTrigger(1);
            obj.camera.setTriggerRepeats(nPixels);
            
        end
        
        function startScanCount(obj)
            % Starts reading by scan, this should be called before every line.
            obj.camera.StartRead;
        end
        
        function [meanCounts, sterrCounts, focusGrades] = readFromScan(obj)
            % Read by scan. Reads a single line.
            if obj.nScanIntegration <= 0
                obj.sendError('Can''t read from camera without calling ''prepare()''! ');
            end
            if obj.camera.IsLoggin
                obj.camera.stopRead;
            end
            images = obj.camera.readfromcamera(obj.nScanIntegration);
            images = squeeze(double(images));
            meanCounts = squeeze(mean(images, [1 2]));
            voltageFullReshape = reshape(images, size(images, 3), prod(size(images, [1 2])));
            sterrCounts = ste(voltageFullReshape, 0, 1);
            focusGrades = obj.evaluateFocus(images);
        end
        
        function clearScanRead(obj)
            obj.camera.clearMemory;
            obj.camera.setTriggerType('manual');
            obj.camera.allData = {};
            obj.camera.setExposureAuto(obj.exposureInitState);
        end
    %%% End (By stage) %%%%
        
        
    %%% By PulseGenerator (Experiment) %%%
        function prepareExperimentCount(obj, nReads, timeout, nParemeters)
            % Prepare to read voltage from opening the detector window
            if ~ValidationHelper.isValuePositiveInteger(nReads)
                obj.sendError(sprintf('Can''t prepare for reading %d times, only positive integers allowed! Igonring.', nReads));
            end
            obj.nExpIntegration = nReads;
            obj.expTimeoutTime = timeout;
            obj.camera.prepareExperiment(obj.nExpIntegration, obj.expTimeoutTime);
        end
    
        function startExperimentCount(obj)
            obj.camera.stopRead;
            obj.camera.StartRead;
        end
    
        function images = readFromExperiment(obj)
            if obj.camera.IsLoggin
                obj.camera.stopRead;
            end
            iamgesFull = obj.camera.readExperimentData(obj.nExpIntegration);
            images = double(permute(iamgesFull, [4, 1, 2, 3]));
        end
    
        function stopExperimentCount(obj)
        end

        function returnToDefault(obj)
            obj.camera.resetToDefault;
        end

    
        function clearExperimentRead(obj)
        end
    %%% End (by PulseGenerator) %%%
    end
    
    methods
        function focusGrades = evaluateFocus(obj, imageMatrix)
            focusGrades = zeros(1, obj.nScanIntegration);
            for i = 1:obj.nScanIntegration
                focusGrades(i) = fmeasure(squeeze(imageMatrix(:, :, i)), 'LAPV', []);
            end
        end
 
        function onNiDaqReset()
        end
    end
    
    methods (Static)
        function finalValue = roundOrError(value, digits, epsilon, errorTxt)
            % check wheather the value is not rounded. If the error larger
            % than epsilon its return error, otherwise it rounded
            if ~prod((value - round(value, digits)) == 0)
                if max(abs((value - round(value, digits)))) > epsilon
                    error(errorTxt)
                else
                    finalValue = round(value, digits);
                end
            else
                finalValue = value;
            end
        end
        
        function CameraObj = create(CameraName, CameraStruct)
            missingField = FactoryHelper.usualChecks(CameraStruct, CameraControlled.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Can''t initialize Camera - required field "%s" was not found in initialization struct!', ...
                    missingField);
            end
            
            % We want to get either values set in json, or empty variables
            % (which will be handled by NiDaqControlled constructor):
            CameraStruct = FactoryHelper.supplementStruct(CameraStruct, CameraControlled.OPTIONAL_FIELDS);
            CameraObj = CameraControlled(CameraName);
        end
    end
    
    %% Overridden from spcm
    methods (Static)
        % Auxilary function, for parallel reading: we need to fetch objects
        % before sending task to workers
        function measuringObj = variablesForTimeRead
            measuringObj = getObjByName(NiDaq.NAME);
        end
    end

end