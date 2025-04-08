classdef AWGExpPiSpinLockDualChannel < ExperimentAWG

    properties (Constant)
        NAME = 'AWG Spin Lcok Dual Channels';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        tauLimits           % in us 
        tauStep             % in us
        delay
        % timeDelay           % in us
        smallOnDelay        % in us
        smallOffDelay       % in us

        doubleMeasurement   % logical
        debug               % logical
    end
    
    properties (SetAccess = private)
        tau             % in us
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = AWGExpPiSpinLockDualChannel()
            obj@ExperimentAWG(AWGExpPiSpinLock.NAME);
            obj.parameterName = 'tau';
            
            % Set properties inherited from Experiment
            obj.repeats = 5000;
            obj.averages = 1000;
            
            obj.frequency = 3000;           % in MHz
            obj.amplitude = [-15, -15];     % in dBm
            obj.halfPiTime = 0.025;         % in us
            obj.piTime = 0.05;              % in us
            obj.tauLimits = [2, 5];      % mus (lower limit should be bigger than piTime/2)
            obj.tauStep = 2;              % min 0.15 because of the min waveform length. should be fixed
            obj.delay = 0.1;
%             obj.timeDelay = -0.003;
            obj.timeDelay = 0.1/obj.frequency;
            obj.nChannels = 2;
            obj.smallOnDelay = 0;         % us
            obj.smallOffDelay = 1.75;        % us
            
            obj.constantTime = false;       % logical
            obj.doubleMeasurement = true;   % logical
            obj.debug = false;              % logical
            
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
        function set.tauLimits(obj, newVal)	% newVal in microsec
            checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.tauLimits = newVal;
            obj.changeFlag = true;
        end
        
        function set.tauStep(obj, newVal)	% newVal in microsec
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.tauStep = newVal;
            obj.changeFlag = true;
        end
        
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
            obj.detectionPeriodsPerRepeat = 2 * (1 + double(obj.doubleMeasurement));
            obj.runsPerPerform = 1;
            MWChannel = obj.MWChannel;
            finalTime = obj.piTime + obj.halfPiTime + 2*obj.delay;
            
            %%% Creating the sequence
            if obj.seperatedTrigger                         % AWG trigger
                triggers = {'trigger', 'trigger2'};
            else
                triggers = {'trigger'};
            end
            MW = {MWChannel};
            if obj.AWGorSRSswitch
                MW = [MW{:}, {'AWG'}];
            end
            
            S = Sequence;
            for k = 1:1+obj.doubleMeasurement
                S.addEvent(obj.smallOnDelay,                               MW,             'preTime');
                S.addEvent(obj.AWG.TRIG_DURATION,           [triggers(:)', MW(:)']);   
                S.addEvent(finalTime,                       MW,             'preTime');
                S.addEvent(obj.tauLimits(2),                MW,             'tau');
                S.addEvent(finalTime,                       MW);
                S.addEvent(obj.smallOffDelay,                                  MW,             'preTime');
                S.addEvent(Experiment.DEFAULT_LAST_DELAY,   '',            'lastDelay');       % Last delay
                S.addEvent(obj.detectionDuration,...
                                                            {'greenLaser', 'detector'});        % Detection
                S.addEvent(initDuration,                    'greenLaser');                      % Initialization
                S.addEvent(obj.referenceDetectionDuration,...
                                                            {'greenLaser', 'detector'});        % Reference detection
                
                if k==2
                    S.addEvent(10,                           'greenLaser');                      % Initialization
                end
            end
            
            if obj.changeFlag
                obj.LoadAWG;
            end

            obj.prepareInternal(S)
            
            % Set parameter, for saving
%             obj.mCurrentXAxisParam.value = obj.tau;
%             obj.isPlotAlternateAvailable = obj.doubleMeasurement;
        end
    
        
        function LoadAWG(obj)
            if obj.amplitude(1) > -10
                error('maximum power in the amplified channel is -10 dBm, in order to save the power combiner')
            end
            
            minStepFrac = 10;
            minStep  = obj.RoundDurationByFrequencies(obj.tauStep/minStepFrac, obj.frequency);
            obj.tauStep  = minStepFrac*minStep;
            obj.AWG.ResetStoredData;
            obj.AWG.workChannels = 1:obj.nChannels;
            obj.AWG.setAmplitude(obj.amplitude);
            obj.AWG.ChangeSampleRate(minStep);
            minWaveformTime = obj.AWG.minWaveformDuration;
            
            obj.tauLimits = ceil(obj.tauLimits/minStep)*minStep;
            
            disp('The next parameters changed to be divided by the MW period time:');
            fprintf('tauStep=%d, tauLimits=[%d,%d]\n', obj.tauStep, obj.tauLimits(1), obj.tauLimits(2));
            fprintf('Number of elements in the tau vector: %.0f', length(obj.tau));
            
            obj.tau = obj.tauLimits(1):obj.tauStep:obj.tauLimits(2);
            
            N = length(obj.tau);
            obj.indexSeq = zeros(obj.nChannels, N);
            
            % creating waveforms:
            A = obj.AWG.MaxNormPowerAllowed;    % pulses amplitude
            w = 2*pi*obj.frequency;
            
            initTime = minWaveformTime+obj.halfPiTime+2*obj.delay+obj.piTime;
            minWaveformTime = minWaveformTime - mod(initTime, 1/obj.AWG.SampleRate);
            roundDelay = obj.timeDelay - mod(obj.timeDelay, 1/obj.AWG.SampleRate);
            
            if obj.timeDelay > 0
                prePulseTime1 = minWaveformTime + roundDelay;
                prePulseTime2 = minWaveformTime;
            else
                prePulseTime1 = minWaveformTime;
                prePulseTime2 = minWaveformTime + roundDelay;
            end
            
%             pg = getObjByName(PulseGenerator.NAME);
%             pg.changeSequence('preTime', 'duration', prePulseTime1 + obj.halfPiTime + 2*obj.delay + obj.piTime);
            
            phase = w*(prePulseTime1+obj.halfPiTime+2*obj.delay+obj.piTime);
            f = @(t) A(1) * ((prePulseTime1<=t & t<prePulseTime1+obj.halfPiTime) + (prePulseTime1+obj.halfPiTime+obj.delay<=t & t<prePulseTime1+obj.halfPiTime+obj.delay+obj.piTime)) .* cos(w*t-phase);
            firstPulsesIndex = obj.AWG.AddWaveformByFunction(f,   prePulseTime1+obj.halfPiTime+2*obj.delay+obj.piTime,  0, 0);
            firstPulsesZeroIndex = obj.AWG.AddWaveformByFunction(@(t) f(t).*0, prePulseTime2+obj.halfPiTime+2*obj.delay+obj.piTime,  0, 0);
            
            f = @(t) A(1) * ((obj.delay<=t & t<obj.delay+obj.piTime) + (obj.piTime+2*obj.delay<=t & t<obj.piTime+2*obj.delay+obj.halfPiTime)) .* cos(w*t);
            lastPulsesIndex = obj.AWG.AddWaveformByFunction(f,   minWaveformTime+obj.halfPiTime+2*obj.delay+obj.piTime,  0, 1);
            f = @(t) A(1) * ((obj.delay<=t & t<obj.delay+obj.piTime) .* cos(w*t) + (obj.piTime+2*obj.delay<=t & t<obj.piTime+2*obj.delay+obj.halfPiTime) .* cos(w*t+pi));
            lastPulsesRefIndex = obj.AWG.AddWaveformByFunction(f,   minWaveformTime+obj.halfPiTime+2*obj.delay+obj.piTime,  0, 1);
            lastPulsesZeroIndex = obj.AWG.AddWaveformByFunction(@(t) f(t).*0, minWaveformTime+obj.halfPiTime+2*obj.delay+obj.piTime,  0, 1);
            
            f = @(t) A(2) * cos(w*t);
            centerPulseIndex  = obj.AWG.AddWaveformByFunction(f, minStep, 0, 1);
            centerPulseZeroIndex = obj.AWG.AddWaveformByFunction(@(t) f(t).*0, minStep, 0, 1);
            obj.AWG.LoadWaveform();
            
            % creating sequences:
            for i = 1:N
                rep = obj.tau(i)/minStep;
                obj.indexSeq(1, i) = obj.AWG.AddSequence([firstPulsesIndex, centerPulseZeroIndex, lastPulsesIndex, firstPulsesIndex, centerPulseZeroIndex, lastPulsesRefIndex], ...
                                                      [1, rep, 1, 1, rep, 1], [1 0 0 1 0 0] , i==2 );
                obj.indexSeq(2, i) = obj.AWG.AddSequence([firstPulsesZeroIndex, centerPulseIndex, lastPulsesZeroIndex, firstPulsesZeroIndex, centerPulseIndex, lastPulsesZeroIndex], ...
                                                      [1, rep, 1, 1, rep, 1], [1 0 0 1 0 0] , i==2);
                    
            end
            obj.AWG.LoadSequence()
        end
        
        
        function perform(obj)
            %%% Initialization
            
            if obj.debug
                obj.LoadAWG;
            end
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
                if isempty(tracker); throwBaseObjException(Tracker.Name); end
            
            % Some magic numbers
            maxLastDelay = Experiment.DEFAULT_LAST_DELAY + max(obj.tau);
            
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
                        pg.changeSequence('tau', 'duration', obj.tau(t));
                        if obj.constantTime
                            pg.changeSequence('lastDelay', 'duration', maxLastDelay - obj.tau(t));
                        end
                        
                        obj.AWG.assignSequence(obj.indexSeq(1,t),1)
                        obj.AWG.assignSequence(obj.indexSeq(2,t),2);
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

