classdef SpcmNiDaqControlled < Spcm & NiDaqControlled
    %SPCMNIDAQCONTROLLED spcm that is controlled by the NiDaq
    %   inherit NiDaqControlled, also inherit Spcm
    
    properties (Access = protected)
        % Backup, for NiDaq reset
        isEnabled   % logical
        
        % For time counter
        counterIntegrationTime
        nTimeCounts
        counterTimeTask
        
        % For scanning
        nScanCounts
        scanTimeoutTime
        counterScanSPCMTask
        counterScanTimeTask
        fastScan
        scanningStageName
        countsLastSPCM
        countsLastTime
        
        % For Experiment
        nExpCounts
        expTimeoutTime
        counterExpTask
        
        % Channel Names
        niDaqGateChannelName % GATE
        niDaqCountChannelName % SPCM
        niDaqPgChannelName % PG
    end
    
    properties (Constant, Hidden)
        NEEDED_FIELDS = [Spcm.SPCM_NEEDED_FIELDS, {'nidaq_channel_gate', 'nidaq_channel_counts', 'nidaq_channel_pg'}];
        OPTIONAL_FIELDS = {'nidaq_channel_min_val', 'nidaq_channel_max_val'};
    end
    
    
    methods
        function obj = SpcmNiDaqControlled(name, niDaqGateChannel, niDaqCountsChannel, niDaqPgChannel, ...
                channelMinValue, channelMaxValue)
            % Contructor, creates the object and registers the channels in
            % the DAQ.
            obj@Spcm(name);
            niDaqGateChannelName = sprintf('%s_gate', name);
            niDaqCountChannelName = sprintf('%s_channel', name);
            niDaqPgChannelName = sprintf('%s_PG_channel', name);
            obj@NiDaqControlled({niDaqGateChannelName, niDaqCountChannelName, niDaqPgChannelName}, ...
                {niDaqGateChannel, niDaqCountsChannel, niDaqPgChannel}, channelMinValue, channelMaxValue);
            obj.niDaqGateChannelName = niDaqGateChannelName;
            obj.niDaqCountChannelName = niDaqCountChannelName;
            obj.niDaqPgChannelName = niDaqPgChannelName;
            
            daq = getObjByName(NiDaq.NAME);
            obj.isEnabled = daq.readDigital(obj.niDaqGateChannelName);
            obj.nScanCounts = 0;
        end
    end
    
    methods % SPCM functions
        function setSPCMEnable(obj, newBooleanValue)
            % Enables/Disables the SPCM.
            daq = getObjByName(NiDaq.NAME);
            daq.writeDigital(obj.niDaqGateChannelName, newBooleanValue)
            obj.isEnabled = newBooleanValue;
        end
        
    %%% Read by time %%%
        function prepareReadByTime(obj, integrationTimeInSec)
            % Prepare the SPCM to a scan by timer, with integration time of
            % integrationTime in seconds.
            obj.counterIntegrationTime = integrationTimeInSec;
            obj.nTimeCounts = integrationTimeInSec*100e3; % 100kHz basis.
            
            niDaq = getObjByName(NiDaq.NAME);
            obj.counterTimeTask = CreateDAQEdgeCountingMeas(niDaq,  obj.nTimeCounts, obj.niDaqCountChannelName, niDaq.CHANNEL_100kHZ);
            niDaq.startTask(obj.counterTimeTask);
        end
        
        function [kcps, sterr] = readFromTime(obj)
            % Reads from the SPCM for the integration time and returns a
            % single point which is the kcps and also the standard error.
            
            % Actual reading from device
            try
                countsSPCM = obj.readEdgeCounting(obj.counterTimeTask, obj.nTimeCounts, obj.counterIntegrationTime);
            catch err
                msg = err.message;
                errCodeSlow = '-200279'; % "The application is not able to keep up with the hardware acquisition."
                errCodeTaskAbort = '-88709'; % "The specified operation cannot be performed because a task has been aborted [...]"
                
                if contains(msg, errCodeSlow) 
                    % There was NiDaq reset, we can now safely resume
                    err2warning(err);
                    countsSPCM = obj.readEdgeCounting(obj.counterTimeTask, obj.nTimeCounts, obj.counterIntegrationTime);
                elseif contains(msg, errCodeTaskAbort)
                    obj.prepareReadByTime(obj.counterIntegrationTime)
                    countsSPCM = obj.readEdgeCounting(obj.counterTimeTask, obj.nTimeCounts, obj.counterIntegrationTime);
                else
                    rethrow(err)
                end
                % ^ This *should* work. If it doesn't, there might be a
                % bigger problem, and we want to let the user know
                % about it.
            end
            
            % Data processing
            kiloCounts = countsSPCM/1000;
            meanTime = obj.counterIntegrationTime/obj.nTimeCounts; % mean time for each reading
            kcps = mean(kiloCounts/meanTime);
            sterr = ste(kiloCounts/meanTime);   % ste is a home-made function for standard error
        end
        
        function clearTimeRead(obj)
            % Clears the task for reading SPCM by time.
            if obj.nTimeCounts <= 0
                obj.sendError('Can''t clear SPCM task without calling ''prepare()''! ');
            end
            obj.nTimeCounts = 0;
            daq = getObjByName(NiDaq.NAME);
            daq.endTask(obj.counterTimeTask);
        end
    %%% End (by time) %%%
    
    
    %%% By Stage %%%
        function prepareCountByStage(obj, stageName, nPixels, timeout, fastScan)
            % Prepare the SPCM to a scan by a stage. Before a multiline
            % scan, this should be called only once.
            if ~ValidationHelper.isValuePositiveInteger(nPixels)
                obj.sendError('Can''t prepare for reading %s points, only positive integers allowed! Igonring');
            end
            obj.nScanCounts = BooleanHelper.ifTrueElse(fastScan, nPixels+1, nPixels); % Fast scans works by edges, so an extra count is needed.
            obj.scanTimeoutTime = timeout;
            obj.fastScan = fastScan;
            obj.scanningStageName = stageName;
            
            niDaq = getObjByName(NiDaq.NAME);
            prepareCountByStageInternal(obj, niDaq);
        end
        
        function startScanCount(obj)
            % Starts reading by scan, this should be called before every line.
            daq = getObjByName(NiDaq.NAME);
            daq.startTask(obj.counterScanSPCMTask);
            daq.startTask(obj.counterScanTimeTask);
        end
        
        function vectorOfKcps = readFromScan(obj)
            % Read by scan. Reads a single line.
            if obj.nScanCounts <= 0
                obj.sendError('Can''t read from SPCM without calling ''prepare()''! ');
            end
            
            if obj.fastScan
                countsSPCM = obj.readEdgeCounting(obj.counterScanSPCMTask, obj.nScanCounts, obj.scanTimeoutTime);
                countsTime = obj.readEdgeCounting(obj.counterScanTimeTask, obj.nScanCounts, obj.scanTimeoutTime);
            else
                [countsSPCM, obj.countsLastSPCM] = obj.readPulseWidthCounting(obj.counterScanSPCMTask, obj.nScanCounts, obj.scanTimeoutTime, obj.countsLastSPCM);
                [countsTime, obj.countsLastTime] = obj.readPulseWidthCounting(obj.counterScanTimeTask, obj.nScanCounts, obj.scanTimeoutTime, obj.countsLastTime);
            end
            
            kiloCounts = countsSPCM/1000;
            time = countsTime*1e-8; % For seconds
            vectorOfKcps = kiloCounts./time;
            if any(isnan(vectorOfKcps))
                if all(time == 0)
                    obj.sendError('NaN detected in kcps, time is zeros (no data read from the DAQ)')
                else
                    obj.sendError('NaN detected in kcps')
                end
            end
        end
        
        function clearScanRead(obj)
            % Clear the task that scans from stage.
            if obj.nScanCounts <= 0
                obj.sendError('Can''t clear without calling ''prepare()''! ');
            end
            obj.nScanCounts = 0;
            daq = getObjByName(NiDaq.NAME);
            daq.endTask(obj.counterScanSPCMTask);
            daq.endTask(obj.counterScanTimeTask);
        end
    %%% End (By stage) %%%%
        
        
    %%% By PulseGenerator (Experiment) %%%
        function prepareExperimentCount(obj, nReads, timeout, nParemeters) %nParameters added by rotem 18.4.21
            % Prepare to read spcm count from opening the spcm window
            if ~ValidationHelper.isValuePositiveInteger(nReads)
                obj.sendError(sprintf('Can''t prepare for reading %d times, only positive integers allowed! Igonring.', nReads));
            end
            obj.nExpCounts = nReads;
            obj.expTimeoutTime = timeout;
            
            daq = getObjByName(NiDaq.NAME);
            task = daq.CreateDAQPulseWidthMeas(nReads, ...
                obj.niDaqCountChannelName, obj.niDaqPgChannelName); % Set pulse-width measurement
            obj.counterExpTask = task;

            daq.startTask(obj.counterExpTask);


        end
        
        function startExperimentCount(obj)
            % Actually start the process
        end
        
        function counts = readFromExperiment(obj)
            % Read vector of signals from the spcm
            if obj.nExpCounts <= 0
                obj.sendError('Can''t read from SPCM without calling ''prepare()''!');
            end
            
            counts = obj.readPulseWidthCounting(obj.counterExpTask, obj.nExpCounts, obj.expTimeoutTime);
            
            % Error handling
            if any(isnan(counts))
                if isnan(counts)    % i.e. all are NaN
                    obj.sendError('NaN detected in kcps (no data read from the DAQ)')
                else
                    obj.sendError('NaN detected in kcps')
                end
            end
        end
        
        function stopExperimentCount(obj)
           % Stop reading (to clear memory)
           daq = getObjByName(NiDaq.NAME);
           daq.stopTask(obj.counterExpTask);
        end
        
        function clearExperimentRead(obj)
            % Complete the task of reading the spcm
            if obj.nExpCounts <= 0
                obj.sendError('Can''t clear without calling ''prepare()''! ');
            end
            obj.nExpCounts = 0;
            daq = getObjByName(NiDaq.NAME);
            daq.endTask(obj.counterExpTask);
        end
    %%% End (by PulseGenerator) %%%
    end
    
        
    % SPCM protected methods
    methods (Access = protected)
        function prepareCountByStageInternal(obj, niDaq)
            % Creates the measurment in the DAQ according to the parameters
            % in the object.
            if obj.fastScan
                obj.counterScanSPCMTask = niDaq.CreateDAQEdgeCountingMeas(obj.nScanCounts, obj.niDaqCountChannelName, obj.scanningStageName, 0);
                obj.counterScanTimeTask = niDaq.CreateDAQEdgeCountingMeas(obj.nScanCounts, niDaq.CHANNEL_100MHZ, obj.scanningStageName, 1);
            else
                obj.counterScanSPCMTask = niDaq.CreateDAQPulseWidthMeas(obj.nScanCounts, obj.niDaqCountChannelName, obj.scanningStageName, 0);
                obj.counterScanTimeTask = niDaq.CreateDAQPulseWidthMeas(obj.nScanCounts, niDaq.CHANNEL_100MHZ, obj.scanningStageName, 1);
                obj.countsLastSPCM = 0;
                obj.countsLastTime = 0;
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
            
            % Not necessary, but maybe in the future
%             %%% This is called in real time, so we wait until data is acquired
%             wait = true;
%             t = tic;  % We also want to wait between calls to the DAQ, so as not to jam it
%             while wait
%                 if toc(t) > timeout/10 % we waited enough for next check
%                     availSamps = niDaq.availableSamples(daqTask);
%                     wait = (availSamps < nCounts); % we wait as long as there aren't enough samples
%                     t = tic; % Reset the clock for next read
%                 end
%             end
            
            %%% Actually reading
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
            if obj.nScanCounts > 0
                prepareCountByStageInternal(obj, niDaq);
            end
            if obj.isEnabled
                % When reset, the NiDaq no longer remembers whether the
                % channel was off or on. We need to set the value, but only
                % if needed (since writeDigital is costly)
                obj.setSPCMEnable(obj.isEnabled)
            end
        end
    end
  
    methods (Static)
        function spcmObj = create(spcmName, spcmStruct)
            missingField = FactoryHelper.usualChecks(spcmStruct, SpcmNiDaqControlled.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Can''t initialize NiDaq-controlled SPCM - required field "%s" was not found in initialization struct!', ...
                    missingField);
            end
            
            % We want to get either values set in json, or empty variables
            % (which will be handled by NiDaqControlled constructor):
            spcmStruct = FactoryHelper.supplementStruct(spcmStruct, SpcmNiDaqControlled.OPTIONAL_FIELDS);
            
            counts = spcmStruct.nidaq_channel_counts;
            gate = spcmStruct.nidaq_channel_gate;
            pg = spcmStruct.nidaq_channel_pg;
            minVal = spcmStruct.nidaq_channel_min_val;
            maxVal = spcmStruct.nidaq_channel_max_val;
            
            spcmObj = SpcmNiDaqControlled(spcmName, gate, counts, pg, minVal, maxVal);
        end
    end
end