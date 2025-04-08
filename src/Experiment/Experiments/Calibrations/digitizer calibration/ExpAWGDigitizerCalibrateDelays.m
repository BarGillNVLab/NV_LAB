classdef ExpAWGDigitizerCalibrateDelays < ExperimentAWG
    %ExpCalibrateDelays Experiment for calibrating the delay times
    
    properties (Constant)
        NAME = 'Calibration_Delays';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        sampleRate                  % acquisition sample rate
        detectionDelay              % in us - The delay between detection periods.
        %detectionDuration          % in us - The duration of each detection period. (Defined in Experiment)
        detectionTimeShift          % in us - The shifts between detection periods.
        listOfChannels              % Cell array of channels, the channels will be turned on according to the order listed
        channelDelay                % in us - The delay between turning channels on and off. The first channel will be turned on after this time.
                                    % It is possible to indicate the on/off times of each channel, and then it should be a vector of length = 2 * length(listOfChannels).
        detectionStartStopOffset    % in us - How long before and after the seqeunce should the detection start and stop.
    end
    
    properties (Dependent = true)
        channelDelayFull
        time
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpAWGDigitizerCalibrateDelays()
            obj@ExperimentAWG(ExpCalibrateDelays.NAME);
            obj.parameterName = 'time';
            
            % Set properties inherited from Experiment
            obj.frequency = 2756;           % in MHz
            obj.amplitude = -10;            % in dBm
            
            obj.repeats = 100;
            obj.averages = 100;
            obj.isTracking = 0;             % Initialize tracking
            obj.trackThreshhold = 0.7;
            obj.shouldAutosave = true;
            obj.fixDelays = 0;              % Do not fix delays for this experiment!
            
            digi = getObjByName(Digitizer.NAME);
            obj.sampleRate = digi.MAX_SAMPLE_RATE;
            
            % obj.listOfChannels = {'greenLaser'};
            % obj.listOfChannels = {'greenLaser', 'trigger', 'MW' };
            obj.listOfChannels = {'greenLaser', 'MW', 'trigger' };
            obj.channelDelay = 1;
            obj.detectionStartStopOffset = 1;
            % In case of 'trigger' channel - the AWG waveform will be from 'trigger' on to 'trigger' off

            obj.displayType1 =  'Normal';
            obj.displayType2 =  'Alt (One Color)';
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'kcps', obj.NAME);
        end
    end
    
    %% Setters & Getters
    methods
        function channelDelayFull = get.channelDelayFull(obj)
            channelDelayFull = obj.channelDelay .* ones(1, length(obj.listOfChannels));
        end
        
        function time = get.time(obj)
            dt = 1/obj.sampleRate;
            time = 0 : dt : obj.detectionDuration-dt;
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
            totalParamNum = length(obj.time);
        end
    end
    
    %% Overridden from Experiment
    methods (Access = protected)        
        function prepare(obj)
            % Initializtions before run
            obj.detectionDuration = 2*obj.detectionStartStopOffset + sum(obj.channelDelayFull) + sum(obj.channelDelayFull(1:end-1));
            obj.detectionDuration = round(obj.detectionDuration, 2);
            obj.referenceDetectionDuration = obj.detectionDuration;
            obj.detectionPeriodsPerRepeat = 1;
            obj.runsPerPerform = 1;
            
            obj.digitizerFullDataAcquisition = true;
            
            % Sequence
            %%% Useful parameters for what follows
            %%% Creating the sequence s        

            S = Sequence;
            S.addEvent(obj.detectionStartStopOffset, 'detector');               % trigger for start acqisition
            for i = 1 : 1 : length(obj.listOfChannels)
                S.addEvent(obj.channelDelayFull(i), obj.listOfChannels(1:i));
            end
            for i = length(obj.listOfChannels)-1 : -1 : 1
                S.addEvent(obj.channelDelayFull(i), obj.listOfChannels(1:i));
            end
            S.addEvent(obj.detectionStartStopOffset, '');
            S.addEvent(5, '');  % required time for the digitizer to be ready for next meas
            obj.prepareInternal(S)
            

            if any(contains(obj.listOfChannels, 'trigger'))
                obj.LoadAWG;
            end

            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.time;
        end
        
        function LoadAWG(obj)
            ind = find(strcmp(obj.listOfChannels, 'trigger'));
            if ind == length(obj.channelDelayFull)
                WFtime = obj.channelDelayFull(end);
            else
                WFtime = obj.channelDelayFull(ind:end-1) * 2 + obj.channelDelayFull(end);
            end
            WFtime = obj.RoundDurationByFrequencies(WFtime, obj.frequency);
            obj.AWG.ResetStoredData;
            obj.AWG.workChannels = 1:obj.nChannels;
            obj.AWG.setAmplitude(obj.amplitude);
            obj.AWG.ChangeSampleRate(WFtime);
            
            driveIndexWF = zeros(1, obj.nChannels);
            initZeroIndex = zeros(1, obj.nChannels);

            % creating waveforms:
            A = obj.AWG.MaxNormPowerAllowed;
            w = 2*pi*obj.frequency;
            
            [prePulseTime, phase] = obj.channelsDifference;
            for chan = 1:obj.nChannels
                f = @(t) 0 * t;
                initZeroIndex(chan) = obj.AWG.AddWaveformByFunction(f, prePulseTime(chan), 0);
                f = @(t) A(chan) * cos(w*t - phase(chan));
                driveIndexWF(chan) = obj.AWG.AddWaveformByFunction(f, WFtime, 0);
            end
            obj.AWG.LoadWaveform();
            
            obj.indexSeq = zeros(1, obj.nChannels);
            for chan = 1:obj.nChannels
                obj.indexSeq(chan) = obj.AWG.AddSequence([initZeroIndex(chan), driveIndexWF(chan)], [1 1], [1 0]);
            end
            obj.AWG.LoadSequence()
        end
        
        function perform(obj)
            %%% Initialization

            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
            if isempty(tracker); throwBaseObjException(Tracker.NAME); end

            success = false;

            if any(contains(obj.listOfChannels, 'trigger'))
                for i = 1:length(obj.activeChannels)
                    obj.AWG.assignSequence(obj.indexSeq(i), obj.activeChannels(i));
                end
                obj.AWG.Run;
            end
            
            for trial = 1 : 5
                if obj.checkEmergencyStop()
                    return;
                end
                try
                    data = obj.getRawData(pg, spcm);
                    data = data';
                    data = data(:)';
                    [sig, sterr] = obj.processData(data);

                    obj.signal(1, :, obj.currIter) = sig;
                    obj.sterr(1, :, obj.currIter) = sterr;

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