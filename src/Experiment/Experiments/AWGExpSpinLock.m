classdef AWGExpSpinLock < ExperimentAWG

    properties (Constant)
        NAME = 'AWG Spin Lcok';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        spinLockAmp
        tau

        doubleMeasurement   % logical
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = AWGExpSpinLock()
            obj@ExperimentAWG(AWGExpSpinLock.NAME);
            obj.parameterName = 'tau';
            
            % Set properties inherited from Experiment
            obj.repeats = 5000;
            obj.averages = 1000;
            
            obj.frequency = 3000;           % in MHz
            obj.amplitude = -10;            % in dBm
            obj.spinLockAmp = -20;
            obj.halfPiTime = 0.067;         % in us
            obj.tau = 0.005:0.1:5;         % min 0.15 because of the min waveform length. should be fixed
            obj.lastDelay = Experiment.DEFAULT_LAST_DELAY;
            
            obj.constantTime = false;       % logical
            obj.doubleMeasurement = true;   % logical
            
            obj.detectionDuration = 0.25;           % detection window, in us
            obj.referenceDetectionDuration = 5;     % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;   % laser initialization in pulsed experiments in us
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.topParam = ExpParamDoubleVector(StringHelper.TAU, [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|1>');
            obj.signalParam2 = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|0>');
        end
    end
    
    %% Setters
    methods
        function set.doubleMeasurement(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.doubleMeasurement = newVal;
            obj.changeFlag = true;
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
            detectionSequnceDuration = obj.detectionDuration + obj.stabilizationDuration + obj.acquisitionDuration + obj.GIresetDuration;
            obj.detectionPeriodsPerRepeat = 2 * (1 + double(obj.doubleMeasurement));
            obj.runsPerPerform = 1;
            MWChannel = obj.MWChannel;
            
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
                    MW = {MWChannel, 'MW2'};
                otherwise
                    obj.sendError('What should we do here?')
            end
            if obj.AWGorSRSswitch
                MW = [MW{:}, {'AWG'}];
            end
            
            S = Sequence;
            for k = 1:1+obj.doubleMeasurement
                S.addEvent(obj.AWG.TRIG_DURATION,           [triggers(:)', MW(:)']);   
                S.addEvent(obj.tau(end) + 2*obj.halfPiTime, MW,                    'tau');
                S.addEvent(obj.lastDelay,                   '',             'lastDelay');       % Last delay
                
                if ~obj.GIMeas
                    S.addEvent(obj.detectionDuration,       {'greenLaser', 'detector'});                    % Detection
                    S.addEvent(initDuration,                'greenLaser');                                  % Initialization
                    S.addEvent(obj.referenceDetectionDuration,...
                        {'greenLaser', 'detector'});                                                        % Reference detection
                else
                    S.addEvent(obj.detectionDuration,       {'greenLaser', 'GIenable', 'GIgate'});          % Detection
                    S.addEvent(obj.stabilizationDuration,   {'greenLaser', 'GIenable'});                    % voltage stabilization
                    S.addEvent(obj.acquisitionDuration,     {'greenLaser', 'GIenable', 'detector'});        % Acquisition
                    S.addEvent(obj.GIresetDuration,         {'greenLaser'});                                % GI reset
                    S.addEvent(max([0, initDuration - detectionSequnceDuration]),...
                        'greenLaser');                                  % Initialization
                    S.addEvent(obj.referenceDetectionDuration,...
                        {'greenLaser', 'GIenable', 'GIgate'});          % Reference detection
                    S.addEvent(obj.stabilizationDuration,   {'greenLaser', 'GIenable'});                    % voltage stabilization
                    S.addEvent(obj.acquisitionDuration,     {'greenLaser', 'GIenable', 'detector'});        % Reference acquisition
                    S.addEvent(obj.GIresetDuration,         {'greenLaser'});                                % GI reset
                end
            end
            
            if obj.changeFlag
                obj.LoadAWG;
            end

            obj.prepareInternal(S)
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.tau;
            obj.isPlotAlternateAvailable = obj.doubleMeasurement;
        end
    
        
        function LoadAWG(obj)
            baseWFtime = min([0.5, obj.tau(1), diff(obj.tau)]);      % the minimum length of waveform. All waveforms time must be a complete period of it!
            minWaveformTime = obj.AWG.MIN_WAVEFORM_LENGTH / obj.AWG.MAX_SAMPLE_RATE;
            if baseWFtime < minWaveformTime
                baseWFtime = minWaveformTime;
            end
            
            baseWFtime = obj.RoundDurationByFrequencies(baseWFtime, obj.frequency);
            obj.AWG.ResetStoredData;
            obj.AWG.workChannels = 1:obj.nChannels;
            obj.AWG.setAmplitude(obj.amplitude);
            obj.AWG.ChangeSampleRate(baseWFtime);
            minWaveformTime = obj.AWG.minWaveformDuration;
            
            obj.halfPiTime = obj.RoundDurationByFrequencies(obj.halfPiTime , obj.AWG.SampleRate);
            obj.tau = ceil(obj.tau/baseWFtime)*baseWFtime;
            fprintf('The ''tau'' values rounded to be a complete period of the baseWFtime - %d.', baseWFtime);
            
            N = length(obj.tau);
            A = obj.AWG.MaxNormPowerAllowed;
            B = A .* 10.^((obj.spinLockAmp - obj.amplitude)/20);
            w = 2*pi*obj.frequency;
            
            % creating waveforms:
            fprintf('Loading %d waveforms: ',  obj.nChannels * 4);
            firstPiHalfIndex = zeros(1, obj.nChannels);
            lastPiHalfIndex = zeros(1, obj.nChannels);
            lastPiHalfRefIndex = zeros(1, obj.nChannels);
            centerSegmentIndex = zeros(1, obj.nChannels);
            
            % delays between two channels:
            prePulseTime = minWaveformTime * ones(1,obj.nChannels);
            phase = zeros(1,obj.nChannels);
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
                phaseZero = w * (prePulseTime(chan)+obj.halfPiTime) + phase(chan);
                f = @(t) A(chan) * (prePulseTime(chan)<=t & t<prePulseTime(chan)+obj.halfPiTime) .* cos(w*t - phaseZero);
                firstPiHalfIndex(chan)   = obj.AWG.AddWaveformByFunction(f, prePulseTime(chan)+obj.halfPiTime, 0, 0);
                f = @(t) A(chan) * (0<=t & t<obj.halfPiTime) .* cos(w*t - phase(chan));
                lastPiHalfIndex(chan)    = obj.AWG.AddWaveformByFunction(f, minWaveformTime+obj.halfPiTime,  0, 1);
                f = @(t) A(chan) * (0<=t & t<obj.halfPiTime) .* cos(w*t - phase(chan) + pi);
                lastPiHalfRefIndex(chan) = obj.AWG.AddWaveformByFunction(f, minWaveformTime+obj.halfPiTime,  0, 1);
                f = @(t) B(chan) * (0<=t & t<baseWFtime)     .* cos(w*t - phase(chan) + pi/2);
                centerSegmentIndex(chan)  = obj.AWG.AddWaveformByFunction(f, baseWFtime, 0, 0);
            end
            fprintf('\n');
            obj.AWG.LoadWaveform();
            
            % creating sequences:
            obj.indexSeq = zeros(obj.nChannels, N);
            fprintf('Loading %d sequences: ', obj.nChannels*N*2);
            for chan = 1:obj.nChannels
                for i = 1:N
                    zeroSegNum = obj.tau(i)/baseWFtime;
                    waveFormsIndexes = [firstPiHalfIndex(chan) centerSegmentIndex(chan) lastPiHalfIndex(chan) ...
                                        firstPiHalfIndex(chan) centerSegmentIndex(chan) lastPiHalfRefIndex(chan)];
                    repeats =  [1 zeroSegNum 1 1 zeroSegNum 1];
                    triggers = [1 0          0 1 0          0];
                    
                    obj.indexSeq(chan, i) = obj.AWG.AddSequence(waveFormsIndexes, repeats, triggers);
                    fprintf('%d ', N*(chan-1)+i);
                end
            end
            fprintf('\n');
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
            maxLastDelay = obj.lastDelay + max(obj.tau);
            
            %%% Run - Go over all tau's, in random order
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
                        pg.changeSequence('tau', 'duration', obj.tau(t) + 2*obj.halfPiTime);
                        if obj.constantTime
                            pg.changeSequence('lastDelay', 'duration', maxLastDelay - obj.tau(t));
                        end
                        
                        obj.AWG.assignSequence(obj.indexSeq(1,t),1)
                        if obj.nChannels == 2
                            obj.AWG.assignSequence(obj.indexSeq(2,t),2);
                        end
                        obj.AWG.Run;
                        
                        data = obj.getRawData(pg, spcm);
                        [sig, sterr] = obj.processData(data);
                        
                        obj.signal(:, t, obj.currIter) = sig;
                        obj.sterr(:, t, obj.currIter) = sterr;
                        
                        success = true;
                        obj.currParamIter = obj.currParamIter + 1;
                        sendEventParamIterationDone(obj);
                        
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
            % In the future, it will also analyze results and fit from it
            % the coherence time.
            
            obj.wrapUpInternal()
        end
        
        function dataParam = alternateSignal(obj)
            % Returns alternate view ("referenced") of the data, as an
            % ExpParam.
            
            N1 = obj.signalParam.value;
            N0 = obj.signalParam2.value;

            value = N0 - N1;
            sterr = sqrt(obj.signalParam.sterr.^2 + obj.signalParam2.sterr.^2);
            dataParam = ExpResultDoubleVector('FL', value, sterr, 'Normalized', obj.NAME);
        end
    end
end

