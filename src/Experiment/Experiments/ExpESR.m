classdef ExpESR < Experiment
    %EXPESR ESR (electron spin resonance) Experiment
    
    properties (Constant)
        NAME = 'ESR'
        
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
        
        mode                % string. Either 'CW' or 'pulsed'
                            % ('pulsed is to be implemented in the future, if needed)
        nChannels           % int. Must be <= the number of FGs in the system
        
        equalChannels       % boolean. true if all the channels with the same frequency
        timeDelay           % double. in mus. Time delay between two FG channels (if they are the same)
        
        piTime              % in us. For pulsed ESR.
        singletDelay        % in us. For Pulsed ESR. day between Laser and MW
    end
    
    properties %(Hidden, Access = private)
        freqMirrored        % set in private function
    end
    
    methods
        
        function obj = ExpESR(FGs, MWChannel, passedExpName)
            
            if nargin == 3
               expName = passedExpName;
            else
               expName = ExpESR.NAME;
            end
            
            obj@Experiment(expName);
            if exist('MWChannel', 'var')
                obj.MWChannel = MWChannel;
            end
            if exist('FGs', 'var')
                obj.givenFG = FGs;
                obj.freqGenName = obj.getFgName(FGs);
            end
            
            obj.parameterName = 'frequencies';
                        
            obj.repeats = 100;
            obj.averages = 1000;
            
            obj.frequency = obj.ZERO_FIELD_SPLITTING + (-100 : 2 : 100);     %in MHz
            obj.amplitude = -25;        % dBm
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
            
            obj.displayType2 = 'kcps';
            obj.isPlotAlternateAvailable = true;
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Frequency', [], [], 'MHz', obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, 'Normal');
            obj.signalParam2 = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, 'Mirrored');
        end
        
        function force_prepare(obj)
            obj.prepare();
        end            
    end
    
    %% Setters
    methods
        function set.frequency(obj, newVal)	% newVal in microsec
            checkFrequencyVector(obj, newVal)
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
            
        function set.timeDelay(obj, newVal)
            obj.timeDelay = newVal;
        end
end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.frequency);
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
            isSingleMeasurement = (isempty(obj.mirrorSweepAround) || obj.nChannels > 1);
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
                    
%                     S.addEvent(1000,                       '');
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
                        obj.freqGenName = cellfun(@(fg)fg.name, fgCell(1:end), 'UniformOutput' ,0);
                    end
                end
            end
            obj.prepareInternal(S)
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.frequency;
        end
        
        function perform(obj)
            % Initialization
            len = length(obj.frequency);
            f1 = randperm(len);
            
            %%% Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
            if isempty(tracker); throwBaseObjException(Tracker.Name); end
            if obj.nChannels == 1
                fg = getObjByName(obj.freqGenName);
            end
            
            % Some magic numbers
            isSingleMeasurement = (isempty(obj.mirrorSweepAround) || obj.nChannels > 1);
            n = obj.detectionPeriodsPerRepeat * obj.runsPerPerform;
            
            sig = zeros(1, n);
            sterr = zeros(1, n);
            
            % Run - Go over all frequencies, in random order
            for k = 1:len
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, f1(k), obj.currIter)) ~= 0
                    continue
                end
                success = false;
                
                for trial = 1 : 5
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        i = f1(k);
                        if obj.nChannels == 1
                            fg.frequency = obj.frequency(i);
                        else % This will run both channels at the same time
                            if obj.equalChannels
                                obj.setMultipleFGFrequencies([obj.frequency(i), obj.frequency(i)]);
                                fg.phase = [0, obj.calculatePhase(obj.frequency(i))];
                            else
                                obj.setMultipleFGFrequencies([obj.frequency(i), obj.freqMirrored(i)]);
                            end
                        end
                        data = obj.getRawData(pg, spcm);
                        if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                            [sig(1:2), sterr(1:2)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(1+~isSingleMeasurement)*(k-1)+1:end));%obj.detectionPeriodsPerRepeat*obj.repeats*k));
                        else
                            [sig(1:2), sterr(1:2)] = obj.processData(data);
                        end
                        
                        if ~isSingleMeasurement % run another sweep with the same source
                            fg.frequency = obj.freqMirrored(i);
                            data = obj.getRawData(pg, spcm);
                            if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                                [sig(3:4), sterr(3:4)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*2*(k-0.5)+1:end));%obj.detectionPeriodsPerRepeat*obj.repeats*k));
                            else
                                [sig(3:4), sterr(3:4)] = obj.processData(data);
                            end
                        end
                        
                        obj.signal(:, i, obj.currIter) = sig;
                        obj.sterr(:, i, obj.currIter) = sterr;
                        
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
                                if obj.countWithLifeTime %added by rotem 29.08.22
                                    if obj.currIter > 1
                                        tracker.updateReference(mean(mean(obj.signal(2,:,1:obj.currIter-1)))); %should think of a better way to set the tracking reference. Not ideal, but if we have enough averages that were good, a bad average shouldn't impact too much
                                    else
                                        tracker.updateReference(sig(2));
                                    end
                                end
                            end
                        end
                        
                        %%added by rotem 29.08.22 for tracking using lifetime
%                         if obj.countWithLifeTime && (mod(obj.currIter,5) == 0) && obj.currParamIter == 1
%                             tracker.trackUsing(TrackablePosition.NAME, obj)
%                             obj.prepare;
%                         end
                                                    
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
            
            %if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled') %maybe check something different
            if length(data) == obj.detectionPeriodsPerRepeat*obj.repeats*obj.getTotalNumberOfParams*(1+~isSingleMeasurement) %if true we're proccessing data at the end of the average
                for k = 1:len
                    [sig(1:2), sterr(1:2)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(1+~isSingleMeasurement)*(k-1)+(1:obj.detectionPeriodsPerRepeat*obj.repeats)));
                    if ~isSingleMeasurement % run another sweep with the same source
                         [sig(3:4), sterr(3:4)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*2*(k-0.5)+(1:obj.detectionPeriodsPerRepeat*obj.repeats)));
                    end
                    obj.signal(:, f1(k), obj.currIter) = sig';
                    obj.sterr(:, f1(k), obj.currIter) = sterr';
                end
            end
                
                
            
            S1 = squeeze(obj.signal(1, :, 1:obj.currIter));
            S1sterr = squeeze(obj.sterr(1, :, 1:obj.currIter));
            S2 = squeeze(obj.signal(2, :, 1:obj.currIter));
            S2sterr = squeeze(obj.sterr(2, :, 1:obj.currIter));
            
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
        end
        
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results and fit from it
            % the resonance frequency/ies
            
            obj.wrapUpInternal()
        end
        
        function params = alternateSignal(obj)
            % Returns alternate view of the data.
            % Return a cell array ExpParams. The first cell is dataParam.
            % The second cell is either another dataParam or a cell of
            % three dataParams. The the last cell is a cell of strings
            % which indiciates what are the ExpParams. It is either
            % {'yParam', 'yParam2'} or {'yParam', 'yParam2+'}
            
            if obj.currIter == 0
                params = ExpResultDoubleVector('FL', [], [], 'kcps', obj.NAME);
                return
            end
            S1 = squeeze(obj.signal(1, :, 1:obj.currIter));
            S1sterr = squeeze(obj.sterr(1, :, 1:obj.currIter));
            S2 = squeeze(obj.signal(2, :, 1:obj.currIter));
            S2sterr = squeeze(obj.sterr(2, :, 1:obj.currIter));
            if obj.currIter ~= 1
                % Calculate the mean
                S1sterr = obj.getCombinedSterr(S1, S1sterr);
                S2sterr = obj.getCombinedSterr(S2, S2sterr);
                S1 = mean(S1, 2);
                S2 = mean(S2, 2);
            end
            dataParam = ExpResultDoubleVector('FL', S1, S1sterr, 'kcps', obj.NAME, 'With MW');
            dataParam2 = ExpResultDoubleVector('FL', S2, S2sterr, 'kcps', obj.NAME, 'Without MW');
            
            isSingleMeasurement = (isempty(obj.mirrorSweepAround) || obj.nChannels > 1);
            if ~isSingleMeasurement
                S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
                S3sterr = squeeze(obj.sterr(3, :, 1:obj.currIter));
                S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
                S4sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));
                
                if obj.currIter ~= 1
                    % Calculate the mean
                    S3sterr = obj.getCombinedSterr(S3, S3sterr);
                    S4sterr = obj.getCombinedSterr(S4, S4sterr);
                    S3 = mean(S3, 2);
                    S4 = mean(S4, 2);
                end
                dataParam3 = ExpResultDoubleVector('FL', S3, S3sterr, 'kcps', obj.NAME, 'With MW - Mirrored');
                dataParam4 = ExpResultDoubleVector('FL', S4, S4sterr, 'kcps', obj.NAME, 'Without MW - Mirrored');
                params = {dataParam, {dataParam2, dataParam3, dataParam4}, {'yParam', 'yParam2+'}};
            else
                params = {dataParam, dataParam2, {'yParam', 'yParam2'}};
            end
        end
    end
end