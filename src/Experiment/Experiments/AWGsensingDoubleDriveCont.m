classdef AWGsensingDoubleDriveCont < ExperimentAWG
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
    end
    
    properties (Dependent)
        signalFreq      % The signal frequency
    end

    methods
        function obj = AWGsensingDoubleDriveCont()
            obj@ExperimentAWG(AWGsensingDoubleDriveCont.NAME);
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
            freq = obj.frequency + obj.rabiFreq1 + obj.rabiFreq2/2;
%             freq = obj.frequency + obj.rabiFreq2/2;
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
            % S.addEvent(2,                   '');
            S.addEvent(obj.tau(end),                    MW,                         'MW');               % MW
            S.addEvent(obj.lastDelay,                   '',                         'lastDelay');       % Last delay
            % S.addEvent(2,                   '');
            
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

            obj.indexWF = zeros(1, obj.nChannels);

            % creating waveforms:
            A1 = obj.AWG.MaxNormPowerAllowed;
            A2 = A1 .* 10.^(obj.ampltudeRatio / 20);
            g  = A2 .* 10.^(obj.signalRatio / 20);
            w = 2*pi*obj.frequency;
            w1 = 2*pi*obj.rabiFreq1;
            ws = 2*pi*obj.signalFreq;
            d = pi/2 * (obj.directions == 'YYY');

            fprintf('Loading waveforms:');

            % the resolution of the time delay is the sample rate, so we add also aditional phase delay
            t0 = [obj.timeDelay, 0];
            for chan = 1:obj.nChannels
                f = @(t) A1(chan)*cos(w *(t-t0(chan))) + ...
                         A2(chan)*cos(w *(t-t0(chan))  + d(1)).*cos(w1*(t-t0(chan)) + d(2)) + ...
                         g(chan) *cos(ws*(t-t0(chan))  + d(3));
                obj.indexWF(chan) = obj.AWG.AddWaveformByFunction(f, baseWFtime, 0);
            end
            fprintf('\n');
            obj.AWG.LoadWaveform();
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

            %           AWG run:
            for i = 1:length(obj.activeChannels)
                obj.AWG.assignWaveform(obj.indexWF(i), obj.activeChannels(i))
            end
            obj.AWG.Run;
            
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
