classdef ExpCalibrateSNRIR < Experiment
    %EXPCALIBRATESNR Experiment for calibration of the detection time & laser power
    
    properties (Constant)
        NAME = 'Calibration_SNRIR';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency           % in MHz
        amplitude           % in dBm. Amplitude for the withMW configuration
        
        delay               % in us. Delay between laser & MW.
        detectionDurations  % in us. A vector of the scanned detection times
        laserPowers         % in ??. A vector of laser powers.
        laserSource
        detectionIRLaserPower % in whatever units the setup works with
        populationLaserPower
        initializationLaserPower
        
        piTime              % in us
          
        waitTime            % in us. Delay between population and detection.
        TrackRefDuration
        
        popDuration                % in us. Populating the singlet state. 
        waitTimeExcited            % in us. Delay between population and detection.
        waitTimeSinglet            % in us. Delay between population and detection.
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpCalibrateSNRIR(FG, MWChannel)
            obj@Experiment(ExpCalibrateSNRIR.NAME);
            
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
            obj.frequency = 3029;                   % in MHz
            obj.amplitude = -10;                    % in dBm. Amplitude for the withMW configuration
            obj.piTime = 0.025;                     % in us
            
            obj.repeats = 5000;
            obj.averages = 100;
            obj.isTracking = false;                  % Initialize tracking
            obj.trackThreshhold = 0.7;
            obj.TrackWithIR = true;                 % Turn on IR laser during Tracking
            obj.TrackRefDuration = 1;               % In us
            obj.shouldAutosave = true;
            
            obj.delay = 0.1;                        % in us (100 ns)
            
            obj.laserPowers = [0,0.1]; % in whatever units the setup works with
            obj.laserSource = 'Green Laser';
            obj.detectionIRLaserPower = 0.8; % in whatever units the setup works with
            obj.populationLaserPower = 0.3;
            obj.initializationLaserPower = 0.2;
            
            obj.detectionDurations = [0.03:0.03:0.3 , 0.4:0.1:1];  % detection windows, in \mus
            obj.waitTimeSinglet = 0.5; %0.03;
            obj.referenceDetectionDuration = 0.5;     % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 200; %10;   % laser initialization in pulsed experiments in us
            
            obj.popDuration = 0.4; %1;
            obj.waitTimeExcited = 0.15; %0.03;
            obj.waitTime = 10; %0.5;
            
            obj.displayType1 =  'SNR';
            obj.displayType2 =  'Contrast';
            obj.isPlotAlternateAvailable = true;
            
            laser = getObjByName('Green Laser');
            [~, laserParts] = laser.getContollableParts();
            % Now assumes laser changing the first laser part:
            laserPart = laserParts{1};
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Laser Power', [], [], laserPart.units, obj.NAME);
            obj.mCurrentYAxisParam = ExpParamDoubleVector('Detection Duration', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('SNR', [], [], '', obj.NAME);
        end
    end
    
    %% Setters & Getters
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
        
        function set.piTime(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.piTime = newVal;
            obj.changeFlag = true;
        end
        
        function set.delay(obj ,newVal)	% newVal in microsec
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.delay = newVal;
            obj.changeFlag = true;
        end
        
        function set.detectionDurations(obj ,newVal)	% newVal in microsec
            checkDetectionDuration(obj, newVal);
            % If we got here, then newVal is OK.
            obj.detectionDurations = newVal;
            obj.changeFlag = true;  % We need to update the PG
        end
        
        function set.TrackRefDuration(obj ,newVal)	% newVal in microsec
            checkDetectionDuration(obj, newVal);
            % If we got here, then newVal is OK.
            obj.TrackRefDuration = newVal;
            obj.changeFlag = true;  % We need to update the PG
        end
        
        function set.popDuration(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.popDuration = newVal;
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
        
        function set.detectionIRLaserPower(obj ,newVal) %check if this works well
            checkGreenLaserPower(obj, newVal)  % should be checkIRLaserPower
            % If we got here, then newVal is OK.
            obj.detectionIRLaserPower = newVal;
            obj.changeFlag = true;
        end
        
        function set.populationLaserPower(obj ,newVal) %check if this works well
            checkGreenLaserPower(obj, newVal)
            % If we got here, then newVal is OK.
            obj.populationLaserPower = newVal;
            obj.changeFlag = true;
        end
        
        function set.initializationLaserPower(obj ,newVal) %check if this works well
            checkGreenLaserPower(obj, newVal)
            % If we got here, then newVal is OK.
            obj.initializationLaserPower = newVal;
            obj.changeFlag = true;
        end
        
        function set.laserSource(obj,newVal)
            switch newVal
%                 case 'White Laser'
%                     obj.laserSource = 'White Laser';
%                     obj.changeFlag = true;
                case 'IR Laser'
                    obj.laserSource = 'IR Laser';
                    obj.changeFlag = true;
                case 'Green Laser'
                    obj.laserSource = 'Green Laser';
                    obj.changeFlag = true;
                otherwise
                    obj.sendError('Unknown mode! Ignoring.')
            end
        end
    end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.detectionDurations) * length(obj.laserPowers);
        end
    end
    
    %% Overridden from Experiment
    methods (Access = protected)
        function prepare(obj)
            % Initializtions before run (also before reset!)
            
            % Sequence
            %%% Useful parameters for what follows
            obj.detectionPeriodsPerRepeat = 4;
            obj.runsPerPerform = 1;
            initDuration = obj.laserInitializationDuration - min(obj.detectionDurations) - obj.referenceDetectionDuration;
            MWChannel = obj.MWChannel;
            lastDelay = Experiment.DEFAULT_LAST_DELAY;
            
            %%% Creating the sequence
            S = Sequence;
            for k = 1:2
                S.addEvent(initDuration,                    'greenLaser')               % Initialization to spin 0
                S.addEvent(obj.waitTimeSinglet,                       '');                        % Singlet delay
                
                if k ==1
                    S.addEvent(obj.piTime,                   MWChannel)
                else
                    S.addEvent(obj.piTime,                   '')
                end
                
                S.addEvent(lastDelay,                       '');                        % Last delay
                S.addEvent(obj.popDuration,          {'greenLaser','greenLaserOneOrTwo'})               % Populating the singlet
                S.addEvent(obj.waitTimeExcited,                         '')                         % Delay for excited state decay
                S.addEvent(max(obj.detectionDurations),           {'IR','detector'}, 'detection')          % Delay for excited state decay
                S.addEvent(0.5,          {'IR'})
                S.addEvent(obj.waitTimeSinglet,                       '');                        % Singlet delay
                S.addEvent(initDuration,                    'greenLaser')               % Initialization to spin 0
                S.addEvent(obj.waitTimeSinglet+obj.piTime+lastDelay,                       '');                        % Singlet delay
                S.addEvent(obj.popDuration,          {'greenLaser','greenLaserOneOrTwo'})               % Populating the singlet
                S.addEvent(obj.waitTimeExcited,                         '')                         % Delay for excited state decay
                S.addEvent(obj.referenceDetectionDuration,           {'IR','detector'}) % Reference detection
                S.addEvent(0.5,          {'IR'})
                S.addEvent(obj.waitTimeSinglet,                       '');                        % Singlet delay
                
                    
                    
%                 if k == 1
%                     S.addEvent(obj.piTime,  MWChannel);                                             % MW
%                     S.addEvent(obj.delay,   ''); % Delay
%                 else
%                     S.addEvent(obj.piTime,   '');
%                 end
%                 S.addEvent(obj.PopulationDuration,          'greenLaser')                           % Populating the singlet
%                 S.addEvent(obj.waitTime,                         '')                                % Delay for excited state decay
%                 S.addEvent(max(obj.detectionDurations),      {'IR','detector'}, 'detection')                   % Delay for excited state decay
% %                 S.addEvent(max(obj.detectionDurations), ...
% %                                             {'greenLaser', 'detector'},     'detection');         % Detection
%                 if k==1
%                     S.addEvent(obj.delay,   '');
%                     S.addEvent(obj.TrackRefDuration,      {'greenLaser','IR','detector'}, 'TrackRef') 
%                 end
%                 S.addEvent(initDuration,    'greenLaser',                   'initDuration');        % Initialization
%                 S.addEvent(obj.waitTime,                         '')                                % Delay for excited state decay
%                 S.addEvent(obj.referenceDetectionDuration,      {'IR','detector'})                  % Delay for excited state decay
% %                 S.addEvent(obj.referenceDetectionDuration, ...
% %                                             {'greenLaser', 'detector'});                          % Reference detection
%                 S.addEvent(obj.delay,       '');                                                    % Delay
                
            end
            S.addEvent(Experiment.DEFAULT_LAST_DELAY, ...
                                            '');
            
            obj.prepareInternal(S)
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.laserPowers;
            obj.mCurrentYAxisParam.value = obj.detectionDurations;
            
        end
        
        function perform(obj)
            %%% Initialization
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
            if isempty(tracker); throwBaseObjException(Tracker.NAME); end
            
            laser = getObjByName('Green Laser');
            [~, laserParts] = laser.getContollableParts();
            % Now assumes laser changing the first laser part:
            laserPartGreen = laserParts{1};
            laserPartGreen.aomOne.value = obj.initializationLaserPower; % change value of AOM1
            laserPartGreen.aomTwo.value = obj.populationLaserPower; % change value of AOM2 
            
            laser = getObjByName('IR Laser');
            [~, laserParts] = laser.getContollableParts();
            % Now assumes laser changing the first laser part:
            laserPartIR = laserParts{1};
            laserPartIR.value = obj.detectionIRLaserPower;
            
            laser = getObjByName(obj.laserSource);
            [~, laserParts] = laser.getContollableParts();
            % Now assumes laser changing the first laser part:
            laserPart = laserParts{1};
            
            % Some magic numbers
            
            % length(obj.detectionDurations) = 10;
            % length(obj.laserPowers) = 5;
            % length(obj.signal(1, :, 1) = 50;
            % d = 5, p = 4 -> obj.signal(1, 35, 1);
            % (p-1)*length(obj.detectionDurations)+d
            %%% Run - Go over all parameter space, in random order
            for p = randperm(length(obj.laserPowers))
                if obj.checkEmergencyStop()
                    return;
                end
                laserPart.value = obj.laserPowers(p);
                for d = randperm(length(obj.detectionDurations))
                    if obj.currIter <= size(obj.signal, 3) && ...
                            sum(obj.signal(:, (p-1)*length(obj.detectionDurations)+d, obj.currIter)) ~= 0
                        continue
                    end
                    success = false;
                    
                    % The detection duration is changed here simply to comply
                    % with the "ProcessData" function. It is not really
                    % significant... However, it changes the changeFlag,
                    % therefore, we change it back.
                    obj.detectionDuration = obj.detectionDurations(d);
                    obj.changeFlag = false;
                    
%                     initDuration = obj.laserInitializationDuration - obj.detectionDuration - obj.referenceDetectionDuration;
                    for trial = 1 : 5
                        if obj.checkEmergencyStop()
                            return;
                        end
                        try
                            pg.changeSequence('detection', 'duration', obj.detectionDuration);
%                             pg.changeSequence('initDuration', 'duration', initDuration);
                            
                            data = obj.getRawData(pg, spcm);
                            [sig, sterr] = obj.processData(data);
                            
                            obj.signal(:, (p-1)*length(obj.detectionDurations)+d, obj.currIter) = sig;
                            obj.sterr(:, (p-1)*length(obj.detectionDurations)+d, obj.currIter) = sterr;
                            
                            success = true;
                            obj.currParamIter = obj.currParamIter + 1;
                            sendEventParamIterationDone(obj);
                            
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
                            err2warning(err.message);
                            fprintf('Experiment failed at trial %d, attempting again.\n', trial);
                            try
                                % Maybe we need to manually clear the resources
                                spcm.stopGatedCount;
                            catch
                                % But maybe we don't, and that's perfectly ok.
                            end
                        end
                    end
                    if ~success
                        obj.emergencyStop
                        return
                    end
                end
            end
% %             for p = randperm(length(obj.laserPowers))
% %                 if obj.checkEmergencyStop()
% %                     return;
% %                 end
% %                 laserPart.value = obj.laserPowers(p);
% %                 for d = randperm(length(obj.detectionDurations))
% %                     if obj.currIter <= size(obj.signal, 3) && ...
% %                             sum(obj.signal(:, (p-1)*length(obj.detectionDurations)+d, obj.currIter)) ~= 0
% %                         continue
% %                     end
% %                     success = false;
% %                     
% %                     % The detection duration is changed here simply to comply
% %                     % with the "ProcessData" function. It is not really
% %                     % significant... However, it changes the changeFlag,
% %                     % therefore, we change it back.
% %                     obj.detectionDuration = obj.detectionDurations(d);
% %                     obj.changeFlag = false;
% %                     
% % %                     initDuration = obj.laserInitializationDuration - obj.detectionDuration - obj.referenceDetectionDuration;
% %                     for trial = 1 : 5
% %                         if obj.checkEmergencyStop()
% %                             return;
% %                         end
% %                         try
% %                             pg.changeSequence('detection', 'duration', obj.detectionDuration);
% % %                             pg.changeSequence('initDuration', 'duration', initDuration);
% %                             
% %                             data = obj.getRawData(pg, spcm);
% %                             n = obj.repeats;
% %                             m = length(data)/n;  % Number of reads each repeat
% %                             s = (reshape(data, m, n))';
% %                             data = reshape(s(:,[1,3:5])',1,(m-1)*n);
% %                             [sig, sterr] = obj.processData(data);
% %                             TrackSig = mean(s(:,2));
% %                             TrackSig = TrackSig./(obj.TrackRefDuration*1e-6)/1e3; %kcounts per second
% %                             
% %                             Tracksterr = ste(s(:,2));
% %                             Tracksterr = Tracksterr./(obj.TrackRefDuration*1e-6)/1e3; % convert to kcps
% %                             
% %                             obj.signal(:, (p-1)*length(obj.detectionDurations)+d, obj.currIter) = [sig, TrackSig];
% %                             obj.sterr(:, (p-1)*length(obj.detectionDurations)+d, obj.currIter) = [sterr, Tracksterr];
% %                             
% %                             success = true;
% %                             obj.currParamIter = obj.currParamIter + 1;
% %                             sendEventParamIterationDone(obj);
% %                             
% %                             if obj.isTracking && obj.laserPowers(p) == max(obj.laserPowers)
% %                                 if obj.checkEmergencyStop()
% %                                     return;
% %                                 end
% %                                 isTrackingNeeded = tracker.compareReference(...
% %                                     TrackSig, Tracksterr, ... 
% %                                     Tracker.REFERENCE_TYPE_KCPS, obj.trackThreshhold);
% %                                 if isTrackingNeeded
% %                                     tracker.trackUsing(TrackablePosition.NAME)
% %                                     obj.prepare;    % Before next measurement
% %                                 end
% %                             end
% %                             
% %                             break;
% %                         catch err
% %                             err2warning(err); %err2warning(err.message);
% %                             fprintf('Experiment failed at trial %d, attempting again.\n', trial);
% %                             try
% %                                 % Maybe we need to manually clear the resources
% %                                 spcm.stopGatedCount;
% %                             catch
% %                                 % But maybe we don't, and that's perfectly ok.
% %                             end
% %                         end
% %                     end
% %                     if ~success
% %                         obj.emergencyStop
% %                         return
% %                     end
% %                 end
% % %                 if obj.isTracking
% % %                     tracker.resetReference;
% % %                 end
% %             end
            
           % Saving results in the Experiment parameters
%             N0Norm = squeeze(obj.signal(1, :, 1:obj.currIter));
%             N0sterr = squeeze(obj.sterr(1, :, 1:obj.currIter));
%             R0 = squeeze(obj.signal(2, :, 1:obj.currIter));
%             R0sterr = squeeze(obj.sterr(2, :, 1:obj.currIter));
%             
%             [N0Norm, N0Normsterr] = getRatioDistributionValues(obj, N0Norm, R0, N0sterr, R0sterr);
%             [N0NormNorm, N0NormNormsterr] = getRatioDistributionValues(obj, N0Norm, R0, N0Normsterr, R0sterr);
%             
%             N1Norm = squeeze(obj.signal(3, :, 1:obj.currIter));
%             N1sterr = squeeze(obj.sterr(3, :, 1:obj.currIter));
%             R1 = squeeze(obj.signal(4, :, 1:obj.currIter));
%             R1sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));
%             
%             [N1Norm, N1Normsterr] = getRatioDistributionValues(obj, N1Norm, R1, N1sterr, R1sterr);
%             [N1NormNorm, N1NormNormsterr] = getRatioDistributionValues(obj, N1Norm, R1, N1Normsterr, R1sterr);
%             
%             numerator = N0Norm - N1Norm;
%             numeratorSterr = sqrt(N0Normsterr.^2 + N1Normsterr.^2);
%             
%             denumerator = sqrt(N0NormNorm + N1NormNorm);
%             denumeratorSterr = 1/2 * 1./sqrt(N0NormNorm+N1NormNorm) .* sqrt(N0NormNormsterr.^2 + N1NormNormsterr.^2);
%             
%             [valueVector, sterrVector] = getRatioDistributionValues(obj, numerator, denumerator, numeratorSterr, denumeratorSterr);
%             
%             value = reshape(valueVector, length(obj.detectionDurations), length(obj.laserPowers));
%             sterr = reshape(sterrVector, length(obj.detectionDurations), length(obj.laserPowers));

            N0 = squeeze(obj.signal(1, :, 1:obj.currIter));
            R0 = squeeze(obj.signal(2, :, 1:obj.currIter));
            N0Norm = N0./R0;
            N1 = squeeze(obj.signal(3, :, 1:obj.currIter));
            R1 = squeeze(obj.signal(4, :, 1:obj.currIter));
            N1Norm = N1./R1;
            if obj.currIter > 1
                valueVector = mean(N0Norm-N1Norm, 2) ./ std(N0Norm-N1Norm, 0, 2);
            else
                valueVector = N0Norm-N1Norm;
            end
            value = reshape(valueVector, length(obj.detectionDurations), length(obj.laserPowers));
            
            obj.signalParam.value = value;
        end
        
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results and fit from it
            % the coherence time.
            
            obj.wrapUpInternal()
        end
        
        function dataParam = alternateSignal(obj)
            % Returns alternate view ("Contrast") of the data, as an ExpParam.
            
            N0 = squeeze(obj.signal(1, :, 1:obj.currIter));
            R0 = squeeze(obj.signal(2, :, 1:obj.currIter));
            N0Norm = N0./R0;
            N1 = squeeze(obj.signal(3, :, 1:obj.currIter));
            R1 = squeeze(obj.signal(4, :, 1:obj.currIter));
            N1Norm = N1./R1;
            if obj.currIter > 1
                valueVector = mean(N0Norm-N1Norm, 2);
            else
                valueVector = N0Norm-N1Norm;
            end
            value = reshape(valueVector, length(obj.detectionDurations), length(obj.laserPowers));
            
            dataParam = ExpResultDoubleVector('Contrast', value, [], 'Normalized', obj.NAME);
        end
    end
end