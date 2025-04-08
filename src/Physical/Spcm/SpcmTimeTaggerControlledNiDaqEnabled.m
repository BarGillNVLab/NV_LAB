classdef SpcmTimeTaggerControlledNiDaqEnabled < Spcm & NiDaqControlled
    %SpcmTimeTaggerControlledNiDaqEnabled spcm that is controlled by the
    % Time Tagger and enabled by NiDaq
    
    properties % Public!
        lastTimeG2 % The last G2 from a time
        lastTimeHist % The last hist from a time
        lastScanHist % The last hist from a scan
        lastExpHist % The last hist from an exp
%         counterIntegrationTime %temp should be at line 51
        countWithLifeTime %default is false, if true use the lifetime measurement to compute counts.
    end

    properties (SetAccess = {?ViewSpcmControl})
        binWidth % Hist bin width in ps
        nBins % Number of bins in hist
        startRead % Bin index to start readout.
        endRead % Bin index to stop readout.
    end
    
    properties (Access = {?ViewSpcmControl})
        % Backup, for NiDaq reset
        isEnabled   % logical
        
        % Hardware
        tt
        daq
        
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
        
        % Channels
        niDaqGateChannelName
        timeTaggerCount1ChannelName
        timeTaggerPGChannelName
        
        % Two counters
        timeTaggerCount2ChannelName % When there are two counters
        timeTaggerCountCombinedChannelName % The sum of the two counters if there are two, or just the 1st one if there is only one.
        combinedCountVirtualChannel
        
        % Alt counter
        timeTaggerAltCountChannelName
        niDaqAltGateChannelName
        
        % Pulsed lasers
        timeTaggerLaserChannelName % For pulsed lasers
        
        % Configuration
        hardwareFilter
        bLifetime = 1;
        currentCounter = 1; % Options are given in COUNT_OPTIONS
    end
    
    properties (Constant)
        DEFAULT_TIME_NUMBER_COUNTS = 1000;      % Always read 100 bins.
        DEFAULT_HIST_BIN_WIDTH = 100;           % 100 ps % DEFAULT VALUE=100 % change back to default once done. Jonathan 27.5.2021
        DEFAULT_HIST_NUMBER_BINS = 490; %190;         % 490 bins = 49ns % DEFAULT VALUE=490 % change back to default once done. Jonathan 27.5.2021
        COUNT_OPTIONS = {'SPCM 1', 'SPCM 2', 'SPCM 1 & 2', 'SPCM Sum', 'PMT'};
    end
    
    properties (Constant, Hidden)
        NEEDED_FIELDS_SPCM_NIDAQ_TIMETAGGER = {'nidaq_channel_gate', 'timeTagger_channel_counts', 'timeTagger_channel_counts_delay', 'timeTagger_channel_pg', 'timeTagger_channel_pg_delay'};
        OPTIONAL_FIELDS_SPCM_NIDAQ_TIMETAGGER = {'nidaq_channel_alt_gate', 'timeTagger_channel_counts2', 'timeTagger_channel_counts2_delay', 'timeTagger_channel_alt_counts',...
            'timeTagger_channel_alt_counts_delay', 'timeTagger_channel_laser', 'timeTagger_channel_laser_delay', 'timeTagger_conditionalFilter_trigger_channel', 'timeTagger_conditionalFilter_filter_channel' ...
            'timeTagger_bin_width', 'timeTagger_number_bins', 'timeTagger_start_bin', 'timeTagger_end_bin'};
    end
    
    properties (Dependent)
        bUseAltCounter
    end
    
    methods
        function value = get.bUseAltCounter(obj)
            value = obj.currentCounter == 5; % Alt Counter is option 5
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
                bool = hasLifetime@Spcm(obj) && obj.bLifetime; % Only if it is enabled!
            end
        end
        

    end
    
    methods
        function obj = SpcmTimeTaggerControlledNiDaqEnabled(name, niDaqGateChannel, countChannel, countChannelDelay, pgChannel, pgChannelDelay, count2Channel, count2ChannelDelay, laserChannel, laserChannelDelay, altCountChannel, altCountChannelDelay, niDaqAltGateChannel, conditionalFilter_triggerChannels, conditionalFilter_filterChannels, binWidth, nBins, startBin, endBin)
            % Contructor, creates the object and registers the channels in
            % the DAQ and Time Tagger.
            obj@Spcm(name);
            
            daq = getObjByName(NiDaq.NAME);
            niDaqGateChannelName = sprintf('%s_gate', name);
            obj@NiDaqControlled({niDaqGateChannelName}, {niDaqGateChannel}, 0, 0);
            obj.niDaqGateChannelName = niDaqGateChannelName;
            
            tt = getObjByName(TimeTaggerWrapper.NAME);
            if isempty(tt)
                tt = TimeTaggerWrapper.create();
            end
            
            countChannelName = sprintf('%s_count', name);
            obj.timeTaggerCount1ChannelName = countChannelName;
            tt.registerChannel(countChannel, countChannelName, countChannelDelay)
            tt.setTriggerLevel(countChannelName, 1) % Exceltias spcm only reaches 2V, so Trigger is 1
            
            pgChannelName = sprintf('%s_pg', name);
            obj.timeTaggerPGChannelName = pgChannelName;
            tt.registerChannel(pgChannel, pgChannelName, pgChannelDelay)
            
            if ~isempty(laserChannel)
                laserChannelName= sprintf('%s_laser', name);
                obj.timeTaggerLaserChannelName = laserChannelName;
                obj.availableProperties.(obj.HAS_LIFETIME) = true;
                tt.registerChannel(laserChannel, laserChannelName, laserChannelDelay)
            end
            if ~isempty(count2Channel)
                count2ChannelName= sprintf('%s_count2', name);
                obj.timeTaggerCount2ChannelName = count2ChannelName;
                obj.availableProperties.(obj.HAS_G2) = true;
                tt.registerChannel(count2Channel, count2ChannelName, count2ChannelDelay)
                tt.setTriggerLevel(count2ChannelName, 1) % Exceltias spcm only reaches 2V, so Trigger is 1
                
                combinedCountName = sprintf('%s_combinedCount', name);
                obj.combinedCountVirtualChannel = tt.createVirtualChannel('Combiner', {obj.timeTaggerCount1ChannelName, obj.timeTaggerCount2ChannelName});
                tt.registerChannel(obj.combinedCountVirtualChannel.getChannel(), combinedCountName)
                obj.timeTaggerCountCombinedChannelName = combinedCountName;
                obj.currentCounter = 4;
            end
            if ~isempty(altCountChannel)
                altCountChannelName= sprintf('%s_alt_count', name);
                obj.timeTaggerAltCountChannelName = altCountChannelName;
                obj.availableProperties.(obj.HAS_ALTCOUNT) = true;
                tt.registerChannel(altCountChannel, altCountChannelName, altCountChannelDelay)
                if ~isempty(niDaqAltGateChannel) % If it's empty, then it's manually switched on and off
                    niDaqAltGateChannelName = sprintf('%s_alt_gate', name);
                    obj.niDaqAltGateChannelName = niDaqAltGateChannelName;
                    if ~isequal(niDaqAltGateChannel, niDaqGateChannel) % They might be the same channel!
                        daq.registerChannel(niDaqAltGateChannel, niDaqAltGateChannelName);
                    end
                end
            end
            if ~isempty('conditionalFilter_triggerChannels')
                tt.setConditionalFilter(conditionalFilter_triggerChannels, conditionalFilter_filterChannels);
            end
            
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
                %obj.startRead = 27; % changed by Jonathan to avoid metal luminescence at short time scales. 15.6.2021
            else
                obj.startRead = 1;
            end
            
            if ~isempty(endBin)
                obj.endRead = endBin;
            else
                obj.endRead = obj.DEFAULT_HIST_NUMBER_BINS;
            end
            
            obj.nScanPixels = 0;
            obj.availableProperties.(obj.HAS_BINNING) = true;
            obj.isEnabled = 0;
            obj.tt = tt;
            obj.daq = daq;
            obj.startListeningTo(SpcmCounter.NAME);
        end
        
        function prepareReadByTime(obj, integrationTimeInSec)
            % Prepare the SPCM to a scan by timer, with integration time of
            % integrationTime in seconds.
            if isempty(obj.timeSyncMeasTask) || integrationTimeInSec ~= obj.counterIntegrationTime
                obj.counterIntegrationTime = integrationTimeInSec;
                obj.timeSyncMeasTask = obj.tt.createMeasurement('SynchronizedMeasurements');
                timeBinWidth = obj.counterIntegrationTime*1e12/obj.DEFAULT_TIME_NUMBER_COUNTS;
                
                if obj.currentCounter ~= 3 % Normal case
                    obj.counterTimeTask = obj.tt.createMeasurement('Counter', obj.getCurrentCounter(), timeBinWidth, obj.DEFAULT_TIME_NUMBER_COUNTS);
                    obj.timeSyncMeasTask.registerMeasurement(obj.counterTimeTask);
                else % Both SPCMs at once.
                    obj.counterTimeTask = obj.tt.createMeasurement('Counter', obj.timeTaggerCount1ChannelName, timeBinWidth, obj.DEFAULT_TIME_NUMBER_COUNTS);
                    obj.timeSyncMeasTask.registerMeasurement(obj.counterTimeTask);
                    
                    obj.counterTime2Task = obj.tt.createMeasurement('Counter', obj.timeTaggerCount2ChannelName, timeBinWidth, obj.DEFAULT_TIME_NUMBER_COUNTS);
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
                        obj.DEFAULT_HIST_NUMBER_BINS*2+1);      % Number of bins
                    obj.timeSyncMeasTask.registerMeasurement(obj.counterTimeG2Task);
                end
                
                obj.timeSyncMeasTask.stop();
                obj.timeSyncMeasTask.clear();
            end
        end
        
        function [kcps, stdev] = readFromTime(obj)
            % Reads from the SPCM for the integration time and returns a
            % single point which is the kcps and also the standard error.
            if ~obj.timeSyncMeasTask.isRunning()
                obj.counterTimer = tic;
                obj.timeSyncMeasTask.start();
                obj.tt.sync();
                pause(obj.counterIntegrationTime);
            end
            
            % Actual reading from device
            while toc(obj.counterTimer) < obj.counterIntegrationTime
                drawnow();
                if ~obj.timeSyncMeasTask.isRunning()
                    obj.counterTimer = tic;
                    obj.timeSyncMeasTask.start();
                    obj.tt.sync();
                    pause(obj.counterIntegrationTime);
                end
            end
            
            % Read normal
            countsSPCM = single(obj.counterTimeTask.getData())';
            obj.counterTimer = tic;
            
            if obj.currentCounter == 3 % Both SPCMs at once.
                countsSPCM(:, 2) = single(obj.counterTime2Task.getData())';
            end
            
            % Read histogram
            if obj.hasLifetime()
                %counts = single(obj.counterTimeHistTask.getData());
                hist = single(obj.counterTimeHistTask.getData());
%                 if ~obj.fastScan
%                     hist = hist(1:2:end, :);
%                 end
                counts_rec = zeros(obj.DEFAULT_HIST_NUMBER_BINS-(obj.endRead-obj.startRead)-1,1); % added to compensate for histograms that start at a later time-bin than 1 - Rotem and Jonathan 15.6.2021
                counts = [counts_rec', hist(obj.startRead:obj.endRead)];
                
                time = single(obj.counterTimeHistTask.getCaptureDuration());
                obj.lastTimeHist = counts*1e-3 * obj.nBins / (time * 1e-12);
            end
            
            % Read G2
            if obj.hasG2()
                obj.lastTimeG2 = single(obj.counterTimeG2Task.getDataNormalized());
            end
            
            obj.checkOverflows();
            
            % Data processing
            kiloCounts = countsSPCM/1000;
            meanTime = obj.counterIntegrationTime/obj.DEFAULT_TIME_NUMBER_COUNTS; % time for each reading
%             if sum(kiloCounts == 0) < obj.DEFAULT_TIME_NUMBER_COUNTS/10
%                 if obj.currentCounter ~= 3
%                     kcps = mean(kiloCounts(kiloCounts>0)/meanTime);
%                 else
%                     kcps(1) = mean(kiloCounts(kiloCounts(:,1)>0, 1)/meanTime);
%                     kcps(2) = mean(kiloCounts(kiloCounts(:,2)>0, 2)/meanTime);
%                 end
%             else
                kcps = mean(kiloCounts/meanTime);
%             end
            stdev = std(kiloCounts/meanTime)/sqrt(length(kiloCounts));
        end
        
        function clearTimeRead(obj)
            % Clears the task for reading SPCM by time.
            if ~isempty(obj.timeSyncMeasTask)
                obj.timeSyncMeasTask.stop();
                obj.timeSyncMeasTask.clear();
            end
        end
        
        function resetTimeRead(obj)
            % Removes all measurements of time reading!
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
                
        function prepareCountByStage(obj, stageName, nPixels, timeout, fastScan)
            % Prepare the SPCM to a scan by a stage. Before a multiline
            % scan, this should be called only once.
            if ~ValidationHelper.isValuePositiveInteger(nPixels)
                obj.sendError('Can''t prepare for reading %s points, only positive integers allowed! Igonring');
            end
            if isempty(obj.scanSyncMeasTask) ...
                    || obj.nScanPixels ~= nPixels ...
                    || strcmp(obj.scanningStageName,stageName) ...
                    || obj.fastScan ~= fastScan
                
                obj.scanSyncMeasTask = obj.tt.createMeasurement('SynchronizedMeasurements');
                % Prepare histogram
                if obj.hasLifetime()
                    % Can do histogram per pixel! Everything is possible!
                    if fastScan
                        % Fast scans works by edges, so everything is simple.
                        nextChannel = stageName;
                        nCounts = nPixels;
                    else % NEVER TESTED!
                        % Slow scans work between rising and falling edges.
                        if isempty(obj.slowScanStageChannelName)
                            combinedRisingFallingStageName = sprintf('%s_combinedRisingFallingStageName', obj.name);
                            obj.slowScanStageChannelName = combinedRisingFallingStageName;
                            fallingEdgeStage = obj.tt.getInvertedChannel(stageName);
                            obj.combinedRisingFallingStageVirtualChannel = obj.tt.createVirtualChannel('Combiner', {stageName, fallingEdgeStage});
                            obj.tt.registerChannel(obj.combinedRisingFallingStageVirtualChannel.getChannel(), obj.slowScanStageChannelName)
                        end
                        nextChannel = obj.slowScanStageChannelName;
                        nCounts = nPixels*2;
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
                
                % Prepare normal
                if fastScan
                    endChannel = TimeTaggerWrapper.CHANNEL_UNUSED; % Fast scans works by edges, so end trigger is empty.
                else
                    endChannel = obj.tt.getInvertedChannel(stageName); % Slow scans work between rising and falling edges.
                end
                
                obj.counterScanTask = obj.tt.createMeasurement('CountBetweenMarkers', obj.getCurrentCounter(), stageName, endChannel, nPixels);
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
            % Starts reading by scan, this should be called before every
            % line.
            if ~isempty(obj.scanSyncMeasTask)
                obj.scanSyncMeasTask.start();
                obj.tt.sync();
            else
                obj.sendError('Cannot start reading, prepare hasn''t been called!');
            end
        end
        
        function vectorOfKcps = readFromScan(obj)
            % Read by scan. Reads a single line.
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
            
            % Read normal
            countsSPCM = single(obj.counterScanTask.getData());
            countsTime = single(obj.counterScanTask.getBinWidths());
            
            % Read histogram
            if obj.hasLifetime()
                % Histogram per pixel!
                hist = single(obj.counterScanHistTask.getData());
                if ~obj.fastScan
                    hist = hist(1:2:end, :);
                end
                countsSPCM = sum(hist(:, obj.startRead:obj.endRead), 2)';
                obj.lastScanHist = hist;
            end
            obj.scanSyncMeasTask.clear();
            obj.checkOverflows();
            
            kiloCounts = countsSPCM/1000;
            time = countsTime*1e-12; % For seconds
            vectorOfKcps = kiloCounts./time;
            if nnz(isnan(vectorOfKcps))
                if nnz(time)==0
                    obj.sendError('NaN detected in kcps, time is zeros (no data read from the TT)')
                else
                    obj.sendError('NaN detected in kcps')
                end
            end
        end
        
        function clearScanRead(obj)
            % Clear the task that scans from stage.
            if ~isempty(obj.scanSyncMeasTask)
                obj.scanSyncMeasTask.stop();
                obj.scanSyncMeasTask.clear();
            end
        end
        
        function resetScanRead(obj)
            % Removes all measurements of time reading!
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
        
        function prepareExperimentCount(obj, nReads, timeout, nParameters)
            % Prepare to read spcm count from opening the spcm window
            if ~ValidationHelper.isValuePositiveInteger(nReads)
                obj.sendError(sprintf('Can''t prepare for reading %d times, only positive integers allowed! Igonring.', nReads));
            end
            if isempty(obj.expSyncMeasTask) ...
                    || obj.nExpCounts ~= nReads 
                
                obj.expSyncMeasTask = obj.tt.createMeasurement('SynchronizedMeasurements'); %commented out by rotem 14.1.21
                % Prepare normal
                startChannel = obj.timeTaggerPGChannelName;
                endChannel = obj.tt.getInvertedChannel(startChannel); % Falling edge, end of detection period
                
                synced_tagger = obj.expSyncMeasTask.getTagger();
                obj.counterExpTask = obj.tt.createMeasurement('CountBetweenMarkers', synced_tagger , obj.getCurrentCounter(), startChannel, endChannel, nReads);
%                 obj.debugCBM = TTCountBetweenMarkers(obj.tt.tagger, obj.tt.channelArray{5,1}, obj.tt.channelArray{2,1}, obj.tt.tagger.getInvertedChannel(obj.tt.channelArray{2,1}), nReads);
                
                %obj.counterExpTask = obj.tt.createMeasurement('CountBetweenMarkers', obj.getCurrentCounter(), startChannel, endChannel, nReads); %commented out by rotem 14.1.21
                %obj.expSyncMeasTask.registerMeasurement(obj.counterExpTask); %commented out by rotem 14.1.21
                
                % Prepare histogram
                if obj.hasLifetime() %added ~ (not) by rotem 14.1.21
                    if isempty(obj.expPGChannelName)
                        combinedRisingFallingPGName = sprintf('%s_combinedRisingFallingPGName', obj.name);
                        obj.expPGChannelName = combinedRisingFallingPGName;
                        obj.combinedRisingFallingPGVirtualChannel = obj.tt.createVirtualChannel('Combiner', {startChannel, endChannel});
                        obj.tt.registerChannel(obj.combinedRisingFallingPGVirtualChannel.getChannel(), obj.expPGChannelName)
                    end
                    nextChannel = obj.expPGChannelName;
                    nCounts = nReads*2; % nCounts is twice as large as nReads, 
                    % because we measure the histogram for both signal and 
                    % reference, and in order to measure the histogram on the
                    % detection windows correctly, the trigger uses both 
                    % rising and falling edge on the nextChannel, and
                    % starts measuring a "fake histogram" when the detector
                    % is actually closed. the resulting matrix dimensions are nBins by nCounts,
                    % but only the odd rows (nCounts) hold significant
                    % data. the actual data is extracted in the function
                    % "counts = readFromExperiment(obj)" in line: hist = hist(1:2:end, :);
                    % Rotem and Jonathan 1.7.20212
                    
                    obj.counterExpHistTask = obj.tt.createMeasurement('TimeDifferences', ...
                        synced_tagger, ...                      % tagger
                        obj.getCurrentCounter(), ...            % Click
                        obj.timeTaggerLaserChannelName, ...     % Start
                        nextChannel, ...                        % Next
                        TimeTaggerWrapper.CHANNEL_UNUSED, ...   % Sync
                        obj.DEFAULT_HIST_BIN_WIDTH, ...         % Binwidth
                        obj.DEFAULT_HIST_NUMBER_BINS, ...       % Number of bins
                        nCounts);                               % Number of pixels
                    obj.counterExpHistTask.setMaxCounts(1);
                    obj.expSyncMeasTask.registerMeasurement(obj.counterExpHistTask);
                end
                obj.nExpCounts = nReads;
            end
            obj.expTimeoutTime = timeout;
            obj.nExpParams = nParameters;
            
            %obj.expSyncMeasTask.stop(); %commented out by rotem 14.1.21
            %obj.expSyncMeasTask.clear(); %commented out by rotem 14.1.21
            obj.expSyncMeasTask.start();
            obj.tt.sync();
        end
        
        function startExperimentCount(obj)
            % Starts the experiment reading.
            %obj.debugCBM.clear();
            if ~isempty(obj.expSyncMeasTask)
                %obj.counterExpTask.clear();
                %obj.counterExpTask.start();
                %obj.expSyncMeasTask.clear();
                %obj.expSyncMeasTask.start();
                %obj.tt.sync(); %commented out by rotem 14.1.21 
            else
                obj.sendError('Cannot start reading, prepare hasn''t been called!');
            end
        end
        
        function stopExperimentCount(obj, varargin)
            % Stops the experiment reading.
            if ~isempty(obj.expSyncMeasTask)
                if obj.counterExpTask.ready()
                    obj.expSyncMeasTask.clear();
                    obj.tt.sync();
                    %pause(0.2);
                    %obj.expSyncMeasTask.stop();
                end
                if sum(all(obj.counterExpTask.getIndex(),1))+1 == obj.nExpCounts
                    obj.expSyncMeasTask.clear(); %commented out by rotem 29.1.21
                    obj.expSyncMeasTask.stop(); %commented out by rotem 14.1.21
                    clear obj.expSyncMeasTask; %added by rotem 12.4.21
                end
                if nargin > 1 % meaning we want to clear the last average added by rotem and yachel 09.07.23
                    obj.expSyncMeasTask.clear(); %commented out by rotem 29.1.21
                    obj.expSyncMeasTask.stop(); %commented out by rotem 14.1.21
                    clear obj.expSyncMeasTask; %added by rotem 12.4.21
                end
            end
        end
        
        function counts = readFromExperiment(obj)
            % Read vector of signals from the spcm
% %             if isempty(obj.expSyncMeasTask)
% %                 obj.sendError('Cannot start reading, prepare hasn''t been called!');
% %             end
%             timer = tic;
% %             %while ~obj.counterExpTask.ready()
% %             
%             esr = getObjByName('ESR');
%             indexArray = sum(all(obj.counterExpTask.getIndex(),1))+1; %+1 because first tag is at place 0 thus isn't counted
%             %timer_index = tic;
% %             disp(indexArray)
%             while indexArray < obj.nExpCounts*(esr.currParamIter+1)/length(esr.frequency)
%                 indexArray = sum(all(obj.counterExpTask.getIndex(),1))+1; %+1 because first tag is at place 0 thus isn't counted
%             end
% %             %disp(indexArray)
% %             %disp(toc(timer_index))
%             
%             %pause(0.3);
% %             pg = PulseStreamer('132.64.56.49');
% %             while ~pg.hasFinished()
% %                 
% % %                 if toc(timer) > obj.expTimeoutTime*100
% % %                     obj.counterExpTask.stop();
% % %                     obj.counterExpTask.clear();
% % %                     obj.counterExpTask.start();
% % %                 end
% %                 if toc(timer) > obj.expTimeoutTime*1000
% %                     obj.clearExperimentRead();
% %                     obj.sendError('Timeout while waiting for experiment');
% %                 end
% %             end
           
           pg = getObjByName(PulseGenerator.NAME);
           timer = tic;
           while ~pg.hasFinished()
               if toc(timer) > obj.expTimeoutTime*1000
                   obj.clearExperimentRead();
                   obj.sendError('Timeout while waiting for experiment');
               end
               %pause(0.001);
           end
           
%            pg = PulseStreamer('132.64.56.49');
%            while ~pg.hasFinished()
%                pause(0.001);
%            end
            % Read normal
            counts_length = sum(all(obj.counterExpTask.getIndex(),1))+1;
            counts = single(obj.counterExpTask.getData());
            counts = counts(1:counts_length);
            
            if (obj.nExpCounts - counts_length) < obj.nExpCounts/obj.nExpParams
                while (~obj.counterExpTask.ready())
                    %pause(0.001);
                end
                counts = single(obj.counterExpTask.getData());
            end
            
            
        %             esr = getObjByName('ESR');
%             if (esr.currParamIter+1) == length(esr.frequency)
%                 while ~obj.counterExpTask.ready()
%                     %pause(0.001);
%                 end
%                 counts = single(obj.counterExpTask.getData());
%             end

%             counts = zeros(1,obj.nExpCounts);
%              esr = getObjByName('ESR');
%             indexArray = sum(all(obj.counterExpTask.getIndex(),1))+1;
%             disp(indexArray)
%             if (esr.currParamIter+1) == length(esr.frequency)
%                 disp('last')
%                 while ~obj.counterExpTask.ready()
%                 end
%                 counts = single(obj.counterExpTask.getData());
%             end
            
            % Read histogram
            if obj.hasLifetime() %added ~ (not) by rotem 14.1.21
                % Histogram per pixel!
                
                hist = single(obj.counterExpHistTask.getData());
                hist = hist(1:2:end, :);
                if obj.countWithLifeTime
                    counts_length = sum(all(obj.counterExpTask.getIndex(),1))+1;
                    counts = sum(hist(:, obj.startRead:obj.endRead), 2)';
                    counts = counts(1:counts_length); %%
                end
                obj.lastExpHist = hist;
            end
            %obj.expSyncMeasTask.clear(); %commented out by rotem 29.1.21
            obj.checkOverflows();

%             if any(isnan(counts))
%                 if isnan(counts)    % i.e. all are NaN
%                     obj.sendError('NaN detected in kcps (no data read from the DAQ)')
%                 else
%                     obj.sendError('NaN detected in kcps')
%                 end
%             end
        end
        
        function clearExperimentRead(obj)
            % Clear the task that reads experiments.
            if ~isempty(obj.expSyncMeasTask)
                %obj.expSyncMeasTask.stop(); %commented out by rotem 14.1.21
                obj.expSyncMeasTask.clear(); 
                clear obj.expSyncMeasTask; %added by rotem 12.4.21
                pause(1);
            end
        end
        
        function resetExpRead(obj)
            % Removes all measurements of time reading!
            if ~isempty(obj.expSyncMeasTask)
                obj.expSyncMeasTask.stop();
                obj.expSyncMeasTask.delete();
                obj.expSyncMeasTask = '';
                clear obj.expSyncMeasTask; % added by rotem 18.4.21
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
        
        function setSPCMEnable(obj, newBooleanValue)
            % Enables/Disables the SPCM (or alt counter).
            if ~obj.bUseAltCounter
                obj.daq.writeDigital(obj.niDaqGateChannelName, newBooleanValue)
            elseif ~isempty(obj.niDaqAltGateChannelName) % If it's empty, then turning it on and off is manual
                obj.daq.writeDigital(obj.niDaqAltGateChannelName, newBooleanValue)
            end
            obj.isEnabled = newBooleanValue;
        end
        
        function counterName = getCurrentCounter(obj)
            % Returns the current counter name
            switch obj.currentCounter
                case 1
                    counterName = obj.timeTaggerCount1ChannelName;
                case 2
                    counterName = obj.timeTaggerCount2ChannelName;
                case {3,4}
                    counterName = obj.timeTaggerCountCombinedChannelName;
                case 5
                    counterName = obj.timeTaggerAltCountChannelName;
            end
        end
        
        function checkOverflows(obj)
            % Check if there were any overflows, and if there were, inform
            % the user.
            ret = obj.tt.getOverflowsAndClear();
            if ret > 0
                obj.sendWarning(sprintf('There were %d overflows since the last read from the TimeTagger. Consider lowering the count rate or disabling the lifetime. Check the "checkOverflows" function documnetion for an explanation.', ret));
                % The max count rate is given by the USB2 protocl and it is
                % ~8MHz (~8000 kcps). If the histogram is active, this
                % is dropped by half to ~4MHz.
                % When there are overflows, data is lost, so it best to
                % avoid it...
            end
        end
    end
    
    methods
        function onNiDaqReset(obj, ~)
            % This function jumps when the NiDaq resets
            if obj.isEnabled
                % When reset, the NiDaq no longer remembers whether the
                % channel was off or on. We need to set the value, but only
                % if needed (since writeDigital is costly)
                obj.setSPCMEnable(obj.isEnabled)
            end
        end
        
        function onEventNotNiDaq(obj, event)
            if strcmp(event.creator.name, SpcmCounter.NAME) ...
                    && isfield(event.extraInfo, SpcmCounter.EVENT_SPCM_COUNTER_RESET)
                
                obj.resetTimeRead();
            end
        end
    end
  
    methods (Static)
        function spcmObj = create(spcmName, spcmStruct)
            missingField = FactoryHelper.usualChecks(spcmStruct, SpcmTimeTaggerControlledNiDaqEnabled.NEEDED_FIELDS_SPCM_NIDAQ_TIMETAGGER);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Can''t initialize NiDaq-controlled SPCM - required field "%s" was not found in initialization struct!', ...
                    missingField);
            end
            gate = spcmStruct.nidaq_channel_gate;
            counts = spcmStruct.timeTagger_channel_counts;
            countsDelay = spcmStruct.timeTagger_channel_counts_delay;
            pg = spcmStruct.timeTagger_channel_pg;
            pgDelay = spcmStruct.timeTagger_channel_pg_delay;
            
            % We want to get either values set in json, or empty variables
            % (which will be handled by the constructor):
            spcmStruct = FactoryHelper.supplementStruct(spcmStruct, SpcmTimeTaggerControlledNiDaqEnabled.OPTIONAL_FIELDS_SPCM_NIDAQ_TIMETAGGER);
            
            counts2 = spcmStruct.timeTagger_channel_counts2;
            counts2Delay = spcmStruct.timeTagger_channel_counts2_delay;
            laser = spcmStruct.timeTagger_channel_laser;
            laserDelay = spcmStruct.timeTagger_channel_laser_delay;
            altCountChannel = spcmStruct.timeTagger_channel_alt_counts;
            altCountChannelDelay = spcmStruct.timeTagger_channel_alt_counts_delay;
            niDaqAltGateChannel = spcmStruct.nidaq_channel_alt_gate;
            cf_triggerChannel = spcmStruct.timeTagger_conditionalFilter_trigger_channel;
            cf_filterChannel = spcmStruct.timeTagger_conditionalFilter_filter_channel;
            binWidth = spcmStruct.timeTagger_bin_width;
            nBins = spcmStruct.timeTagger_number_bins;
            startBin = spcmStruct.timeTagger_start_bin;
            endBin = spcmStruct.timeTagger_end_bin;
            spcmObj = SpcmTimeTaggerControlledNiDaqEnabled(spcmName, gate, counts, countsDelay, pg, pgDelay, counts2, counts2Delay, laser, laserDelay, altCountChannel, altCountChannelDelay, niDaqAltGateChannel, cf_triggerChannel, cf_filterChannel, binWidth, nBins, startBin, endBin);
        end
        
        function OptimizeTimingSNR(hist, NV_index, BG_indices)
            for i=1:round(SpcmTimeTaggerControlledNiDaqEnabled.DEFAULT_HIST_NUMBER_BINS/10)
                for j = i+1:SpcmTimeTaggerControlledNiDaqEnabled.DEFAULT_HIST_NUMBER_BINS
                    C(i,j) = sum(hist(NV_index, i:j), 2) - mean(sum(hist(BG_indices, i:j), 2)) / sqrt(sum(hist(NV_index, i:j), 2) + std(sum(hist(BG_indices, i:j), 2))^2);
                end
            end
            figure
            contourf(C, 50)
            ylabel('Start Bin')
            xlabel('End Bin');
            a = colorbar;
            ylabel(a,'SNR','FontSize',14,'Rotation',270);
            pause(0.1)
            a.Label.Position(1) = 3;
        end
    end
    
    
    
end