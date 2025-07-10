classdef ExpCalibrateDelays < Experiment
    %ExpCalibrateDelays Experiment for calibrating the delay times
    
    properties (Constant)
        NAME = 'Calibration_Delays';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency                   % in MHz
        amplitude                   % in dBm
        
        detectionDelay              % in us - The delay between detection periods.
        %detectionDuration          % in us - The duration of each detection period. (Defined in Experiment)
        detectionTimeShift          % in us - The shifts between detection periods.
        listOfChannels              % Cell array of channels, the channels will be turned on according to the order listed
        channelDelay                % in us - The delay between turning channels on and off. The first channel will be turned on after this time.
                                    % It is possible to indicate the on/off times of each channel, and then it should be a vector of length = 2 * length(listOfChannels).
        detectionStartStopOffset    % in us - How long before and after the seqeunce should the detection start and stop.
        AWGchannel
        waveform
    end
    
    properties (Hidden, Dependent = true)
        t_
        tStart
        tEnd
    end
    
    properties (Hidden, Access = private)
        privateSequences
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpCalibrateDelays(FG)
            obj@Experiment(ExpCalibrateDelays.NAME);
            obj.parameterName = 'shifts';
            
            % First, get a frequency generator
            if exist('MWChannel', 'var')
                sg = getObjByName(SignalGenerator.NAME);
                if ~iscell(MWChannel)
                    MWChannel = {MWChannel};
                end
                
                % validate the MWChannel exists
                for i = 1:length(MWChannel)
                    if ischar(MWChannel{i})
                        tf = cellfun(@(s) strcmp(s.pgChannelName, MWChannel{i}), sg.FGchannels);
                    else
                        tf = cellfun(@(s) s.pgChannelNumber == MWChannel{i}, sg.FGchannels);
                    end
                    if tf == 0
                        error('No frequency generator found');
                    end
                end
                obj.MWChannel = MWChannel;
            end

            % Set properties inherited from Experiment
            obj.frequency = 3029;           % in MHz
            obj.amplitude = -10;            % in dBm
            
            obj.repeats = 50000;
            obj.averages = 100;
            obj.isTracking = true;          % Initialize tracking
            obj.trackThreshhold = 0.7;
            obj.shouldAutosave = true;
            obj.fixDelays = 0;              % Do not fix delays for this experiment!
            
            obj.setDelayResolution(0.1);    % Default is 100ns
            obj.listOfChannels = {'greenLaser', 'MW'};
            obj.channelDelay = 2;
            obj.detectionStartStopOffset = 1;
            
            obj.displayType1 =  'Normal';
            obj.displayType2 =  'Alt (One Color)';
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'kcps', obj.NAME);
        end
        
        function setDelayResolution(obj, delayRes)
            % Sets the delay to the one given. If it is >1, than assumes it
            % is in ns, if it is small than 1, assume it is in us.
            if delayRes > 1
                delayRes = delayRes/1000;
            end
            obj.detectionDuration = delayRes;
            obj.detectionDelay = obj.detectionDuration;
            obj.detectionTimeShift = 0:0.02:obj.detectionDuration + obj.detectionDelay - eps;
        end
    end
    
    %% Setters & Getters
    methods
        function t = get.t_(obj)
            dt = obj.detectionDelay + obj.detectionDuration;
            tShift = obj.detectionDelay/2;
            t = (obj.tStart + tShift:dt:obj.tEnd + tShift - dt);
        end
        
        function tStart = get.tStart(obj)
            tStart = obj.channelDelay(1) - obj.detectionStartStopOffset;
        end
        
        function tEnd = get.tEnd(obj)
            if length(obj.channelDelay) == 1
                tEnd = obj.channelDelay * (2 * length(obj.listOfChannels)) + obj.detectionStartStopOffset;
            elseif length(obj.channelDelay) == 2 * length(obj.listOfChannels)
                tEnd = sum(obj.channelDelay) + obj.detectionStartStopOffset;
            else
                obj.sendError('Channel Delay size is wrong');
            end
        end
        
        function set.frequency(obj, newVal) % newVal is in MHz
%             checkFrequencyScalar(obj, newVal)
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
        
        function set.detectionDelay(obj, newVal)	% newVal in microsec
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.detectionDelay = newVal;
            obj.changeFlag = true;
        end
        
        function set.listOfChannels(obj, newVal)
            checkChannels(obj, newVal)
            % If we got here, then newVal is OK.
            obj.listOfChannels = newVal;
            obj.changeFlag = true;
        end

        function set.detectionTimeShift(obj, newVal)	% newVal in microsec
            checkMaxTime(obj, newVal)
            % If we got here, then newVal is OK.
            obj.detectionTimeShift = newVal;
            obj.changeFlag = true;
        end
        
        function set.channelDelay(obj, newVal)	% newVal in microsec
            checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.channelDelay = newVal;
            obj.changeFlag = true;
        end 
        
        function set.detectionStartStopOffset(obj, newVal)	% newVal in microsec
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.detectionStartStopOffset = newVal;
            obj.changeFlag = true;
        end 
    end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.detectionTimeShift);
        end

        function genWave(obj) % function generateWaveform(obj)
            sg = getObjByName(SignalGenerator.NAME);
            awg = sg.AWGchannels{sg.AWGchannelMap(obj.AWGchannel)}.device;
            S = Sequence;
            S.addEvent(obj.channelDelay, obj.MWChannel);
            S.name = 'DelayCalibration_1';
            if iscell(obj.frequency)
                % obj.frequency = cell(obj.frequency);
                obj.frequency = obj.frequency{1};
            end
            frequency = obj.frequency;
            obj.frequency = {frequency};
            waveform = {Waveform(obj, S, obj.MWChannel{1}, 1, frequency+50)};
            awg.loadAWGInternal(awg, waveform);
            obj.frequency = frequency;
            obj.waveform = waveform;
        end
    end
    
    %% Overridden from Experiment
    methods (Access = protected)        
        function prepare(obj)
            % Initializtions before run
            
            % Sequence
            %%% Useful parameters for what follows
            t = obj.t_;
            obj.detectionPeriodsPerRepeat = length(t);
            obj.runsPerPerform = 1;
            obj.privateSequences = cell(1,length(obj.detectionTimeShift));
            
            %%% Creating the sequence s        
            for n = 1:length(obj.detectionTimeShift)
                obj.privateSequences{n} = Sequence;
                S = obj.privateSequences{n};
                S.addEvent(obj.tStart + obj.detectionTimeShift(n), ...
                                                                '')
                for j = 1:length(t)
                    S.addEvent(obj.detectionDuration,           'detector');
                    S.addEvent(obj.detectionDelay,              '');
                end
                
                for k = 1:length(obj.listOfChannels)
                    if length(obj.channelDelay) == 1
                        startTime = obj.channelDelay * k;
                        duration = obj.channelDelay * (2 * (length(obj.listOfChannels) - k) + 1);
                    else
                        times = cumsum(obj.channelDelay);
                        startTime = times(k);
                        duration = times(end+1-k) - times(k);
                    end
                    % S.addEventAtGivenTime(startTime, duration, obj.listOfChannels{k});
                    if ~isempty(obj.AWGchannel) && any(contains(obj.listOfChannels{k}, obj.AWGchannel{1}))
                        if isempty(obj.waveform)
                            obj.genWave();
                        end
                        S.addEventAtGivenTime(startTime, 5e-3, obj.listOfChannels{k});
                        % S.addEventAtGivenTime(startTime+duration-10e-3, 5e-3, obj.listOfChannels{k});
                    else
                        S.addEventAtGivenTime(startTime, duration, obj.listOfChannels{k});
                    end
                end
                S.addEvent(Experiment.DEFAULT_LAST_DELAY,       '');
            end
            S = obj.privateSequences{1};
            
            obj.prepareInternal(S)
            
            % Set parameter, for saving
            tMatrix = zeros(length(t), length(obj.detectionTimeShift));
            for k = 1:length(obj.detectionTimeShift)
                tMatrix(:,k) = t' + obj.detectionTimeShift(k);
            end
            obj.mCurrentXAxisParam.value = tMatrix;
            
            obj.isPlotAlternateAvailable = (length(obj.detectionTimeShift) > 1);
        end
        
        function perform(obj)
            %%% Initialization
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
            if isempty(tracker); throwBaseObjException(Tracker.NAME); end
            
            % Some magic numbers
            
            %%% Run - Go over all shifts's, in random order
            for n = randperm(length(obj.privateSequences))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, n, obj.currIter)) ~= 0
                    continue
                end
                success = false;
            
                for trial = 1 : 5
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        pg.setSequence(obj.privateSequences{n});
                        try
                            data = obj.getRawData(pg, spcm);
                        catch err
                            if contains(err.message, '201314')
                                obj.sendError(sprintf('Delay is currently %d ns and it is too short, increase it (in small jumps) using .setDelayResolution(delay) function', obj.detectionDuration*1000));
                            end
                        end
                        [sig, sterr] = obj.processData(data);
                        
                        obj.signal(:, n, obj.currIter) = sig;
                        obj.sterr(:, n, obj.currIter) = sterr;
                        
                        success = true;
                        obj.currParamIter = obj.currParamIter + 1;
                        sendEventParamIterationDone(obj);
                        
                        if obj.isTracking
                            if obj.checkEmergencyStop()
                                return;
                            end
%                             [sig_track, sterr_track] = obj.processData(data(1:
                            isTrackingNeeded = tracker.compareReference(...
                                mean(sig), mean(sterr)*sqrt(obj.detectionPeriodsPerRepeat), ... % Sum over all seqeunce
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
                    obj.emergencyStop
                    return
                end
            end
            
            % Saving results in the Experiment parameters
            S = squeeze(obj.signal(:, :, 1:obj.currIter));
            Ssteerr = squeeze(obj.sterr(:, :, 1:obj.currIter));
            if obj.currIter > 1
                n = BooleanHelper.ifTrueElse(length(obj.detectionTimeShift) > 1, 3, 2);
                S = mean(S, n);
                Ssteerr = mean(Ssteerr, n)./sqrt(size(Ssteerr, n));
            end
            
            obj.signalParam.value = S;
            obj.signalParam.sterr = Ssteerr;
        end
        
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results and fit from it
            % the coherence time.

            if ~isempty(obj.AWGchannel)
                obj.waveform = [];

                sg = getObjByName(SignalGenerator.NAME);
                awg = sg.AWGchannels{sg.AWGchannelMap(obj.AWGchannel)}.device;
                awg.disconnectIQ(awg);
            end
            
            obj.wrapUpInternal()
        end
        
        function params = alternateSignal(obj)
            % Returns alternate view of the data when all of the different
            % time shifts are merged.
            % Return a cell array ExpParams. The first cell is dataParam.
            % The second cell is xAxisParam. The the last cell is a cell of
            % strings which indiciates what are the ExpParams. It is
            % {'yParam', 'xParam'}
            
            if obj.currIter == 0
                params = ExpResultDoubleVector('FL', [], [], 'kcps', obj.NAME);
                return
            end
            
            S = squeeze(obj.signal(:, :, 1:obj.currIter));
            Ssteerr = squeeze(obj.sterr(:, :, 1:obj.currIter));
            if obj.currIter > 1
                n = BooleanHelper.ifTrueElse(length(obj.detectionTimeShift) > 1, 3, 2);
                S = mean(S, n);
                Ssteerr = mean(Ssteerr, n)./sqrt(size(Ssteerr, n));
            end
            S = reshape(S', 1, []);
            Ssteerr = reshape(Ssteerr', 1, []);
            dataParam = ExpResultDoubleVector('FL', S, Ssteerr, 'kcps', obj.NAME);
            
            t = reshape(obj.t_+obj.detectionTimeShift',1,[]);
            xAxisParam = ExpParamDoubleVector('Time', t, [], StringHelper.MICROSEC, obj.NAME);
            params = {dataParam, xAxisParam, {'yParam', 'xParam'}};
        end
    end
    
    methods (Access = {?Experiment, ?ViewExperimentPlot})
        function plotResults(obj)
            % Plots the data in axes inside ViewExperimentPlot. Can be
            % overridden to allow for special kinds of plots, when an
            % Experiment requires that.
            plotResults@Experiment(obj);
            h = get(obj.gAxes, 'Children');
            for i = 1:length(h)
                if strcmp(get(h(i), 'Type'), 'text')
                    continue
                end
                set(h(i), 'Marker', '.')
                set(h(i), 'LineStyle', 'none')
            end
            
            yLimits = get(obj.gAxes,'YLim');
            if ~isempty(yLimits)
                if length(obj.channelDelay) == 1
                    times = obj.channelDelay : obj.channelDelay: obj.channelDelay * (2*length(obj.listOfChannels));
                else
                    times = cumsum(obj.channelDelay);
                end
                for i = 1:length(times)
                    x = times(i);
                    line(obj.gAxes, [x x], yLimits, 'LineStyle', '--', 'Color', 'k')

                    if i <= length(obj.listOfChannels)
                        if iscell(obj.listOfChannels{i})
                            textStr = sprintf('%s\n%s', [obj.listOfChannels{i}{:}], 'on');
                        else
                            textStr = sprintf('%s\n%s', obj.listOfChannels{i}, 'on');
                        end
                    else
                        if iscell(obj.listOfChannels{2*end + 1 - i})
                            textStr = sprintf('%s\n%s', [obj.listOfChannels{2*end + 1 - i}{:}], 'off');
                        else
                            textStr = sprintf('%s\n%s', obj.listOfChannels{2*end + 1 - i}, 'off');
                        end
                    end
                    text(obj.gAxes, x, yLimits(2), textStr, ...
                                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle')
                end
            end
        end
    end
end