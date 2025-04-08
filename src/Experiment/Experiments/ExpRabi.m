classdef ExpRabi < Experiment
    % EXPRABI Rabi Experiment
    
    properties (Constant)
        NAME = 'Rabi';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency       % in MHz
        amplitude       % in dBm
        tau             % in us
        nChannels
        constantTime    % logical
        tau_permutations
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpRabi(FG, MWChannel)
            obj@Experiment(ExpRabi.NAME);
            obj.parameterName = 'taus';
            
%            First, get a frequency generator
            if exist('MWChannel', 'var')
                obj.MWChannel = MWChannel;
            end
            if exist('FG', 'var')
                obj.givenFG = FG;
            else
                FG = [];
            end
            obj.freqGenName = obj.getFgName(FG);

%             %%% To use MW2 comment the aboove block and unomment the block
%             %%% below. make sure to pass the amplitude and frequency as a
%             %%% 2d vector, e.g. frequency=[2870,2870], amplitude=[-10,-10]
            if ~exist('FGs', 'var')
                fgCell = FrequencyGenerator.getFG();
                if fgCell{1}.numChannels == 2 || length(fgCell) == 1
                    obj.freqGenName = fgCell{1}.name;
                else
                    obj.freqGenName = cellfun(@(fg)fg.name, fgCell(1:end), 'UniformOutput' ,0);
                end
            else
                obj.freqGenName = obj.getFgName(FGs);
            end
            
            obj.repeats = 10000;
            obj.averages = 1000;
            obj.nChannels=1;
            obj.frequency = 3029; %in MHz
            obj.amplitude = -10; % in dBm
            obj.tau = 0.005:0.005:0.25; % in us
            obj.tau_permutations = zeros(obj.averages, length(obj.tau));
            obj.constantTime = true;
            
            obj.detectionDuration = 0.25; % detection window, in us
            obj.referenceDetectionDuration = 5; % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10; % laser initialization in pulsed experiments
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
        end
    end
    
    %% Setters
    methods
        function set.frequency(obj, newVal) % newVal is in MHz
            checkFrequencyVector(obj, newVal)
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
        
        function set.tau(obj, newVal) % newVal is in us
            checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.tau = newVal;
            obj.changeFlag = true;
        end
        
        function set.constantTime(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.constantTime = newVal;
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
            initDuration = obj.laserInitializationDuration - obj.detectionDuration;
            obj.detectionPeriodsPerRepeat = 2;
            obj.runsPerPerform = 1;
            checkDetectionDuration(obj, obj.detectionDuration); % The mode might have changed; before running, we check obj.detectionDuration again.
            lastDelay = Experiment.DEFAULT_LAST_DELAY;
            
            MW = obj.MWChannel;
            %tau=obj.tau(end);
            %%% Creating the sequence
            S = Sequence;
            S.addEvent(obj.smallDelay,        '')
            S.addEvent(max(obj.tau),        MW,                         'MW')               % MW
            S.addEvent(obj.smallDelay,        '')
            %S.addEvent(tau,           '',                         'lastDelay2');       % Last delay

            S.addEvent(Experiment.DEFAULT_LAST_DELAY,           '',                         'lastDelay');       % Last delay
            
            S.addEvent(obj.detectionDuration,...
                                            {'greenLaser', 'detector'});                    % Detection
            S.addEvent(initDuration,        'greenLaser');                                  % Initialization
            S.addEvent(obj.referenceDetectionDuration,...
                                            {'greenLaser', 'detector'});                    % Reference detection
            S.addEvent(1,                   'greenLaser');                                  % 1usec delay to ensure full overlap of ref detection and laser, and to init first repaet (less important), Yachel 27.02.22

            obj.prepareInternal(S)


            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.tau;
        end
        
        function perform(obj)
            %%% Initialization
            
            if obj.currIter == 1
                obj.tau_permutations = zeros(obj.averages, length(obj.tau));
            end
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
                if isempty(tracker); throwBaseObjException(Tracker.Name); end
            
            % Some magic numbers
            maxLastDelay = Experiment.DEFAULT_LAST_DELAY + max(obj.tau);
            
            k = 0; %added by rotem 18.4.21
            f1 = []; %added by rotem 18.4.21
            tau_perm = randperm(length(obj.tau));
            obj.tau_permutations(obj.currIter,:) = tau_perm;
            for t = tau_perm
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue % Wat?
                end
                success = false;
                f1 = [f1, t]; %added by rotem 18.4.21
                k = k + 1; %added by rotem 18.4.21
                
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
                        
                        % added by rotem 18.4.21 %
                        if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                            [sig(1:2), sterr(1:2)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(k-1)+1:end));%obj.detectionPeriodsPerRepeat*obj.repeats*k));
                        else
                            [sig(1:2), sterr(1:2)] = obj.processData(data);
                        end
                        
%                         if obj.currIter > 2 && t == tau_perm(15)
%                             sig(1) = sig(2)*3;
%                         end

                        if sig(1)/sig(2) > 2
                            disp(sig)
                            ME = MException('SPCMRead:badSignal', ...
                                'Weird value for the measured signal.');
                            throw(ME);
                        end
                        
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
                             if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                                 obj.restartAverageFlag = 1;
                                 spcm.stopExperimentCount(obj.restartAverageFlag);
                                 break;
                             else
                                 spcm.stopExperimentCount;
                             end
                        catch
                            % But maybe we don't, and that's perfectly ok.
                        end
                    end
                end
                if obj.restartAverageFlag
                    break;
                end
                if ~success
                    obj.emergencyStop;
                    return
                end
            end
            % added by rotem 18.4.21 %
            if length(data) == obj.detectionPeriodsPerRepeat*obj.repeats*obj.getTotalNumberOfParams %if true we're proccessing data at the end of the average
                for k = 1:length(obj.tau)
                    [obj.signal(:, f1(k), obj.currIter), obj.sterr(:, f1(k), obj.currIter)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(k-1)+1:obj.detectionPeriodsPerRepeat*obj.repeats*k));
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