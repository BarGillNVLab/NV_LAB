classdef ExpCalibrateDetectionDuration < Experiment
    %EXPCALIBRATEDETECTIONDURATION Experiment for calibration of the detection time for measurement 
    
    properties (Constant)
        NAME = 'Calibration_DetectionDuration';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency           % in MHz
        amplitude           % in dBm. Amplitude for the withMW configuration
        
        delay               % in us
        detectionDurations  % in us. A vector of the scanned detection times
        
        piTime              % in us
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpCalibrateDetectionDuration(FG, MWChannel)
            obj@Experiment(ExpCalibrateDetectionDuration.NAME);
            obj.parameterName = 'durations';
            
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
            
            obj.repeats = 10000;
            obj.averages = 100;
            obj.isTracking = true;                  % Initialize tracking
            obj.trackThreshhold = 0.7;
            obj.shouldAutosave = true;
            
            obj.delay = 0.1;                        % in us (100 ns)
            
            obj.detectionDurations = 0.05:0.05:1.5; % detection windows, in \mus
            obj.referenceDetectionDuration = 5;     % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;   % laser initialization in pulsed experiments in us
            
            obj.displayType1 =  'FL';
            obj.displayType2 =  'SNR';
            obj.isPlotAlternateAvailable = true;
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Detection Duration', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|0>');
            obj.signalParam2 = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|1>');
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
    end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.detectionDurations);
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
                S.addEvent(1,                   'greenLaser');                                  % 1usec delay to ensure full overlap of ref detection and laser, and to init first repaet (less important), Yachel 27.02.22
                S.addEvent(obj.delay,       '');                                            % Delay
                if k == 1
                    S.addEvent(obj.piTime,  MWChannel);                                     % MW                    
                else
                    S.addEvent(obj.piTime,   '');                                            % Delay
%                     S.addEvent(obj.delay,   '');                                            % Delay
                end
                S.addEvent(obj.delay,   '');                                            % Delay
            end
%             S.addEvent(obj.delay,   '');                                            % Delay
%             S.addEvent(Experiment.DEFAULT_LAST_DELAY, ...
%                                             '');
            
            obj.prepareInternal(S)
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.detectionDurations;
        end
        
        function perform(obj)
            %%% Initialization
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
            if isempty(tracker); throwBaseObjException(Tracker.NAME); end
            
            % Some magic numbers
            
            %%% Run - Go over all parameter space, in random order
            for t = randperm(length(obj.detectionDurations))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue
                end
                success = false;
                
                % The detection duration is changed here simply to comply
                % with the "ProcessData" function. It is not really
                % significant... However, it changes the changeFlag,
                % therefore, we change it back.
                obj.detectionDuration = obj.detectionDurations(t);
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
                        [sig, sterr] = obj.processData(data);
                        
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
            
           % Saving results in the Experiment parameters
            S1 = squeeze(obj.signal(1, :, 1:obj.currIter));
            S1sterr = squeeze(obj.sterr(1, :, 1:obj.currIter));
            S2 = squeeze(obj.signal(2, :, 1:obj.currIter));
            S2sterr = squeeze(obj.sterr(2, :, 1:obj.currIter));
            
            [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);
            obj.signalParam.value = value;
            obj.signalParam.sterr = sterr;
            
            S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
            S3sterr = squeeze(obj.sterr(3, :, 1:obj.currIter));
            S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
            S4sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));
            
            [value, sterr] = getRatioDistributionValues(obj, S3, S4, S3sterr, S4sterr);
            obj.signalParam2.value = value;
            obj.signalParam2.sterr = sterr;

        end
        
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results and fit from it
            % the coherence time.
            
            obj.wrapUpInternal()
        end
        
        function dataParam = alternateSignal(obj)
            % Returns alternate view ("SNR") of the data, as an ExpParam.
            
            %% First method, which is probably wrong
            % N is actually N/R
            % M is N/R^2
%             N0 = obj.signalParam.value; 
%             N1 = obj.signalParam2.value;
%             N0sterr = obj.signalParam.sterr;
%             N1sterr = obj.signalParam2.sterr;
%             
%             R0 = squeeze(obj.signal(2, :, 1:obj.currIter));
%             R0sterr = squeeze(obj.sterr(2, :, 1:obj.currIter));
%             R1 = squeeze(obj.signal(4, :, 1:obj.currIter));
%             R1sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));
%             
%             [M0, M0sterr] = getRatioDistributionValues(obj, N0, R0, N0sterr, R0sterr);
%             [M1, M1sterr] = getRatioDistributionValues(obj, N1, R1, N1sterr, R1sterr);
%             
%             % N0-N1/sqrt(M0+M1)
%             numeratorSterr = sqrt(N0sterr.^2 + N1sterr.^2);
%             denumeratorSterr = 1/2 * 1./sqrt(M0+M1) .* sqrt(M0sterr.^2 + M1sterr.^2);
%             [value, sterr] = getRatioDistributionValues(obj, N0-N1, sqrt(M0+M1), numeratorSterr, denumeratorSterr);
%             dataParam = ExpResultDoubleVector('SNR', value, sterr, '', obj.NAME);
            
            %% Second method, works (?), but no error bars.
            % N is actually N/R
            S1 = squeeze(obj.signal(1, :, 1:obj.currIter));
            S2 = squeeze(obj.signal(2, :, 1:obj.currIter));
            N0 = S1./S2;
            S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
            S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
            N1 = S3./S4;
%             value = mean(N0-N1, 3) ./ std(N0-N1, 0, 3);
            value = (1-obj.signalParam.value) ./ (obj.signalParam.sterr * sqrt(obj.repeats*obj.averages));
            sterr = [];
            dataParam = ExpResultDoubleVector('SNR', value, sterr, '', obj.NAME);
            
            %% Third method (correction for first method?)
%             N0 = squeeze(obj.signal(1, :, 1:obj.currIter));
%             R0 = squeeze(obj.signal(2, :, 1:obj.currIter));
%             N1 = squeeze(obj.signal(3, :, 1:obj.currIter));
%             R1 = squeeze(obj.signal(4, :, 1:obj.currIter));
%             
%             if obj.currIter == 1
%                 sig = N0./R0-N1./R1;
%                 noise = sqrt(N0.*(N0+R0)./R0.^3 + N1.*(N1+R1)./R1.^3);
%             else
%                 sig = mean(N0./R0-N1./R1, 2);
%                 noise = mean(sqrt(N0.*(N0+R0)./R0.^3 + N1.*(N1+R1)./R1.^3), 2);
%             end
%             sterr = [];
%             dataParam = ExpResultDoubleVector('SNR', sig./noise, sterr, '', obj.NAME);
        end
    end
end