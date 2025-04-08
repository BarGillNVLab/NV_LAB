classdef GIA_InitializationTime_ExpCalibrateDelays < ExperimentAWG
    %ExpCalibrateDelays Experiment for calibrating the delay times
    
    properties (Constant)
        NAME = 'GIA GIgate Calibration Delays';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency                   % in MHz
        amplitude                   % in dBm
        
        channelToMeasure            % the channel to measure
        time                        % vector of durations to measure
        piTime
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = GIA_InitializationTime_ExpCalibrateDelays(FG)
            obj@ExperimentAWG(ExpCalibrateDelays.NAME);
            obj.parameterName = 'delays';
            
            % First, get a frequency generator
            if exist('FG', 'var')
                obj.givenFG = FG;
            else
                FG = [];
            end
            obj.freqGenName = obj.getFgName(FG);
            
            % Set properties inherited from Experiment
            obj.frequency = 2687;           % in MHz
            obj.amplitude = -3 + [0 0.4];            % in dBm
            
            obj.repeats = 1000;
            obj.averages = 100;
            obj.isTracking = false;          % Initialize tracking
            obj.trackThreshhold = 0.7;
            obj.shouldAutosave = true;
            obj.fixDelays = 1;              % Do not fix delays for this experiment!
            
            obj.channelToMeasure = 'GIgate';
            obj.time = 0.01:0.1:5;
            obj.piTime = 0.05;
            
            obj.detectionDuration = 0.5;
            obj.referenceDetectionDuration = 0.5;
            obj.GIMeas = 1;
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'volt', obj.NAME);
        end
    end
    
    %% Setters & Getters
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
            obj.amplitude = newVal;
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
            % Initializtions before run
            initDuration = obj.laserInitializationDuration-obj.detectionDuration-obj.referenceDetectionDuration;
            detectionSequnceDuration = obj.detectionDuration + obj.stabilizationDuration + obj.acquisitionDuration + obj.GIresetDuration;
            obj.detectionPeriodsPerRepeat = 2;
            obj.runsPerPerform = 1;
            checkDetectionDuration(obj, obj.detectionDuration); % The mode might have changed; before running, we check

            if obj.seperatedTrigger                         % AWG trigger
                triggers = {'trigger', 'trigger2'};
            else
                triggers = {'trigger'};
            end
            switch obj.nChannels
                case 1
                    MW = 'MW';
                case 2
                    MW = {'MW', 'MW2'};
                otherwise
                    obj.sendError('What should we do here?')
            end
            if obj.AWGorSRSswitch
%                 MW = [MW{:}, {'AWG'}];
                MW = '';
            end
            
            
            S = Sequence;
            S.addEvent(1,                               '')
            S.addEvent(obj.AWG.TRIG_DURATION,           [triggers(:)', MW(:)']);                    % AWG trigger
            S.addEvent(obj.piTime,                    MW)               % MW
            S.addEvent(1,                               '')
            S.addEvent(max(obj.time),               'greenLaser',                   'initTime');    % initialization time
            S.addEvent(0.1,                         {'greenLaser', 'GIenable', 'GIgate'});          % Detection
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
            
            obj.prepareInternal(S)
            if obj.changeFlag || obj.restartFlag
                obj.LoadAWG;
            end
            obj.mCurrentXAxisParam.value = obj.time;
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
            fprintf('Loading 2 waveforms: ');
            for chan = 1:obj.nChannels
                f = @(t) A(chan) * (0<=t & t<obj.piTime) .* cos(w*t);
                if obj.timeDelay > 0
                    prePulseTime = minWaveformTime + obj.timeDelay*(chan==1);
                else
                    prePulseTime = minWaveformTime + obj.timeDelay*(chan==2);
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
            if isempty(tracker); throwBaseObjException(Tracker.NAME); end
            
            % Some magic numbers
            obj.AWG.assignSequence(obj.indexSeq(1), 1)
            if obj.nChannels == 2
                obj.AWG.assignSequence(obj.indexSeq(2), 2);
            end
            obj.AWG.Run;

                        %%% Run - Go over all shifts's, in random order
            for n = randperm(length(obj.time))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, n, obj.currIter)) ~= 0
                    continue
                end
                success = false;
            
                for trial = 1 : 5
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        pg.changeSequence('initTime', 'duration', obj.time(n));
                        
                        
                        data = obj.getRawData(pg, spcm);
                        [sig, sterr] = obj.processData(data);
                        obj.signal(:, n, obj.currIter) = sig;
                        obj.sterr(:, n, obj.currIter) = sterr;
                        
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
                    obj.emergencyStop
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
        end
        
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results and fit from it
            % the coherence time.
            
            obj.wrapUpInternal()
        end
        
        function dataParam = alternateSignal(obj) %#ok<MANU>
            % Returns alternate view ("referenced") of the data, as an
            % ExpParam, if possible. If not, it returns an empty variable.
            dataParam = [];
        end
    end
    
end