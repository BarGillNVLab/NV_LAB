classdef AWGExpDigitizerDetectionDuration < ExperimentAWG
    
    properties (Constant)
        NAME = 'AWG detection duration';
    end
    
    properties
        % All of the parameters must have a set function, and when they are changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue running);
        tau             % in us
        totalZero
        smallOnDelay    % in us
        smallOffDelay   % in us
        dontLoadAWG
        sampleRate
    end

    properties (Dependent = true)
        time
    end
    
    methods
        function obj = AWGExpDigitizerDetectionDuration()
            obj@ExperimentAWG(AWGExpDigitizerDetectionDuration.NAME);
            obj.parameterName = 'time';
            
            obj.repeats = 1000;
            obj.averages = 100;
            obj.frequency = 2760;           % in MHz
            obj.amplitude = -2.5 + [0 0];    % in dBm
            obj.constantTime = true;
            obj.smallOnDelay = 0;         % us
            obj.smallOffDelay = 0; %1.75;        % us
            obj.lastDelay = Experiment.DEFAULT_LAST_DELAY;
            obj.dontLoadAWG = 0;
            obj.isTracking = 0;             % Initialize tracking
            obj.isPlotAlternateAvailable = true;
            obj.AWGorSRSswitch = 0;

            digi = getObjByName(Digitizer.NAME);
            obj.sampleRate = digi.MAX_SAMPLE_RATE;
            obj.piTime = 0.036;
            obj.lastDelay = 1;
            


            obj.detectionDuration = 5;                  % detection window, in us
            obj.referenceDetectionDuration = 5;         % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;       % laser initialization in pulsed experiments
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);

            obj.displayType1 =  'Contrast';
            obj.displayType2 =  'SNR';
        end
    end

%% Setters
    methods
        function time = get.time(obj)
            dt = 1/obj.sampleRate;
            time = 0 : dt : obj.detectionDuration-dt;
        end
        
        function set.tau(obj, newVal) % newVal is in us
            checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.tau = newVal;
            obj.changeFlag = true;
        end
        
    end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.time);
        end
    end
    
%% Overridden from Experiment
    methods (Access = protected)
        
        function prepare(obj)
            % Initialize devices (SPCM, PulseGenerator, etc.)
            
            % Sequence
            %%% Useful parameters for what follows
            initDuration = obj.laserInitializationDuration-obj.detectionDuration;
            obj.detectionPeriodsPerRepeat = 2;
            obj.runsPerPerform = 1;
            MWChannel = obj.MWChannel;
            checkDetectionDuration(obj, obj.detectionDuration); % The mode might have changed; before running, we check
            
            obj.digitizerFullDataAcquisition = true;
            
            %%% Creating the sequence
            if obj.seperatedTrigger                         % AWG trigger
                triggers = {'trigger', 'trigger2'};
            else
                triggers = {'trigger'};
            end
            switch obj.nChannels
                case 1
                    MW = {MWChannel};
                case 2
                    MW = {'MW', 'MW2'};
                otherwise
                    obj.sendError('What should we do here?')
            end
            if obj.AWGorSRSswitch
                MW = [MW{:}, {'AWG'}];
            end
            
            S = Sequence;
            S.addEvent(1,                           MW)
            S.addEvent(obj.AWG.TRIG_DURATION,       [triggers(:)', MW(:)']);                        % AWG trigger
            S.addEvent(obj.piTime,                  MW);                                            % MW
            S.addEvent(1,                           MW)
            S.addEvent(obj.lastDelay,               '');                                            % Last delay
            S.addEvent(obj.detectionDuration,       {'greenLaser', 'detector'});                    % Detection
            
            S.addEvent(initDuration,                'greenLaser');                                  % Initialization
            
%             S.addEvent(1,                           MW)
%             S.addEvent(obj.AWG.TRIG_DURATION,       MW);                                            % ref
%             S.addEvent(obj.piTime,                  MW);                                            % ref
%             S.addEvent(1,                           MW)
            S.addEvent(obj.lastDelay,                   '');                                        % ref
            S.addEvent(obj.referenceDetectionDuration, ...
                                                    {'greenLaser', 'detector'});                    % Reference detection
            S.addEvent(1,                           'greenLaser');                                  % extra Initialization
            obj.prepareInternal(S)
            if (obj.changeFlag || obj.restartFlag) && (~obj.dontLoadAWG)
                obj.LoadAWG;
            end
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.time;
        end
        
        function LoadAWG(obj)
            obj.AWG.ResetStoredData;
            obj.AWG.SampleRate = obj.AWG.MAX_SAMPLE_RATE;
            obj.AWG.workChannels = 1:obj.nChannels;
            obj.AWG.setAmplitude(obj.amplitude);
            minWaveformTime = obj.AWG.minWaveformDuration;
            
            initZeroIndex = zeros(1, obj.nChannels);
            waveformsIndex = zeros(1, obj.nChannels);
            
            prePulseTime = minWaveformTime * ones(1, obj.nChannels);
            phase = zeros(1, obj.nChannels);

            % creating waveforms:
            A = obj.AWG.MaxNormPowerAllowed;
            w = 2*pi*obj.frequency;
            fprintf('Loading ~%d waveforms: ', 2 * obj.nChannels);
            
            % the resolution of the time delay is the sample rate, so we add also aditional phase delay
            timeDelay = obj.RoundDurationByFrequencies(abs(obj.timeDelay), obj.AWG.SampleRate, -1);
            phaseDelay = w * (abs(obj.timeDelay) - timeDelay);
            if obj.timeDelay > 0
                prePulseTime(1) = minWaveformTime + timeDelay;
                phase(1) = phaseDelay;
            else
                prePulseTime(2) = minWaveformTime + timeDelay;
                phase(2) = phaseDelay;
            end
            for chan = 1:obj.nChannels
                f = @(t) 0 * t;
                initZeroIndex(chan) = obj.AWG.AddWaveformByFunction(f, prePulseTime(chan), 0);
                f = @(t) A(chan) * cos(w*t - phase(chan)) .* (t < obj.piTime);
                waveformsIndex(chan) = obj.AWG.AddWaveformByFunction(f, obj.piTime + minWaveformTime, 0);
            end
            
            fprintf('\n');
            obj.AWG.LoadWaveform();
            
            % creating sequences:
            obj.indexSeq = zeros(1, obj.nChannels);
            for chan = 1:obj.nChannels
                obj.indexSeq(chan) = obj.AWG.AddSequence([initZeroIndex(chan), waveformsIndex(chan)], [1 1], [1 0]);
            end
            obj.AWG.LoadSequence();
        end
        
        function perform(obj)
            %%% Initialization
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
                if isempty(tracker); throwBaseObjException(Tracker.Name); end

            success = false;
            
            obj.AWG.assignSequence(obj.indexSeq(1), 1)
            if obj.nChannels == 2
                obj.AWG.assignSequence(obj.indexSeq(2), 2);
            end
            obj.AWG.Run;
            
            for trial = 1 : 10
                if obj.checkEmergencyStop()
                    return;
                end
                try
                    data = obj.getRawData(pg, spcm);
                    a = reshape(data, 2, obj.repeats, length(obj.time));
                    sig = squeeze(mean(a, 2));
                    sterr = squeeze(std(a, 1, 2)) / sqrt(size(a,2));
%                     data = data';
%                     data = data(:)';
%                     [sig, sterr] = obj.processData(data);
                    obj.signal(:, :, obj.currIter) = sig;
                    obj.sterr(:, :, obj.currIter) = sterr;
                    
                    success = true;
                    obj.currParamIter = obj.currParamIter + 1;
                    if obj.currParamIter == 1 || mod(obj.currParamIter, 5) == 0 || obj.currParamIter == obj.totalNumberOfParams
                        if obj.currParamIter > obj.totalNumberOfParams
                            '';
                        end
                        sendEventParamIterationDone(obj);
                    end
                    
                    if obj.isTracking
                        if obj.checkEmergencyStop()
                            return;
                        end
                        isTrackingNeeded = tracker.compareReference(...
                            sig(2), sterr(2), ... % 2 for reference
                            Tracker.REFERENCE_TYPE_KCPS, obj.trackThreshhold);
                        if isTrackingNeeded
                            tracker.trackUsing(TrackablePosition.NAME)
                            obj.prepare;    % Before next measurement
                        end
                    end
                    
                    break;
                catch err
                    err2warning(err);
                    fprintf('Experiment failed at trial %d, attempting again.\n', trial);
                    try
                        % Maybe we need to manually clear the resources
                        spcm.stopExperimentCount;
                    catch
                        % But maybe we don't, and that's perfectly ok.
                    end
                end
            end
            if ~success
                obj.emergencyStop;
                return
            end
            
            % for time tagger setup
            if length(data) == obj.detectionPeriodsPerRepeat*obj.repeats*obj.getTotalNumberOfParams %if true we're proccessing data at the end of the average
                for k = 1:length(obj.tau)
                    [obj.signal(:, f1(k), obj.currIter), obj.sterr(:, f1(k), obj.currIter)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(k-1)+(1:obj.detectionPeriodsPerRepeat*obj.repeats)));
                end
            end
            
            % Saving results in the Experiment parameters
            S1 = squeeze(obj.signal(1, :, 1:obj.currIter));
            S1sterr = squeeze(obj.sterr(1, :, 1:obj.currIter));
            S2 = squeeze(obj.signal(2, :, 1:obj.currIter));
            S2sterr = squeeze(obj.sterr(2, :, 1:obj.currIter));
            
            [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);
            obj.signalParam.value = value;
            obj.signalParam.sterr = sterr;         
        end
        
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results.
            
            obj.wrapUpInternal()
        end
        
        function dataParam = alternateSignal(obj) %#ok<MANU>
            % Returns alternate view ("referenced") of the data, as an
            % ExpParam, if possible. If not, it returns an empty variable.
            N = length(obj.time);
            signal = zeros(1, N);
            noise = zeros(1, N);
            S1_full = squeeze(obj.signal(1, :, 1:obj.currIter));
            S1sterr_full = squeeze(obj.sterr(1, :, 1:obj.currIter));
            S2_full = squeeze(obj.signal(2, :, 1:obj.currIter));
            S2sterr_full = squeeze(obj.sterr(2, :, 1:obj.currIter));
            for i = 1:N
                S1 = mean(S1_full(1:i, :), 1);
                S2 = mean(S2_full(1:i, :), 1);
                S1sterr = sqrt(sum(S1sterr_full(1:i, :), 1.^2)) / i;
                S2sterr = sqrt(sum(S2sterr_full(1:i, :), 1.^2)) / i;
                value = mean(S1 ./ S2);
                S1mean = mean(S1);
                S2mean = mean(S2);
                if obj.currIter > 1
                    S1sterr = obj.getCombinedSterr(S1, S1sterr);
                    S2sterr = obj.getCombinedSterr(S2, S2sterr);
                end
                sterr = (S1mean./S2mean).*sqrt(S1sterr.^2./S1mean.^2 + S2sterr.^2./S2mean.^2);
                
                signal(i) = value;
                noise(i) = sterr;
            end
            value = (1-signal) ./ noise;
            dataParam = ExpResultDoubleVector('SNR', value, [], 'Normalized', obj.NAME);
        end
    end

end
