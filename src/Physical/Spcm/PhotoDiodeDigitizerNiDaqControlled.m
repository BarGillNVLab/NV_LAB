classdef PhotoDiodeDigitizerNiDaqControlled < Spcm & NiDaqControlled
    
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
        
        % For Experiment
        nExpIntegration
        expTimeoutTime
        measureExpTask
        
        % Channel Names
        niDaqGateChannelName            % torn on the photodiode power supply
        niDaqOffsetChannelName
    end
    
    properties
        currentChannelGUI = 1;     % The channnel to read by time and stage. we have 3 photodiode: #1: fluorescence, #2: laser sampling, #3: laser block (optional)
        % PD fluorescence               % #1
        % PD fluorescence Referenced    % #1 / (#2 normalized)
        % PD laser sample               % #2
        % PD laser block                % #3
        % PD both                       % #1 + #2
        
        diffrentialInputGUI         % The input configuration to read by time and stage. options: #1: diffrential, #2: normal, #3: display both
        balancedMeas = 0;           % boolean. If to measure both laser and flourescence and to normalize.
        diffrentialInput
        digitizerChannelNames
        digitizerChannelValues
        segmentDuration
        detectionWithGI = 0;

        % For cases when required the full acquired data:
        fullDataAcquisition = 0;
        recordVoltageSpan = 0       % boolean. When true the object saves the measured voltage histogram
        voltageHistogram            % struct with the bins and values of the measures voltage
        daqVolatgeOffset = [];      % Optional way to generate DC voltage from DAQ as an offset voltage to differential input.
    end
    
    properties (Dependent)
        activeChannelsGUI
        activeChannelsMeas
    end
    
    properties (Constant, Hidden)
        NEEDED_FIELDS = [Spcm.SPCM_NEEDED_FIELDS, {'nidaq_channel_gate', 'digitizer_channel_names', 'digitizer_channel_values', ...
                         'input_configuration', 'reference_laser_measurement', 'voltage_offset', 'max_voltage', 'input_impedance'}];
        OPTIONAL_FIELDS = {'nidaq_channel_min_val', 'nidaq_channel_max_val', 'channel_delay', 'nidaq_channel_gate', 'nidaq_channel_offset'};
        PHOTODIODE_OPTIONS = {'PD fluorescence', 'PD fluores norm', 'PD laser sample', 'PD laser block', 'PD both'};
        TYPE_OPTIONS = {'diffrential', 'normal', 'diff - both'};
    end

    methods
        function obj = PhotoDiodeDigitizerNiDaqControlled(name, niDaqGateChannel, digitizerChannelNames, digitizerChannelValues, inputConfiguration, ...
                                                          referenceLaserMeasurement, channelDelay, maxVoltage, inputImpedance, voltageOffset, nidaqChannelOffset, channelMinValue, channelMaxValue)
            % Contructor, creates the object and registers the channels in the DAQ.
            obj@Spcm(name);
            niDaqGateChannelName = sprintf('%s_gate', name);
            niDaqOffsetChannelName = sprintf('%s_offset', name);
            if ~isempty(nidaqChannelOffset)
                channelsNames = {niDaqGateChannelName, niDaqOffsetChannelName};
                channels = {niDaqGateChannel, nidaqChannelOffset};
            else
                channelsNames = {niDaqGateChannelName};
                channels = {niDaqGateChannel};
            end
            obj@NiDaqControlled(channelsNames, channels, num2cell(channelMinValue), num2cell(channelMaxValue));
            digi = Digitizer();
            
            obj.availableProperties.(obj.HAS_PHOTODIODE) = true;
            if strcmpi(inputConfiguration, 'diff')
                obj.availableProperties.(obj.HAS_DIFF_INPUT) = true;
                obj.diffrentialInput = 1;
                obj.diffrentialInputGUI = 1;
            elseif strcmpi(inputConfiguration, 'norm')
                obj.availableProperties.(obj.HAS_DIFF_INPUT) = false;
                obj.diffrentialInput = 0;
                obj.diffrentialInputGUI = 2;
            else
                obj.sendError('Digitizer input configuration can be only ''diff'' or ''norm''!');
            end
            obj.availableProperties.(obj.HAS_LASER_REF) = referenceLaserMeasurement;
            if referenceLaserMeasurement
                obj.balancedMeas = 1;           % balanced meas as defult
            end
            
            obj.niDaqGateChannelName = niDaqGateChannelName;
            obj.niDaqOffsetChannelName = niDaqOffsetChannelName;
            obj.digitizerChannelNames = digitizerChannelNames;
            obj.digitizerChannelValues = digitizerChannelValues;
            
            daq = getObjByName(NiDaq.NAME);
            obj.isEnabled = daq.readDigital(obj.niDaqGateChannelName);
            digi.maxVoltage = maxVoltage;
            digi.voltageOffset = voltageOffset;
            digi.inputImpedance = inputImpedance;
            if isempty(channelDelay)
                channelDelay = digitizerChannelValues * 0;
            end
            if any(mod(channelDelay * digi.MAX_SAMPLE_RATE, 1))
                obj.sendError('Digitizer channel delay durration must be a complete period of the maximum digitizer sample rate - %d MHz', digi.MAX_SAMPLE_RATE);
            end
            digi.channelDelay = channelDelay;
        end
    end
    
    methods % Integrator functions
        function setSPCMEnable(obj, newBooleanValue)
            % Enables/Disables the Integrator.
            daq = getObjByName(NiDaq.NAME);
            daq.writeDigital(obj.niDaqGateChannelName, newBooleanValue)
            obj.isEnabled = newBooleanValue;
        end
        
    %%% Read by time %%%
        function prepareReadByTime(obj, integrationTimeInSec)
            % Prepare the Integrator to a scan by timer, with integration time of
            % integrationTime in seconds.
            digi = getObjByName(Digitizer.NAME);
            obj.voltageIntegrationTime = integrationTimeInSec * digi.UNIT_CONV;
            sampleRate = 1;     % 1 MHz should be enough
            digi.prepareAcquisition(obj.activeChannelsGUI, 1, obj.voltageIntegrationTime, 0, sampleRate);
        end
        
        function [voltage, sterr] = readFromTime(obj)
            % Reads the voltage for the integration time and returns a
            % single point which is the voltage and also the standard error.
            digi = getObjByName(Digitizer.NAME);
            digi.startExperiment;
            digi.forceAcquisition;
            digi.waitForDeviceReady;
            voltageFull = digi.readExperimentData(obj.activeChannelsGUI, true, true);
            
            if any(obj.currentChannelGUI == [1 2 5])
                switch obj.diffrentialInputGUI
                    case 1      % diffrential input
                        v = squeeze(voltageFull(1, :, :))' - squeeze(voltageFull(2, :, :))';
                    case 2      % normal input
                        v = squeeze(voltageFull(1, :, :))';
                    case 3      % normal input - both channels
                        v = [squeeze(voltageFull(1, :, :))'; squeeze(voltageFull(2, :, :))'];
                end
            end
            
            switch obj.currentChannelGUI
                case 2          % PD fluorescence Referenced 
                    laserRef = squeeze(voltageFull(end, :, :))';
                    laserRef = laserRef / mean(laserRef);
                    v = v ./ laserRef;
                case {3, 4}     % laser PDs
                    v = squeeze(voltageFull(1, :, :))';
                case 5          % PD fluorescence & laser sample - both
                    v = [v; squeeze(voltageFull(end, :, :))'];
            end
            
            voltage = mean(v, 2, "omitnan");
            sterr = ste(v, 0, 2);
        end
        
        function clearTimeRead(obj)
            % Clears the task for reading voltage by time.
            digi = getObjByName(Digitizer.NAME);
            digi.stopAcquisition;
        end
    %%% End (by time) %%%
    
    
    %%% By Stage %%%
        function prepareCountByStage(obj, stageName, nPixels, timeout, fastScan, pixelTime)
            % Prepare the photodiode to a scan by a stage. Before a multiline
            % scan, this should be called only once.
            if ~exist('pixelTime', 'var')
                pixelTime = 0.01;
            end
            if ~ValidationHelper.isValuePositiveInteger(nPixels)
                obj.sendError('Can''t prepare for reading %s points, only positive integers allowed! Igonring');
            end
            digi = getObjByName(Digitizer.NAME);
            obj.nScanIntegration = nPixels;
            obj.scanningStageName = stageName;
            obj.pixelTime = pixelTime * digi.UNIT_CONV;
            sampleRate = 1;     % 1 MHz should be enough
            digi.prepareAcquisition(obj.activeChannelsGUI, obj.nScanIntegration, obj.pixelTime, 1, sampleRate);
        end
        
        function startScanCount(obj)
            % Starts reading by scan, this should be called before every line.
            digi = getObjByName(Digitizer.NAME);
%             digi.stopAcquisition;
%             digi.prepareAcquisition(obj.digitizerChannelNames, obj.nScanIntegration, obj.pixelTime);
            digi.startExperiment;
        end
        
        function [voltage, sterr] = readFromScan(obj)
            % Read by scan. Reads a single line.
            if obj.nScanIntegration <= 0
                obj.sendError('Can''t read from Digitizer without calling ''prepare()''! ');
            end
            
            digi = getObjByName(Digitizer.NAME);
            voltageFull = digi.readExperimentData(obj.activeChannelsGUI, true, true);
            if size(voltageFull, 2) ~= obj.nScanIntegration
                error('wrong number of points acquired')
            end
            
            if any(obj.currentChannelGUI == [1 2 5])
                switch obj.diffrentialInputGUI
                    case {1, 3}     % diffrential input
                        v = voltageFull(1, :, :) - voltageFull(2, :, :);
                    case 2          % normal input
                        v = voltageFull(1, :, :);
                end
            end
            
            switch obj.currentChannelGUI
                case {2, 5}         % PD fluorescence Referenced 
                    laserRef = voltageFull(end, :, :);
                    laserRef = laserRef ./ mean(laserRef, 3, "omitnan");
                    v = v ./ laserRef;
                case {3, 4}         % laser PDs
                    v = voltageFull(1, :, :);
            end
            
            v = squeeze(v);
            voltage = mean(v, 2, "omitnan");
            sterr = ste(v);
        end
        
        function clearScanRead(obj)
            % Clear the task that scans from stage.
            digi = getObjByName(Digitizer.NAME);
            digi.stopAcquisition;
        end
    %%% End (By stage) %%%%
        
        
    %%% By PulseGenerator (Experiment) %%%
        function prepareExperimentCount(obj, nReads, timeout, nParemeters)
            % Prepare to read voltage from opening the detector window
            if ~ValidationHelper.isValuePositiveInteger(nReads)
                obj.sendError(sprintf('Can''t prepare for reading %d times, only positive integers allowed! Igonring.', nReads));
            end
            digi = getObjByName(Digitizer.NAME);
            obj.nExpIntegration = nReads;
%             if obj.fullDataAcquisition
%                 obj.nExpIntegration = nReads / (obj.segmentDuration*digi.MAX_SAMPLE_RATE);
%             end
            obj.expTimeoutTime = timeout;
            digi.prepareAcquisition(obj.activeChannelsMeas, obj.nExpIntegration, obj.segmentDuration)
            if obj.recordVoltageSpan
                obj.voltageHistogram = struct;
                obj.voltageHistogram.bins = -digi.maxVoltage(1):0.001:digi.maxVoltage(1);
                obj.voltageHistogram.values = zeros(1+obj.diffrentialInput, length(obj.voltageHistogram.bins)-1);
            end
            if ~isempty(obj.daqVolatgeOffset)
                daq = getObjByName(NiDaq.NAME);
                daq.writeVoltage(obj.niDaqOffsetChannelName, obj.daqVolatgeOffset);
            end

        end
        
        function startExperimentCount(obj)
            % Actually start the process
            digi = getObjByName(Digitizer.NAME);
            digi.startExperiment;
        end
        
        function voltage = readFromExperiment(obj)
            digi = getObjByName(Digitizer.NAME);
            voltageFull = digi.readExperimentData(obj.activeChannelsMeas, true, true);
            
            if size(voltageFull, 2) ~= obj.nExpIntegration
                error('wrong number of points acquired')
            end
            
            if obj.recordVoltageSpan
                vFull = voltageFull(1,:,:);
                voltageHist = histcounts(vFull(:), obj.voltageHistogram.bins);
                obj.voltageHistogram.values(1,:) = obj.voltageHistogram.values(1,:) + voltageHist;
                if obj.diffrentialInput
                    vFull = voltageFull(2,:,:);
                    voltageHist = histcounts(vFull(:), obj.voltageHistogram.bins);
                    obj.voltageHistogram.values(2,:) = obj.voltageHistogram.values(2,:) + voltageHist;
                end
            end

            diffAsBalanced = 1;

            if obj.diffrentialInput && ~diffAsBalanced
                % diffSignal = voltageFull(2, :, :);
                % diffSignal = mean(diffSignal, 3, "omitnan");                            % mean over fast noise - we avarage it anyway
                % diffSignal = diffSignal ./ mean(diffSignal, 2, "omitnan");                % normalization to the mean value
                % v = voltageFull(1, :, :) - diffSignal;
                v = voltageFull(1, :, :) - voltageFull(2, :, :);
                % v = voltageFull(2, :, :);
            else
                v = voltageFull(1, :, :);
            end
            
            if obj.balancedMeas || diffAsBalanced
                % v = voltageFull(end, :, :);
                laserRef = voltageFull(end, :, :);
                laserRef = mean(laserRef, 3, "omitnan");                            % mean over fast noise - we avarage it anyway
                laserRef = laserRef ./ mean(laserRef, 2, "omitnan");                % normalization to the mean value
                v = v ./ laserRef;
            end
            
            v = squeeze(v);
            if ~obj.fullDataAcquisition
                voltage = mean(v, 2, "omitnan");
            else
                voltage = v;
            end

            if mean(voltage(1:2:end) ./ voltage(2:2:end), "omitnan") < 0
                q = 1;
            end
        end
        
        function stopExperimentCount(obj)
            digi = getObjByName(Digitizer.NAME);
            digi.stopAcquisition;
        end
        
        function clearExperimentRead(obj)
            if ~isempty(obj.daqVolatgeOffset)
                daq = getObjByName(NiDaq.NAME);
                daq.writeVoltage(obj.niDaqOffsetChannelName, 0);
            end
        end
    %%% End (by PulseGenerator) %%%
    end
    
    methods
        function onNiDaqReset(obj)
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
        
        function channels = get.activeChannelsGUI(obj)
            FLchan = find(strcmp({'input'}, obj.digitizerChannelNames));
            if any(obj.diffrentialInputGUI == [1 3])
                FLchan = [FLchan, find(strcmp({'input_inverse'}, obj.digitizerChannelNames))];
            end
            laserSampleChan = find(strcmp({'laser_sample'}, obj.digitizerChannelNames));
            laserBlockChan = find(strcmp({'laser_block'}, obj.digitizerChannelNames));
            
            switch obj.currentChannelGUI
                case 1          % PD fluorescence
                    channels = FLchan;
                case {2, 5}     % PD fluorescence Referenced / both
                    channels = [FLchan, laserSampleChan];
                case 3          % PD laser sample
                    channels = laserSampleChan;
                case 4          % PD laser block
                    channels = laserBlockChan;
            end
        end
        
        function channels = get.activeChannelsMeas(obj)
            channels = find(strcmp({'input'}, obj.digitizerChannelNames));
            if obj.diffrentialInput
                channels = [channels, find(strcmp({'input_inverse'}, obj.digitizerChannelNames))];
            end
            if obj.balancedMeas
                channels = [channels, find(strcmp({'laser_sample'}, obj.digitizerChannelNames))];
            end
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
        
        function PhotoDiodeObj = create(PhotoDiodeName, PhotoDiodeStruct)
            missingField = FactoryHelper.usualChecks(PhotoDiodeStruct, PhotoDiodeDigitizerNiDaqControlled.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Can''t initialize NiDaq-controlled PhotoDiode - required field "%s" was not found in initialization struct!', ...
                    missingField);
            end
            
            % We want to get either values set in json, or empty variables
            % (which will be handled by NiDaqControlled constructor):
            PhotoDiodeStruct = FactoryHelper.supplementStruct(PhotoDiodeStruct, PhotoDiodeDigitizerNiDaqControlled.OPTIONAL_FIELDS);
            
            gate = PhotoDiodeStruct.nidaq_channel_gate;
            digitizerChannelNames = PhotoDiodeStruct.digitizer_channel_names;
            digitizerChannelValues = PhotoDiodeStruct.digitizer_channel_values;
            maxVoltage = PhotoDiodeStruct.max_voltage;
            inputImpedance = PhotoDiodeStruct.input_impedance;
            minVal = PhotoDiodeStruct.nidaq_channel_min_val;
            maxVal = PhotoDiodeStruct.nidaq_channel_max_val;
            voltageOffset = PhotoDiodeStruct.voltage_offset;
            inputConfiguration = PhotoDiodeStruct.input_configuration;
            referenceLaserMeasurement = PhotoDiodeStruct.reference_laser_measurement;
            nidaqChannelOffset = PhotoDiodeStruct.nidaq_channel_offset;
            channelDelay = PhotoDiodeStruct.channel_delay;
            PhotoDiodeObj = PhotoDiodeDigitizerNiDaqControlled(PhotoDiodeName, gate, digitizerChannelNames, digitizerChannelValues, ...
                        inputConfiguration, referenceLaserMeasurement, channelDelay, maxVoltage, inputImpedance, voltageOffset, nidaqChannelOffset, minVal, maxVal);
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