classdef GIA_detectionDuration_ExpCalibrateDelays < ExperimentAWG
    
    properties (Constant)
        NAME = 'GIA detection duration calibration';
    end
    
    properties
        % All of the parameters must have a set function, and when they are changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue running);
        frequency       % in MHz
        amplitude       % in dBm
        constantTime    % logical
        piTime             % in us
        totalZero
        smallOnDelay    % in us
        smallOffDelay   % in us
        durations
        doubleMeasurement
    end

    methods
        function obj = GIA_detectionDuration_ExpCalibrateDelays()
            obj@ExperimentAWG(GIA_initNVduration_ExpCalibrateDelays.NAME);
            obj.parameterName = 'delays';
            
            obj.repeats = 10000;
            obj.averages = 20;
            obj.frequency = 2780;           % in MHz
            obj.isTracking = false;          % Initialize tracking
            obj.amplitude = -15.4 + [0 -1.2];            % in dBm
            obj.durations = [0.05, 0.1:0.1:2];
            obj.constantTime = true;
            obj.piTime = 0.150;
            obj.timeDelay = 26e-6;
            obj.constantTime = 1;
            obj.fixDelays = 1;
            obj.lastDelay = 1.2;
            obj.doubleMeasurement = true;   % logical

            obj.nChannels = 2;
            obj.AWGorSRSswitch = 0;
            obj.detectionDuration = 0.25;
            obj.referenceDetectionDuration = 1;
            obj.GIMeas = 1;
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|1>');
            obj.signalParam2 = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|0>');
        end
    end

%% Setters
    methods
        function set.frequency(obj, newVal) % newVal is in MHz
            checkFrequencyScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.frequency = newVal;
            obj.changeFlag = true;
        end
        
        function set.amplitude(obj, newVal) % newVal is in dBm
            checkAmplitude(obj, newVal)
            % If we got here, then newVal is OK.
            obj.amplitude = newVal .* ones(1, obj.nChannels);
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
            totalParamNum = length(obj.durations);
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
            checkDetectionDuration(obj, obj.detectionDuration); % The mode might have changed; before running, we check
            spcm = getObjByName(Spcm.NAME);
            
            lastDelay = 1.2;
            
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
                if k==1
                    S.addEvent(obj.AWG.TRIG_DURATION,   [triggers(:)', MW(:)']);                            % AWG trigger
                else
                    S.addEvent(obj.AWG.TRIG_DURATION,   MW);                                                % AWG trigger
                end
                S.addEvent(obj.piTime,                  MW)                                                 % MW
                S.addEvent(obj.lastDelay,                   '');                                            % Last delay
                S.addEvent(obj.durations(end),          {'greenLaser', 'GIenable', 'GIgate'}, 'detection'); % Detection
                S.addEvent(0.1,                         {'greenLaser', 'GIenable'},           'constTime');
                S.addEvent(obj.stabilizationDuration,   {'greenLaser', 'GIenable'});                        % voltage stabilization
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
            
            obj.prepareInternal(S)
            if obj.changeFlag || obj.restartFlag
                obj.LoadAWG;
            end
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.durations;
            obj.isPlotAlternateAvailable = obj.doubleMeasurement;
        end
        
        function LoadAWG(obj)
            obj.AWG.ResetStoredData;
            obj.AWG.workChannels = 1:obj.nChannels;
            obj.AWG.setAmplitude(obj.amplitude);
            
            minWaveformTime = obj.AWG.minWaveformDuration;
            WaveformsIndex = zeros(obj.nChannels);
            obj.indexSeq = zeros(obj.nChannels);

            % creating waveforms:
            A = obj.AWG.MaxNormPowerAllowed;
            w = 2*pi*obj.frequency;
            for chan = 1:obj.nChannels
                f = @(t) A(chan) * (0<=t & t<obj.piTime) .* cos(w*t);
                if obj.timeDelay > 0
                    prePulseTime = minWaveformTime + obj.timeDelay*(chan==1);
                else
                    prePulseTime = minWaveformTime - obj.timeDelay*(chan==2);
                end
                WaveformsIndex(chan) = obj.AWG.AddWaveformByFunction(f, prePulseTime+obj.piTime, prePulseTime, 1);
            end
            f = @(t) 0*t;
            lastZeroIndex = obj.AWG.AddWaveformByFunction(f, minWaveformTime, 0, 1);
            obj.AWG.LoadWaveform();
            
            % creating sequences:
            for chan = 1:obj.nChannels
                obj.indexSeq(chan) = obj.AWG.AddSequence([WaveformsIndex(chan) lastZeroIndex], [1 1], [1 0]);
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
            
            maxDelay = 0.1 + max(obj.durations);
            
            % Some magic numbers
            obj.AWG.assignSequence(obj.indexSeq(1), 1)
            if obj.nChannels == 2
                obj.AWG.assignSequence(obj.indexSeq(2), 2);
            end
            
            k = 0; %added by rotem 18.4.21
            f1 = []; %added by rotem 18.4.21
            
            for t = randperm(length(obj.durations))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue
                end
                success = false;
                
                obj.detectionDuration = obj.durations(t);
                obj.changeFlag = false;
                
                f1 = [f1, t]; %added by rotem 18.4.21
                k = k + 1; %added by rotem 18.4.21
                for trial = 1 : 10
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        pg.changeSequence('detection', 'duration', obj.durations(t));
                        if obj.constantTime
                            pg.changeSequence('constTime', 'duration', maxDelay - obj.detectionDuration);
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
            
            S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
            S3sterr = squeeze(obj.sterr(3, :, 1:obj.currIter));
            S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
            S4sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));
            
            [value, sterr] = getRatioDistributionValues(obj, S3, S4, S3sterr, S4sterr);
            obj.signalParam2.value = value;
            obj.signalParam2.sterr = sterr;
        end
        
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results.
            
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
