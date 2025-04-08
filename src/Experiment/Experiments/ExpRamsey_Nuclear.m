classdef ExpRamsey_Nuclear < Experiment
    %ExpRamsey Ramsey experiment

    properties (Constant)
        NAME = 'Ramsey_Nuclear';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency          % in MHz
        amplitude          % in dBm
          tau_0               % in us
        tau                 % in us
        halfPiTime          % in us
         piTime              % in us              % in us
        threeHalvesPiTime   % in us

        constantTime        % logical
        doubleMeasurement   % logical
        useIQ               % logical
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpRamsey_Nuclear(FG, MWChannel)
            obj@Experiment(ExpRamsey_Nuclear.NAME);
            obj.parameterName = 'taus';
            
            % First, get a frequency generator
            if exist('MWChannel', 'var')
                obj.MWChannel = MWChannel;
            end
            if exist('FG', 'var')
                obj.givenFG = FG;
            else
                FG = [];
            end
            obj.freqGenName = obj.getFgName(FG);
            
            % Set properties inherited from Experiment
            obj.repeats = 5000;
            obj.averages = 1000;
            obj.tau_0 = 0.02;               % in us
            obj.frequency= [3029, 3029];           % in MHz
            obj.amplitude = [-10,-10];            % in dBm
            obj.tau = 0.05:0.05:1;          % in us
            obj.halfPiTime = [0.025,0.025];         % in us
            obj.threeHalvesPiTime = [0.075,0.075];  % in us
            obj.piTime = [0.05,0.05];              % in us
            obj.constantTime = false;       % logical
            obj.doubleMeasurement = true;   % logical
            obj.useIQ = true;               % logical
            
            obj.detectionDuration = 0.25;           % detection window, in us
            obj.referenceDetectionDuration = 5;     % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;   % laser initialization in pulsed experiments in us
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|1>');
            obj.signalParam2 = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|0>');
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
            checkAmplitudeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.amplitude = newVal;
            obj.changeFlag = true;
        end
        
        function set.tau(obj, newVal)	% newVal in microsec
            checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.tau = newVal;
            obj.changeFlag = true;
        end
       function set.tau_0(obj, newVal)	% newVal in microsec
            checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.tau_0 = newVal;
            obj.changeFlag = true;
        end
       function set.piTime(obj, newVal)
             checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.piTime = newVal;
            obj.changeFlag = true;
        end
        
        function set.constantTime(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.constantTime = newVal;
            obj.changeFlag = true;
        end
        
        function set.doubleMeasurement(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.doubleMeasurement = newVal;
            obj.changeFlag = true;
        end
        
        function set.useIQ (obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.useIQ = newVal;
            obj.changeFlag = true;
        end
        
        function set.halfPiTime(obj, newVal)
             checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.halfPiTime = newVal;
            obj.changeFlag = true;
        end
        
        function set.threeHalvesPiTime(obj, newVal)
            checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.threeHalvesPiTime    = newVal;
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
            obj.detectionPeriodsPerRepeat = 2 * (1 + double(obj.doubleMeasurement));
            obj.runsPerPerform = 1;
            MWChannel = obj.MWChannel;
            
            lastDelay = Experiment.DEFAULT_LAST_DELAY;
            lastDelay = 0;
            %%% Creating the sequence
            S = Sequence;
            for k = 1:1+obj.doubleMeasurement
                S.addEvent(obj.piTime(1),                  'MW');                         % MW in x
                S.addEvent(obj.tau_0, '', 'tau_0');                         % Delay
                S.addEvent(obj.halfPiTime(2),                  'MW2');                      
                S.addEvent(obj.tau(end),                    '',                         'tau'); % Delay
                
                if k == 1  % Half Pi Pulse (For Readout)          
                    S.addEvent(obj.halfPiTime(2),              'MW2');                         % MW in x
                    S.addEvent(obj.tau_0, '', 'tau_0');                         % Delay
                    S.addEvent(obj.piTime(1),                  'MW');                         % MW in x
                else % Half Pi for double measurement (For Readout)
                    if obj.useIQ % With IQ
                        S.addEvent(obj.halfPiTime(2),          {'I', 'Q', 'MW2'});             % MW in -x
                    else  % Half Pi Pulse Without IQ
                        S.addEvent(obj.threeHalvesPiTime(2),   'MW2');                         % MW in -x
                    end
                end
                S.addEvent(lastDelay,                       '',                   'lastDelay'); % Last delay
                S.addEvent(obj.detectionDuration,...
                                                            {'greenLaser', 'detector'});        % Detection
                S.addEvent(initDuration,                    'greenLaser');                      % Initialization
                S.addEvent(obj.referenceDetectionDuration,...
                                                            {'greenLaser', 'detector'});        % Reference detection
            end
            
            obj.prepareInternal(S)
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.tau;
            
            obj.isPlotAlternateAvailable = obj.doubleMeasurement;
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
            
            %%% Run - Go over all tau's, in random order
            k = 0; %added by rotem 18.4.21
            f1 = []; %added by rotem 18.4.21
            for t = randperm(length(obj.tau))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue
                end
                f1 = [f1, t]; %added by rotem 21.11.21
                k = k + 1; %added by rotem 21.11.21
                success = false;
                
                for trial = 1 : 5
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        pg.changeSequence('tau', 'duration', obj.tau(t));
                        if obj.constantTime
                            pg.changeSequence('lastDelay', 'duration', maxLastDelay - obj.tau(t));
                        end
                        
                        data = obj.getRawData(pg, spcm);
                        
                        % added by rotem 21.11.21 %
                        if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                            [sig, sterr] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(k-1)+1:end));%obj.detectionPeriodsPerRepeat*obj.repeats*k));
                        else
                            [sig, sterr] = obj.processData(data);
                        end
                        
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
            
            % added by rotem 21.11.21 %
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