classdef AWGsensingDoubleDrive < ExperimentAWG
    % This experiment for high frequenct sensing besed on Fedor's artcile:
    % https://www.nature.com/articles/s41467-017-01159-2
    
    properties (Constant)
        NAME = 'AWG Double Drive';
    end
    
    properties
        % All of the parameters must have a set function, and when they are changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue running);
        ampltudeRatio   % in dB. the ration between the first and second drive
        signalRatio     % in dB. The ratio between the signal and second drive amplitude
        rabiFreq1       % rabi frequency of the first drive
        rabiFreq2       % rabi frequency of the second drive
        tau             % in us
        directions      % vector of tree phases - second drive, second drive modulation, and signal ('YXY' for example)
        totalZero
        doubleMeasurement
        
        correlatedControl
        correlatedDetuningC
        withSignal
        initHalfPi
        standardResonanceCondition
        signalDetuning    
    end
    
    properties (Dependent)
        signalFreq      % The signal frequency
        modFreq
    end

    methods
        function obj = AWGsensingDoubleDrive()
            obj@ExperimentAWG(AWGsensingDoubleDrive.NAME);
            obj.parameterName = 'taus';
            
            obj.repeats = 100;
            obj.averages = 10;
            obj.frequency = 2790;           % in MHz
            obj.amplitude = -8.8 + [0 0];    % in dBm
            obj.ampltudeRatio = -20;
            obj.signalRatio = -30;          % in dB. relation to the single drive amplitude
            obj.rabiFreq1 = 1.6;
            obj.rabiFreq2 = 0.16;
            
            obj.tau = 1:10:500;       % us
            obj.constantTime = true;
            obj.lastDelay = Experiment.DEFAULT_LAST_DELAY;
            obj.directions = 'YXY';
            obj.doubleMeasurement = true;   % logical

            obj.correlatedControl = 0;
            obj.correlatedDetuningC = 1.5;
            obj.withSignal = 1;
            obj.initHalfPi = 0;
            obj.standardResonanceCondition = 1;
            obj.signalDetuning = 0;

            obj.detectionDuration = 0.5;               % detection window, in us
            obj.referenceDetectionDuration = 0.5;         % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;       % laser initialization in pulsed experiments
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|1>');
            obj.signalParam2 = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|0>');
        end
    end

%% Setters
    methods
        function set.tau(obj, newVal) % newVal is in us
            checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.tau = newVal;
            obj.changeFlag = true;
        end
        
        function freq = get.signalFreq(obj)
            freq = obj.frequency - sqrt((obj.rabiFreq2/2)^2 + (obj.modFreq - obj.rabiFreq1)^2) - obj.modFreq * (obj.standardResonanceCondition==1) + obj.signalDetuning;
        end

        function freq = get.modFreq(obj)
            if ~obj.correlatedControl
                freq = obj.rabiFreq1;
            else
                freq = obj.rabiFreq1 + (obj.rabiFreq2/2)^2/obj.rabiFreq1 * obj.correlatedDetuningC;
            end
        end
   end
    
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.tau);
        end
    end
    
%% Overridden from Experiment
    methods (Access = protected)
        
        function prepare(obj)
            % Initialize devices (SPCM, PulseGenerator, etc.)
            
            % Sequence
            %%% Useful parameters for what follows
            initDuration = obj.laserInitializationDuration-obj.detectionDuration;
            obj.detectionPeriodsPerRepeat = 2 * (1 + double(obj.doubleMeasurement));
            obj.runsPerPerform = 1;
            MWChannel = obj.MWChannel;
            checkDetectionDuration(obj, obj.detectionDuration); % The mode might have changed; before running, we check
            
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
            for k = 1:1+obj.doubleMeasurement
                S.addEvent(obj.AWG.TRIG_DURATION,           [triggers(:)', MW(:)']);                        % AWG trigger
                S.addEvent(obj.tau(end) + obj.piTime,       MW,                         'MW')               % MW
                S.addEvent(obj.lastDelay,                   MW,                         'lastDelay');       % Last delay

                S.addEvent(obj.detectionDuration,       {'greenLaser', 'detector'});                    % Detection
                S.addEvent(initDuration,                'greenLaser');                                  % Initialization
                S.addEvent(obj.referenceDetectionDuration,...
                    {'greenLaser', 'detector'});                                                        % Reference detection
                S.addEvent(1,                           'greenLaser');                                  % Initialization
            end
            obj.prepareInternal(S)
            if obj.changeFlag || obj.restartFlag
                obj.LoadAWG;
            end
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.tau;
            obj.isPlotAlternateAvailable = obj.doubleMeasurement;
        end
        
        function LoadAWG(obj)
            baseWFtime = 1;
            baseWFtime = obj.RoundDurationByFrequencies(baseWFtime, [obj.frequency, obj.signalFreq, obj.rabiFreq1], 1);
            if baseWFtime > 20
                error('Base waveform time too long - %.1f us. You can try to change the parameters', baseWFtime);
            elseif baseWFtime > 5
                warning('Base waveform time a bit long - %.1f us, it will slow the sequence. You can try to change the parameters', baseWFtime);
            end
            obj.AWG.ResetStoredData;
            obj.AWG.workChannels = 1:obj.nChannels;
            obj.AWG.setAmplitude(obj.amplitude);
            obj.AWG.ChangeSampleRate(baseWFtime);
            minWaveformTime = obj.RoundDurationByFrequencies(obj.AWG.minWaveformDuration, obj.AWG.SampleRate, 1);
            
            N = length(obj.tau);
            shortWaveformsIndex = zeros(obj. nChannels, 1+obj.doubleMeasurement);
            shortWaveformsTime = [];
            lastWaveformsIndex = zeros(obj.nChannels, N, 1+obj.doubleMeasurement);
            numBaseWaveformInPoint = zeros(1,N);
            initWFIndex = zeros(1, obj.nChannels);
            constStepIndex = zeros(1,obj.nChannels);
            

            prePulseTime = minWaveformTime * ones(1,obj.nChannels);
            phase_A1 = zeros(1,obj.nChannels);
            phase_A2 = zeros(1,obj.nChannels);
            phase_s  = zeros(1,obj.nChannels);

            % creating waveforms:
            A1 = obj.AWG.MaxNormPowerAllowed;
            A2 = A1 .* 10.^(obj.ampltudeRatio / 20);
            g  = A2 .* 10.^(obj.signalRatio / 20) * obj.withSignal;
            w = 2*pi*obj.frequency;
            w1 = 2*pi*obj.modFreq;
            ws = 2*pi*obj.signalFreq;
            d = pi/2 * (obj.directions == 'YYY');
            fprintf('Loading ~%d waveforms: ', (sum((obj.tau<baseWFtime)) + 2)*obj.nChannels);
            
            % the resolution of the time delay is the sample rate, so we add also aditional phase delay
            timeDelay = obj.RoundDurationByFrequencies(abs(obj.timeDelay), obj.AWG.SampleRate, -1);
            phaseDelay_A1 = w  * (abs(obj.timeDelay) - timeDelay);
            phaseDelay_A2 = w1 * (abs(obj.timeDelay) - timeDelay);
            phaseDelay_s  = ws * (abs(obj.timeDelay) - timeDelay);
            if obj.timeDelay > 0
                prePulseTime(1) = minWaveformTime + timeDelay;
                phase_A1(1) = phaseDelay_A1;
                phase_A2(1) = phaseDelay_A2;
                phase_s(1)  = phaseDelay_s;
            else
                prePulseTime(2) = minWaveformTime + timeDelay;
                phase_A1(2) = phaseDelay_A1;
                phase_A2(2) = phaseDelay_A2;
                phase_s(2)  = phaseDelay_s;
            end
            for chan = 1:obj.nChannels
                if obj.initHalfPi
                    phaseZero = w * round((prePulseTime(chan)+obj.halfPiTime)*obj.AWG.SampleRate)/obj.AWG.SampleRate;
                    f = @(t) A1(chan) * (prePulseTime(chan)<=t & t<prePulseTime(chan)+obj.halfPiTime) .* sin(w*t- phase_A1(chan) - phaseZero );
                    initWFIndex(chan) = obj.AWG.AddWaveformByFunction(f, prePulseTime(chan)+obj.halfPiTime, 0, 1);
                else
                    f = @(t) 0 * t;
                    initWFIndex(chan) = obj.AWG.AddWaveformByFunction(f, prePulseTime(chan), 0);
                end
                f = @(t) A1(chan)*cos(w*t  - phase_A1(chan)) + ...
                         A2(chan)*cos(w*t  - phase_A1(chan)  + d(1)).*cos(w1*t - phase_A2(chan) + d(2)) + ...
                          g(chan)*cos(ws*t - phase_s(chan)   + d(3));
                constStepIndex(chan) = obj.AWG.AddWaveformByFunction(f, baseWFtime, 0);
            end
            
            for i = 1:N
                numBaseWaveformInPoint(i) = floor(obj.tau(i) / baseWFtime);
                residue = mod(obj.tau(i), baseWFtime);
                [closeWFdiff, closeWFindex] = min(abs((residue - shortWaveformsTime)));
                ind = length(shortWaveformsTime) + 1;
                for chan = 1:obj.nChannels
                    for ref = 1:1+obj.doubleMeasurement
                        if closeWFdiff < 0.1*1/obj.signalFreq
                            lastWaveformsIndex(chan, i, ref) = shortWaveformsIndex(chan, closeWFindex, ref);
                            obj.tau(i) = numBaseWaveformInPoint(i) * baseWFtime + shortWaveformsTime(closeWFindex);
                        else
                            shortWaveformsTime(ind) = residue;
                            f1 = @(t) (A1(chan)*cos(w*t  - phase_A1(chan)) + ...
                                A2(chan)*cos(w*t  - phase_A1(chan) + d(1)).*cos(w1*t - phase_A2(chan) + d(2)) + ...
                                g(chan)* cos(ws*t - phase_s(chan) +d(3)));
                            if obj.initHalfPi
                                f2 = @(t) A1(chan) .* sin(w*t - phase_A1(chan) + pi*(ref==1));
                                f = @(t) f1(t) .* (0<=t & t<residue) + f2(t) .* (residue<=t & t<residue+obj.halfPiTime);
                            else
                                f2 = @(t) A1(chan) .* cos(w*t - phase_A1(chan)) * (ref==2);
                                f = @(t) f1(t) .* (0<=t & t<residue) + f2(t) .* (residue<=t & t<residue+obj.piTime);
                            end
                            shortWaveformsIndex(chan, ind, ref) = obj.AWG.AddWaveformByFunction(f, residue + obj.piTime + minWaveformTime, 0, 1);
                            lastWaveformsIndex(chan, i, ref) = shortWaveformsIndex(chan, ind, ref);
                        end
                    end
                end
            end
            fprintf('\n');
            obj.AWG.LoadWaveform();
           % delete double points in tau:
            while any(diff(obj.tau) == 0)
                i = find(diff(obj.tau) == 0, 1);
                obj.tau(i) = [];
                lastWaveformsIndex(:, i) = [];
                numBaseWaveformInPoint(i) = [];
            end
            
            % creating sequences:
            N = length(obj.tau);
            obj.indexSeq = zeros(obj.nChannels,N);
            for i = 1:N
                for chan = 1:obj.nChannels
                    
                    draw = 0;%[w, 0.4, 0.598563];
                    
                    if numBaseWaveformInPoint(i) == 0
                        obj.indexSeq(chan,i) = obj.AWG.AddSequence([initWFIndex(chan), lastWaveformsIndex(chan,i,1), ...
                                                                    initWFIndex(chan), lastWaveformsIndex(chan,i,2)], ...
                                                                   [1 1 1 1], ...
                                                                   [1 0 1 0], draw);
                    else
                        obj.indexSeq(chan,i) = obj.AWG.AddSequence([initWFIndex(chan), constStepIndex(chan), lastWaveformsIndex(chan,i,1)...
                                                                    initWFIndex(chan), constStepIndex(chan), lastWaveformsIndex(chan,i,2)], ...
                                                                   [1, numBaseWaveformInPoint(i), 1, 1, numBaseWaveformInPoint(i), 1], ...
                                                                   [1 0 0 1 0 0], draw);
                    end
                end    
            end
            obj.AWG.LoadSequence()
        end
       
        function perform(obj)
            %%% Initialization
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
                if isempty(tracker); throwBaseObjException(Tracker.Name); end

            % Some magic numbers
            maxLastDelay = obj.lastDelay + max(obj.tau) + obj.piTime;
            
            for t = randperm(length(obj.tau))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue
                end
                success = false;
                
                for trial = 1 : 5
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        pg.changeSequence('MW', 'duration', obj.tau(t) + obj.piTime);
                        if obj.constantTime
                            pg.changeSequence('lastDelay', 'duration', maxLastDelay - obj.tau(t) - obj.piTime);
                        end
                        obj.AWG.assignSequence(obj.indexSeq(1,t), 1)
                        if obj.nChannels == 2
                            obj.AWG.assignSequence(obj.indexSeq(2,t), 2);
                        end
                        
                        obj.AWG.Run;

                        data = obj.getRawData(pg, spcm);
                        [sig, sterr] = obj.processData(data);
                        obj.signal(:, t, obj.currIter) = sig;
                        obj.sterr(:, t, obj.currIter) = sterr;
                        
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
            end
            
            % Saving results in the Experiment parameters
            S1 = squeeze(obj.signal(1, :, 1:obj.currIter));
            S1sterr = squeeze(obj.sterr(1, :, 1:obj.currIter));
            S2 = squeeze(obj.signal(2, :, 1:obj.currIter));
            S2sterr = squeeze(obj.sterr(2, :, 1:obj.currIter));
            
            [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);
            obj.signalParam.value = value;
            obj.signalParam.sterr = sterr;         
            
            if obj.doubleMeasurement
                S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
                S3sterr = squeeze(obj.sterr(3, :, 1:obj.currIter));
                S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
                S4sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));
                
                [value, sterr] = getRatioDistributionValues(obj, S3, S4, S3sterr, S4sterr);
                obj.signalParam2.value = value;
                obj.signalParam2.sterr = sterr;
            else    
                obj.signalParam2.value = [];
            end
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
            N1 = obj.signalParam.value;
            N0 = obj.signalParam2.value;

            value = N0 - N1;
            sterr = sqrt(obj.signalParam.sterr.^2 + obj.signalParam2.sterr.^2);
            dataParam = ExpResultDoubleVector('FL', value, sterr, 'Normalized', obj.NAME);
        end
    end

end
