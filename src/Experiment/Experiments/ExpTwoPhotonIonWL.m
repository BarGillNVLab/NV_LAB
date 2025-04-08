classdef ExpTwoPhotonIonWL < Experiment
    % ExpSingletEnergy an experiment desined to find whether there is
    % ionization from the singlet state. This experiment works only with
    % setups that allow two laser powers (2 NIDAQ channels for the AOM for
    % example).
    
    properties (Constant)
        NAME = 'TwoPhotonIonWL';
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
        
        ionDuration                % in us. Ionization of the singlet state.
        waitTimeSinglet            % in us. Delay between initialization and ionization.
        waitTimeIon                % in us. Delay between ionization and detection.
        
        laserPowers                % in ??. A vector of laser powers.
        detectionLaserPower        % in ??. A vector of laser powers.
        laserSource
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpTwoPhotonIonWL(FG, MWChannel)
            obj@Experiment(ExpTwoPhotonIonWL.NAME);
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
            obj.laserSource = 'White Laser'; %1 - White Laser, 2 - IR Laser, 3 - Green Laser?
            obj.detectionLaserPower = 0.2; %0.01; % in whatever units the setup works with
            
            obj.constantTime = 0;
            obj.doubleMeasurement = true;   % logical
            
            obj.detectionDuration = 0.25; % detection window, in us
            obj.referenceDetectionDuration = 5; % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 300; %20; % laser initialization in pulsed experiments
            
            obj.ionDuration = 0.5; %1;
            obj.waitTimeSinglet = 5; %0.5;
            obj.waitTimeIon = 5;
            
            
            %             obj.displayType1 =  'Counts';
            %             obj.displayType2 =  'Contrast';
            %             obj.isPlotAlternateAvailable = true;
            
            laser = getObjByName('Green Laser');
            [~, laserParts] = laser.getContollableParts();
            % Now assumes laser changing the first laser part:
            laserPart = laserParts{1};
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Laser Power', [], [], laserPart.units, obj.NAME);
%             obj.mCurrentYAxisParam = ExpParamDoubleVector('Wait Time', [], [], StringHelper.MICROSEC, obj.NAME);
            %             obj.mCurrentYAxisParam = ExpParamDoubleVector('Ionization Duration', [], [], StringHelper.MICROSEC, obj.NAME);
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
        
        function set.ionDuration(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.ionDuration = newVal;
            obj.changeFlag = true;
        end
        
        
        function set.waitTimeSinglet(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            %             d = [length(obj.laserPowers),length(obj.waitTimesIon),length(newVal)];
            %             if length(find(~(d == 1)))<2
            obj.waitTimeSinglet = newVal;
            obj.changeFlag = true;
            %             else
            %                 fprintf('too many vector parameters', trial);
            %             end
        end
        
        function set.waitTimeIon(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.waitTimeIon = newVal;
            obj.changeFlag = true;
        end
        
        function set.laserPowers(obj ,newVal)
            checkGreenLaserPower(obj, newVal)
            % If we got here, then newVal is OK.
            obj.laserPowers = newVal;
            obj.changeFlag = true;
        end
        
        function set.detectionLaserPower(obj ,newVal) %check if this works well
            checkGreenLaserPower(obj, newVal)
            % If we got here, then newVal is OK.
            obj.detectionLaserPower = newVal;
            obj.changeFlag = true;
        end
        
        function set.laserSource(obj,newVal)
            switch newVal
                case 'White Laser'
                    obj.laserSource = 'White Laser';
                    obj.changeFlag = true;
                case 'IR Laser'
                    obj.laserSource = 'IR Laser';
                    obj.changeFlag = true;
                otherwise
                    obj.sendError('Unknown mode! Ignoring.')
            end
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
                
                S.addEvent(obj.waitTimeSinglet,          '')                                 % Delay for excited and singlet states decay
%                 if k==1
%                     S.addEvent(obj.ionDuration,          {'whiteLaser','detector'}, 'ionDuration')                  % Ionization from Singlet state
%                 else
%                     %                   S.addEvent(obj.IonDuration,          'greenLaser','greenLaserOneOrTwo')                  % Ionization from Singlet state
%                     S.addEvent(obj.ionDuration,          {'greenLaser', 'detector'}, 'ionDuration')                  % Ionization from Singlet state
%                     %                     S.addEvent(obj.ionDuration,          'greenLaser')                  % Ionization from Singlet state
%                 end
                
                if k==1
                    switch obj.laserSource
                        case 'White Laser'
                    S.addEvent(obj.ionDuration,          {'whiteLaser'}, 'ionDuration')                  % Ionization from Singlet state
                        case 'IR Laser'
                    S.addEvent(obj.ionDuration,          {'IR'}, 'ionDuration')                  % Ionization from Singlet state        
                    end
                    
                else
                    %                   S.addEvent(obj.IonDuration,          'greenLaser','greenLaserOneOrTwo')                  % Ionization from Singlet state
                    S.addEvent(obj.ionDuration,          '', 'ionDuration')                  % Ionization from Singlet state
                    %                     S.addEvent(obj.ionDuration,          'greenLaser')                  % Ionization from Singlet state
                end
                S.addEvent(obj.waitTimeIon,      '',    'waitTimeIon')                                 % Delay for excited state decay
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
%             obj.mCurrentYAxisParam.value = obj.waitTimesIon;
            %             obj.mCurrentYAxisParam.value = obj.ionDurations;
            
            
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
            laserPart = laserParts{1};
            laserPart.aomOne.value = obj.detectionLaserPower; % change value of AOM1
            
            laser = getObjByName(obj.laserSource);
            [~, laserParts] = laser.getContollableParts();
            % Now assumes laser changing the first laser part:
            if ~isempty(laserParts)
                laserPartIon = laserParts{1};
            else
                if obj.currIter == 1
                    fprintf('Power will not change. \n');
                end
            end
            %             laserPart.aomOne.value = obj.detectionLaserPower; % change value of AOM1
            
            
            % Some magic numbers
            %             maxLastDelay = Experiment.DEFAULT_LAST_DELAY + max(obj.tau);
            
            
            for p = randperm(length(obj.laserPowers))
                if obj.checkEmergencyStop()
                    return;
                end
                if ~isempty(laserParts)
                    laserPartIon.value = obj.laserPowers(p);
                end
                %                 laserPart.aomTwo.value = obj.laserPowers(t); %change value of AOM2
                
                %                 for d = randperm(length(obj.ionDurations))
%                 for t = randperm(length(obj.waitTimesIon))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, p, obj.currIter)) ~= 0
                    continue
                end
%                 if obj.currIter <= size(obj.signal, 3) && ...
%                             sum(obj.signal(:, (p-1)*length(obj.waitTimesIon)+t, obj.currIter)) ~= 0
%                         continue
%                     end
                success = false;
                
                % The wait time is changed here simply to comply
                    % with the "ProcessData" function. It is not really
                    % significant... However, it changes the changeFlag,
                    % therefore, we change it back.
%                     waitTimeIon = obj.waitTimesIon(t);
                    obj.changeFlag = false;
                
                
                
                for trial = 1 : 10
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        %                         pg.changeSequence('MW', 'duration', obj.tau(t));
                        %                         if obj.constantTime
                        %                             pg.changeSequence('lastDelay', 'duration', maxLastDelay - obj.tau(t));
                        %                         end
                        
                        %                         pg.changeSequence('detection', 'duration', obj.detectionDuration);
                        %                         pg.changeSequence('initDuration', 'duration', initDuration);
%                         pg.changeSequence('waitTimeIon', 'duration', waitTimeIon);
                        
%                         data = obj.getRawData(pg, spcm);
%                             [sig, sterr] = obj.processData(data);
%                             
%                             obj.signal(:, (p-1)*length(obj.waitTimesIon)+t, obj.currIter) = sig;
%                             obj.sterr(:, (p-1)*length(obj.waitTimesIon)+t, obj.currIter) = sterr;
                            
                        data = obj.getRawData(pg, spcm);
                        [sig, sterr] = obj.processData(data);
                        
                        
                        obj.signal(:, p, obj.currIter) = sig;
                        obj.sterr(:, p, obj.currIter) = sterr;
                        
                        success = true;
                        obj.currParamIter = obj.currParamIter + 1;
                        
                        if obj.currParamIter == 1 || mod(obj.currParamIter, 5) == 0 || obj.currParamIter == obj.totalNumberOfParams
                            if obj.currParamIter > obj.totalNumberOfParams
                                '';
                            end
                            sendEventParamIterationDone(obj);
                        end
                        
                        if obj.isTracking && obj.laserPowers(p) == max(obj.laserPowers)
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
%             value = reshape(valueVector, length(obj.waitTimesIon), length(obj.laserPowers));
%             sterr = reshape(sterrVector, length(obj.waitTimesIon), length(obj.laserPowers));
            
            obj.signalParam.value = value;
            obj.signalParam.sterr = sterr;
            
            if obj.doubleMeasurement
                S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
                S3sterr = squeeze(obj.sterr(3, :, 1:obj.currIter));
                S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
                S4sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));
                
                [value, sterr] = getRatioDistributionValues(obj, S3, S4, S3sterr, S4sterr);
%                 value = reshape(valueVector, length(obj.waitTimesIon), length(obj.laserPowers));
%                 sterr = reshape(sterrVector, length(obj.waitTimesIon), length(obj.laserPowers));
                obj.signalParam2.value = value;
                obj.signalParam2.sterr = sterr;
%                 obj.signalParam2.value = [];
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