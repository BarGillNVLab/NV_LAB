classdef GIA_NVdetectionDuration_ExpCalibrate < ExperimentAWG
    %ExpCalibrateDelays Experiment for calibrating the detection time
    
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
        
        delay               % in us
        detectionDurations  % in us. A vector of the scanned detection times
        piTime
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = GIA_NVdetectionDuration_ExpCalibrate(FG)
            obj@ExperimentAWG(ExpCalibrateDelays.NAME);
            obj.parameterName = 'durations';
            
            % First, get a frequency generator
            if exist('FG', 'var')
                obj.givenFG = FG;
            else
                FG = [];
            end
            obj.freqGenName = obj.getFgName(FG);
            
            % Set properties inherited from Experiment
            obj.frequency = 3029;           % in MHz
            obj.amplitude = -10;            % in dBm
            
            obj.repeats = 1000;
            obj.averages = 100;
            obj.isTracking = false;          % Initialize tracking
            obj.trackThreshhold = 0.7;
            obj.shouldAutosave = true;
            obj.fixDelays = 1;              % Do not fix delays for this experiment!
            
            obj.delay = 0.5;                        % in us (100 ns)
            obj.piTime = 0.430;
            obj.detectionDurations = 0.1:0.1:1.5; % detection windows, in \mus
            obj.laserInitializationDuration = 10;
            
            obj.detectionDuration = 1;
            obj.referenceDetectionDuration = 1;
            obj.photoDiodeMeas = 1;
            
            obj.displayType1 =  'FL';
            obj.displayType2 =  'SNR';
            obj.isPlotAlternateAvailable = true;
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Detection Duration', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|0>');
            obj.signalParam2 = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|1>');
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
        
        function set.detectionDurations(obj ,newVal)	% newVal in microsec
            checkDetectionDuration(obj, newVal);
            % If we got here, then newVal is OK.
            obj.detectionDurations = newVal;
            obj.changeFlag = true;  % We need to update the PG
        end
    end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.detectionDurations);
        end
    end
    
    %% Overridden from Experiment
    methods (Access = protected)        
        function prepare(obj)
            % Initializtions before run

            % Sequence
            %%% Useful parameters for what follows
            initDuration = obj.laserInitializationDuration - max(obj.detectionDurations) - obj.stabilizationDuration - obj.acquisitionDuration - obj.GIresetDuration;
            if initDuration < 0
                obj.laserInitializationDuration = max(obj.detectionDurations) + obj.stabilizationDuration + obj.acquisitionDuration + obj.GIresetDuration;
                warning('"laserInitializationDuration" was set to %.2f us', obj.laserInitializationDuration);
                initDuration = 0;
            end
            obj.detectionPeriodsPerRepeat = 4;
            obj.runsPerPerform = 1;
            
            MWChannel = obj.MWChannel;
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
            for k = 1:2
                S.addEvent(max(obj.detectionDurations), {'greenLaser', 'GIenable', 'GIgate'},     'detection');     % Detection
                S.addEvent(obj.stabilizationDuration,   {'greenLaser', 'GIenable'});                                % voltage stabilization
                S.addEvent(obj.acquisitionDuration,     {'greenLaser', 'GIenable', 'detector'});                    % Acquisition 
                S.addEvent(obj.GIresetDuration,         {'greenLaser'});                                            % GI reset
                S.addEvent(initDuration,                'greenLaser',                             'initDuration');  % Initialization
                S.addEvent(obj.referenceDetectionDuration,...
                                                        {'greenLaser', 'GIenable', 'GIgate'});                      % Reference detection
                S.addEvent(obj.stabilizationDuration,   {'greenLaser', 'GIenable'});                                % voltage stabilization
                S.addEvent(obj.acquisitionDuration,     {'greenLaser', 'GIenable', 'detector'});                    % Reference acquisition 
                S.addEvent(obj.GIresetDuration,         {'greenLaser'});                                            % GI reset
                S.addEvent(obj.delay,       '');                                                                    % Delay
                if k == 1
%                     S.addEvent(obj.AWG.TRIG_DURATION,         [triggers(:)', MW(:)']);                              % AWG trigger
%                     S.addEvent(obj.piTime,                    MW)                                                   % MW pi pulse
                    S.addEvent(5000,                    '')                                                   % dark time
                end
                S.addEvent(obj.delay,       '');                                                                    % Delay
                S.addEvent(Experiment.DEFAULT_LAST_DELAY, '');
            end
            obj.prepareInternal(S)
%             obj.isPlotAlternateAvailable = 1;
            
            if obj.changeFlag
                obj.LoadAWG;
            end
            obj.mCurrentXAxisParam.value = obj.detectionDurations;
        end
        
        function LoadAWG(obj)
            obj.AWG.ResetStoredData;
            obj.AWG.workChannels = 1:obj.nChannels;
            obj.AWG.setAmplitude(obj.amplitude);
            
            minWaveformTime = obj.AWG.minWaveformDuration;
            WaveformsIndex = zeros(1, obj.nChannels);
            obj.indexSeq = zeros(1, obj.nChannels);

            % creating waveforms:
            A = obj.AWG.MaxNormPowerAllowed;
            w = 2*pi*obj.frequency;
            fprintf('Loading %d waveforms: ', 2);
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
            if isempty(tracker); throwBaseObjException(Tracker.NAME); end
            
            % Some magic numbers
            
            %%% Run - Go over all shifts's, in random order
            for t = randperm(length(obj.detectionDurations))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue
                end
                success = false;
                
                % The detection duration is changed here simply to comply
                % with the "ProcessData" function. It is not really
                % significant... However, it changes the changeFlag,
                % therefore, we change it back.
                obj.detectionDuration = obj.detectionDurations(t);
                obj.changeFlag = false;
                initDuration = obj.laserInitializationDuration - obj.detectionDuration - obj.stabilizationDuration - obj.acquisitionDuration - obj.GIresetDuration;

                for trial = 1 : 5
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        pg.changeSequence('detection', 'duration', obj.detectionDuration);
                        pg.changeSequence('initDuration', 'duration', initDuration);
                        
                        obj.AWG.assignSequence(obj.indexSeq(1), 1)
                        if obj.nChannels == 2
                            obj.AWG.assignSequence(obj.indexSeq(2), 2);
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
            % In the future, it will also analyze results and fit from it
            % the coherence time.
            
            obj.wrapUpInternal()
        end
        
        function dataParam = alternateSignal(obj)
            % Returns alternate view ("SNR") of the data, as an ExpParam.
            S1 = squeeze(obj.signal(1, :, 1:obj.currIter));
            S2 = squeeze(obj.signal(2, :, 1:obj.currIter));
            N0 = S1./S2;
            S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
            S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
            N1 = S3./S4;
            value = mean(N0-N1, 2) ./ std(N0-N1, 0, 2);
            sterr = [];
            dataParam = ExpResultDoubleVector('SNR', value, sterr, '', obj.NAME);
        end
    end
    
end