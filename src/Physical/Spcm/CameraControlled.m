classdef CameraControlled < Spcm & NiDaqControlled
    
    properties (Access = protected)
        % Backup, for NiDaq reset
        isEnabled   % logical
        
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
        end
    %%% End (by time) %%%
    
    
    %%% By Stage %%%
        function prepareCountByStage(obj, stageName, nPixels, timeout, fastScan, pixelTime)
            % Prepare the camera to a scan by a stage. Before a multiline
            % scan, this should be called only once.
            if ~exist('pixelTime', 'var')
                pixelTime = 0.01;
            end
            if ~ValidationHelper.isValuePositiveInteger(nPixels)
                obj.sendError('Can''t prepare for reading %s points, only positive integers allowed! Igonring');
            end
            obj.nScanIntegration = nPixels;
            obj.scanningStageName = stageName;
            obj.pixelTime = pixelTime;
            obj.camera.prepareAcquisition(obj.nScanIntegration, obj.pixelTime);
        end
        
        function startScanCount(obj)
            % Starts reading by scan, this should be called before every line.
            obj.camera.startExperiment;
        end
        
        function [meanCounts, sterrCounts, focusGrades] = readFromScan(obj)
            % Read by scan. Reads a single line.
            if obj.nScanIntegration <= 0
                obj.sendError('Can''t read from camera without calling ''prepare()''! ');
            end
            
            images = obj.camera.readExperimentData();
            meanCounts = mean(images, [2 3]);
            voltageFullReshape = reshape(images, size(images, 1), prod(size(images, [2 3])));
            sterrCounts = ste(voltageFullReshape, 0, 2);
            focusGrades = evaluateFocus(images);
        end
        
        function clearScanRead(obj)
            % Clear the task that scans from stage.
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
            obj.camera.prepareAcquisition(obj.nExpIntegration)
        end
        
        function startExperimentCount(obj)
            obj.camera.startExperiment;
        end
        
        function images = readFromExperiment(obj)
            iamgesFull = obj.camera.readExperimentData();
            images = iamgesFull;
        end
        
        function stopExperimentCount(obj)
        end
        
        function clearExperimentRead(obj)
        end
    %%% End (by PulseGenerator) %%%
    end
    
    methods
        function focusGrades = evaluateFocus(imageMatrix)
            focusGrades = zeros(1, obj.nScanIntegration);
            for i = 1:obj.nScanIntegration
                focusGrades(i) = fmeasure(squeeze(imageMatrix(i, :, :)), 'LAPV', []);
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