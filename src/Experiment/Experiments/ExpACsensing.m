classdef ExpACsensing < Experiment
    %ExpACsensing Echo experiment

    properties (Constant)
        NAME = 'ACsensing';
        XY4_PULSES = {'X', 'Y', 'Y', 'X'};
        XY8_PULSES = {'X', 'Y', 'X', 'Y', 'Y', 'X', 'Y', 'X'};
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency           % in MHz
        amplitude           % in dBm
        
        tau                 % in us
        halfPiTime          % in us
        piTime              % in us
        threeHalvesPiTime   % in us
        
        cycles 
        ACamplitude
        ACsource
        phase               % in deg
        xyMeas
        lastPhase
        
        constantTime        % logical
        doubleMeasurement   % logical
        useIQ               % logical
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpACsensing(FG, MWChannel)
            obj@Experiment(ExpACsensing.NAME);
            obj.parameterName = 'voltage';
            
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
            
            obj.frequency = 3029;           % in MHz
            obj.amplitude = -10;            % in dBm
            obj.tau = 5;                   % in us
            obj.halfPiTime = 0.025;         % in us
            obj.piTime = 0.05;              % in us
            obj.threeHalvesPiTime = 0.075;  % in us
            obj.phase=90-15;                   % the AC sorce phase 
            obj.cycles = 8;                % number of pi pulses
            obj.ACamplitude = 0:1:10 ;   % V to 0
            
            obj.constantTime = false;       % logical
            obj.doubleMeasurement = true;   % logical
            obj.useIQ = false;              % logical
            obj.xyMeas = 1;
            obj.lastPhase = 'X';            % 'X' or 'Y'
            
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
        
        function set.tau(obj, newVal)	% newVal in microsec
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
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.halfPiTime = newVal;
            obj.changeFlag = true;
        end
        
        function set.piTime(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.piTime = newVal;
            obj.changeFlag = true;
        end
        
        function set.threeHalvesPiTime(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.threeHalvesPiTime    = newVal;
            obj.changeFlag = true;
        end
    end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.ACamplitude);
        end
        
        function IQpulse = xy2iq(obj, xyPhase)
            switch upper(xyPhase)
                case 'Y'
                    IQpulse = {'I'};
                case 'X'
                    IQpulse = '';
                case '-Y'
                    IQpulse = {'Q'};
                case '-X'
                    IQpulse = {'I', 'Q'};
                otherwise
                    error('Pulse type can be just "X", "Y", "-X", "-Y"')
            end
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
            if ~mod(obj.cycles, 8)
                xyPulses = obj.XY8_PULSES;
                m = 8;
            elseif ~mod(obj.cycles, 4)
                xyPulses = obj.XY4_PULSES;
                m = 4;
            else
                if obj.xyMeas
                    error('Number of cycles must divide by 4 in XY measurement')
                end
            end

            
            %%% Creating the sequence
            S = Sequence;
            for k = 1:1+obj.doubleMeasurement
                S.addEvent(obj.halfPiTime,                  {MWChannel, 'ACtrigger'});
                S.addEvent(obj.tau/2,                       '');
                
                S.addEvent(obj.piTime,                      MWChannel);
                for i = 1:obj.cycles-1
                    if obj.useIQ && obj.xyMeas
                        xyPhase = xyPulses{mod(i, m)+1};
                    else
                        xyPhase = 'X';
                    end
                    IQpulse = obj.xy2iq(xyPhase);
                    S.addEvent(obj.tau,                     '');
                    S.addEvent(obj.piTime,                  [IQpulse(:)', MWChannel(:)']);
                end                                         
                S.addEvent(obj.tau/2,                       '');
                
                if k == 1  % Half Pi Pulse (For Readout)
                    IQpulse = obj.xy2iq(obj.lastPhase);
                    S.addEvent(obj.halfPiTime,              [IQpulse(:)', MWChannel(:)']);      % MW in x
                else % Half Pi for double measurement (For Readout)
                    if obj.useIQ % With IQ
                        IQpulse = obj.xy2iq(['-', obj.lastPhase]);
                        S.addEvent(obj.halfPiTime,          [IQpulse(:)', MWChannel(:)']);      % MW in -x
                    else  % Half Pi Pulse Without IQ
                        S.addEvent(obj.threeHalvesPiTime,   MWChannel);                         % MW in -x
                    end
                end
                
                S.addEvent(Experiment.DEFAULT_LAST_DELAY,   '',             'lastDelay');       % Last delay
                S.addEvent(obj.detectionDuration,...
                                                            {'greenLaser', 'detector'});        % Detection
                S.addEvent(initDuration,                    'greenLaser');                      % Initialization
                S.addEvent(obj.referenceDetectionDuration,  {'greenLaser', 'detector'});        % Reference detection
            end
            
            obj.prepareInternal(S)
            
            obj.ACsource = getObjByName('RigolAWG-SN-NA');
            obj.loadRigolAWG;
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.ACamplitude;
            obj.isPlotAlternateAvailable = obj.doubleMeasurement;
        end
        
        function loadRigolAWG(obj)
            obj.ACsource.setTimeOut(100);
            obj.ACsource.connect();
            obj.ACsource.burstNcycle(ceil(obj.cycles/2)+2);
            obj.ACsource.setDelay(obj.ACsource.SETUP_AWG_DELAY);
            obj.ACsource.setFreq(0.5/(obj.tau+obj.piTime));  
            obj.ACsource.setPeriod(obj.tau*2);
            obj.ACsource.setImpedance();
            obj.ACsource.setBurstState();
            obj.ACsource.setDelay(0)
            obj.ACsource.setPhase(obj.phase);
        
%             obj.ACsource.setPhase(90);
            obj.laserInitializationDuration = max(obj.tau+5, obj.laserInitializationDuration); % we need space between two sequences to the MF turn off and waiting to trigger
        end
        
        
        function perform(obj)
            %%% Initialization
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
                if isempty(tracker); throwBaseObjException(Tracker.Name); end
            
           
            %%% Run - Go over all tau's, in random order
            for t = randperm(length(obj.ACamplitude))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue
                end
                success = false;
                
                for trial = 1 : 5
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        obj.ACsource.setVoltage(obj.ACamplitude(t));
                        
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

