classdef GIA_lastDelayCont_ExpCalibrateDelays < ExperimentAWG
    
    properties (Constant)
        NAME = 'GIA last delay calibration';
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
        delays
    end

    methods
        function obj = GIA_lastDelayCont_ExpCalibrateDelays()
            obj@ExperimentAWG(GIA_triggerDelay_ExpCalibrateDelays.NAME);
            obj.parameterName = 'delays';
            
            obj.repeats = 10000;
            obj.averages = 100;
            obj.frequency = 2780;           % in MHz
            obj.isTracking = false;          % Initialize tracking
            obj.amplitude = -3.69 + [0 -1.6];            % in dBm
            obj.delays = 0:0.01:2;
            obj.constantTime = true;
            obj.piTime = 0.245;
            obj.timeDelay = -40e-6;
            obj.constantTime = 1;
            obj.fixDelays = 1;
                        
            obj.AWGorSRSswitch = 0;
            obj.detectionDuration = 0.5;
            obj.referenceDetectionDuration = 0.5;
            obj.GIMeas = 1;
            
            obj.lastDelay = Experiment.DEFAULT_LAST_DELAY;
            obj.nChannels = 2; 
            obj.lastDelay = 1.2;  
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
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
        
    end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.delays);
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
            S.addEvent(1,                           {'greenLaser'});
            S.addEvent(obj.piTime,                  MW);
            S.addEvent(obj.lastDelay,               '',                                 'lastDelay');   % Last delay
            S.addEvent(obj.detectionDuration+0.066, {'greenLaser', 'GIenable', 'GIgate'});              % Detection
            S.addEvent(obj.stabilizationDuration,   {'greenLaser', 'GIenable'});                        % voltage stabilization
            S.addEvent(obj.acquisitionDuration,     {'greenLaser', 'GIenable', 'detector'});            % Acquisition
            S.addEvent(obj.GIresetDuration,         {'greenLaser'});                                    % GI reset
            S.addEvent(max([0, initDuration - detectionSequnceDuration]),...
                'greenLaser');                                  % Initialization
            S.addEvent(obj.referenceDetectionDuration+0.066,...
                {'greenLaser', 'GIenable', 'GIgate'});          % Reference detection
            S.addEvent(obj.stabilizationDuration,   {'greenLaser', 'GIenable'});                    % voltage stabilization
            S.addEvent(obj.acquisitionDuration,     {'greenLaser', 'GIenable', 'detector'});        % Reference acquisition
            S.addEvent(obj.GIresetDuration,         {'greenLaser'});                                % GI reset
            
            obj.prepareInternal(S)
            if obj.changeFlag || obj.restartFlag
                obj.LoadAWG;
            end
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.delays;
        end
        
        function LoadAWG(obj)
            baseWFtime = 0.2;
            baseWFtime = obj.RoundDurationByFrequencies(baseWFtime, obj.frequency);
            obj.AWG.ResetStoredData;
            obj.AWG.workChannels = 1:obj.nChannels;
            obj.AWG.setAmplitude(obj.amplitude);
            obj.AWG.ChangeSampleRate(baseWFtime);
            
            obj.indexWF = zeros(1, obj.nChannels);

            % creating waveforms:
            A = obj.AWG.MaxNormPowerAllowed;
            w = 2*pi*obj.frequency;
            
            % the resolution of the time delay is the sample rate, so we add also aditional phase delay
            t0 = [0, obj.timeDelay];
            for chan = 1:obj.nChannels
                f = @(t) A(chan) * cos(w*(t - t0(chan)));
                obj.indexWF(chan) = obj.AWG.AddWaveformByFunction(f, baseWFtime, 0);
            end
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
            maxLastDelay = obj.lastDelay + abs(min(obj.delays));
%             AWG load and run:
            obj.AWG.assignWaveform(obj.indexWF(1), 1)
            if obj.nChannels == 2
                obj.AWG.assignWaveform(obj.indexWF(2), 2);
            end
            obj.AWG.Run;
            
            k = 0; %added by rotem 18.4.21
            f1 = []; %added by rotem 18.4.21
            
            for t = randperm(length(obj.delays))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue
                end
                success = false;
                
                f1 = [f1, t]; %added by rotem 18.4.21
                k = k + 1; %added by rotem 18.4.21
                for trial = 1 : 10
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        pg.changeSequence('lastDelay', 'duration', obj.delays(t));
                        
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
