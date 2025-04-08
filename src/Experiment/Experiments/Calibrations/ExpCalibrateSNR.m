classdef ExpCalibrateSNR < Experiment
    %EXPCALIBRATESNR Experiment for calibration of the detection time & laser power
    
    properties (Constant)
        NAME = 'Calibration_SNR';
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
        
        piTime              % in us
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpCalibrateSNR(FG, MWChannel)
            obj@Experiment(ExpCalibrateSNR.NAME);
            
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
            
            % added by rotem 16.02.22
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
            
            % Set properties inherited from Experiment
            obj.frequency = 3029;                   % in MHz
            obj.amplitude = -10;                    % in dBm. Amplitude for the withMW configuration
            obj.piTime = 0.025;                     % in us
            
            obj.repeats = 50000;
            obj.averages = 100;
            obj.isTracking = true;                  % Initialize tracking
            obj.trackThreshhold = 0.7;
            obj.shouldAutosave = true;
            
            obj.delay = 0.1;                        % in us (100 ns)
            
            obj.detectionDurations = 0.01:0.1:0.8;  % detection windows, in \mus
            
            obj.referenceDetectionDuration = 5;     % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;   % laser initialization in pulsed experiments in us
            
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
        
        function set.laserPowers(obj ,newVal)
            checkGreenLaserPower(obj, newVal)
            % If we got here, then newVal is OK.
            obj.laserPowers = newVal;
            obj.changeFlag = true;
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
            
            %%% Creating the sequence
            S = Sequence;
            for k = 1:2
                S.addEvent(max(obj.detectionDurations), ...
                                            {'greenLaser', 'detector'},     'detection');   % Detection
                S.addEvent(initDuration,    'greenLaser',                   'initDuration');% Initialization
                S.addEvent(obj.referenceDetectionDuration, ...
                                            {'greenLaser', 'detector'});                    % Reference detection
                S.addEvent(obj.delay,       '');                                            % Delay
                if k == 1
                    S.addEvent(obj.piTime,  MWChannel);                                     % MW
                    S.addEvent(obj.delay,   '');                                            % Delay
                end
            end
            S.addEvent(Experiment.DEFAULT_LAST_DELAY, ...
                                            '');
            
            obj.prepareInternal(S)
            
            % Set parameter, for saving
%             obj.mCurrentXAxisParam.value = obj.detectionDurations;
%             obj.mCurrentYAxisParam.value = obj.laserPowers;
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
            laserPart = laserParts{1};
            
            % Some magic numbers
            
            % length(obj.detectionDurations) = 10;
            % length(obj.laserPowers) = 5;
            % length(obj.signal(1, :, 1) = 50;
            % d = 5, p = 4 -> obj.signal(1, 35, 1);
            % (p-1)*length(obj.detectionDurations)+d
            %%% Run - Go over all parameter space, in random order
            k1 = 0; %added by rotem 16.02.22
            f1 = []; %added by rotem 16.02.22
            k2 = 0; %added by rotem 16.02.22
            f2 = []; %added by rotem 16.02.22
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
                    f2 = [f2, d];
                    k2 = k2 + 1; %added by rotem 16.02.22
                    success = false; %added by rotem 16.02.22
                    
                    % The detection duration is changed here simply to comply
                    % with the "ProcessData" function. It is not really
                    % significant... However, it changes the changeFlag,
                    % therefore, we change it back.
                    obj.detectionDuration = obj.detectionDurations(d);
                    obj.changeFlag = false;
                    
                    initDuration = obj.laserInitializationDuration - obj.detectionDuration - obj.referenceDetectionDuration;
                    for trial = 1 : 5
                        if obj.checkEmergencyStop()
                            return;
                        end
                        try
                            pg.changeSequence('detection', 'duration', obj.detectionDuration);
                            pg.changeSequence('initDuration', 'duration', initDuration);
                            
                            data = obj.getRawData(pg, spcm);
                            
                            % added by rotem 16.02.22 %
                            if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                                curr_idx = (p-1)*length(obj.detectionDurations)+d;
                                [sig, sterr] = obj.processData(data(curr_idx:end));
%                                 [sig, sterr] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(k2-1)+1:end));%obj.detectionPeriodsPerRepeat*obj.repeats*k));
                            else
                                [sig, sterr] = obj.processData(data);
                            end
%                             [sig, sterr] = obj.processData(data);
                            
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
%                                 spcm.stopGatedCount;
                                spcm.stopExperimentCount;
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
                f1 = [f1, p]; %added by rotem 16.02.22
                k1 = k1 + 1; %added by rotem 16.02.22
            end
            
            % added by rotem 16.02.22 %
            if length(data) == obj.detectionPeriodsPerRepeat*obj.repeats*obj.getTotalNumberOfParams %if true we're proccessing data at the end of the average
                for k1 = 1:length(obj.laserPowers)
                    for k2 = 1:length(obj.detectionDurations)
                        start_idx = (f1(k1)-1)*length(obj.detectionDurations)+f2(k2+(k1-1)*length(obj.detectionDurations));%f2(k2*(k1-1));%(k2-1)*length(obj.detectionDurations);
                        end_idx = start_idx+length(obj.detectionDurations)-1;
                        [obj.signal(:, start_idx, obj.currIter), obj.sterr(:, start_idx, obj.currIter)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(k2-1)+1:obj.detectionPeriodsPerRepeat*obj.repeats*k2));
%                     [obj.signal(:, f1(k1), obj.currIter), obj.sterr(:, f1(k1), obj.currIter)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(k1-1)+1:obj.detectionPeriodsPerRepeat*obj.repeats*k1));
                    end
                end
            end
                
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
%             value = reshape(valueVector, length(obj.laserPowers), length(obj.detectionDurations));
            
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
%            value = reshape(valueVector, length(obj.laserPowers), length(obj.detectionDurations));
            
            dataParam = ExpResultDoubleVector('Contrast', value, [], 'Normalized', obj.NAME);
        end
    end
end