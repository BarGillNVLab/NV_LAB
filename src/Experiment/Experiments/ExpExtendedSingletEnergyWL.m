classdef ExpExtendedSingletEnergyWL < Experiment
    % ExpSingletEnergy an experiment desined to find whether there is
    % ionization from the singlet state. This experiment works only with
    % setups that allow two laser powers (2 NIDAQ channels for the AOM for
    % example).
    
    properties (Constant)
        NAME = 'ExtendedSingletEnergyWL';
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
        referenceSpin
        endPi
        
        PopDuration                % in us. Populating the singlet state. 
        IonDuration                % in us. Ionization of the singlet state.
        waitTimeExcited            % in us. Delay between population and detection.
        waitTimeSinglet            % in us. Delay between population and detection.
        
        laserPowers                % in ??. A vector of laser powers.
        laserSource
        detectionLaserPower        % in ??. A vector of laser powers.
        populationLaserPower        % in ??. A vector of laser powers.
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpExtendedSingletEnergyWL(FG, MWChannel)
            obj@Experiment(ExpExtendedSingletEnergyWL.NAME);
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
            obj.detectionLaserPower = 0.2; % in whatever units the setup works with
            obj.populationLaserPower = 0.3;
            
            obj.constantTime = 0;
            obj.doubleMeasurement = true;   % logical
            obj.referenceSpin = true;
            obj.endPi = false;
            
            obj.detectionDuration = 0.4; %0.25; % detection window, in us
            obj.referenceDetectionDuration = 5; % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 300; %20; % laser initialization in pulsed experiments
            
            obj.PopDuration = 0.4; %1;
            obj.IonDuration = 0.5; %1;
            obj.waitTimeExcited = 0.15; %0.03;
            obj.waitTimeSinglet = 10; %0.5;
            
            
%             obj.displayType1 =  'Counts';
%             obj.displayType2 =  'Contrast';
%             obj.isPlotAlternateAvailable = true;
            
            laser = getObjByName('Green Laser');
            [~, laserParts] = laser.getContollableParts();
            % Now assumes laser changing the first laser part:
            laserPart = laserParts{1};
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Laser Power', [], [], laserPart.units, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
            obj.signalParam2 = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
%             obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, 'Ion');
%             obj.signalParam2 = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, 'noIon');
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
        
        function set.referenceSpin(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.referenceSpin = newVal;
            obj.changeFlag = true;
        end
        
        function set.endPi(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.endPi = newVal;
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
        
        function set.detectionLaserPower(obj ,newVal) %check if this works well
            checkGreenLaserPower(obj, newVal)
            % If we got here, then newVal is OK.
            obj.detectionLaserPower = newVal;
            obj.changeFlag = true;
        end
        
        function set.populationLaserPower(obj ,newVal) %check if this works well
            checkGreenLaserPower(obj, newVal)
            % If we got here, then newVal is OK.
            obj.populationLaserPower = newVal;
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
            obj.detectionPeriodsPerRepeat = 2 * (1 + double(obj.doubleMeasurement))*(1 + double(obj.referenceSpin));
            obj.runsPerPerform = 1;
            MWChannel = obj.MWChannel;
            checkDetectionDuration(obj, obj.detectionDuration); % The mode might have changed; before running, we check
                                                                % obj.detectionDuration again.

            lastDelay = Experiment.DEFAULT_LAST_DELAY;
            
            %%% Creating the sequence
            S = Sequence;
            for k = 1:(1+obj.doubleMeasurement)
                for j = 1:(1+obj.referenceSpin)
                    if j==1
                        S.addEvent(obj.piTime,        MWChannel,  {'piPulse'})               % MW - greenLaserOneOrTwo is also turned on in order to avoide delay problems during the pop and ion pulses
                    else
                        S.addEvent(obj.piTime,        '',  {'piPulse'})
                    end
                    %             S.addEvent(lastDelay,           '',                         'lastDelay');       % Last delay
                    %                 S.addEvent(obj.PopDuration,              {'greenLaser','greenLaserOneOrTwo'})                       % Populating the singlet
                    S.addEvent(obj.PopDuration,              {'greenLaser','greenLaserOneOrTwo'} ,'populationDuration')                       % Populating the singlet
                    S.addEvent(obj.waitTimeExcited,          '')                                 % Delay for excited state decay
                    if k==1
                        switch obj.laserSource
                            case 'White Laser'
                                S.addEvent(obj.IonDuration,          {'whiteLaser'} )                  % Ionization from Singlet state
                            case 'IR Laser'
                                S.addEvent(obj.IonDuration,          {'IR'})                  % Ionization from Singlet state
                            case 'Green Laser'
                                S.addEvent(obj.IonDuration,          {'greenLaser'}, 'ionDuration')                  % Ionization from Singlet state
                        end
                    else
                        %                   S.addEvent(obj.IonDuration,          'greenLaser','greenLaserOneOrTwo')                  % Ionization from Singlet state
                        S.addEvent(obj.IonDuration,          '')                  % Ionization from Singlet state
                        %                     S.addEvent(obj.waitTimeExcited,          '')
                        %                     S.addEvent(obj.IonDuration,          'greenLaser')                  % Ionization from Singlet state
                    end
                    S.addEvent(obj.waitTimeSinglet,          '')                                 % Delay for excited state decay
                    if obj.endPi
                        S.addEvent(obj.piTime,        MWChannel,  {'piPulse'})
                    end
                    S.addEvent(obj.detectionDuration,...
                        {'greenLaser', 'detector'});                                            % Detection
                    S.addEvent(initDuration,        {'greenLaser'});                              % Initialization
                    S.addEvent(obj.referenceDetectionDuration,...
                        {'greenLaser', 'detector'});
                    %                 S.addEvent(obj.detectionDuration,...
                    %                     {'detector'});                                            % Detection
                    %                 S.addEvent(initDuration,        '');                              % Initialization
                    %                 S.addEvent(obj.referenceDetectionDuration,...
                    %                     {'detector'});
                    %                 S.addEvent(lastDelay,           '',                         'lastDelay');       % Last delay
                    S.addEvent(0.5,           '');
                end
            end
            
            obj.prepareInternal(S)

            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.laserPowers;
            
%             isPi = ['\pi','no \pi','\pi','no \pi'];
%             isIon = ['Ion','Ion','no Ion','no Ion'];
%             pairName = sprintf('%s , %s', isPi , readFrom);
%             obj.signalParam.desc = pairName;
            
            obj.isPlotAlternateAvailable = ((double(obj.doubleMeasurement)+double(obj.referenceSpin))>1);
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
            laserPart.aomTwo.value = obj.populationLaserPower; % change value of AOM2 
            
            laser = getObjByName(obj.laserSource);
            [~, laserParts] = laser.getContollableParts();
            % Now assumes laser changing the first laser part:
            laserPartIon = laserParts{1};

            
            % Some magic numbers
%             maxLastDelay = Experiment.DEFAULT_LAST_DELAY + max(obj.tau);
            
            for t = randperm(length(obj.laserPowers))
                if obj.checkEmergencyStop()
                    return;
                end
                laserPartIon.value = obj.laserPowers(t); 
%                 laserPart.aomTwo.value = obj.laserPowers(t); %change value of AOM2


                
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

%                         pg.changeSequence('detection', 'duration', obj.detectionDuration);
%                         pg.changeSequence('initDuration', 'duration', initDuration);
                            
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
            
%             isPi = ['\pi','no \pi','\pi','no \pi'];
%             isIon = ['Ion','Ion','no Ion','no Ion'];
%             pairName = sprintf('%s , %s', isPi , readFrom);
%             obj.signalParam.desc = pairName;
            
            % Saving results in the Experiment parameters
            S1 = squeeze(obj.signal(1, :, 1:obj.currIter));
            S1sterr = squeeze(obj.sterr(1, :, 1:obj.currIter));
            S2 = squeeze(obj.signal(2, :, 1:obj.currIter));
            S2sterr = squeeze(obj.sterr(2, :, 1:obj.currIter));
            
            [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);
            obj.signalParam.value = value;
            obj.signalParam.sterr = sterr;  
            obj.signalParam.desc = 'With \pi with Ion';
            
            if obj.referenceSpin
                S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
                S3sterr = squeeze(obj.sterr(3, :, 1:obj.currIter));
                S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
                S4sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));
                [value, sterr] = getRatioDistributionValues(obj, S3, S4, S3sterr, S4sterr);
                obj.signalParam2.value = value;
                obj.signalParam2.sterr = sterr;
                obj.signalParam2.desc = 'Without \pi with Ion';
                if obj.doubleMeasurement
                    S5 = squeeze(obj.signal(5, :, 1:obj.currIter));
                    S5sterr = squeeze(obj.sterr(5, :, 1:obj.currIter));
                    S6 = squeeze(obj.signal(6, :, 1:obj.currIter));
                    S6sterr = squeeze(obj.sterr(6, :, 1:obj.currIter));
                    [value, sterr] = getRatioDistributionValues(obj, S5, S6, S5sterr, S6sterr);
                    [value, sterr] = getRatioDistributionValues(obj, obj.signalParam.value, value, obj.signalParam.sterr, sterr);
                    obj.signalParam.value = value;
                    obj.signalParam.sterr = sterr;
                    obj.signalParam.desc = 'With \pi Normalized';
            
                    S7 = squeeze(obj.signal(7, :, 1:obj.currIter));
                    S7sterr = squeeze(obj.sterr(7, :, 1:obj.currIter));
                    S8 = squeeze(obj.signal(8, :, 1:obj.currIter));
                    S8sterr = squeeze(obj.sterr(8, :, 1:obj.currIter));
                    [value, sterr] = getRatioDistributionValues(obj, S7, S8, S7sterr, S8sterr);
                    [value, sterr] = getRatioDistributionValues(obj, obj.signalParam2.value, value, obj.signalParam2.sterr, sterr);
                    obj.signalParam2.value = value;
                    obj.signalParam2.sterr = sterr;
                    obj.signalParam2.desc = 'Without \pi Normalized';
                end
            else    
                if obj.doubleMeasurement
                    S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
                    S3sterr = squeeze(obj.sterr(3, :, 1:obj.currIter));
                    S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
                    S4sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));
                    
                    [value, sterr] = getRatioDistributionValues(obj, S3, S4, S3sterr, S4sterr);
                    obj.signalParam2.value = value;
                    obj.signalParam2.sterr = sterr;
                    obj.signalParam2.desc = 'With \pi without Ion';
                    %             else
                    %                 obj.signalParam2.value = [];
                end
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
            
            isPi = {'\pi','no \pi','\pi','no \pi'};
            isIon = {'Ion','Ion','no Ion','no Ion'};
            
            if obj.currIter == 0
                dataParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
                return
            end
            
            dataParam2Plus = cell(1, (1+double(obj.doubleMeasurement))*(1+double(obj.referenceSpin)));
            for i = 1:(1+double(obj.doubleMeasurement))*(1+double(obj.referenceSpin))
                S1 = squeeze(obj.signal(2*i-1, :, 1:obj.currIter));
                S1sterr = squeeze(obj.sterr(2*i-1, :, 1:obj.currIter));
                S2 = squeeze(obj.signal(2*i, :, 1:obj.currIter));
                S2sterr = squeeze(obj.sterr(2*i, :, 1:obj.currIter));
            
                [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);
%                 startReadPair = obj.startReadPairs{i};
                pairName = sprintf('%s , %s', isPi{i} , isIon{i});
                dataParam2Plus{i} = ExpResultDoubleVector('FL', value, sterr, 'Normalized', obj.NAME, pairName);
            end
            dataParam = {dataParam2Plus{1}, {dataParam2Plus{2:end}}, {'yParam', 'yParam2+'}};
%             params = {dataParam, dataParam2Plus, {'yParam', 'yParam2+'}};
            
%             S1 = squeeze(obj.signal(1, :, 1:obj.currIter));
%             S1sterr = squeeze(obj.sterr(1, :, 1:obj.currIter));
%             S2 = squeeze(obj.signal(2, :, 1:obj.currIter));
%             S2sterr = squeeze(obj.sterr(2, :, 1:obj.currIter));
%             
%             [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);
%             obj.signalParam.value = value;
%             obj.signalParam.sterr = sterr;  
%             
%             if obj.referenceSpin
%                 S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
%                 S3sterr = squeeze(obj.sterr(3, :, 1:obj.currIter));
%                 S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
%                 S4sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));
%                 [value, sterr] = getRatioDistributionValues(obj, S3, S4, S3sterr, S4sterr);
%                 obj.signalParam2.value = value;
%                 obj.signalParam2.sterr = sterr;
%                 if obj.doubleMeasurement
%                     S5 = squeeze(obj.signal(5, :, 1:obj.currIter));
%                     S5sterr = squeeze(obj.sterr(5, :, 1:obj.currIter));
%                     S6 = squeeze(obj.signal(6, :, 1:obj.currIter));
%                     S6sterr = squeeze(obj.sterr(6, :, 1:obj.currIter));
%                     [value, sterr] = getRatioDistributionValues(obj, S5, S6, S5sterr, S6sterr);
%                     [value, sterr] = getRatioDistributionValues(obj, obj.signalParam.value, value, obj.signalParam.sterr, sterr);
%                     obj.signalParam.value = value;
%                     obj.signalParam.sterr = sterr;
%             
%                     S7 = squeeze(obj.signal(7, :, 1:obj.currIter));
%                     S7sterr = squeeze(obj.sterr(7, :, 1:obj.currIter));
%                     S8 = squeeze(obj.signal(8, :, 1:obj.currIter));
%                     S8sterr = squeeze(obj.sterr(8, :, 1:obj.currIter));
%                     [value, sterr] = getRatioDistributionValues(obj, S7, S8, S7sterr, S8sterr);
%                     [value, sterr] = getRatioDistributionValues(obj, obj.signalParam2.value, value, obj.signalParam2.sterr, sterr);
%                     obj.signalParam2.value = value;
%                     obj.signalParam2.sterr = sterr;
%                 end
%             else    
%                 if obj.doubleMeasurement
%                     S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
%                     S3sterr = squeeze(obj.sterr(3, :, 1:obj.currIter));
%                     S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
%                     S4sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));
%                     
%                     [value, sterr] = getRatioDistributionValues(obj, S3, S4, S3sterr, S4sterr);
%                     obj.signalParam2.value = value;
%                     obj.signalParam2.sterr = sterr;
%                     %             else
%                     %                 obj.signalParam2.value = [];
%                 end
%             end


%             value = Ion - noIon;
%             sterr = sqrt(obj.signalParam.sterr.^2 + obj.signalParam2.sterr.^2);
%             dataParam = ExpResultDoubleVector('FL', value, sterr, 'Normalized', obj.NAME);
        end
    end
end