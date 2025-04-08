classdef GIA_laser_trigger_ExpCalibrateDelays < ExperimentAWG
    % calibration experiment of the delays between laser off to the AWG trigger on
    % The code teke in account the channels delays, so you must zero the
    % 'trigger' on delay on json before run.
    
    
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
        
        privateSequences
        listOfChannels              % Cell array of channels, the channels will be turned on according to the order listed
        delays                      % vector of on/off delays to measure
        MWduration
        otherDelays                 % fixed off/on delay
        piTime                      % in us
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = GIA_laser_trigger_ExpCalibrateDelays(FG)
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
            obj.frequency = 2870;           % in MHz
            obj.amplitude = -10;            % in dBm
            
            obj.repeats = 1000;
            obj.averages = 100;
            obj.isTracking = false;          % Initialize tracking
            obj.trackThreshhold = 0.7;
            obj.shouldAutosave = true;
            obj.fixDelays = 1;              % Do not fix delays for this experiment!
            
            obj.delays = -2:0.1:2;
            obj.centerDuration = 1;         % Gienable+GIgate on 
            obj.MWduration = 5;
            obj.piTime = 0.1;

            
            obj.AWGorSRSswitch = 0;
            obj.detectionDuration = 0.5;
            obj.referenceDetectionDuration = [];
            obj.photoDiodeMeas = 1;

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
        
        function set.listOfChannels(obj, newVal)
            checkChannels(obj, newVal)
            % If we got here, then newVal is OK.
            obj.listOfChannels = newVal;
            obj.changeFlag = true;
        end

    end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.delays);
        end
    end
    
    %% Overridden from Experiment
    methods (Access = protected)        
        function prepare(obj)
            % Initializtions before run
            obj.detectionPeriodsPerRepeat = 1;
            obj.runsPerPerform = 1;
            pg = getObjByName('pulseGenerator');
            [~, laserOffDelay] = pg.channelName2Delays('greenLaser');
            lastDelay = Experiment.DEFAULT_LAST_DELAY;
            startTime = 2;
            
            if obj.seperatedTrigger                         % AWG trigger
                triggers = {'trigger', 'trigger2'};
            else
                triggers = {'trigger'};
            end
            switch obj.nChannels
                case 1
                    MW = {'MW'};
                case 2
                    MW = {'MW', 'MW2'};
                otherwise
                    obj.sendError('What should we do here?')
            end
            if obj.AWGorSRSswitch
                MW = [MW{:}, {'AWG'}];
            end
            
            S = Sequence;
            S.addEvent(startTime,                   {'greenLaser'});
            S.addEvent(max(obj.delays),             [triggers(:)', MW(:)'],               'triggerDelay');  % trigger delay
            S.addEvent(obj.AWG.TRIG_DURATION,       [triggers(:)', MW(:)']);                                % AWG trigger
            S.addEvent(obj.piTime,                  MW)                                                     % MW
            S.addEvent(lastDelay,                   '');                                                    % Last delay
            S.addEvent(obj.detectionDuration,       {'greenLaser', 'GIenable', 'GIgate'});                  % off delay. must enter manual
            S.addEvent(obj.stabilizationDuration,   {'greenLaser', 'GIenable'});                            % Stabilization
            S.addEvent(obj.acquisitionDuration,     {'greenLaser', 'GIenable', 'detector'});                % Acquisition
            S.addEvent(obj.GIresetDuration,         {'greenLaser'});                                        % GI reset
            
            obj.prepareInternal(S);
            obj.isPlotAlternateAvailable = 1;
            
            if obj.changeFlag
                obj.LoadAWG;
            end
            obj.mCurrentXAxisParam.value = obj.delays;
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
            fprintf('Loading %d waveforms: ', N+1);
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
            fprintf('%d\n', N+1);
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
            
            %%% Run - Go over all shifts's, in random order
            for n = randperm(length(obj.delays))
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
                        pg.setSequence(obj.privateSequences{n});
                        obj.AWG.assignSequence(obj.indexSeq(1), 1)
                        if obj.nChannels == 2
                            obj.AWG.assignSequence(obj.indexSeq(2), 2);
                        end
                        obj.AWG.Run;
                        
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
            S = squeeze(obj.signal(:, :, 1:obj.currIter));
            Ssteerr = squeeze(obj.sterr(:, :, 1:obj.currIter));
            
            if obj.currIter > 1
                n = BooleanHelper.ifTrueElse(length(obj.delays) > 1, 2, 1);
                S = mean(S, n);
                Ssteerr = mean(Ssteerr, n)./sqrt(size(Ssteerr, n));
            end
            obj.signalParam.value = S;
            obj.signalParam.sterr = Ssteerr;
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