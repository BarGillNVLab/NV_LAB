classdef AWGExpESR < ExperimentAWG
    %EXPESR ESR (electron spin resonance) Experiment
    
    properties (Constant)
        NAME = 'AWG ESR'
        
        ZERO_FIELD_SPLITTING = 2.87e3     % in Mhz
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        mirrorSweepAround   % double. in MHz
        
        mode                % string. Either 'CW' or 'pulsed'
                            % ('pulsed is to be implemented in the future, if needed)
        freqMirrored
        
        isSingleMeasurement
        delayBetweenDetections
        
        temp
    end
    
    methods
        
        function obj = AWGExpESR(passedExpName)
            
            if nargin == 1
               expName = passedExpName;
            else
               expName = AWGExpESR.NAME;
            end
            
            obj@ExperimentAWG(expName);
            
            obj.parameterName = 'frequencies';
                        
            obj.repeats = 100;
            obj.averages = 1000;
            
            obj.frequency = obj.ZERO_FIELD_SPLITTING + (-2 : 2 : 2);     %in MHz
            obj.amplitude = -25 + [6 0];        % dBm
            obj.mode = 'CW';            % Can only be 'CW' for now.
            
            obj.detectionDuration = 500;
            obj.referenceDetectionDuration = 500;
            obj.laserInitializationDuration = 10; % laser initialization
            spcm = getObjByName(Spcm.NAME);
            if isa(spcm, 'PhotoDiodeDigitizerNiDaqControlled')
                obj.delayBetweenDetections = 10;
            else
                obj.delayBetweenDetections = 0;
            end
            
            obj.mirrorSweepAround = []; % Use this for a single frequency range
            
            obj.displayType2 = 'kcps';
            obj.isPlotAlternateAvailable = true;
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Frequency', [], [], 'MHz', obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, 'Normal');
            obj.signalParam2 = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, 'Mirrored');
        end
    end
    
    %% Setters
    methods
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
            obj.isSingleMeasurement = isempty(obj.mirrorSweepAround);
            obj.detectionPeriodsPerRepeat = 2;
            obj.runsPerPerform = (1 + ~obj.isSingleMeasurement);
            obj.freqMirrored = obj.mirrorFrequency;
            MWChannel = obj.MWChannel;

            %%% Create
            if obj.seperatedTrigger                         % AWG trigger
                triggers = {'trigger', 'trigger2'};
            else
                triggers = {'trigger'};
            end
            switch obj.nChannels
                case 1
                    MW = {MWChannel};
                case 2
                    MW = {MWChannel, 'MW2'};
                otherwise
                    obj.sendError('What should we do here?')
            end
            if obj.AWGorSRSswitch
                MW = [MW{:}, {'AWG'}];
            end
            
            S = Sequence;
%             S.addEvent(obj.AWG.TRIG_DURATION,               [{'greenLaser'}, triggers(:)', MW(:)']);   
%             S.addEvent(obj.laserInitializationDuration,     [MW{:}, {'greenLaser'}]);
%             S.addEvent(obj.detectionDuration,               [MW{:}, {'greenLaser'}, {'detector'}]);
%             S.addEvent(obj.laserInitializationDuration,     {'greenLaser'});
%             S.addEvent(obj.referenceDetectionDuration,      {'greenLaser','detector'})
%             
            S.addEvent(obj.AWG.TRIG_DURATION,                           [{'greenLaser'}, triggers(:)', MW(:)']);   
            S.addEvent(obj.detectionDuration - obj.AWG.TRIG_DURATION,   [{'greenLaser'}, MW{:}, {'detector'}]);
            S.addEvent(obj.delayBetweenDetections,                      {'greenLaser'});   
            S.addEvent(obj.AWG.TRIG_DURATION,                           {'greenLaser'});
            S.addEvent(obj.detectionDuration - obj.AWG.TRIG_DURATION,   {'greenLaser','detector'})
            S.addEvent(obj.delayBetweenDetections,                      {'greenLaser'});   

            if obj.changeFlag % || obj.restartFlag
                obj.LoadAWG;
            end
            obj.prepareInternal(S)
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.frequency;
        end
        
        function LoadAWG(obj)
            obj.AWG.ResetStoredData;
            obj.AWG.workChannels = 1:obj.nChannels;
            obj.AWG.setAmplitude(obj.amplitude);
            minWaveformTime = obj.AWG.minWaveformDuration;
            N = length(obj.frequency);
            WaveformsIndex = zeros(obj.nChannels, N, obj.runsPerPerform);
            obj.indexSeq = zeros(obj.nChannels, N);

            % creating waveforms:
            A = obj.AWG.MaxNormPowerAllowed;
            w = 2*pi*obj.frequency;
            numSegments = zeros(obj.runsPerPerform,N);
            fprintf('Loading %d waveforms:', N*obj.runsPerPerform*obj.nChannels);
            for i = 1:N
                segmentTime = round(obj.frequency(i)*1) / obj.frequency(i);
                numSegments(1,i) = round((obj.detectionDuration+obj.laserInitializationDuration) / segmentTime);
                for chan = 1:obj.nChannels
                    f = @(t) A(chan) * (0<=t & t<segmentTime) .* cos(w(i)*t);
                    WaveformsIndex(chan,i,1) = obj.AWG.AddWaveformByFunction(f, segmentTime, 0, 1);
                end
            end
            fprintf('\n');
            fprintf('Loading %d waveforms:', 2*N*obj.nChannels);
            if ~obj.isSingleMeasurement
                w = 2*pi*obj.freqMirrored;
                for i = 1:N
                    segmentTime = round(obj.freqMirrored(i)*1) / obj.freqMirrored(i);
                    numSegments(2,i) = round(obj.detectionDuration/segmentTime);
                    for chan = 1:obj.nChannels
                        f = @(t) A(chan) * (0<=t & t<segmentTime) .* cos(w(i)*t);
                        WaveformsIndex(chan,i,2) = obj.AWG.AddWaveformByFunction(f, segmentTime, 0, 1);
                    end
                end
            end
            fprintf('\n');
            f = @(t) 0*t;
            firstZeroIndex = zeros(obj.nChannels,1);
            for chan = 1:obj.nChannels
                if obj.timeDelay > 0
                    prePulseTime = minWaveformTime + obj.timeDelay*(chan==1);
                else
                    prePulseTime = minWaveformTime + obj.timeDelay*(chan==2);
                end
                firstZeroIndex(chan) = obj.AWG.AddWaveformByFunction(f, prePulseTime, 0, 1);
            end
            lastZeroIndex  = obj.AWG.AddWaveformByFunction(f, minWaveformTime, 0, 1);
            obj.AWG.LoadWaveform();
            
            % creating sequences:
            for i = 1:N
                for chan = 1:obj.nChannels
                    if obj.isSingleMeasurement
                        obj.indexSeq(chan,i) = obj.AWG.AddSequence([firstZeroIndex(chan) WaveformsIndex(chan,i,1) lastZeroIndex], ...
                                                                   [1 numSegments(1,i) 1], [1 0 0]);
                    else
                        obj.indexSeq(chan,i) = obj.AWG.AddSequence([firstZeroIndex(chan) WaveformsIndex(chan,i,1) lastZeroIndex, ...
                                                                    firstZeroIndex(chan) WaveformsIndex(chan,i,2) lastZeroIndex], ...
                                                                   [1 numSegments(1,i) 1, 1 numSegments(2,i) 1], [1 0 0, 1 0 0], 0);
                    end
                end
            end
            obj.AWG.LoadSequence()
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
            
            % Some magic numbers
            n = obj.detectionPeriodsPerRepeat * obj.runsPerPerform;
            
            sig = zeros(1, n);
            sterr = zeros(1, n);

            obj.temp = [];
            
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
                        obj.AWG.assignSequence(obj.indexSeq(1,i),1)
                        if obj.nChannels == 2
                            obj.AWG.assignSequence(obj.indexSeq(2,i),2);
                        end
                        obj.AWG.Run;
                        data = obj.getRawData(pg, spcm);
                        
                        [sig(1:2), sterr(1:2)] = obj.processData(data);
                        
                        if ~obj.isSingleMeasurement % run another sweep with the same source
                            data = obj.getRawData(pg, spcm);
                            [sig(3:4), sterr(3:4)] = obj.processData(data);
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
        
            S1 = squeeze(obj.signal(1, :, 1:obj.currIter));
            S1sterr = squeeze(obj.sterr(1, :, 1:obj.currIter));
            S2 = squeeze(obj.signal(2, :, 1:obj.currIter));
            S2sterr = squeeze(obj.sterr(2, :, 1:obj.currIter));
            
            [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);
            obj.signalParam.value = value;
            obj.signalParam.sterr = sterr;
            
            if obj.isSingleMeasurement
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
            
            if ~obj.isSingleMeasurement
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