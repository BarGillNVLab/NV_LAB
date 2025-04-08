classdef ExpEchoNpulseWithACMagnetic < Experiment
    %EXPECHO Echo experiment With AC Magnetic faild

    properties (Constant)
        NAME = 'EchoNpulseWithACMagnetic';
        XY4_PULSES = {'X', 'Y', 'Y', 'X'};
        XY8_PULSES = {'X', 'Y', 'X', 'Y', 'Y', 'X', 'Y', 'X'};
        XY12_PULSES = {'X', 'Y', 'X', 'Y','X', 'Y', 'Y', 'X', 'Y', 'X', 'Y', 'X'};
        CPMG={'Y', 'Y', 'Y', 'Y'}
        XY1={'Y'};
        
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency           % in MHz
        amplitude           % in dBm
        water
        tau                 % in us
        halfPiTime          % in us
        piTime              % in us
        threeHalvesPiTime   % in us
        cycles
        constantTime        % logical
        doubleMeasurement   % logical
        useIQ               % logical
        xyMeas
        lastPhase
        pulsesMode
        ACamplitude
        ACsource
        AcFrequency
        phase
        phaseType
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpEchoNpulseWithACMagnetic(FG, MWChannel)
            obj@Experiment(ExpEchoNpulseWithACMagnetic.NAME);
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
            obj.water=0; 
            obj.frequency = 3029;           % in MHz
            obj.amplitude = -10;            % in dBm
            obj.tau = 0.1:1:50;             % in us
            obj.halfPiTime = 0.025;         % in us
            obj.piTime = 0.05;              % in us
            obj.threeHalvesPiTime = 0.075;  % in us
            obj.cycles = 8;                 % number of pi pulses
            obj.constantTime = false;       % logical
            obj.doubleMeasurement = true;   % logical
            obj.useIQ = true;               % logical
            obj.xyMeas = 1;
            obj.lastPhase = 'X';             % 'X' or 'Y'
            obj.pulsesMode='CPMG-n';          % CPMG-n ot XY-n
            obj.detectionDuration = 0.25;           % detection window, in us
            obj.referenceDetectionDuration = 5;     % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;   % laser initialization in pulsed experiments in us
            obj.phaseType='normal'; % normal to const Rand for random
            
            obj.AcFrequency=0.1;                % the AC sorce frequency in MHz
            obj.phase=90-15;                   % the AC sorce phase 
            obj.ACamplitude = 5;                   % v to 0
            
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.topParam = ExpParamDoubleVector(StringHelper.TAU, [], [], StringHelper.MICROSEC, obj.NAME);
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
            totalParamNum = length(obj.tau);
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
            if obj.pulsesMode=="CPMG-n"
                xyPulses=obj.CPMG;
                m=4;
            elseif obj.pulsesMode=="xy-n"
                if ~mod(obj.cycles, 12)
                    xyPulses=obj.XY12_PULSES;
                    m=12;
                elseif ~mod(obj.cycles, 8)
                    xyPulses = obj.XY8_PULSES;
                    m = 8;
                elseif ~mod(obj.cycles, 4)
                    xyPulses = obj.XY4_PULSES;
                    m = 4;
                elseif obj.cycles==1
                    m=1;
                     xyPulses = obj.XY1;
                else
                    
                    if obj.xyMeas
                        error('Number of cycles must divide by 4 in XY measurement')
                    end
                end
            else 
                eroor('pulse mode must be "CPMG-n" or "xy-n" ')
            end

            
            %%% Creating the sequence
            S = Sequence;

            for k = 1:1+obj.doubleMeasurement
                if obj.ACamplitude>0
                    S.addEvent(obj.halfPiTime,                  {MWChannel, 'ACtrigger'});
                else
                      S.addEvent(obj.halfPiTime,                  MWChannel);
                end
                
                
                for i = 1:obj.cycles
                    if obj.useIQ && obj.xyMeas && obj.cycles>1
                        n=mod(i, m);
                        if n==0 ; n=4;end
                        xyPhase = xyPulses{n};
                    elseif ~obj.useIQ
                        xyPhase = 'X';
                    elseif obj.useIQ && obj.xyMeas && obj.cycles== 1
                        n=1;
                        xyPhase = 'Y';
                    end
                    
                    IQpulse = obj.xy2iq(xyPhase);
                    
                    S.addEvent(obj.tau(end),                     '',               'tau');
                    S.addEvent(obj.piTime,                  [IQpulse(:)', MWChannel(:)']);
                    S.addEvent(obj.tau(end),                     '',               'tau');
                end                        % MW in x

                 if k == 1  % Half Pi Pulse (For Readout)
                      IQpulse = obj.xy2iq(obj.lastPhase);
                    S.addEvent(obj.halfPiTime,              [IQpulse(:)', MWChannel(:)']);      % MW in X/Y
                else % Half Pi for double measurement (For Readout)
                    if obj.useIQ % With IQ
                        IQpulse = obj.xy2iq(['-', obj.lastPhase]);
                        S.addEvent(obj.halfPiTime,          [IQpulse(:)', MWChannel(:)']);      % MW in -X/-Y
                    else  % Half Pi Pulse Without IQ
                        S.addEvent(obj.threeHalvesPiTime,   MWChannel);                         % MW in -x
                    end
                 end
                    
                S.addEvent(Experiment.DEFAULT_LAST_DELAY,   '',             'lastDelay');       % Last delay
                S.addEvent(obj.detectionDuration,...
                                                            {'greenLaser', 'detector'});        % Detection
                S.addEvent(initDuration,                    'greenLaser');                      % Initialization
                S.addEvent(obj.referenceDetectionDuration,...
                                                            {'greenLaser', 'detector'});        % Reference detection
               S.addEvent(1,                    'greenLaser');                      % Initialization

            end
            
            obj.prepareInternal(S)
           if obj.ACamplitude>0
            obj.ACsource = getObjByName('RigolAWG-SN-NA');
            obj.loadRigolAWG;
           end
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.tau;
            
            obj.isPlotAlternateAvailable = obj.doubleMeasurement;
        end
        function loadRigolAWG(obj)
            N=round(2*obj.cycles*obj.tau(end)*obj.AcFrequency+3);
            obj.ACsource.setTimeOut(100);
            obj.ACsource.connect();
            obj.ACsource.burstNcycle(N);
            obj.ACsource.setDelay(obj.ACsource.SETUP_AWG_DELAY);
            obj.ACsource.setFreq(obj.AcFrequency);  %freq in MHz
            obj.ACsource.setPeriod(N/obj.AcFrequency);
            obj.ACsource.setVoltage(obj.ACamplitude);
            obj.ACsource.setImpedance();
            obj.ACsource.setBurstState();
            obj.ACsource.setDelay(0)
            if obj.phaseType=="Rand"
                obj.phase=360*rand();
                end
                obj.ACsource.setPhase(obj.phase);
            
            obj.laserInitializationDuration = max(2/obj.AcFrequency+5, obj.laserInitializationDuration); % we need space between two sequences to the MF turn off and waiting to trigger
        end
        function perform(obj)
            %%% Initialization
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
                if isempty(tracker); throwBaseObjException(Tracker.Name); end
            
            % Some magic numbers
            maxLastDelay = Experiment.DEFAULT_LAST_DELAY + 2 * max(obj.tau);
            
            %%% Run - Go over all tau's, in random order
            for t = randperm(length(obj.tau))
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
                        pg.changeSequence('tau', 'duration', obj.tau(t));
                        if obj.constantTime
                            pg.changeSequence('lastDelay', 'duration', maxLastDelay - 2*obj.tau(t));
                        end
                        if obj.ACamplitude >0
                        obj.ACsource.burstNcycle(round(2*obj.cycles*obj.tau(t)*obj.AcFrequency+5)); %5*obj.tau(t)*obj.AcFrequency
                        if obj.phaseType=="Rand"
                            obj.phase=360*rand();
                            obj.ACsource.setPhase(obj.phase);

                        end
                        end
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

