classdef AWGtriggerCalibration < ExperimentAWG
    
    properties (Constant)
        NAME = 'AWG trigger Calibration Delays';
    end
    
    properties
        % All of the parameters must have a set function, and when they are changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue running);
        tau             % in us
        totalZero
    end

    methods
        function obj = AWGtriggerCalibration()
            obj@ExperimentAWG(AWGtriggerCalibration.NAME);
            obj.parameterName = 'taus';
            
            obj.repeats = 10000;
            obj.averages = 100;
            obj.frequency = 2023;           % in MHz
            obj.amplitude = -15 + [0 0];    % in dBm
            obj.time = 0.005:0.02:0.6;       % us
            obj.piTime = 0.1;
            obj.constantTime = true;
            
            obj.detectionDuration = 0.25;               % detection window, in us
            obj.referenceDetectionDuration = 5;         % in us. Detection duration of the reference read
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
            initDuration = obj.laserInitializationDuration-obj.detectionDuration-obj.referenceDetectionDuration;
            detectionSequnceDuration = obj.detectionDuration + obj.stabilizationDuration + obj.acquisitionDuration + obj.GIresetDuration;
            obj.detectionPeriodsPerRepeat = 2;
            obj.runsPerPerform = 1;
            MWChannel = obj.MWChannel;
            checkDetectionDuration(obj, obj.detectionDuration); % The mode might have changed; before running, we check
            
            lastDelay = Experiment.DEFAULT_LAST_DELAY;
            
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
            S.addEvent(obj.time(end),                   triggers(:)',                   'delay');                        % AWG trigger
            S.addEvent(obj.AWG.TRIG_DURATION,           [triggers(:)', MW(:)']);                        % AWG trigger
            S.addEvent(obj.piTime,                    MW)               % MW
            S.addEvent(lastDelay,                       '',                         'lastDelay');       % Last delay
            
            if ~obj.photoDiodeMeas
                S.addEvent(obj.detectionDuration,       {'greenLaser', 'detector'});                    % Detection
                S.addEvent(initDuration,                'greenLaser');                                  % Initialization
                S.addEvent(obj.referenceDetectionDuration,...
                    {'greenLaser', 'detector'});                                                        % Reference detection
            else
%                 S.addEvent(2,                           '');
                
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
%                 S.addEvent(2,                           '');
            end
            obj.prepareInternal(S)
            if obj.changeFlag || obj.restartFlag
                obj.LoadAWG;
            end
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.time;
        end
        
        function LoadAWG(obj)
            obj.AWG.ResetStoredData;
            obj.AWG.workChannels = 1:obj.nChannels;
            obj.AWG.setAmplitude(obj.amplitude);
            
            minWaveformTime = obj.AWG.minWaveformDuration;
            N = 1;
            WaveformsIndex = zeros(obj.nChannels,N);
            obj.indexSeq = zeros(obj.nChannels,N);

            % creating waveforms:
            A = obj.AWG.MaxNormPowerAllowed;
            w = 2*pi*obj.frequency;
            fprintf('Loading %d waveforms: ', N+1);
            for i = 1:N
                for chan = 1:obj.nChannels
                    f = @(t) A(chan) * (0<=t & t<obj.tau(i)) .* cos(w*t);
                    if obj.timeDelay > 0
                        prePulseTime = minWaveformTime + obj.timeDelay*(chan==1);
                    else
                        prePulseTime = minWaveformTime - obj.timeDelay*(chan==2);
                    end
                    WaveformsIndex(chan,i) = obj.AWG.AddWaveformByFunction(f, prePulseTime+obj.tau(i), prePulseTime, 1);
                    fprintf('%d ', i);
                end
            end
            f = @(t) 0*t;
            lastZeroIndex = obj.AWG.AddWaveformByFunction(f, minWaveformTime, 0, 1);
            fprintf('%d\n', N+1);
            obj.AWG.LoadWaveform();
            
            % creating sequences:
            for i = 1:N
                for chan = 1:obj.nChannels
                    obj.indexSeq(chan,i) = obj.AWG.AddSequence([WaveformsIndex(chan,i) lastZeroIndex], [1 1], [1 0], N==10);
                end    
            end
           
%             time_waveForm =waveFormData.time;
%             total_WF =waveFormData.total_WF;
% 
%             save('waveformData.mat','time_waveForm','total_WF');

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
            maxLastDelay = Experiment.DEFAULT_LAST_DELAY + max(obj.tau);
            
            k = 0; %added by rotem 18.4.21
            f1 = []; %added by rotem 18.4.21
            
            for t = randperm(length(obj.time))
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
                        pg.changeSequence('delay', 'duration', obj.time(t));
                        obj.AWG.assignSequence(obj.indexSeq(1,1), 1)
                        if obj.nChannels == 2
                            obj.AWG.assignSequence(obj.indexSeq(2,1), 2);
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
