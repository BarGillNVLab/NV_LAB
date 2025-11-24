classdef SpcmTimeTaggerControlledArduinoDaqEnabled < Spcm
    % TimeTagger-controlled SPCM, gated by ArduinoGP8413Dac
    % Full feature parity with SpcmTimeTaggerControlledNiDaqEnabled, but
    % using an Arduino-based DAQ (GP8413 DAC + digital pins) instead of NiDaq.
    %
    % Gate line:
    %   - "arduino_gate_channel" in JSON can be either:
    %       "dN"   -> digital pin N, gate via writeDigital()
    %       "aoN"  -> analog output N, gate via writeVoltage(0/5V)
    %   - Optional: "arduino_alt_gate_channel" (same format), for alt counter.

    properties % Public
        lastTimeG2      % The last G2 from a time measurement
        lastTimeHist    % The last hist from a time measurement
        lastScanHist    % The last hist from a scan
        lastExpHist     % The last hist from an experiment

        countWithLifeTime = false; % If true, use lifetime hist to compute counts
    end

    properties (SetAccess = {?ViewSpcmControl})
        binWidth    % Hist bin width in ps
        nBins       % Number of bins in hist
        startRead   % Bin index to start readout
        endRead     % Bin index to stop readout
    end

    properties (Access = {?ViewSpcmControl})
        % State
        isEnabled   % logical

        % Hardware
        tt          % TimeTaggerWrapper
        daq         % ArduinoGP8413Dac

        % For scanning
        nScanPixels
        scanTimeoutTime
        counterScanTask
        counterScanHistTask
        fastScan
        scanningStageName
        slowScanStageChannelName
        combinedRisingFallingStageVirtualChannel
        scanSyncMeasTask

        % For experiments
        nExpCounts
        nExpParams
        expTimeoutTime
        expPGChannelName
        counterExpTask
        counterExpHistTask
        combinedRisingFallingPGVirtualChannel
        expSyncMeasTask
        debugCBM

        % For time counter
        counterIntegrationTime
        counterTimeTask
        counterTime2Task
        counterTimeHistTask
        counterTimeG2Task
        counterTimer
        timeSyncMeasTask

        % Channels (logical names registered in TimeTagger / DAQ)
        niDaqGateChannelName              % reused name, but actually Arduino gate logical name
        timeTaggerCount1ChannelName
        timeTaggerPGChannelName

        % Two counters
        timeTaggerCount2ChannelName       % second SPCM / PMT
        timeTaggerCountCombinedChannelName
        combinedCountVirtualChannel

        % Alt counter
        timeTaggerAltCountChannelName
        niDaqAltGateChannelName           % reused name, but Arduino alt gate logical name

        % Pulsed lasers
        timeTaggerLaserChannelName

        % Configuration
        hardwareFilter
        bLifetime = 1;
        currentCounter = 1;               % Options are given in COUNT_OPTIONS

        % Arduino-specific gate mode
        isGateAnalog      = false;        % true if main gate is AOx (analog)
        isAltGateAnalog   = false;        % true if alt gate is AOx (analog)
    end

    properties (Constant)
        DEFAULT_TIME_NUMBER_COUNTS = 1000;      % Always read 1000 time bins
        DEFAULT_HIST_BIN_WIDTH     = 100;       % 100 ps
        DEFAULT_HIST_NUMBER_BINS   = 490;       % 490 bins = 49 ns
        COUNT_OPTIONS = {'SPCM 1', 'SPCM 2', 'SPCM 1 & 2', 'SPCM Sum', 'PMT'};
    end

    properties (Constant, Hidden)
        NEEDED_FIELDS_SPCM_ARDUINO_TIMETAGGER = { ...
            'arduino_gate_channel', ...
            'timeTagger_channel_counts', ...
            'timeTagger_channel_counts_delay', ...
            'timeTagger_channel_pg', ...
            'timeTagger_channel_pg_delay'};

        OPTIONAL_FIELDS_SPCM_ARDUINO_TIMETAGGER = { ...
            'arduino_alt_gate_channel', ...
            'timeTagger_channel_counts2', ...
            'timeTagger_channel_counts2_delay', ...
            'timeTagger_channel_alt_counts', ...
            'timeTagger_channel_alt_counts_delay', ...
            'timeTagger_channel_laser', ...
            'timeTagger_channel_laser_delay', ...
            'timeTagger_conditionalFilter_trigger_channel', ...
            'timeTagger_conditionalFilter_filter_channel', ...
            'timeTagger_bin_width', ...
            'timeTagger_number_bins', ...
            'timeTagger_start_bin', ...
            'timeTagger_end_bin'};
    end

    properties (Dependent)
        bUseAltCounter
    end

    % =====================================================================
    %                         GETTERS / SETTERS
    % =====================================================================
    methods
        function value = get.bUseAltCounter(obj)
            value = obj.currentCounter == 5; % Alt counter is option 5
        end

        function set.currentCounter(obj, newValue)
            if obj.isEnabled %#ok<MCSUP>
                counter = getObjByName(SpcmCounter.NAME);
                if isempty(counter) || ~counter.isRunning
                    obj.sendWarning('Can''t change counter while counter is turned on');
                    return
                end
            end
            if obj.currentCounter ~= newValue
                obj.currentCounter = newValue;
                obj.resetTimeRead();
                obj.resetScanRead();
                obj.resetExpRead();
            end
            if obj.isEnabled %#ok<MCSUP>
                obj.prepareReadByTime(obj.counterIntegrationTime); %#ok<MCSUP>
            end
        end

        function set.bLifetime(obj, newValue)
            if obj.isEnabled %#ok<MCSUP>
                counter = getObjByName(SpcmCounter.NAME);
                if isempty(counter) || ~counter.isRunning
                    obj.sendWarning('Can''t change histogram status while counter is turned on');
                    return
                end
            end
            if obj.bLifetime ~= newValue
                obj.bLifetime = newValue;
                obj.resetTimeRead();
                obj.resetScanRead();
                obj.resetExpRead();
            end
            if obj.isEnabled %#ok<MCSUP>
                obj.prepareReadByTime(obj.counterIntegrationTime); %#ok<MCSUP>
            end
        end

        function bool = hasLifetimeCapability(obj) % For GUI
            bool = obj.hasLifetime(true);
        end

        function bool = hasLifetime(obj, bHas) % Override SPCM
            if exist('bHas', 'var') && bHas
                bool = hasLifetime@Spcm(obj); % If has feature
            else
                bool = hasLifetime@Spcm(obj) && obj.bLifetime; % Only if enabled
            end
        end
    end

    % =====================================================================
    %                           CONSTRUCTOR
    % =====================================================================
    methods
        function obj = SpcmTimeTaggerControlledArduinoDaqEnabled( ...
                name, ...
                arduinoGateChannel, ...
                countChannel, countChannelDelay, ...
                pgChannel, pgChannelDelay, ...
                count2Channel, count2ChannelDelay, ...
                laserChannel, laserChannelDelay, ...
                altCountChannel, altCountChannelDelay, ...
                arduinoAltGateChannel, ...
                conditionalFilter_triggerChannels, ...
                conditionalFilter_filterChannels, ...
                binWidth, nBins, startBin, endBin)
            % Constructor: creates the object and registers the channels in
            % the Arduino DAQ and Time Tagger.

            % ---------- Base class ----------
            obj@Spcm(name);

            % ---------- Arduino DAQ instance ----------
            daq = getObjByName(ArduinoGP8413Dac.NAME);
            if isempty(daq)
                error('SpcmTimeTaggerControlledArduinoDaqEnabled:NoArduinoDAQ', ...
                      'ArduinoGP8413Dac object not found. Make sure Daq.create(...) was called from JSON before SPCM creation.');
            end
            obj.daq = daq;

            % ---------- Register main gate channel ----------
            gatePhysical = arduinoGateChannel;
            niDaqGateChannelName = sprintf('%s_gate', name); % logical name, reused field
            obj.niDaqGateChannelName = niDaqGateChannelName;

            if ischar(gatePhysical) && strncmpi(gatePhysical, 'ao', 2)
                obj.isGateAnalog = true;
            elseif ischar(gatePhysical) && strncmpi(gatePhysical, 'd', 1)
                obj.isGateAnalog = false;
            else
                error('SpcmTimeTaggerControlledArduinoDaqEnabled:BadGateChannel', ...
                      'arduino_gate_channel must be "dN" or "aoN", got "%s"', gatePhysical);
            end

            daq.registerChannel(gatePhysical, niDaqGateChannelName, 0, 5);

            % ---------- TimeTagger ----------
            tt = getObjByName(TimeTaggerWrapper.NAME);
            if isempty(tt)
                tt = TimeTaggerWrapper.create();
            end
            obj.tt = tt;

            % ---------- Main count channel ----------
            countChannelName = sprintf('%s_count', name);
            obj.timeTaggerCount1ChannelName = countChannelName;
            tt.registerChannel(countChannel, countChannelName, countChannelDelay);
            tt.setTriggerLevel(countChannelName, 1); % Excelitas SPCM ~2 V, trigger at 1 V

            % ---------- Pulse generator / PG channel ----------
            pgChannelName = sprintf('%s_pg', name);
            obj.timeTaggerPGChannelName = pgChannelName;
            tt.registerChannel(pgChannel, pgChannelName, pgChannelDelay);

            % ---------- Optional laser channel (for lifetime) ----------
            if ~isempty(laserChannel)
                laserChannelName = sprintf('%s_laser', name);
                obj.timeTaggerLaserChannelName = laserChannelName;
                obj.availableProperties.(obj.HAS_LIFETIME) = true;
                tt.registerChannel(laserChannel, laserChannelName, laserChannelDelay);
            end

            % ---------- Optional second counter (SPCM 2 / PMT) ----------
            if ~isempty(count2Channel)
                count2ChannelName = sprintf('%s_count2', name);
                obj.timeTaggerCount2ChannelName = count2ChannelName;
                obj.availableProperties.(obj.HAS_G2) = true;

                tt.registerChannel(count2Channel, count2ChannelName, count2ChannelDelay);
                tt.setTriggerLevel(count2ChannelName, 1);

                combinedCountName = sprintf('%s_combinedCount', name);
                obj.combinedCountVirtualChannel = tt.createVirtualChannel( ...
                    'Combiner', ...
                    {obj.timeTaggerCount1ChannelName, obj.timeTaggerCount2ChannelName});
                tt.registerChannel(obj.combinedCountVirtualChannel.getChannel(), combinedCountName);
                obj.timeTaggerCountCombinedChannelName = combinedCountName;

                obj.currentCounter = 4; % "SPCM Sum"
            end

            % ---------- Optional alternative counter ----------
            if ~isempty(altCountChannel)
                altCountChannelName = sprintf('%s_alt_count', name);
                obj.timeTaggerAltCountChannelName = altCountChannelName;
                obj.availableProperties.(obj.HAS_ALTCOUNT) = true;
                tt.registerChannel(altCountChannel, altCountChannelName, altCountChannelDelay);

                if ~isempty(arduinoAltGateChannel)
                    altGatePhysical = arduinoAltGateChannel;
                    altGateLogical  = sprintf('%s_alt_gate', name);
                    obj.niDaqAltGateChannelName = altGateLogical;

                    if ischar(altGatePhysical) && strncmpi(altGatePhysical, 'ao', 2)
                        obj.isAltGateAnalog = true;
                    elseif ischar(altGatePhysical) && strncmpi(altGatePhysical, 'd', 1)
                        obj.isAltGateAnalog = false;
                    else
                        error('SpcmTimeTaggerControlledArduinoDaqEnabled:BadAltGateChannel', ...
                              'arduino_alt_gate_channel must be "dN" or "aoN", got "%s"', altGatePhysical);
                    end

                    if ~isequal(altGatePhysical, gatePhysical)
                        daq.registerChannel(altGatePhysical, altGateLogical, 0, 5);
                    else
                        % same physical line as main gate
                        obj.isAltGateAnalog = obj.isGateAnalog;
                    end
                end
            end

            % ---------- Optional conditional filter on TimeTagger ----------
            if ~isempty(conditionalFilter_triggerChannels)
                tt.setConditionalFilter(conditionalFilter_triggerChannels, ...
                                        conditionalFilter_filterChannels);
            end

            % ---------- Histogram configuration ----------
            if ~isempty(binWidth)
                obj.binWidth = binWidth;
            else
                obj.binWidth = obj.DEFAULT_HIST_BIN_WIDTH;
            end

            if ~isempty(nBins)
                obj.nBins = nBins;
            else
                obj.nBins = obj.DEFAULT_HIST_NUMBER_BINS;
            end

            if ~isempty(startBin)
                obj.startRead = startBin;
            else
                obj.startRead = 1;
            end

            if ~isempty(endBin)
                obj.endRead = endBin;
            else
                obj.endRead = obj.DEFAULT_HIST_NUMBER_BINS;
            end

            % ---------- Finalization ----------
            obj.nScanPixels = 0;
            obj.availableProperties.(obj.HAS_BINNING) = true;
            obj.isEnabled   = false;

            % In NiDaq version they call startListeningTo(SpcmCounter.NAME).
            % Only do that if this method exists in the class hierarchy.
            if ismethod(obj, 'startListeningTo')
                obj.startListeningTo(SpcmCounter.NAME);
            end
        end
    end

    % =====================================================================
    %                       TIME-BASED COUNTER
    % =====================================================================
    methods
        function prepareReadByTime(obj, integrationTimeInSec)
            % Prepare the SPCM to a scan by timer, with integration time in seconds.
            if isempty(obj.timeSyncMeasTask) || integrationTimeInSec ~= obj.counterIntegrationTime
                obj.counterIntegrationTime = integrationTimeInSec;
                obj.timeSyncMeasTask = obj.tt.createMeasurement('SynchronizedMeasurements');
                timeBinWidth = obj.counterIntegrationTime * 1e12 / obj.DEFAULT_TIME_NUMBER_COUNTS;

                if obj.currentCounter ~= 3 % Normal case
                    obj.counterTimeTask = obj.tt.createMeasurement( ...
                        'Counter', obj.getCurrentCounter(), timeBinWidth, obj.DEFAULT_TIME_NUMBER_COUNTS);
                    obj.timeSyncMeasTask.registerMeasurement(obj.counterTimeTask);
                else % Both SPCMs at once
                    obj.counterTimeTask = obj.tt.createMeasurement( ...
                        'Counter', obj.timeTaggerCount1ChannelName, timeBinWidth, obj.DEFAULT_TIME_NUMBER_COUNTS);
                    obj.timeSyncMeasTask.registerMeasurement(obj.counterTimeTask);

                    obj.counterTime2Task = obj.tt.createMeasurement( ...
                        'Counter', obj.timeTaggerCount2ChannelName, timeBinWidth, obj.DEFAULT_TIME_NUMBER_COUNTS);
                    obj.timeSyncMeasTask.registerMeasurement(obj.counterTime2Task);
                end

                % Prepare histogram
                if obj.hasLifetime()
                    obj.counterTimeHistTask = obj.tt.createMeasurement('TimeDifferences', ...
                        obj.getCurrentCounter(), ...            % Click
                        obj.timeTaggerLaserChannelName, ...     % Start
                        TimeTaggerWrapper.CHANNEL_UNUSED, ...   % Next
                        TimeTaggerWrapper.CHANNEL_UNUSED, ...   % Sync
                        obj.DEFAULT_HIST_BIN_WIDTH, ...         % Binwidth
                        obj.DEFAULT_HIST_NUMBER_BINS, ...       % Number of bins
                        1);                                     % Number of histograms
                    obj.timeSyncMeasTask.registerMeasurement(obj.counterTimeHistTask);
                end

                % Prepare G2
                if obj.hasG2()
                    obj.counterTimeG2Task = obj.tt.createMeasurement('Correlation', ...
                        obj.timeTaggerCount1ChannelName, ...    % Channel 1
                        obj.timeTaggerCount2ChannelName, ...    % Channel 2
                        obj.DEFAULT_HIST_BIN_WIDTH, ...         % Binwidth
                        obj.DEFAULT_HIST_NUMBER_BINS * 2 + 1);  % Number of bins
                    obj.timeSyncMeasTask.registerMeasurement(obj.counterTimeG2Task);
                end

                obj.timeSyncMeasTask.stop();
                obj.timeSyncMeasTask.clear();
            end
        end

        function [kcps, stdev] = readFromTime(obj)
            % Reads from the SPCM for the integration time and returns:
            %   kcps  - mean kilo-counts per second
            %   stdev - standard error
            if ~obj.timeSyncMeasTask.isRunning()
                obj.counterTimer = tic;
                obj.timeSyncMeasTask.start();
                obj.tt.sync();
                pause(obj.counterIntegrationTime);
            end

            while toc(obj.counterTimer) < obj.counterIntegrationTime
                drawnow();
                if ~obj.timeSyncMeasTask.isRunning()
                    obj.counterTimer = tic;
                    obj.timeSyncMeasTask.start();
                    obj.tt.sync();
                    pause(obj.counterIntegrationTime);
                end
            end

            countsSPCM = single(obj.counterTimeTask.getData())';
            obj.counterTimer = tic;

            if obj.currentCounter == 3 % Both SPCMs at once.
                countsSPCM(:, 2) = single(obj.counterTime2Task.getData())';
            end

            % Read histogram
            if obj.hasLifetime()
                hist = single(obj.counterTimeHistTask.getData());
                counts_rec = zeros(obj.DEFAULT_HIST_NUMBER_BINS - (obj.endRead - obj.startRead) - 1, 1);
                counts = [counts_rec', hist(obj.startRead:obj.endRead)];

                time = single(obj.counterTimeHistTask.getCaptureDuration());
                obj.lastTimeHist = counts * 1e-3 * obj.nBins / (time * 1e-12);
            end

            % Read G2
            if obj.hasG2()
                obj.lastTimeG2 = single(obj.counterTimeG2Task.getDataNormalized());
            end

            obj.checkOverflows();

            kiloCounts = countsSPCM / 1000;
            meanTime = obj.counterIntegrationTime / obj.DEFAULT_TIME_NUMBER_COUNTS; % time per reading

            kcps = mean(kiloCounts / meanTime);
            stdev = std(kiloCounts / meanTime) / sqrt(length(kiloCounts));
        end

        function clearTimeRead(obj)
            if ~isempty(obj.timeSyncMeasTask)
                obj.timeSyncMeasTask.stop();
                obj.timeSyncMeasTask.clear();
            end
        end

        function resetTimeRead(obj)
            if ~isempty(obj.timeSyncMeasTask)
                obj.timeSyncMeasTask.stop();
                obj.timeSyncMeasTask.delete();
                obj.timeSyncMeasTask = '';
            end
            if ~isempty(obj.counterTimeTask)
                obj.counterTimeTask.delete();
                obj.counterTimeTask = '';
            end
            if ~isempty(obj.counterTime2Task)
                obj.counterTime2Task.delete();
                obj.counterTime2Task = '';
            end
            if ~isempty(obj.counterTimeHistTask)
                obj.counterTimeHistTask.delete();
                obj.counterTimeHistTask = '';
            end
            if ~isempty(obj.counterTimeG2Task)
                obj.counterTimeG2Task.delete();
                obj.counterTimeG2Task = '';
            end
        end
    end

    % =====================================================================
    %                             SCANNING
    % =====================================================================
    methods
        function prepareCountByStage(obj, stageName, nPixels, timeout, fastScan)
            if ~ValidationHelper.isValuePositiveInteger(nPixels)
                obj.sendError('Can''t prepare for reading %s points, only positive integers allowed! Ignoring');
            end

            if isempty(obj.scanSyncMeasTask) ...
                    || obj.nScanPixels ~= nPixels ...
                    || strcmp(obj.scanningStageName, stageName) ...
                    || obj.fastScan ~= fastScan

                obj.scanSyncMeasTask = obj.tt.createMeasurement('SynchronizedMeasurements');

                % Histogram per pixel
                if obj.hasLifetime()
                    if fastScan
                        nextChannel = stageName;
                        nCounts = nPixels;
                    else
                        if isempty(obj.slowScanStageChannelName)
                            combinedRisingFallingStageName = sprintf('%s_combinedRisingFallingStageName', obj.name);
                            obj.slowScanStageChannelName = combinedRisingFallingStageName;
                            fallingEdgeStage = obj.tt.getInvertedChannel(stageName);
                            obj.combinedRisingFallingStageVirtualChannel = obj.tt.createVirtualChannel('Combiner', {stageName, fallingEdgeStage});
                            obj.tt.registerChannel(obj.combinedRisingFallingStageVirtualChannel.getChannel(), obj.slowScanStageChannelName);
                        end
                        nextChannel = obj.slowScanStageChannelName;
                        nCounts = nPixels * 2;
                    end

                    obj.counterScanHistTask = obj.tt.createMeasurement('TimeDifferences', ...
                        obj.getCurrentCounter(), ...            % Click
                        obj.timeTaggerLaserChannelName, ...     % Start
                        nextChannel, ...                        % Next
                        TimeTaggerWrapper.CHANNEL_UNUSED, ...   % Sync
                        obj.DEFAULT_HIST_BIN_WIDTH, ...         % Binwidth
                        obj.DEFAULT_HIST_NUMBER_BINS, ...       % Number of bins
                        nCounts);                               % Number of pixels
                    obj.counterScanHistTask.setMaxCounts(1);
                    obj.scanSyncMeasTask.registerMeasurement(obj.counterScanHistTask);
                end

                % Normal counts
                if fastScan
                    endChannel = TimeTaggerWrapper.CHANNEL_UNUSED;
                else
                    endChannel = obj.tt.getInvertedChannel(stageName);
                end

                obj.counterScanTask = obj.tt.createMeasurement('CountBetweenMarkers', ...
                    obj.getCurrentCounter(), stageName, endChannel, nPixels);
                obj.scanSyncMeasTask.registerMeasurement(obj.counterScanTask);

                obj.nScanPixels = nPixels;
                obj.fastScan = fastScan;
                obj.scanningStageName = stageName;
            end

            obj.scanTimeoutTime = timeout;
            obj.scanSyncMeasTask.stop();
            obj.scanSyncMeasTask.clear();
        end

        function startScanCount(obj)
            if ~isempty(obj.scanSyncMeasTask)
                obj.scanSyncMeasTask.start();
                obj.tt.sync();
            else
                obj.sendError('Cannot start reading, prepare hasn''t been called!');
            end
        end

        function vectorOfKcps = readFromScan(obj)
            if isempty(obj.scanSyncMeasTask)
                obj.sendError('Cannot start reading, prepare hasn''t been called!');
            end

            timer = tic;
            while ~obj.counterScanTask.ready()
                if toc(timer) > obj.scanTimeoutTime
                    obj.clearScanRead();
                    obj.sendError('Timeout while waiting for scan');
                end
            end

            countsSPCM = single(obj.counterScanTask.getData());
            countsTime = single(obj.counterScanTask.getBinWidths());

            if obj.hasLifetime()
                hist = single(obj.counterScanHistTask.getData());
                if ~obj.fastScan
                    hist = hist(1:2:end, :);
                end
                countsSPCM = sum(hist(:, obj.startRead:obj.endRead), 2)';
                obj.lastScanHist = hist;
            end

            obj.scanSyncMeasTask.clear();
            obj.checkOverflows();

            kiloCounts = countsSPCM / 1000;
            time = countsTime * 1e-12;
            vectorOfKcps = kiloCounts ./ time;

            if nnz(isnan(vectorOfKcps))
                if nnz(time) == 0
                    obj.sendError('NaN detected in kcps, time is zeros (no data read from the TT)');
                else
                    obj.sendError('NaN detected in kcps');
                end
            end
        end

        function clearScanRead(obj)
            if ~isempty(obj.scanSyncMeasTask)
                obj.scanSyncMeasTask.stop();
                obj.scanSyncMeasTask.clear();
            end
        end

        function resetScanRead(obj)
            if ~isempty(obj.scanSyncMeasTask)
                obj.scanSyncMeasTask.stop();
                obj.scanSyncMeasTask.delete();
                obj.scanSyncMeasTask = '';
            end
            if ~isempty(obj.counterScanTask)
                obj.counterScanTask.delete();
                obj.counterScanTask = '';
            end
            if ~isempty(obj.counterScanHistTask)
                obj.counterScanHistTask.delete();
                obj.counterScanHistTask = '';
            end
        end
    end

    % =====================================================================
    %                        EXPERIMENT (PG-DRIVEN)
    % =====================================================================
    methods
        function prepareExperimentCount(obj, nReads, timeout, nParameters)
            if ~ValidationHelper.isValuePositiveInteger(nReads)
                obj.sendError(sprintf('Can''t prepare for reading %d times, only positive integers allowed! Ignoring.', nReads));
            end
            if isempty(obj.expSyncMeasTask) || obj.nExpCounts ~= nReads
                obj.expSyncMeasTask = obj.tt.createMeasurement('SynchronizedMeasurements');

                startChannel = obj.timeTaggerPGChannelName;
                endChannel   = obj.tt.getInvertedChannel(startChannel);

                synced_tagger = obj.expSyncMeasTask.getTagger();
                obj.counterExpTask = obj.tt.createMeasurement('CountBetweenMarkers', ...
                    synced_tagger, ...
                    obj.getCurrentCounter(), ...
                    startChannel, ...
                    endChannel, ...
                    nReads);

                if obj.hasLifetime()
                    if isempty(obj.expPGChannelName)
                        combinedRisingFallingPGName = sprintf('%s_combinedRisingFallingPGName', obj.name);
                        obj.expPGChannelName = combinedRisingFallingPGName;
                        obj.combinedRisingFallingPGVirtualChannel = obj.tt.createVirtualChannel('Combiner', {startChannel, endChannel});
                        obj.tt.registerChannel(obj.combinedRisingFallingPGVirtualChannel.getChannel(), obj.expPGChannelName);
                    end

                    nextChannel = obj.expPGChannelName;
                    nCounts = nReads * 2;

                    obj.counterExpHistTask = obj.tt.createMeasurement('TimeDifferences', ...
                        synced_tagger, ...
                        obj.getCurrentCounter(), ...
                        obj.timeTaggerLaserChannelName, ...
                        nextChannel, ...
                        TimeTaggerWrapper.CHANNEL_UNUSED, ...
                        obj.DEFAULT_HIST_BIN_WIDTH, ...
                        obj.DEFAULT_HIST_NUMBER_BINS, ...
                        nCounts);
                    obj.counterExpHistTask.setMaxCounts(1);
                    obj.expSyncMeasTask.registerMeasurement(obj.counterExpHistTask);
                end

                obj.nExpCounts = nReads;
            end

            obj.expTimeoutTime = timeout;
            obj.nExpParams     = nParameters;

            obj.expSyncMeasTask.start();
            obj.tt.sync();
        end

        function startExperimentCount(obj)
            if isempty(obj.expSyncMeasTask)
                obj.sendError('Cannot start reading, prepare hasn''t been called!');
            end
        end

        function stopExperimentCount(obj, varargin)
            if ~isempty(obj.expSyncMeasTask)
                if obj.counterExpTask.ready()
                    obj.expSyncMeasTask.clear();
                    obj.tt.sync();
                end
                if sum(all(obj.counterExpTask.getIndex(), 1)) + 1 == obj.nExpCounts
                    obj.expSyncMeasTask.clear();
                    obj.expSyncMeasTask.stop();
                    clear obj.expSyncMeasTask;
                end
                if nargin > 1
                    obj.expSyncMeasTask.clear();
                    obj.expSyncMeasTask.stop();
                    clear obj.expSyncMeasTask;
                end
            end
        end

        function counts = readFromExperiment(obj)
            pg = getObjByName(PulseGenerator.NAME);
            timer = tic;
            while ~pg.hasFinished()
                if toc(timer) > obj.expTimeoutTime * 1000
                    obj.clearExperimentRead();
                    obj.sendError('Timeout while waiting for experiment');
                end
            end

            counts_length = sum(all(obj.counterExpTask.getIndex(), 1)) + 1;
            counts = single(obj.counterExpTask.getData());
            counts = counts(1:counts_length);

            if (obj.nExpCounts - counts_length) < obj.nExpCounts / obj.nExpParams
                while ~obj.counterExpTask.ready()
                end
                counts = single(obj.counterExpTask.getData());
            end

            if obj.hasLifetime()
                hist = single(obj.counterExpHistTask.getData());
                hist = hist(1:2:end, :);
                if obj.countWithLifeTime
                    counts_length = sum(all(obj.counterExpTask.getIndex(), 1)) + 1;
                    counts = sum(hist(:, obj.startRead:obj.endRead), 2)';
                    counts = counts(1:counts_length);
                end
                obj.lastExpHist = hist;
            end

            obj.checkOverflows();
        end

        function clearExperimentRead(obj)
            if ~isempty(obj.expSyncMeasTask)
                obj.expSyncMeasTask.clear();
                clear obj.expSyncMeasTask;
                pause(1);
            end
        end

        function resetExpRead(obj)
            if ~isempty(obj.expSyncMeasTask)
                obj.expSyncMeasTask.stop();
                obj.expSyncMeasTask.delete();
                obj.expSyncMeasTask = '';
                clear obj.expSyncMeasTask;
            end
            if ~isempty(obj.counterExpTask)
                obj.counterExpTask.delete();
                obj.counterExpTask = '';
            end
            if ~isempty(obj.counterExpHistTask)
                obj.counterExpHistTask.delete();
                obj.counterExpHistTask = '';
            end
        end
    end

    % =====================================================================
    %                         GATE CONTROL (Arduino)
    % =====================================================================
    methods
        function setSPCMEnable(obj, newBooleanValue)
            % Enables/Disables the SPCM (or alt counter) by writing to the
            % Arduino gate channel(s). Supports both digital ("dN") and
            % analog ("aoN") channels registered on the Arduino.
            newBooleanValue = logical(newBooleanValue);

            if ~obj.bUseAltCounter
                % Main gate
                if obj.isGateAnalog
                    obj.daq.writeVoltage(obj.niDaqGateChannelName, newBooleanValue * 5.0);
                else
                    obj.daq.writeDigital(obj.niDaqGateChannelName, newBooleanValue);
                end
            elseif ~isempty(obj.niDaqAltGateChannelName)
                % Alt gate
                if obj.isAltGateAnalog
                    obj.daq.writeVoltage(obj.niDaqAltGateChannelName, newBooleanValue * 5.0);
                else
                    obj.daq.writeDigital(obj.niDaqAltGateChannelName, newBooleanValue);
                end
            end

            obj.isEnabled = newBooleanValue;
        end

        function counterName = getCurrentCounter(obj)
            switch obj.currentCounter
                case 1
                    counterName = obj.timeTaggerCount1ChannelName;
                case 2
                    counterName = obj.timeTaggerCount2ChannelName;
                case {3, 4}
                    counterName = obj.timeTaggerCountCombinedChannelName;
                case 5
                    counterName = obj.timeTaggerAltCountChannelName;
            end
        end

        function checkOverflows(obj)
            ret = obj.tt.getOverflowsAndClear();
            if ret > 0
                obj.sendWarning(sprintf(['There were %d overflows since the last read from the TimeTagger. ', ...
                    'Consider lowering the count rate or disabling the lifetime. ', ...
                    'Check the "checkOverflows" documentation for more info.'], ret));
            end
        end
    end

    % =====================================================================
    %                       EVENT HANDLING (legacy hook)
    % =====================================================================
    methods
        function onNiDaqReset(obj, ~)
            % For legacy compatibility with NiDaq-based code.
            % Here, obj.daq is ArduinoGP8413Dac, so this function effectively
            % does nothing (no NiDaq reset events expected).
            if ~isa(obj.daq, 'NiDaq')
                return;
            end
            if obj.isEnabled
                obj.setSPCMEnable(obj.isEnabled);
            end
        end

        function onEventNotNiDaq(obj, event)
            if strcmp(event.creator.name, SpcmCounter.NAME) ...
                    && isfield(event.extraInfo, SpcmCounter.EVENT_SPCM_COUNTER_RESET)
                obj.resetTimeRead();
            end
        end
    end

    % =====================================================================
    %                             STATIC API
    % =====================================================================
    methods (Static)
        function spcmObj = create(spcmName, spcmStruct)
            % Factory for TimeTagger-controlled SPCM with Arduino gate.

            missingField = FactoryHelper.usualChecks( ...
                spcmStruct, ...
                SpcmTimeTaggerControlledArduinoDaqEnabled.NEEDED_FIELDS_SPCM_ARDUINO_TIMETAGGER);

            if ~isnan(missingField)
                EventStation.anonymousError( ...
                    'Can''t initialize TimeTagger-controlled Arduino SPCM - required field "%s" was not found in initialization struct!', ...
                    missingField);
            end

            spcmStruct = FactoryHelper.supplementStruct( ...
                spcmStruct, ...
                SpcmTimeTaggerControlledArduinoDaqEnabled.OPTIONAL_FIELDS_SPCM_ARDUINO_TIMETAGGER);

            gate        = spcmStruct.arduino_gate_channel;
            counts      = spcmStruct.timeTagger_channel_counts;
            countsDelay = spcmStruct.timeTagger_channel_counts_delay;
            pg          = spcmStruct.timeTagger_channel_pg;
            pgDelay     = spcmStruct.timeTagger_channel_pg_delay;

            counts2              = spcmStruct.timeTagger_channel_counts2;
            counts2Delay         = spcmStruct.timeTagger_channel_counts2_delay;
            laser                = spcmStruct.timeTagger_channel_laser;
            laserDelay           = spcmStruct.timeTagger_channel_laser_delay;
            altCountChannel      = spcmStruct.timeTagger_channel_alt_counts;
            altCountChannelDelay = spcmStruct.timeTagger_channel_alt_counts_delay;
            arduinoAltGateChannel= spcmStruct.arduino_alt_gate_channel;
            cf_triggerChannel    = spcmStruct.timeTagger_conditionalFilter_trigger_channel;
            cf_filterChannel     = spcmStruct.timeTagger_conditionalFilter_filter_channel;
            binWidth             = spcmStruct.timeTagger_bin_width;
            nBins                = spcmStruct.timeTagger_number_bins;
            startBin             = spcmStruct.timeTagger_start_bin;
            endBin               = spcmStruct.timeTagger_end_bin;

            spcmObj = SpcmTimeTaggerControlledArduinoDaqEnabled( ...
                spcmName, ...
                gate, ...
                counts, countsDelay, ...
                pg, pgDelay, ...
                counts2, counts2Delay, ...
                laser, laserDelay, ...
                altCountChannel, altCountChannelDelay, ...
                arduinoAltGateChannel, ...
                cf_triggerChannel, cf_filterChannel, ...
                binWidth, nBins, startBin, endBin);
        end

        function OptimizeTimingSNR(hist, NV_index, BG_indices)
            for i = 1:round(SpcmTimeTaggerControlledArduinoDaqEnabled.DEFAULT_HIST_NUMBER_BINS / 10)
                for j = i+1:SpcmTimeTaggerControlledArduinoDaqEnabled.DEFAULT_HIST_NUMBER_BINS
                    C(i, j) = sum(hist(NV_index, i:j), 2) ...
                        - mean(sum(hist(BG_indices, i:j), 2)) ...
                        / sqrt(sum(hist(NV_index, i:j), 2) ...
                        + std(sum(hist(BG_indices, i:j), 2))^2); %#ok<AGROW>
                end
            end
            figure;
            contourf(C, 50);
            ylabel('Start Bin');
            xlabel('End Bin');
            a = colorbar;
            ylabel(a, 'SNR', 'FontSize', 14, 'Rotation', 270);
            pause(0.1);
            a.Label.Position(1) = 3;
        end
    end
end
