classdef PhotoDiodeGatedIntegratorNiDaqControlled < Spcm & NiDaqControlled
    % GatedIntegratorNiDaqControlled Gated Integrator that is controlled by the NiDaq
    % inherit NiDaqControlled, also inherit GatedIntegrator
    
    properties (Access = protected)
        % Backup, for NiDaq reset
        isEnabled   % logical
        
        % For time measure
        voltageIntegrationTime
        nTimeIntegration
        voltageTimeTask
        
        % For scanning
        nScanIntegration
        scanTimeoutTime
        voltageScanIntegratorTask
        voltageScanTimeTask
        fastScan
        scanningStageName
        gatedClockStageTask
        voltageLastPhotodiode
        voltageLastTime
        samplesPerPixel        
        
        % For Experiment
        nExpIntegration
        expTimeoutTime
        gatedClockMeasTask
        measureExpTask
        measureExpTimeTask
        
        expControlTask          % a task to debug when there is problems in the experiments
        
        % Channel Names
        niDaqGateChannelName            % torn on the photodiode power supply
        niDaqPgChannelName              % input from pulse generator for ADC detection triggering
        niDaqVoltageChannelName         % voltage input from of the signal
        niDaqDetectionPathChannelName   % channel of switch for the detection path - through the gated integrator or around
        niDaqGILSBChannelName           % GIgain channel MSB
        niDaqGIMSBChannelName           % GIgain channel LSB
        
        % general
        voltageOffset
        GIvoltageOffset
        temp
    end
    
    properties (Constant, Hidden)
        NEEDED_FIELDS = [Spcm.SPCM_NEEDED_FIELDS, {'nidaq_channel_gate', 'nidaq_channel_pg', 'nidaq_channel_voltage'}];
        OPTIONAL_FIELDS = {'nidaq_channel_min_val', 'nidaq_channel_max_val', 'nidaq_channel_detection_path',...
                           'nidaq_channel_min_voltage', 'nidaq_channel_max_voltage', 'nidaq_channel_GI_LSB', 'nidaq_channel_GI_MSB',...
                           'GI_gain', 'voltage_offset', 'GI_voltage_offset'};
    end
    
    properties
        GIgain                          % gated integrator gain value - 1, 2, 5, 10
        detectionWithGI
    end
    
    methods
        function obj = PhotoDiodeGatedIntegratorNiDaqControlled(name, niDaqGateChannel, niDaqPgChannel, niDaqVoltageChannel, minVoltage, maxVoltage,...
                                                       niDaqGILSBChannel, niDaqGIMSBChannel, niDaqDetectionPathChannel, GIgain, ...
                                                       voltageOffset, GIvoltageOffset, channelMinValue, channelMaxValue)
            % Contructor, creates the object and registers the channels in  the DAQ.
            obj@Spcm(name);
            niDaqGateChannelName = sprintf('%s_gate', name);
            niDaqPgChannelName = sprintf('%s_pg', name);
            niDaqVoltageChannelName = sprintf('%s_voltage', name);
            niDaqGILSBChannelName = sprintf('%s_LSB', name);
            niDaqGIMSBChannelName = sprintf('%s_MSB', name);
            niDaqDetectionPathChannelName = sprintf('%s_detection_path', name);
            obj@NiDaqControlled({niDaqGateChannelName, niDaqPgChannelName, niDaqVoltageChannelName, niDaqDetectionPathChannelName, niDaqGILSBChannelName, niDaqGIMSBChannelName}, ...
                                {niDaqGateChannel,     niDaqPgChannel,     niDaqVoltageChannel,     niDaqDetectionPathChannel,     niDaqGILSBChannel,     niDaqGIMSBChannel}, ...
                                 channelMinValue, channelMaxValue);
            obj.niDaqGateChannelName = niDaqGateChannelName;
            obj.niDaqPgChannelName = niDaqPgChannelName;
            obj.niDaqVoltageChannelName = niDaqVoltageChannelName;
            obj.niDaqDetectionPathChannelName = niDaqDetectionPathChannelName;
            obj.niDaqGILSBChannelName = niDaqGILSBChannelName;
            obj.niDaqGIMSBChannelName = niDaqGIMSBChannelName;
            if ismember(GIgain, [1, 2, 5, 10])
                obj.GIgain = GIgain;
            else
                error('Gated integrator GIgain must be 1, 2, 5 or 10. Change to json file.')
            end
            obj.voltageOffset = voltageOffset;
            obj.GIvoltageOffset = GIvoltageOffset;
            
            daq = getObjByName(NiDaq.NAME);
            obj.isEnabled = daq.readDigital(obj.niDaqGateChannelName);
            obj.nScanIntegration = 0;
            if isempty(minVoltage); minVoltage = -10; end
            if isempty(maxVoltage); maxVoltage =  10; end
            daq.analogInputMinVoltage = minVoltage;
            daq.analogInputMaxVoltage = maxVoltage;
            
            if ~isempty(niDaqDetectionPathChannel)
                obj.availableProperties.(obj.HAS_GATED_INTEGRATOR) = true;
            end
        end
    end
    
    methods % Integrator functions
        function setSPCMEnable(obj, newBooleanValue)
            % Enables/Disables the Integrator.
            daq = getObjByName(NiDaq.NAME);
            daq.writeDigital(obj.niDaqGateChannelName, newBooleanValue)
            if obj.detectionWithGI
                daq.writeDigital(obj.niDaqDetectionPathChannelName, newBooleanValue)
            else
                daq.writeDigital(obj.niDaqDetectionPathChannelName, false)
            end
            %  Switch the MSB and LSB due to the gated integrator GIgain
            if obj.GIgain > 4
                MSB = 1;
            else
                MSB = 0;
            end
            if mod(obj.GIgain, 2)
                LSB = 0;
            else
                LSB = 1;
            end
            daq.writeDigital(obj.niDaqGIMSBChannelName, newBooleanValue*MSB)
            daq.writeDigital(obj.niDaqGILSBChannelName, newBooleanValue*LSB)
            obj.isEnabled = newBooleanValue;
        end
        
    %%% Read by time %%%
        function prepareReadByTime(obj, integrationTimeInSec)
            % Prepare the Integrator to a scan by timer, with integration time of
            % integrationTime in seconds.
            obj.voltageIntegrationTime = integrationTimeInSec;
            sampleRate = 100e3;     % 100 kHz sample rate.
            obj.nTimeIntegration = integrationTimeInSec*sampleRate; 
            
            niDaq = getObjByName(NiDaq.NAME);
            obj.voltageTimeTask = niDaq.CreateDAQcoutiniousVoltageMeas(obj.niDaqVoltageChannelName);
            niDaq.startTask(obj.voltageTimeTask);
        end
        
        function [voltage, sterr] = readFromTime(obj)
            % Reads the voltage for the integration time and returns a
            % single point which is the voltage and also the standard error.
            
%             niDaq = getObjByName(NiDaq.NAME);
%             tic
%             while (~niDaq.isTaskComplete(obj.voltageTimeTask)) && (toc < 10)
%                 pause(0.001);
%             end
            
            try
                voltageFullData = obj.readVoltage(obj.voltageTimeTask, obj.nTimeIntegration, obj.voltageIntegrationTime);
            catch err
                msg = err.message;
                errCodeSlow = '-200279'; % "The application is not able to keep up with the hardware acquisition."
                errCodeTaskAbort = '-88709'; % "The specified operation cannot be performed because a task has been aborted [...]"
                
                if contains(msg, errCodeSlow) 
                    % There was NiDaq reset, we can now safely resume
                    err2warning(err);
                    voltageFullData = obj.readVoltage(obj.voltageTimeTask, obj.nTimeIntegration, obj.voltageIntegrationTime);
                elseif contains(msg, errCodeTaskAbort)
                    obj.prepareReadByTime(obj.voltageIntegrationTime)
                    voltageFullData = obj.readVoltage(obj.voltageTimeTask, obj.nTimeIntegration, obj.voltageIntegrationTime);
                else
                    rethrow(err)
                end
                % ^ This *should* work. If it doesn't, there might be a
                % bigger problem, and we want to let the user know
                % about it.
            end
            
            % Data processing
            voltageData = voltageFullData(voltageFullData ~= -obj.voltageOffset);
            voltage = mean(voltageData);
            sterr = ste(voltageData);     % ste is a home-made function for standard error
        end
        
        function clearTimeRead(obj)
            % Clears the task for reading voltage by time.
            if obj.nTimeIntegration <= 0
                obj.sendError('Can''t clear voltage task without calling ''prepare()''! ');
            end
            obj.nTimeIntegration = 0;
            daq = getObjByName(NiDaq.NAME);
            daq.endTask(obj.voltageTimeTask);
        end
    %%% End (by time) %%%
    
    
    %%% By Stage %%%
        function prepareCountByStage(obj, stageName, nPixels, timeout, fastScan, pixelTime)
            % Prepare the photodiode to a scan by a stage. Before a multiline
            % scan, this should be called only once.
            if ~exist('pixelTime', 'var')
                pixelTime = 0.05;
            end
            if ~ValidationHelper.isValuePositiveInteger(nPixels)
                obj.sendError('Can''t prepare for reading %s points, only positive integers allowed! Igonring');
            end
            obj.samplesPerPixel = pixelTime*1.25e6;     % full aquasition rate
            obj.nScanIntegration = BooleanHelper.ifTrueElse(fastScan, nPixels+1, nPixels); % Fast scans works by edges, so an extra count is needed.
            obj.scanTimeoutTime = timeout;
            obj.fastScan = fastScan;
            obj.scanningStageName = stageName;
            
            niDaq = getObjByName(NiDaq.NAME);
            prepareCountByStageInternal(obj, niDaq);
        end
        
        function startScanCount(obj)
            % Starts reading by scan, this should be called before every line.
            daq = getObjByName(NiDaq.NAME);
            daq.startTask(obj.voltageScanIntegratorTask);
            daq.startTask(obj.voltageScanTimeTask);
            if ~obj.fastScan
                daq.startTask(obj.gatedClockStageTask);
            end
        end
        
        function [voltage, sterr] = readFromScan(obj)
            % Read by scan. Reads a single line.
            if obj.nScanIntegration <= 0
                obj.sendError('Can''t read from SPCM without calling ''prepare()''! ');
            end
            samplesPerPulse = obj.readEdgeCounting(obj.voltageScanTimeTask, obj.nScanIntegration, obj.scanTimeoutTime);
            VoltagePoints = obj.readVoltage(obj.voltageScanIntegratorTask, sum(samplesPerPulse)*2, obj.scanTimeoutTime);
            
            voltage = nan(1, obj.nScanIntegration);
            sterr = nan(1, obj.nScanIntegration);
            VoltagePoints = VoltagePoints(VoltagePoints~=-obj.voltageOffset);
            if length(VoltagePoints) < sum(samplesPerPulse)
                obj.sendError('something wrong...')
            end
            samplesPerPulse = [samplesPerPulse, length(VoltagePoints)-sum(samplesPerPulse)];
            for i = 1:obj.nScanIntegration
                pulseVoltage = VoltagePoints(1 : samplesPerPulse(i));
                % find and delete the samples far from the mean 5 standard
                % deviations (under the assumption there are an error):
                legitPoints = find(abs(pulseVoltage - mean(pulseVoltage)) <= 3*std(pulseVoltage));
                voltage(i) = mean(pulseVoltage(legitPoints));
                sterr(i) = ste(pulseVoltage(legitPoints));
                VoltagePoints(1 : samplesPerPulse(i)) = [];
            end
            
        end
        
        function clearScanRead(obj)
            % Clear the task that scans from stage.
            if obj.nScanIntegration <= 0
                obj.sendError('Can''t clear without calling ''prepare()''! ');
            end
            obj.nScanIntegration = 0;
            daq = getObjByName(NiDaq.NAME);
            daq.endTask(obj.voltageScanIntegratorTask);
            daq.endTask(obj.voltageScanTimeTask);
            if ~obj.fastScan
                daq.endTask(obj.gatedClockStageTask);
            end
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
            
            daq = getObjByName(NiDaq.NAME);
            if obj.detectionWithGI
                obj.measureExpTask = daq.CreateDAQEdgeVoltageMeas(nReads, obj.niDaqVoltageChannelName, obj.niDaqPgChannelName);
                
%                 %%%
%                 obj.expControlTask = daq.CreateDAQCountingMeas(obj.niDaqPgChannelName);
%                 %%%
            else
                [obj.gatedClockMeasTask, gatedClockChannel] = daq.CreateDAQgatedClock(obj.niDaqPgChannelName);
                obj.measureExpTask = daq.CreateDAQclockedVoltageMeas(nReads, obj.niDaqVoltageChannelName, gatedClockChannel);
                obj.measureExpTimeTask = daq.CreateDAQEdgeCountingMeas(nReads, gatedClockChannel, obj.niDaqPgChannelName, 1);
            end
        end
        
        function startExperimentCount(obj)
            % Actually start the process
            daq = getObjByName(NiDaq.NAME);
            if ~obj.detectionWithGI
                daq.startTask(obj.gatedClockMeasTask);
                daq.startTask(obj.measureExpTimeTask);
            end
            daq.startTask(obj.measureExpTask);
            
%             %%%
%             daq.startTask(obj.expControlTask);
%             %%%
        end
        
        function voltage = readFromExperiment(obj)
            % Read vector of voltage signals
            if obj.nExpIntegration <= 0
                obj.sendError('Can''t read the voltage without calling ''prepare()''!');
            end
            
            if obj.detectionWithGI
                daq = getObjByName(NiDaq.NAME);
                
%                 %%%
%                 pgCountedPulses = daq.ReadDAQCounterScalar(obj.expControlTask, obj.expTimeoutTime)
%                 daq.stopTask(obj.expControlTask);
%                 %%%
                
                tic
                while ~daq.isTaskComplete(obj.measureExpTask)
                    if toc > obj.expTimeoutTime
                        toc
                        error('time out: acquisision not complete')
                    end
                    pause(0.001);
                end
            
                voltage = obj.readVoltage(obj.measureExpTask, obj.nExpIntegration, obj.expTimeoutTime);
                if any(voltage == -obj.voltageOffset)
                    error('not enought points!!')
                end
            else
                samplesPerPulse = obj.readEdgeCounting(obj.measureExpTimeTask, obj.nExpIntegration, obj.expTimeoutTime);
                VoltagePoints = obj.readVoltage(obj.measureExpTask, sum(samplesPerPulse)*2, obj.expTimeoutTime);
                
                voltage = nan(1, obj.nExpIntegration);
                VoltagePoints = VoltagePoints(VoltagePoints~=-obj.voltageOffset);
                if length(VoltagePoints) < sum(samplesPerPulse)
                    obj.sendError('something wrong...')
                end
                samplesPerPulse = [samplesPerPulse, length(VoltagePoints)-sum(samplesPerPulse)];
                for i = 1:obj.nExpIntegration
                    pulseVoltage = VoltagePoints(1 : samplesPerPulse(i));
                    % find and delete the samples far from the mean 5 standard
                    % deviations (under the assumption there are an error):
                    legitPoints = find(abs(pulseVoltage - mean(pulseVoltage)) <= 3*std(pulseVoltage));
                    voltage(i) = mean(pulseVoltage(legitPoints));
                    VoltagePoints(1 : samplesPerPulse(i)) = [];
                end
            end
            
        end
        
        function stopExperimentCount(obj)
           % Stop reading (to clear memory)
           daq = getObjByName(NiDaq.NAME);
           daq.stopTask(obj.measureExpTask);
           if ~obj.detectionWithGI
               daq.stopTask(obj.measureExpTimeTask);
               daq.stopTask(obj.gatedClockMeasTask);
           end
        end
        
        function clearExperimentRead(obj)
            % Complete the task of reading the spcm
            if obj.nExpIntegration <= 0
                obj.sendError('Can''t clear without calling ''prepare()''! ');
            end
            obj.nExpIntegration = 0;
            daq = getObjByName(NiDaq.NAME);
            daq.endTask(obj.measureExpTask);
            if ~obj.detectionWithGI
                daq.endTask(obj.measureExpTimeTask);
                daq.endTask(obj.gatedClockMeasTask);
            end
            
%            %%%
%            daq.endTask(obj.expControlTask);
%            %%%
        end
    %%% End (by PulseGenerator) %%%
    end
    
        
    methods (Access = protected)
        function voltage = readVoltage(obj, daqTask, nVoltage, timeout, niDaq)
            if exist('niDaq', 'var')
                % We are using workers (parallel pool), so we need to load
                % the NI-DAQ library
                LoadNIDAQmx
            else
                niDaq = getObjByName(NiDaq.NAME);
            end
            
            %%% Actually reading
            voltage = double(niDaq.readDAQVoltage(daqTask, nVoltage, timeout));
            if obj.detectionWithGI
                voltage = voltage - obj.GIvoltageOffset;
            else
                voltage = voltage - obj.voltageOffset;
            end
        end
    end

    % photodiode protected methods
    methods (Access = protected)
        function prepareCountByStageInternal(obj, niDaq)
            % Creates the measurment in the DAQ according to the parameters
            % in the object.
            if obj.fastScan
                warning('fast scan with photodiode not checked!');
                obj.voltageScanIntegratorTask = niDaq.CreateDAQclockedVoltageMeas(obj.nScanIntegration, obj.niDaqVoltageChannelName, niDaq.CHANNEL_100kHZ, obj.samplesPerPixel);
                obj.voltageScanTimeTask = niDaq.CreateDAQEdgeCountingMeas(obj.nScanIntegration, niDaq.CHANNEL_100kHZ, obj.scanningStageName, 1);
            else
                [obj.gatedClockStageTask, gatedClockChannel] = niDaq.CreateDAQgatedClock(obj.scanningStageName);
                obj.voltageScanIntegratorTask = niDaq.CreateDAQclockedVoltageMeas(obj.nScanIntegration, obj.niDaqVoltageChannelName, gatedClockChannel, obj.samplesPerPixel);
                obj.voltageScanTimeTask = niDaq.CreateDAQEdgeCountingMeas(obj.nScanIntegration, gatedClockChannel, obj.scanningStageName, 1);
                obj.voltageLastPhotodiode = 0;
                obj.voltageLastTime = 0;
            end
        end
    end

    methods (Static, Access = protected)
        function counts = readEdgeCounting(daqTask, nCounts, timeout, niDaq)
            if exist('niDaq', 'var')
                % We are using workers (parallel pool), so we need to load
                % the NI-DAQ library
                LoadNIDAQmx
            else
                niDaq = getObjByName(NiDaq.NAME);
            end
            counts = double(niDaq.ReadDAQCounter(daqTask, nCounts, timeout));
            counts = niDaq.countDiff(counts);
        end
        
        function [counts, countsLast] = readPulseWidthCounting(daqTask, nCounts, timeout, countsLast)
            % This is used for pseudo pulse-width counting. We actually use
            % edge counting with a pause trigger. This means that we need to
            % add a 0 in the beginning of the read vector, and then caculate
            % the difference between pairs of readings.
            if ~exist('countsLast', 'var')
                countsLast = 0;
            end
            niDaq = getObjByName(NiDaq.NAME);
            countsAccum = double(niDaq.ReadDAQCounter(daqTask, nCounts, timeout));
            counts = niDaq.countDiff([countsLast countsAccum]);
            countsLast = countsAccum(end);
        end
        
    end
    
    %%%
    methods % DAQ function
        function onNiDaqReset(obj, niDaq)
            % This function jumps when the NiDaq resets
%             if obj.nScanIntegration > 0
%                 prepareMeasureByStageInternal(obj, niDaq);
%             end
            if obj.isEnabled
                % When reset, the NiDaq no longer remembers whether the
                % channel was off or on. We need to set the value, but only
                % if needed (since writeDigital is costly)
                obj.setSPCMEnable(obj.isEnabled)
            end
        end
    end
  
    methods (Static)
        function PhotoDiodeObj = create(PhotoDiodeName, PhotoDiodeStruct)
            missingField = FactoryHelper.usualChecks(PhotoDiodeStruct, PhotoDiodeGatedIntegratorNiDaqControlled.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Can''t initialize NiDaq-controlled PhotoDiode - required field "%s" was not found in initialization struct!', ...
                    missingField);
            end
            
            % We want to get either values set in json, or empty variables
            % (which will be handled by NiDaqControlled constructor):
            PhotoDiodeStruct = FactoryHelper.supplementStruct(PhotoDiodeStruct, PhotoDiodeGatedIntegratorNiDaqControlled.OPTIONAL_FIELDS);
            
            voltage = PhotoDiodeStruct.nidaq_channel_voltage;
            gate = PhotoDiodeStruct.nidaq_channel_gate;
            pg = PhotoDiodeStruct.nidaq_channel_pg;
            minVoltage = PhotoDiodeStruct.nidaq_channel_min_voltage;
            maxVoltage = PhotoDiodeStruct.nidaq_channel_max_voltage;
            GILSB = PhotoDiodeStruct.nidaq_channel_GI_LSB;
            GIMSB = PhotoDiodeStruct.nidaq_channel_GI_MSB;
            detectionPath = PhotoDiodeStruct.nidaq_channel_detection_path;
            GIgain = PhotoDiodeStruct.GI_gain;
            minVal = PhotoDiodeStruct.nidaq_channel_min_val;
            maxVal = PhotoDiodeStruct.nidaq_channel_max_val;
            voltageOffset = PhotoDiodeStruct.voltage_offset;
            GIvoltageOffset = PhotoDiodeStruct.GI_voltage_offset;
            
            PhotoDiodeObj = PhotoDiodeGatedIntegratorNiDaqControlled(PhotoDiodeName, gate, pg, voltage, minVoltage, maxVoltage, ...
                GILSB, GIMSB, detectionPath, GIgain, voltageOffset, GIvoltageOffset, minVal, maxVal);
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