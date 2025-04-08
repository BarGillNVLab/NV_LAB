classdef ExpLaser2DESR < Experiment
    %EXP2DESR ESR (electron spin resonance) Experiment with multiple MW
    %powers
    %Ty Zabelotsky 24/10/21
    
    properties (Constant)
        NAME = 'LASER_2D_ESR'
        
        ZERO_FIELD_SPLITTING = 2.87e3     % in Mhz
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency           % double. in MHz
        mirrorSweepAround   % double. in MHz
        amplitude           % double. in dBm
        phase               % double. in degrees
        laserPowers         % double. a.u. 0 to 1
        
        mode                % string. Either 'CW' or 'pulsed'
                            % ('pulsed is to be implemented in the future, if needed)
        nChannels           % int. Must be <= the number of FGs in the system
        
        equalChannels       % boolean. true if all the channels with the same frequency
        timeDelay           % double. in mus. Time delay between two FG channels (if they are the same)
        
        piTime              % in us. For pulsed ESR.
        singletDelay        % in us. For Pulsed ESR. day between Laser and MW
    end
    
    properties (Hidden, Access = private)
        freqMirrored        % set in private function
    end
    
    methods
        
        function obj = ExpLaser2DESR(FGs, MWChannel)
            obj@Experiment(ExpLaser2DESR.NAME);
            if exist('MWChannel', 'var')
                obj.MWChannel = MWChannel;
            end
            if exist('FGs', 'var')
                obj.givenFG = FGs;
                obj.freqGenName = obj.getFgName(FGs);
            end
                        
            obj.repeats = 100;
            obj.averages = 1000;
            
            obj.frequency = obj.ZERO_FIELD_SPLITTING + (-100 : 2 : 100);     %in MHz
            obj.amplitude = -8;         % dBm
            obj.phase = 0;
            obj.mode = 'CW';            % Can only be 'CW' for now.
            obj.nChannels = 1;          % two channels can be added....
            
            obj.equalChannels = 0;      % boolean. true if all the channels with the same frequency
            obj.timeDelay = 0;          % double. in mus. Time delay between two FG channels (if they are the same)
            
            obj.detectionDuration = 500;
            obj.referenceDetectionDuration = 500;
            obj.laserInitializationDuration = 10; % laser initialization
            obj.singletDelay = 1;
            
            obj.mirrorSweepAround = []; % Use this for a single frequency range
            
            obj.laserPowers = 0.1:0.05:0.4; % a.u. aom power
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Frequency', [], [], 'MHz', obj.NAME);
            obj.mCurrentYAxisParam = ExpParamDoubleVector('AOM power', [], [], '%', obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
        end
        
        function force_prepare(obj)
            obj.prepare();
        end            
    end
    
    %% Setters
    methods
        function set.frequency(obj, newVal)	% newVal in Mhz
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

        function set.phase(obj, newVal) % newVal is in degrees
            checkPhase(obj, newVal)
            % If we got here, then newVal is OK.
            obj.phase = newVal;
            obj.changeFlag = true;
        end

        function set.nChannels(obj, newVal)
            checkNumberOfChannels(obj, newVal)
            % If we got here, then newVal is OK.
            obj.nChannels = newVal;
            obj.changeFlag = true;
        end
        
        function set.mode(obj, newVal)
            checkMode(obj, newVal)
            % If we got here, then the mode was changed
            obj.mode = newVal;
            obj.changeFlag = true;
        end
        
        function set.mirrorSweepAround(obj, newVal)
            if ~isempty(newVal)
                % If it is empty, no further checking is needed
                checkFrequencyScalar(obj, newVal)
            end
            
            % If we got here, then newVal is OK.
            obj.mirrorSweepAround = newVal;
            obj.changeFlag = true;
        end
        
        function set.piTime(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.piTime = newVal;
            obj.changeFlag = true;
        end
        
        function set.singletDelay(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.singletDelay = newVal;
            obj.changeFlag = true;
        end
        
        function set.equalChannels(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.equalChannels = newVal;
            obj.changeFlag = true;
        end
        
        function set.laserPowers(obj ,newVal)
            checkGreenLaserPower(obj, newVal)
            % If we got here, then newVal is OK.
            obj.laserPowers = newVal;
            obj.changeFlag = true;
        end
            
        function set.timeDelay(obj, newVal)
            obj.timeDelay = newVal;
        end
end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            pwrSize = size(obj.laserPowers);
            totalParamNum = pwrSize(2) * length(obj.frequency);
        end
    end
    
    %% Helper functions
    methods
        function f = mirrorFrequency(obj)
            if isempty(obj.mirrorSweepAround)
                f = [];
            else
                % newFrequencies = |mirrorFreq - (oldFrequencies - mirrorFreq)|
                %                = |2 * mirrorFreq - oldFrequencies|
                % or, in proper code:
                f = abs(2*obj.mirrorSweepAround - obj.frequency);
                if min(f) < obj.mirrorSweepAround && max(f) > obj.mirrorSweepAround
                    f = flip(f);
                end
            end
        end
        
        function phase = calculatePhase(obj, f)
            phase = obj.timeDelay * f;
        end
    end
    
    %% Overridden from Experiment
    methods (Access = protected)
        function prepare(obj)
            % Initialize devices (SPCM, PulseGenerator, etc.)
            
            % Sequence
            %%% Useful parameters for what follows
            isSingleMeasurement = isempty(obj.mirrorSweepAround);
            obj.detectionPeriodsPerRepeat = 2;
            obj.runsPerPerform = (1 + ~isSingleMeasurement);
            obj.freqMirrored = obj.mirrorFrequency;
            MWChannel = obj.MWChannel;
            
            %%% Create
            S = Sequence;
            switch obj.mode
                case 'CW'
                    if obj.laserInitializationDuration > obj.detectionDuration
                        warning('A CW experiment is set but it seems that the durations are for a pulsed experiment.');
                    end
                    switch obj.nChannels
                        case 1
                            P = Pulse(obj.detectionDuration,        {MWChannel, 'greenLaser', 'detector'});
                        case 2
                            P = Pulse(obj.detectionDuration,        {MWChannel, 'MW2', 'greenLaser', 'detector'});
                        otherwise
                            obj.sendError('What should we do here?')
                    end
                    
                    S.addEvent(obj.laserInitializationDuration,     {MWChannel, 'greenLaser'});
                    S.addPulse(P);
                    S.addEvent(obj.laserInitializationDuration,     {'greenLaser'});
                    S.addEvent(obj.referenceDetectionDuration,      {'greenLaser','detector'});
                case 'pulsed'
                    if obj.laserInitializationDuration < obj.detectionDuration
                        warning('A pulsed experiment is set but it seems that the durations are for a CW experiment.');
                    end
                    initDuration = obj.laserInitializationDuration-obj.detectionDuration-obj.referenceDetectionDuration;
                    lastDelay = Experiment.DEFAULT_LAST_DELAY;
                    
                    if length(obj.piTime) ~= obj.nChannels
                        obj.sendError('There should be pi pulse time for each MW channel')
                    end
                    
                    S.addEvent(obj.piTime(1),                   MWChannel)
                    if obj.nChannels > 1
                        S.addEventAtGivenTime(0, obj.piTime(2), 'MW2');                     % Add second MW at the same time as first MW
                    end
                    
                    S.addEvent(lastDelay,                       '');                        % Last delay
                    S.addEvent(obj.detectionDuration,           {'greenLaser','detector'})  % Detection
                    S.addEvent(initDuration,                    'greenLaser')               % Initialization
                    S.addEvent(obj.referenceDetectionDuration,...
                                                                {'greenLaser','detector'})  % Reference detection
                    S.addEvent(obj.singletDelay,                       '');                        % Last delay
            end
            
            % Initialize FrequencyGenerator
            if isempty(obj.givenFG)
                fgCell = FrequencyGenerator.getFG();
                if obj.nChannels == 1
                    obj.freqGenName = fgCell{1}.name;
                else
                    if fgCell{1}.numChannels == 2
                        obj.freqGenName = fgCell{1}.name;
                    else
                        obj.freqGenName = cellfun(@(fg)fg.name, fgCell(1:2), 'UniformOutput' ,0);
                    end
                end
            end
            obj.prepareInternal(S)
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.frequency;
            obj.mCurrentYAxisParam.value = obj.laserPowers;
        end
        
        function perform(obj)
            % Initialization
            lenF = length(obj.frequency);
            lenLP = length(obj.laserPowers);
            sz = [length(obj.laserPowers) length(obj.frequency)];
            
            %%% Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
            if isempty(tracker); throwBaseObjException(Tracker.Name); end
            if obj.nChannels == 1
                fg = getObjByName(obj.freqGenName);
            end
            laser = getObjByName('Green Laser');
            [~, laserParts] = laser.getContollableParts();
            % Now assumes laser changing the first laser part:
            laserPart = laserParts{1};
            
            % Some magic numbers
            isSingleMeasurement = isempty(obj.mirrorSweepAround);
            n = obj.detectionPeriodsPerRepeat * obj.runsPerPerform;
            
            sig = zeros(1, n);
            sterr = zeros(1, n);
            
            % Run - Go over all frequencies, in random order
            ii = 0;
            for n = randperm(obj.getTotalNumberOfParams)
                ii = ii + 1;
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, n, obj.currIter)) ~= 0
                    continue
                end
                success = false;
                
                for trial = 1 : 10
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        [p, f] = ind2sub(sz, n); % [row, col]

                        fg.frequency = obj.frequency(f);
                        laserPart.value = obj.laserPowers(p);
                        
                        data = obj.getRawData(pg, spcm);
                        if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                            [sig(1:2), sterr(1:2)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(1+~isSingleMeasurement)*(k-1)+1:end));%obj.detectionPeriodsPerRepeat*obj.repeats*k));
                        else
                            [sig(1:2), sterr(1:2)] = obj.processData(data);
                        end
                        
                        if ~isSingleMeasurement % run another sweep with the same source
                            fg.frequency = obj.freqMirrored(f);
                            data = obj.getRawData(pg, spcm);
                            if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                                [sig(3:4), sterr(3:4)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*2*(k-0.5)+1:end));%obj.detectionPeriodsPerRepeat*obj.repeats*k));
                            else
                                [sig(3:4), sterr(3:4)] = obj.processData(data);
                            end
                        end
                        
                        obj.signal(:, f, obj.currIter) = sig;
                        obj.sterr(:, f, obj.currIter) = sterr;
                        
                        success = true;
                        obj.currParamIter = obj.currParamIter + 1;
                        if obj.currParamIter == 1 || mod(obj.currParamIter, 5) == 0 || obj.currParamIter == obj.totalNumberOfParams
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
                                tracker.trackUsing(TrackablePosition.NAME, obj)
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
                
            S1 = reshape(squeeze(obj.signal(1, :, 1:obj.currIter)), lenLP, lenF, []);
            S1sterr = reshape(squeeze(obj.sterr(1, :, 1:obj.currIter)), lenLP, lenF, []);
            S2 = reshape(squeeze(obj.signal(2, :, 1:obj.currIter)), lenLP, lenF, []);
            S2sterr = reshape(squeeze(obj.sterr(2, :, 1:obj.currIter)), lenLP, lenF, []);
            
            [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);
            obj.signalParam.value = value;
            obj.signalParam.sterr = sterr;
            
            if isSingleMeasurement
                obj.signalParam2.value = [];
            else
                S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
                S3sterr = squeeze(obj.sterr(3, :, 1:obj.currIter));
                S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
                S4sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));

                [value, sterr] = getRatioDistributionValues(obj, S3, S4, S3sterr, S4sterr);
                obj.signalParam2.value = value;
                obj.signalParam2.sterr = sterr;
            end
            
            for f_i = 1:lenLP
                currentFreq = obj.frequency;
                obj.signalParam.esr(f_i, :) = interp1(currentFreq, value(f_i, :), obj.frequency, 'spline', NaN); % can change 'extrap' to be NaN or 0,
                obj.signalParam2.value = value; %Backup for raw data

            end
             
        end
        
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results and fit from it
            % the resonance frequency/ies
            
            obj.wrapUpInternal()
        end

        function dataParam = alternateSignal(obj) %#ok<MANU>
            % Returns alternate view ("referenced") of the data, as an
            % ExpParam, if possible. If not, it returns an empty variable.
            dataParam = [];
        end
        
    end
end