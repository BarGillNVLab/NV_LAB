classdef AWGExp2DRabi< ExperimentAWG
    
    properties (Constant)
        NAME = 'AWG 2D Rabi';
    end
    
    properties
        % All of the parameters must have a set function, and when they are changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue running);
        tau             % in us
        
    end
    
    properties (SetAccess = private)
        tauVector
    end

    methods
        function obj = AWGExp2DRabi()
            obj@ExperimentAWG(AWGExp2DRabi.NAME);
            
            obj.repeats = 10000;
            obj.averages = 1000;
            obj.frequency = 2870;               % in MHz
            obj.amplitude = -25:1:-10;          % in dBm
            obj.tau = 0.005:0.02:0.6;           % in mus - Can be a matrix such that for each amplitude there is a different time
            obj.constantTime = true;
            
            obj.detectionDuration = 0.25;               % detection window, in us
            obj.referenceDetectionDuration = 5;         % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;       % laser initialization in pulsed experiments
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.mCurrentYAxisParam = ExpParamDoubleVector('Amplitude', [], [], 'dBm', obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
        end
    end

%% Setters
    methods
        function set.tau(obj, newVal) % newVal is in us
            checkTimeVectorOrMatrix(obj, newVal)
            % If we got here, then newVal is OK.
            obj.tau = newVal;
            obj.changeFlag = true;
        end
        
    end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            tauSize = size(obj.tau);
            totalParamNum = tauSize(2) * length(obj.amplitude);
        end
    end
    
%% Overridden from Experiment
    methods (Access = protected)
        
        function prepare(obj)
            % Initialize devices (SPCM, PulseGenerator, etc.)
            
            % Sequence
            %%% Useful parameters for what follows
            initDuration = obj.laserInitializationDuration-obj.detectionDuration-obj.referenceDetectionDuration;
            obj.detectionPeriodsPerRepeat = 2;
            obj.runsPerPerform = 1;
            MWChannel = obj.MWChannel;
            checkDetectionDuration(obj, obj.detectionDuration); % The mode might have changed; before running, we check
            tauSize = size(obj.tau);
            if tauSize(1) > 1 && tauSize(1) ~= length(obj.amplitude)
                obj.sendError('Tau should either be a vector or a matrix whose 1st dimenstion''s length is the same as amplitudes');
            end
            
            obj.tauVector = linspace(min(min(obj.tau)), max(max(obj.tau)), 1000);
            
            lastDelay = Experiment.DEFAULT_LAST_DELAY;
            
            % Initialize FrequencyGenerator
            if isempty(obj.givenFG)
                fgCell = FrequencyGenerator.getFG();
                if obj.nChannels == 1
                    obj.freqGenName = fgCell{1}.name;
                else
                    if fgCell{1}.numChannels == 2
                        obj.freqGenName = fgCell{1}.name;
                    else
                        obj.freqGenName = cellfun(@(fg)fg.name, fgCell(1:2), 'UniformOutput' ,0);
                    end
                end
            end
            
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
            
            S = Sequence;
            S.addEvent(obj.AWG.TRIG_DURATION,   [triggers{:}, MW{:}, {'AWG'}]);             % AWG trigger
            S.addEvent(max(max(obj.tau)),       [MW{:}, {'AWG'}],     'MW')                 % MW
            S.addEvent(lastDelay,           '',                       'lastDelay');         % Last delay
            S.addEvent(obj.detectionDuration,...
                {'greenLaser', 'detector'});                                                % Detection
            S.addEvent(initDuration,        'greenLaser');                                  % Initialization
            S.addEvent(obj.referenceDetectionDuration,...
                {'greenLaser', 'detector'});                                                % Reference detection
            
            obj.prepareInternal(S)
            if obj.changeFlag
                obj.LoadAWG;
            end
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.tauVector;
            obj.mCurrentYAxisParam.value = obj.amplitude;
        end
        
        function LoadAWG(obj)
            obj.AWG.ResetStoredData;
            obj.AWG.workChannels = 1:obj.nChannels;
            obj.AWG.setAmplitude(max(obj.amplitude));
            
            minWaveformTime = obj.AWG.minWaveformDuration;
            tauSize = size(obj.tau);
            N = tauSize(1);
            M = tauSize(2);
            waveformsIndex = zeros(obj.nChannels, tauSize(1), tauSize(2));
            obj.indexSeq = waveformsIndex;
            
            ampls = sqrt(10.^(obj.amplitude/10));
            amplitudesScale = ampls / max(ampls);

            % creating waveforms:
            A = obj.AWG.MaxNormPowerAllowed;
            w = 2*pi*obj.frequency;
            fprintf('Loading %d waveforms: ', N*M);
            
            for i = 1:N
                for j = 1:M
                    for chan = 1:obj.nChannels
                        f = @(t) A(chan) * amplitudesScale(i) * (0<=t & t<obj.tau(i,j)) .* cos(w*t);
                        
                        if obj.timeDelay > 0
                            prePulseTime = minWaveformTime + obj.timeDelay*(chan==1);
                        else
                            prePulseTime = minWaveformTime + obj.timeDelay*(chan==2);
                        end
                        waveformsIndex(chan,i,j) = obj.AWG.AddWaveformByFunction(f, prePulseTime+obj.tau(i,j), prePulseTime, 1);
                        fprintf('%d ', i*(N-1)+j);
                        if mod(i,30) == 0
                            fprintf('\n');
                        end
                    end
                end
            end
            f = @(t) 0*t;
            lastZeroIndex = obj.AWG.AddWaveformByFunction(f, minWaveformTime, 0, 1);
            fprintf('%d\n', N*M+1);
            obj.AWG.LoadWaveform();
            
            % creating sequences:
            for i = 1:N
                for j = 1:M
                    for chan = 1:obj.nChannels
                        obj.indexSeq(chan,i,j) = obj.AWG.AddSequence([waveformsIndex(chan,i,j) lastZeroIndex], [1 1], [1 0], 0);
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
            maxLastDelay = Experiment.DEFAULT_LAST_DELAY + max(max(obj.tau));
            
            for n = randperm(obj.getTotalNumberOfParams)
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, n, obj.currIter)) ~= 0
                    continue
                end
                success = false;
                
                for trial = 1 : 10
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        pg.changeSequence('MW', 'duration', obj.tau(n));
                        if obj.constantTime
                            pg.changeSequence('lastDelay', 'duration', maxLastDelay - obj.tau(n));
                        end
                        [i, j] = ind2sub(size(obj.tau),n);
                        obj.AWG.assignSequence(obj.indexSeq(1,i,j),1)
                        if obj.nChannels == 2
                            obj.AWG.assignSequence(obj.indexSeq(2,i,j),2);
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
                    obj.emergencyStop;
                    return
                end
            end
            
            % Saving results in the Experiment parameters
            tauSize = size(obj.tau);
            S1 = reshape(squeeze(obj.signal(1, :, 1:obj.currIter)), length(obj.amplitude), tauSize(2), []);
            S1sterr = reshape(squeeze(obj.sterr(1, :, 1:obj.currIter)), length(obj.amplitude), tauSize(2), []);
            S2 = reshape(squeeze(obj.signal(2, :, 1:obj.currIter)), length(obj.amplitude), tauSize(2), []);
            S2sterr = reshape(squeeze(obj.sterr(2, :, 1:obj.currIter)), length(obj.amplitude), tauSize(2), []);
            
            [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);
            if tauSize(1) == 1
                obj.signalParam.value = value;
                obj.signalParam.sterr = sterr;
                obj.signalParam2.value = value; %Backup for raw data(although not needed it is here for consistency)
            else
                L = length(obj.amplitude);
                for i = 1:L
                    currentTau = obj.tau(i, :);
%                     currentSig = squeeze(obj.signal(1, L*(i-1)+1:L*i, 1:obj.currIter));
%                     currentRef = squeeze(obj.signal(2, L*(i-1)+1:L*i, 1:obj.currIter));
                    obj.signalParam.value(i, :) = interp1(currentTau, value(i, :), obj.tauVector, 'spline', NaN); % can change 'extrap' to be NaN or 0
                    obj.signalParam2.value = value; %Backup for raw data since signalParam is interpolated.
                end
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
            dataParam = [];
        end
    end
end