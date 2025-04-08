classdef ExpSingletEnergyOld < Experiment
    % EXPRABI Rabi Experiment
    
    properties (Constant)
        NAME = 'SingletEnergyOld';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency                  % in MHz
        amplitude                  % in dBm
        piTime                     % in us
        
        constantTime               % logical
        doubleMeasurement          % logical
        
        PopDuration                % in us. Populating the singlet state. 
        IonDuration                % in us. Ionization of the singlet state.
        waitTimeExcited            % in us. Delay between population and detection.
        waitTimeSinglet            % in us. Delay between population and detection.
        
        laserPowers                % in ??. A vector of laser powers.
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpSingletEnergyOld(FG, MWChannel)
            obj@Experiment(ExpSingletEnergyOld.NAME);
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
            
            obj.repeats = 10000;
            obj.averages = 1000;
            
            obj.frequency = 3029; %in MHz
            obj.amplitude = -10; % in dBm
            obj.laserPowers = [0,0.1]; % in whatever units the setup works with
            
            obj.constantTime = 0;
            obj.doubleMeasurement = true;   % logical
            
            obj.detectionDuration = 0.25; % detection window, in us
            obj.referenceDetectionDuration = 5; % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10; % laser initialization in pulsed experiments
            
            obj.PopDuration = 1;
            obj.IonDuration = 1;
            obj.waitTimeExcited = 0.03;
            obj.waitTimeSinglet = 5; %0.5;
            
            
%             obj.displayType1 =  'Counts';
%             obj.displayType2 =  'Contrast';
%             obj.isPlotAlternateAvailable = true;
            
            laser = getObjByName('Green Laser');
            [~, laserParts] = laser.getContollableParts();
            % Now assumes laser changing the first laser part:
            laserPart = laserParts{1};
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Laser Power', [], [], laserPart.units, obj.NAME);
%             obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, 'Ion');
            obj.signalParam2 = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, 'noIon');
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
            obj.amplitude = newVal;
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
        
        function set.piTime(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.piTime = newVal;
            obj.changeFlag = true;
        end
        
        function set.PopDuration(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.PopDuration = newVal;
            obj.changeFlag = true;
        end
        
        function set.IonDuration(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.IonDuration = newVal;
            obj.changeFlag = true;
        end
        
        function set.waitTimeExcited(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.waitTimeExcited = newVal;
            obj.changeFlag = true;
        end
        
        function set.waitTimeSinglet(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.waitTimeSinglet = newVal;
            obj.changeFlag = true;
        end
        
        function set.laserPowers(obj ,newVal)
            checkGreenLaserPower(obj, newVal)
            % If we got here, then newVal is OK.
            obj.laserPowers = newVal;
            obj.changeFlag = true;
        end
    end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.laserPowers);
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
            checkDetectionDuration(obj, obj.detectionDuration); % The mode might have changed; before running, we check
                                                                % obj.detectionDuration again.

            lastDelay = Experiment.DEFAULT_LAST_DELAY;
            
            %%% Creating the sequence
            S = Sequence;
            for k = 1:1+obj.doubleMeasurement
                S.addEvent(obj.piTime,        MWChannel,  {'piPulse'})               % MW - greenLaserOneOrTwo is also turned on in order to avoide delay problems during the pop and ion pulses
                %             S.addEvent(lastDelay,           '',                         'lastDelay');       % Last delay
                S.addEvent(obj.PopDuration,              {'greenLaser','greenLaserOneOrTwo'})                       % Populating the singlet
                S.addEvent(obj.waitTimeExcited,          'greenLaserOneOrTwo')                                 % Delay for excited state decay
                if k==1
                    S.addEvent(obj.IonDuration,          {'greenLaser','greenLaserOneOrTwo'})                  % Ionization from Singlet state 
                else
                    
                    S.addEvent(obj.IonDuration,          'greenLaserOneOrTwo')                  % Ionization from Singlet state
%                     S.addEvent(obj.waitTimeExcited,          '')
%                     S.addEvent(obj.IonDuration,          'greenLaser')                  % Ionization from Singlet state
                end
                S.addEvent(obj.waitTimeSinglet,          '')                                 % Delay for excited state decay
                S.addEvent(obj.detectionDuration,...
                    {'greenLaser', 'detector'});                                            % Detection
                S.addEvent(initDuration,        {'greenLaser'});                              % Initialization
                S.addEvent(obj.referenceDetectionDuration,...
                    {'greenLaser', 'detector'});
                S.addEvent(lastDelay,           '',                         'lastDelay');       % Last delay
            end
            
            obj.prepareInternal(S)

            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.laserPowers;
            
            obj.isPlotAlternateAvailable = obj.doubleMeasurement;
        end
        
        function perform(obj)
            %%% Initialization
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
                if isempty(tracker); throwBaseObjException(Tracker.Name); end

            laser = getObjByName('Green Laser');
            [~, laserParts] = laser.getContollableParts();
            % Now assumes laser changing the first laser part:
            laserPart = laserParts{1}; %% 2 for AOM2??
            
            % Some magic numbers
%             maxLastDelay = Experiment.DEFAULT_LAST_DELAY + max(obj.tau);
            
            for t = randperm(length(obj.laserPowers))
                if obj.checkEmergencyStop()
                    return;
                end
                laserPart.value = obj.laserPowers(t);
                
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
%                         pg.changeSequence('MW', 'duration', obj.tau(t));
%                         if obj.constantTime
%                             pg.changeSequence('lastDelay', 'duration', maxLastDelay - obj.tau(t));
%                         end
                        
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
                        
                        if obj.isTracking && obj.laserPowers(t) == max(obj.laserPowers)
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
            % In the future, it will also analyze results.
            
            obj.wrapUpInternal()
        end
        
        
        function dataParam = alternateSignal(obj)
            % Returns alternate view ("referenced") of the data, as an
            % ExpParam.
            
            Ion = obj.signalParam.value;
            noIon = obj.signalParam2.value;

            value = Ion - noIon;
            sterr = sqrt(obj.signalParam.sterr.^2 + obj.signalParam2.sterr.^2);
            dataParam = ExpResultDoubleVector('FL', value, sterr, 'Normalized', obj.NAME);
        end
    end
end