classdef AWGsensingSingleDrive < ExperimentAWG
    % This experiment for high frequenct sensing besed on Fedor's artcile:
    % https://www.nature.com/articles/s41467-017-01159-2
    
    properties (Constant)
        NAME = 'AWG Single Drive';
    end
    
    properties
        % All of the parameters must have a set function, and when they are changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue running);
        signalRatio     % in dB. The ratio between the signal and drive amplitude
        rabiFreq1       % rabi frequency of the first drive
        tau             % in us
        totalZero
    end
    
    properties (Dependent)
        signalFreq      % The signal frequency
    end

    methods
        function obj = AWGsensingSingleDrive()
            obj@ExperimentAWG(AWGsensingSingleDrive.NAME);
            obj.parameterName = 'taus';
            
            obj.repeats = 100;
            obj.averages = 10;
            obj.frequency = 2790;           % in MHz
            obj.amplitude = -8.8 + [0 0];    % in dBm
            obj.signalRatio = -40;          % in dB. relation to the single drive amplitude
            obj.rabiFreq1 = 1.6;
            
            obj.tau = 1:1:50;       % us
            obj.constantTime = true;
            obj.lastDelay = Experiment.DEFAULT_LAST_DELAY;
            
            obj.detectionDuration = 0.5;               % detection window, in us
            obj.referenceDetectionDuration = 0.5;         % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;       % laser initialization in pulsed experiments
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
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
            freq = obj.frequency + obj.rabiFreq1;
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
            obj.detectionPeriodsPerRepeat = 2;
            obj.runsPerPerform = 1;
            MWChannel = obj.MWChannel;
            checkDetectionDuration(obj, obj.detectionDuration); % The mode might have changed; before running, we check
            spcm = getObjByName(Spcm.NAME);
            
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
            S.addEvent(obj.AWG.TRIG_DURATION,           [triggers(:)', MW(:)']);                        % AWG trigger
            S.addEvent(obj.tau(end),                    MW,                         'MW')               % MW
            S.addEvent(obj.lastDelay,                   MW,                         'lastDelay');       % Last delay
            
            S.addEvent(obj.detectionDuration,       {'greenLaser', 'detector'});                    % Detection
            S.addEvent(initDuration,                'greenLaser');                                  % Initialization
            S.addEvent(obj.referenceDetectionDuration,...
                {'greenLaser', 'detector'});                                                        % Reference detection
            S.addEvent(1,                           'greenLaser');                                  % Initialization
            obj.prepareInternal(S)
            if obj.changeFlag || obj.restartFlag
                obj.LoadAWG;
            end
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.tau;
        end
        
        function LoadAWG(obj)
            baseWFtime = 1;
            baseWFtime = obj.RoundDurationByFrequencies(baseWFtime, [obj.frequency, obj.signalFreq], 1);
            obj.AWG.ResetStoredData;
            obj.AWG.workChannels = obj.activeChannels;
            obj.AWG.setAmplitude(obj.amplitude);
            obj.AWG.ChangeSampleRate(baseWFtime);
            minWaveformTime = obj.AWG.minWaveformDuration;
            
            N = length(obj.tau);
            shortWaveformsIndex = zeros(obj.nChannels,0);
            shortWaveformsTime = [];
            waveformsIndex = zeros(obj.nChannels,N);
            numBaseWaveformInPoint = zeros(1,N);
            initZeroIndex = zeros(1,obj.nChannels);
            constStepIndex = zeros(1,obj.nChannels);
            
            prePulseTime = minWaveformTime * ones(1,obj.nChannels);
            phase_A1 = zeros(1,obj.nChannels);
            phase_s  = zeros(1,obj.nChannels);

            % creating waveforms:
            A1 = obj.AWG.MaxNormPowerAllowed;
            g = A1 .* 10.^(obj.signalRatio / 20);
            w = 2*pi*obj.frequency;
            ws = 2*pi*obj.signalFreq;
            fprintf('Loading ~%d waveforms: ', (sum((obj.tau<baseWFtime)) + 2)*obj.nChannels);
            
            % the resolution of the time delay is the sample rate, so we add also aditional phase delay
            timeDelay = obj.RoundDurationByFrequencies(abs(obj.timeDelay), obj.AWG.SampleRate, -1);
            phaseDelay_A1 = w  * (abs(obj.timeDelay) - timeDelay);
            phaseDelay_s  = ws * (abs(obj.timeDelay) - timeDelay);
            if obj.timeDelay > 0
                prePulseTime(1) = minWaveformTime + timeDelay;
                phase_A1(1) = phaseDelay_A1;
                phase_s(1)  = phaseDelay_s;
            else
                prePulseTime(2) = minWaveformTime + timeDelay;
                phase_A1(2) = phaseDelay_A1;
                phase_s(2)  = phaseDelay_s;
            end
            for chan = 1:obj.nChannels
                f = @(t) 0 * t;
                initZeroIndex(chan) = obj.AWG.AddWaveformByFunction(f, prePulseTime(chan), 0);
                f = @(t) A1(chan)*cos(w*t - phase_A1(chan)) + g(chan)*cos(ws*t - phase_s(chan) + pi/2);
                constStepIndex(chan) = obj.AWG.AddWaveformByFunction(f, baseWFtime, 0);
            end
            
            for i = 1:N
                numBaseWaveformInPoint(i) = floor(obj.tau(i) / baseWFtime);
                residue = mod(obj.tau(i), baseWFtime);
                [closeWFdiff, closeWFindex] = min(abs((residue - shortWaveformsTime)));
                ind = length(shortWaveformsTime) + 1;
                for chan = 1:obj.nChannels
                    if closeWFdiff < 0.1*1/obj.signalFreq
                        waveformsIndex(chan, i) = shortWaveformsIndex(chan, closeWFindex);
                        obj.tau(i) = numBaseWaveformInPoint(i) * baseWFtime + shortWaveformsTime(closeWFindex);
                    else
                        shortWaveformsTime(ind) = residue;
                        f = @(t) (A1(chan)*cos(w*t - phase_A1(chan)) + g(chan)*cos(ws*t - phase_s(chan) + pi/2)) .* (0<=t & t<residue);
                        shortWaveformsIndex(chan,ind) = obj.AWG.AddWaveformByFunction(f, residue + minWaveformTime, 0, 1);
                        waveformsIndex(chan, i) = shortWaveformsIndex(chan, ind);
                    end
                end
            end
            fprintf('\n');
            obj.AWG.LoadWaveform();
           % delete double points in tau:
            while any(diff(obj.tau) == 0)
                i = find(diff(obj.tau) == 0, 1);
                obj.tau(i) = [];
                waveformsIndex(:, i) = [];
                numBaseWaveformInPoint(i) = [];
            end
            
            % creating sequences:
            N = length(obj.tau);
            obj.indexSeq = zeros(obj.nChannels,N);
            for i = 1:N
                for chan = 1:obj.nChannels
                    
                    draw = 0; %(chan-1)*mod(i,2);
                    
%                     if i == 10 && chan==1
% %                         draw = [w, A1(chan)*0.8, minWaveformTime-obj.timeDelay*(chan==1)];
%                         draw = [ws, g(chan)*0.8, 0.154688];
%                         figure;
%                     end
                    
                    if numBaseWaveformInPoint(i) == 0
                        obj.indexSeq(chan,i) = obj.AWG.AddSequence([initZeroIndex(chan), waveformsIndex(chan,i)], ...
                                                                   [1                  , 1], ...
                                                                   [1                  , 0], draw);
                    else
                        obj.indexSeq(chan,i) = obj.AWG.AddSequence([initZeroIndex(chan), constStepIndex(chan),    waveformsIndex(chan,i)], ...
                                                                   [1                  , numBaseWaveformInPoint(i), 1], ...
                                                                   [1                  , 0                       0], draw);
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
            maxLastDelay = obj.lastDelay + max(obj.tau);
            
            for t = randperm(length(obj.tau))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue
                end
                success = false;
                
                for trial = 1 : 10
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        pg.changeSequence('MW', 'duration', obj.tau(t));
                        if obj.constantTime
                            pg.changeSequence('lastDelay', 'duration', maxLastDelay - obj.tau(t));
                        end
                        for i = 1:length(obj.activeChannels)
                            obj.AWG.assignSequence(obj.indexSeq(i,t), obj.activeChannels(i));
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
            dataParam = [];
        end
    end

end
