classdef AWGExpDynamicalBase < ExperimentAWG
    %EXPECHO Echo experiment

    properties (Constant)
        NAME = 'AWG Dynamical Base';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        tau                 % in us 
        pulsePhase          % Phase of the pi pulses. Can be vector (like 'XYYX' for XY4) and the phases will repeats the order.
        cycles              % Number of pi pulses in each sequence. 1 for regular echo.
        
        doubleMeasurement   % logical
        
        pulseAngles
        directions
        mormSegmentDuration
        segmentDurs
        initPulseDirection
        initPulseAngle
        nRepetitions
    end

    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = AWGExpDynamicalBase()
            obj@ExperimentAWG(AWGExpDynamicalBase.NAME);
            obj.parameterName = 'taus';
            
            % Set properties inherited from Experiment
            obj.repeats = 5000;
            obj.averages = 1000;
            
            obj.frequency = 3000;           % in MHz
            obj.amplitude = -10;            % in dBm
            obj.nRepetitions = 1:1:40;                   
            obj.halfPiTime = 0.021;         % in us
            obj.piTime = 0.042;
            obj.lastDelay = Experiment.DEFAULT_LAST_DELAY;
            
            obj.pulsePhase = 'YYYY';           % Phase of the pi pulses. Can be vector (like 'XYYX' for XY4) and the phases will repeats the order.
            obj.cycles = 1;                 % Number of pi pulses in each sequence. 1 for regular echo.
            
            phi = (sqrt(5) + 1)/ 2;
            obj.pulseAngles = [2/5, 2/5, 4/5, 4/5, 2/5, 2/5, 2/5, 2/5, 4/5, 4/5, 2/5, 2/5] * pi;
            obj.directions = [phi,0,-1; 0,1,phi; -phi,0,-1; 0,-1,-phi; phi,0,1; -1,phi,0; 1,-phi,0; -phi,0,-1; 0,1,phi; phi,0,1; 0,-1,phi; -phi,0,1];  
            obj.mormSegmentDuration = 1;        % us
            obj.segmentDurs = [1, phi, 2*phi-1, 2, phi+1, phi+1, 2*phi-2, phi+1, phi+1, 2, 2*phi-1, phi, 1] * obj.mormSegmentDuration;
            obj.initPulseDirection = [0, 1, phi];
            obj.initPulseAngle = 4 * pi / 5;
            obj.RabiFreq = 11.75;
            obj.RabiX0 = -0.93;
            
            obj.constantTime = false;       % logical
            obj.doubleMeasurement = true;   % logical
            
            obj.detectionDuration = 0.5;           % detection window, in us
            obj.referenceDetectionDuration = 0.5;     % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;   % laser initialization in pulsed experiments in us
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.topParam = ExpParamDoubleVector(StringHelper.TAU, [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|1>');
            obj.signalParam2 = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|0>');
        end
    end
    
    %% Setters
    methods
        function set.pulsePhase(obj, newVal)	% newVal in microsec
            checkPhases(obj, newVal)
            % If we got here, then newVal is OK.
            obj.pulsePhase = newVal;
            obj.changeFlag = true;
                end
        
        function set.cycles(obj, newVal)	% newVal in microsec
            checkPositive(obj, newVal)
            % If we got here, then newVal is OK.
            obj.cycles = newVal;
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
                S.addEvent(1,                               MW,                    'tau');
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
            totalMainPulseTime = sum(obj.segmentDurs);
            totalMainPulseTime = obj.RoundDurationByFrequencies(totalMainPulseTime, obj.frequency);
            obj.segmentDurs = obj.segmentDurs * totalMainPulseTime / sum(obj.segmentDurs);
            
            obj.AWG.ResetStoredData;
            obj.AWG.workChannels = 1:obj.nChannels;
            obj.AWG.setAmplitude(obj.amplitude);
            obj.AWG.ChangeSampleRate(totalMainPulseTime);
            
            N = length(obj.nRepetitions);
            initWaveformIndex = zeros(obj.nChannels, 1);
            mainWaveformsIndexX = zeros(obj.nChannels, 1);
            mainWaveformsIndexY = zeros(obj.nChannels, 1);
            finalWaveformIndex = zeros(obj.nChannels, 1);
            finalWaveformRefIndex = zeros(obj.nChannels, 1);
            
            A = obj.AWG.MaxNormPowerAllowed;
            w = 2*pi*obj.frequency;
            fprintf('Loading 5 waveforms: ');
            
            minWaveformTime = obj.AWG.minWaveformDuration;
                    
        

            [durs, signs] = obj.pulseToDurations(obj.initPulseDirection, obj.initPulseAngle);
            initTime = minWaveformTime + sum(durs) + obj.halfPiTime;
            minWaveformTime = minWaveformTime - (initTime - obj.RoundDurationByFrequencies(initTime, obj.AWG.SampleRate, -1));
            
            % the resolution of the time delay is the sample rate, so we add also aditional phase delay
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
            
            % init pulse:
            pulseTime = sum(durs);
            for chan = 1:obj.nChannels
                phaseZero = w * (prePulseTime(chan) + pulseTime) + phase(chan);
                f = @(t) A(chan) * (prePulseTime(chan)  <=t & t<prePulseTime(chan) + obj.halfPiTime)                                     .* cos(w*t - phaseZero) + ...
                                    (prePulseTime(chan) + obj.halfPiTime <=t & t<prePulseTime(chan)+durs(1))                 * 0 + ...
                                    (prePulseTime(chan)+durs(1)+obj.halfPiTime          <=t & t<prePulseTime(chan)+durs(1)+durs(2)+ obj.halfPiTime)         * 0 + ...
                                    (prePulseTime(chan)+durs(1)+durs(2)+obj.halfPiTime  <=t & t<prePulseTime(chan)+durs(1)+durs(2)+durs(3)+obj.halfPiTime) * 0;
                initWaveformIndex(chan) = obj.AWG.AddWaveformByFunction(f, prePulseTime(chan)+pulseTime+obj.halfPiTime, 0, 0);
            end
            
            % last pulse:
            [durs, signs] = obj.pulseToDurations(-obj.initPulseDirection, obj.initPulseAngle);
            pulseTime = sum(durs);
            for chan = 1:obj.nChannels
                f = @(t) A(chan) * ((0                      <=t & t<durs(1))                 * signs(1)     .* 0 + ...
                                    (durs(1)                <=t & t<durs(1)+durs(2))         * signs(2)     .* 0 + ...
                                    (durs(1)+durs(2)        <=t & t<durs(1)+durs(2)+durs(3)) * signs(3)     .* 0 + ...
                                    (durs(1)+durs(2)+durs(3)<=t & t<durs(1)+durs(2)+durs(3)+obj.halfPiTime) .* cos(w*t - phase(chan)));
                finalWaveformIndex(chan) = obj.AWG.AddWaveformByFunction(f, minWaveformTime+obj.halfPiTime+pulseTime,  0, 1);
                f = @(t) A(chan) * ((0                       <=t & t<durs(1))                 * signs(1) .* 0 + ...
                                    (durs(1)                 <=t & t<durs(1)+durs(2))         * signs(2) .* 0 + ...
                                    (durs(1)+durs(2)         <=t & t<durs(1)+durs(2)+durs(3)) * signs(3) .* 0+...
                                    (durs(1)+durs(2)+durs(3) <=t & t<durs(1)+durs(2)+durs(3)+obj.halfPiTime) .*(-1) .* cos(w*t - phase(chan)));
                finalWaveformRefIndex(chan) = obj.AWG.AddWaveformByFunction(f, minWaveformTime+obj.halfPiTime+pulseTime,  0, 1);
            end
            
            % main pulse X train:
            for chan = 1:N
                total_duration = obj.segmentDurs(1);
                sumMainFunction = @(t) 0*t;
                % Calculate the total duration of the waveform
                for i = 1:length(obj.pulseAngles)
                    %[durs, signs] = obj.pulseToDurations(obj.directions(i,:), obj.pulseAngles(i));
                    f = @(t) A(chan) * 0;
                    sumMainFunction = @(t) sumMainFunction(t) + f(t);
                    if i==(length(obj.pulseAngles)+1)/2 %Pi pulse for dynamical decoupling
                        f = @(t) A(chan) * (total_duration + (obj.segmentDurs(i+1) - obj.piTime)/ 2                <=t & t<total_duration + (obj.segmentDurs(i+1) + obj.piTime)/ 2 ) .* cos(w*t - phase(chan));
                        total_duration = total_duration + obj.segmentDurs(i+1);
                        sumMainFunction = @(t) sumMainFunction(t) + f(t);
                    else
                    total_duration = total_duration + obj.segmentDurs(i+1);
                    end 
                 end
                mainWaveformsIndexX(chan) = obj.AWG.AddWaveformByFunction(sumMainFunction, total_duration, 0, 0);
            end 
            
            % main pulse Y train:
            for chan = 1:N
                total_duration = obj.segmentDurs(1);
                sumMainFunction = @(t) 0*t;
                % Calculate the total duration of the waveform
                for i = 1:length(obj.pulseAngles)
                    %[durs, signs] = obj.pulseToDurations(obj.directions(i,:), obj.pulseAngles(i));
                    f = @(t) A(chan) * (0);
                    sumMainFunction = @(t) sumMainFunction(t) + f(t);
                    if i==(length(obj.pulseAngles)+1)/2 %Pi pulse for dynamical decoupling
                        f = @(t) A(chan) * (total_duration + (obj.segmentDurs(i+1) - obj.piTime)/ 2   <=t & t<total_duration + (obj.segmentDurs(i+1) + obj.piTime)/ 2 ) .* cos(w*t - phase(chan) + pi/2);
                        total_duration = total_duration + obj.segmentDurs(i+1);
                        sumMainFunction = @(t) sumMainFunction(t) + f(t);
                    else
                    total_duration = total_duration + obj.segmentDurs(i+1);
                    end 
                 end
                mainWaveformsIndexY(chan) = obj.AWG.AddWaveformByFunction(sumMainFunction, total_duration, 0, 0);
            end  
            
            obj.AWG.LoadWaveform();
            
            % creating sequences:
            obj.indexSeq = zeros(obj.nChannels, N);
            fprintf('Loading %d sequences: ', obj.nChannels*N);
            for chan = 1:obj.nChannels
                for i = 1:N
                    obj.indexSeq(chan,i) = obj.AWG.AddSequence([initWaveformIndex(chan), mainWaveformsIndexY(chan), finalWaveformIndex(chan), ...
                                                                initWaveformIndex(chan), mainWaveformsIndexY(chan), finalWaveformRefIndex(chan)], ...
                                                                [1 i 1 1 i 1], [1 0 0 1 0 0], [w, A(chan)/2, phaseZero(chan)/w]);
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
            maxLastDelay = obj.lastDelay + max(obj.nRepetitions) * sum(obj.segmentDurs) + 2*obj.angleToDuration(obj.initPulseAngle) + 2*obj.halfPiTime;
            
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
                        expDuration = obj.nRepetitions(t) * sum(obj.segmentDurs) + 2*obj.angleToDuration(obj.initPulseAngle) + 2*obj.halfPiTime;
                        pg.changeSequence('tau', 'duration', expDuration);
                        if obj.constantTime
                            pg.changeSequence('lastDelay', 'duration', maxLastDelay - expDuration);
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

