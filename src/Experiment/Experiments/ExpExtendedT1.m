classdef ExpExtendedT1 < Experiment
    %ExpExtendedT1 T1 experiment between +-1
    % First frequency is for first frequency generator (channel 'MW') and is for
    % transition to 1.
    
    properties (Constant)
        NAME = 'ExtendedT1';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency           % in MHz
        amplitude           % in dBm
        
        tau                 % in us
        piTime              % in us
        singletDelay        % in us. Delay between Laser and MW
        readDelay           % in us. Delay between MW and readout
        
        startReadPairs      % pairs of states: {[0,1], [-1,1]};
        
        constantTime        % logical
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpExtendedT1(FGs)
            obj@Experiment(ExpExtendedT1.NAME);
            obj.parameterName = 'taus';
            
            % First, get a frequency generator
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
            obj.repeats = 5000;
            obj.averages = 1000;
            obj.MWChannel = {'MW', 'MW2'};  % mw channels to use, set by default to MW and MW2.
            
            % First frequency, amplitude and piTime are for first frequency
            % generator and for (channel 'MW').
            % This is for the transition to 1;
            obj.frequency = 2870;           % in MHz, should be vector of size two for both frequenices when needed
            obj.amplitude = 0;              % in dBm, should be vector of size two for both amplitudes when needed
            obj.tau = 0.1:40:2000;          % in us
            obj.piTime = 0.05;              % in us, should be vector of size two for both pi times when needed
            obj.singletDelay = 1;
            obj.readDelay = 1;
            obj.startReadPairs = {[1, 0], [1, 1], [1, -1]};
            obj.WindFreakChannels;

            obj.constantTime = true;        % logical
            % For T1, constantTime is added at the end, after detection! so
            % it is ok :)
            
            obj.detectionDuration = 0.25;           % detection window, in us
            obj.referenceDetectionDuration = 5;     % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;   % laser initialization in pulsed experiments in us
            
            obj.displayType1 = '1st Pair';
            obj.displayType2 = 'All Pairs';
            obj.isPlotAlternateAvailable = true;
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
        end
    end
    
    %% Setters
    methods
        function set.frequency(obj, newVal) % newVal is in MHz
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
        
        function set.startReadPairs(obj, newVal)
            % If we got here, then newVal is OK.
            obj.startReadPairs = newVal;
            obj.changeFlag = true;
        end
        
        function set.piTime(obj, newVal)
            checkTimeVector(obj, newVal)
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
        
        function set.readDelay(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.readDelay = newVal;
            obj.changeFlag = true;
        end
    end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.tau);
        end
    end
    
    %% Overridden from Experiment
    methods (Access = protected)
       function prepare(obj)
            % Initializtions before run
            
            % Sequence
            %%% Useful parameters for what follows
            initDuration = obj.laserInitializationDuration-obj.detectionDuration-obj.referenceDetectionDuration;
            numberOfPermutations = length(obj.startReadPairs);
            obj.detectionPeriodsPerRepeat = 2 * numberOfPermutations;
            obj.runsPerPerform = 1;
            
            %%% Creating the sequence
            S = Sequence;
            for k = 1:numberOfPermutations
                startReadPair = obj.startReadPairs{k};
                startFrom = startReadPair(1);
                readFrom = startReadPair(2);
                S.addEvent(Experiment.DEFAULT_LAST_DELAY,           '',     'lastDelay');   % Last delay move to the beggining of the sequence - rotem 12.10.21
                S.addEvent(obj.laserInitializationDuration,        'greenLaser');                                  % Initialization
%                 if obj.constantTime %commented out - rotem 12.10.21
% %                     S.addEvent(obj.laserInitializationDuration,             'greenLaser');  % Initialization
%                 end
                switch startFrom
                    case 0
                        % Nothing
                    case 1
                        S.addEvent(obj.singletDelay,        '',                         'singletDelay');         % Singlet Delay
                        S.addEvent(obj.piTime(1),  obj.MWChannel{1},                    'initPulse');   % MW
                    case -1
                        S.addEvent(obj.singletDelay,        '',                         'singletDelay');
                        S.addEvent(obj.piTime(2),  obj.MWChannel{2},                   'initPulse');   % MW
                end

                S.addEvent(obj.tau(end),        '',                         'tau');         % Delay
                switch readFrom
                    case 0
                        S.addEvent(obj.piTime(1),  '',                    'equalPiDelay');     % add delay to mach pi-pulse
                    case 1
                        S.addEvent(obj.piTime(1),  obj.MWChannel{1},                    'readPulse');   % MW
                    case -1
                        S.addEvent(obj.piTime(2),  obj.MWChannel{2},                   'readPulse');   % MW
                end
                S.addEvent(obj.readDelay,        '',                         'readDelay');           % before measurement delay
                S.addEvent(obj.detectionDuration,...
                    {'greenLaser', 'detector'});                                            % Detection
                S.addEvent(initDuration,        'greenLaser');                              % Initialization
                S.addEvent(obj.referenceDetectionDuration,...
                    {'greenLaser', 'detector'});                                            % Reference detection
%                 S.addEvent(Experiment.DEFAULT_LAST_DELAY,           '',     'lastDelay');   % Last delay
            end
            
            obj.prepareInternal(S)
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.tau;
            
            startReadPair = obj.startReadPairs{1};
            startFrom = startReadPair(1);
            readFrom = startReadPair(2);
            pairName = sprintf('%d --> %d', startFrom, readFrom);
            obj.signalParam.desc = pairName;
            
            obj.isPlotAlternateAvailable = (numberOfPermutations > 1);
        end
        
        function perform(obj)
            %%% Initialization
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
            if isempty(tracker); throwBaseObjException(Tracker.NAME); end
            
            % Some magic numbers
            maxLastDelay = Experiment.DEFAULT_LAST_DELAY + max(obj.tau);
            
            %%% Run - Go over all tau's, in random order
            k = 0; %added by rotem 12.10.21
            f1 = []; %added by rotem 12.10.21
            for t = randperm(length(obj.tau))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue
                end
                success = false;
                f1 = [f1, t]; %added by rotem 12.10.21
                k = k + 1; %added by rotem 12.10.21
                
                for trial = 1 : 5
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        pg.changeSequence('tau', 'duration', obj.tau(t));
                        if obj.constantTime
                            pg.changeSequence('lastDelay', 'duration', maxLastDelay - obj.tau(t));
                        end
                        data = obj.getRawData(pg, spcm);
                        
                        % added by rotem 12.10.21 %
                        if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                            [sig, sterr] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(k-1)+1:end));%obj.detectionPeriodsPerRepeat*obj.repeats*k));
                        else
                            [sig, sterr] = obj.processData(data);
                        end
                        
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
                    obj.emergencyStop
                    return
                end
            end
            
            % added by rotem 12.10.21 %
            if length(data) == obj.detectionPeriodsPerRepeat*obj.repeats*obj.getTotalNumberOfParams %if true we're proccessing data at the end of the average
                for k = 1:length(obj.tau)
                    [obj.signal(:, f1(k), obj.currIter), obj.sterr(:, f1(k), obj.currIter)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(k-1)+1:obj.detectionPeriodsPerRepeat*obj.repeats*k));
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
        end
        
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results and fit from it
            % the coherence time.
            
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
                params = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
                return
            end
            
            dataParam2Plus = cell(1, length(obj.startReadPairs)-1);
            for i = 2:length(obj.startReadPairs)
                S1 = squeeze(obj.signal(2*i-1, :, 1:obj.currIter));
                S1sterr = squeeze(obj.sterr(2*i-1, :, 1:obj.currIter));
                S2 = squeeze(obj.signal(2*i, :, 1:obj.currIter));
                S2sterr = squeeze(obj.sterr(2*i, :, 1:obj.currIter));
            
                [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);
                startReadPair = obj.startReadPairs{i};
                startFrom = startReadPair(1);
                readFrom = startReadPair(2);
                pairName = sprintf('%d --> %d', startFrom, readFrom);
                dataParam2Plus{i-1} = ExpResultDoubleVector('FL', value, sterr, 'Normalized', obj.NAME, pairName);
            end
            dataParam = obj.signalParam;
            params = {dataParam, dataParam2Plus, {'yParam', 'yParam2+'}};
        end
    end
end