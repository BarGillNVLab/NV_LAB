classdef ExpExtendedCoherentControl < Experiment
    %EXPECHO Echo experiment

    properties (Constant)
        NAME = 'ExtendedCoherentControl';
        XY4_PULSES = {'X', 'Y', 'Y', 'X'};
        XY8_PULSES = {'X', 'Y', 'X', 'Y', 'Y', 'X', 'Y', 'X'};
        XY12_PULSES = {'X', 'Y', 'X', 'Y','X', 'Y', 'Y', 'X', 'Y', 'X', 'Y', 'X',};
        % CPMG={'Y', 'Y', 'Y', 'Y'}
        CPMG = {'Y'};
        
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
        constantTime        % logical
        doubleMeasurement   % logical
        useIQ               % logical
        xyMeas
        lastPhase
        pulsesMode

        MWChannel_detuned   % list of MW channels used for detuned driving
        piTime_detuned      % in us
        startReadPairs      % pairs of states: {[0,1], [-1,1]};
        useThreeHalvePi
        experimentType 
        ddType
        ddPhase
        addHalfPi
    end

    properties (Hidden)
        maxLastDelay
        amplitudeInternal
        phaseInternal
        ddSeq
        privateSequencesFreq    % list of cells, each cell containing all frequencies for a sequence
        privateSequencesAmp     % list of cells, eahc cell containing all amplitudes for a sequence
        privateSequencesPhase   % list of cells, each cell containing all phases for a sequence
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpExtendedCoherentControl(MWChannel)
            obj@Experiment(ExpExtendedCoherentControl.NAME);
            obj.parameterName = 'taus';
            
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
            obj.repeats = 5000;
            obj.averages = 1000;
            
            obj.frequency = 3029;                   % in MHz
            obj.amplitude = -10;                    % in dBm
            obj.tau = 10;                           % in us
            obj.halfPiTime = 0.025;                 % in us
            obj.piTime = 0.05;                      % in us
            obj.threeHalvesPiTime = 0.075;          % in us
            obj.cycles = 8:8:200;                   % number of pi pulses
            obj.constantTime = false;               % logical
            obj.doubleMeasurement = true;           % logical
            obj.useIQ = true;                       % logical
            obj.xyMeas = 1;
            obj.lastPhase = 'X';                    % 'X' or 'Y'
            obj.pulsesMode='CPMG-n';                % CPMG-n or XY-n

            obj.useThreeHalvePi = 0;                    % use 3*pi/2 instead of phases for readout
            obj.experimentType = 'echo';                        % the experiment we want to run
            obj.addHalfPi = true;

            obj.detectionDuration = 0.25;           % detection window, in us
            obj.referenceDetectionDuration = 5;     % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;   % laser initialization in pulsed experiments in us
            % obj.privateSequences = cell(1,length(obj.cycles));
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
            checkTimeVector(obj, newVal)
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
            switch lower(obj.parameterName)
                case 'taus'
                    totalParamNum = length(obj.tau);
                case 'cycles'
                    totalParamNum = length(obj.cycles);
            end
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
        function pulsePhase = xy2phase(obj, xyPhase, numPhase)
            switch upper(xyPhase)
                case 'Y'
                    pulsePhase = {[pi/4, -pi/4]}; % {[pi/2, 0]}; % {[pi/2, -pi/2]};
                case 'X'
                    pulsePhase = {[0, 0]};
                case '-Y'
                    pulsePhase = {[-pi/4, pi/4]}; % {[0, pi/2]}; % {[-pi/2, pi/2]};
                case '-X'
                    pulsePhase = {[pi/2, -pi/2]}; % {[pi, 0]};
                case 'PHI'
                    pulsePhase = {};
                otherwise
                    error('Pulse type can be either "+/-X", "+/-Y" or a user supplied "PHI"')
            end

            % phase relations
            % [pi/4, -pi/4] -> carrier: 0, envelope: pi/4
            % [-pi/4, pi/4] -> carrier: 0, envelope: -pi/4
            % [3pi/4, pi/4] -> carrier: pi/2, envelope: pi/4
            % [pi/4, 3pi/4] -> carrier: pi/2, envelope: -pi/4
            % [pi/2, 0] -> carrier: pi/4, envelope: pi/4
            % [0, pi/2] -> carrier: pi/4, envelope: -pi/4
            % [pi, 0] -> carrier: pi/2, envelope: pi/2
            % [0, pi] -> carrier: pi/2, envelope: -pi/2
            % [pi/2, -pi/2] -> carrier: 0, envelope: pi/2
            % [-pi/2, pi/2] -> carrier: 0, envelope: -pi/2
        end

        function changeSequence(obj, idx)
            % Devices
            sg = getObjByName(SignalGenerator.NAME);
            pg = getObjByName(PulseGenerator.NAME);

            switch lower(obj.parameterName)
                case 'taus'
                    % change sequence in the pulse generator
                    if ~isempty(obj.sequencesList)
                        sg.setSequence(idx, obj.MWChannel);
                        pg.setSequence(obj.sequencesList{idx});
                    else
                        pg.changeSequence('tau', 'duration', obj.tau(idx));
                        if strcmpi(obj.experimentType, 'dd-tau')
                            pg.changeSequence('half-tau', 'duration', obj.tau(idx)/2);
                        end
                        if obj.constantTime
                            if strcmpi(obj.experimentType, 'echo')
                                pg.changeSequence('lastDelay', 'duration', obj.maxLastDelay - 2*obj.tau(idx));
                            elseif strcmpi(obj.experimentType, 'dd-tau')
                                % pg.changeSequence('lastDelay', 'duration', obj.maxLastDelay - obj.cycles(end)*obj.tau(idx));
                                pg.changeSequence('lastDelay', 'duration', obj.maxLastDelay - obj.cycles(end)*obj.tau(idx)/2); % adding a piZ pulse during the lastDelay
                            else
                                pg.changeSequence('lastDelay', 'duration', obj.maxLastDelay - obj.tau(idx));
                            end
                        end
                        obj.privateSequencesFreq{idx} = obj.privateSequencesFreq{1};
                        obj.privateSequencesAmp{idx} = obj.privateSequencesAmp{1};
                        obj.privateSequencesPhase{idx} = obj.privateSequencesPhase{1};
                    end
                case 'cycles'
                    if ~isempty(obj.sequencesList)
                        sg.setSequence(idx, obj.MWChannel);
                        pg.setSequence(obj.sequencesList{idx});
                    elseif idx > 1 % for idx == 1 we already created the sequence in prepare
                        numOfSequences = obj.detectionPeriodsPerRepeat/2;
                        S = pg.sequence;

                        S1 = Sequence;
                        S1.addEvent(obj.tau(end), '', 'tau'); % do we need it?
                        % for i = 1:obj.cycles(idx)-1 % -1 because in prepare() we already created one cycle
                            S1.addSequenceAtGivenTime(obj.ddSeq.sequence);
                            % if i < obj.cycles(idx)-1
                            %     S1.addEvent(obj.tau(end), '', 'tau')
                            % end
                        % end
                        % S1.addEvent(obj.tau(end), '', 'tau'); % do we need it?
                        
                        % let's make sure that we remove 'start-tau' and
                        % 'end-tau' nicknames 
                        % for i = 1:length(S1.pulses)
                        %     S1.pulses(i).nickname = '';
                        % end

                        % we need to find how many mw pulses we have so we
                        % can insert the frequencies, amplitudes and phases
                        % to obj.privateSequence___
                        [pulses, pulseIndexes, pulseTimes] = S.getPulsesByChannel(obj.MWChannel{1}); % get pulses for empty channels (tau)
                        startTauIdx = S.indexFromNickname('start-tau'); % index for the first pulse of the dd sequence
                        firstPulseIdx = arrayfun(@(x) sum(pulseIndexes < x), startTauIdx);
                        
                        endTauIdx = S.indexFromNickname('end-tau'); % index for the last pulse of the dd sequence
                        lastPulseIdx = arrayfun(@(x) sum(pulseIndexes < x), endTauIdx);
                        % lastPulseIdx
                        % numberOfFrequencyPulses = lastPulseIdx - length(pulses(1:lastPulseIdx));
                        % numberOfDDPulses = length(obj.ddSeq.sequence.pulses);

                        % now we add the experiment parameters between all
                        % other parameters

                        obj.privateSequencesFreq{idx} = obj.privateSequencesFreq{idx-1};
                        obj.privateSequencesAmp{idx} = obj.privateSequencesAmp{idx-1};
                        obj.privateSequencesPhase{idx} = obj.privateSequencesPhase{idx-1};
                        
                        for i = 2:-1:1
                            obj.privateSequencesFreq{idx}{1} = [obj.privateSequencesFreq{idx}{1}{1:lastPulseIdx(i)}, obj.ddSeq.frequency, obj.privateSequencesFreq{idx}{1}{lastPulseIdx(i)+1:end}];
                            obj.privateSequencesAmp{idx}{1} = [obj.privateSequencesAmp{idx}{1}{1:lastPulseIdx(i)}, obj.ddSeq.amplitude, obj.privateSequencesAmp{idx}{1}{lastPulseIdx(i)+1:end}];
                            obj.privateSequencesPhase{idx}{1} = [obj.privateSequencesPhase{idx}{1}{1:lastPulseIdx(i)}, obj.ddSeq.phase, obj.privateSequencesPhase{idx}{1}{lastPulseIdx(i)+1:end}];
                            % obj.privateSequencesFreq{idx}{1} = [obj.privateSequencesFreq{1}{1}{1:firstPulseIdx(i)}, repmat(obj.ddSeq.frequency, 1, obj.cycles(idx)), obj.privateSequencesFreq{1}{1}{lastPulseIdx(i)+1:end}];
                            % obj.privateSequencesAmp{idx}{1} = [obj.privateSequencesAmp{1}{1}{1:firstPulseIdx(i)}, repmat(obj.ddSeq.amplitude, 1, obj.cycles(idx)), obj.privateSequencesAmp{1}{1}{lastPulseIdx(i)+1:end}];
                            % obj.privateSequencesPhase{idx}{1} = [obj.privateSequencesPhase{1}{1}{1:firstPulseIdx(i)}, repmat(obj.ddSeq.phase, 1, obj.cycles(idx)), obj.privateSequencesPhase{1}{1}{lastPulseIdx(i)+1:end}];
                            startTime = S.duration(endTauIdx(i)-1); % adding the DD sequence before the end-tau
                            S.addSequenceAtGivenTime(S1, startTime);
                        end

                        
                        % startTime = sum([S.pulses(1:endTauIdx(1)).duration]);
                        % 
                        % S.addSequencesAtGivenTime(S1, startTime)

                        
                    end
                    if obj.constantTime % do we need it?
                        pg.changeSequence('lastDelay', 'duration', obj.maxLastDelay - obj.cycles(idx)*obj.ddSeq.sequence.duration);
                    end
            end
        end

        function ddSeq = createSequence(obj, cycles, ddType, ddPhases)
            ddName = ddType{1};
            switch lower(ddName)
                case 'cpmg-n'
                    xyPulses = obj.CPMG;
                    m = 1;
                case 'xy-4'
                    xyPulses = obj.XY4_PULSES;
                    m = 4;
                case 'xy-8'
                    xyPulses = obj.XY8_PULSES;
                    m = 8;
                case 'xy-12'
                    xyPulses = obj.XY12_PULSES;
                    m = 12;
                case 'manual'
                    xyPulses = ddType{2}; % a cell array containing either X, Y or PHI for the phases. If the cell contains 'PHI', the user needs to supply the phases.
                    m = length(ddType{2});

                    if isempty(ddPhases)
                        error('DD phases are missing to create the sequence!')
                    elseif length(ddPhases) > 1 && length(ddType{2}) ~= length(ddPhases)
                        error('The number of DD pulses and phases don''t match!')
                    elseif isscalar(ddPhases)
                        ddPhases = ddPhases .* ones(xyPulses);
                    end

                otherwise
                    error('Dynamical Decoupling sequence unknown. Please either choose a known sequence or ''manual'' to supply your own sequence.')
            end
            if ~exist('ddPhases') || isempty(ddPhases)
                ddPhases = xyPulses;
            end
            
            ddSeq.frequency = {};
            ddSeq.amplitude = {};
            ddSeq.phase = {};
            

            ddSeq.sequence = Sequence;

            for i = 1:length(xyPulses)*cycles
                ddSeq.sequence.addEvent(obj.piTime_detuned, obj.MWChannel_detuned, xyPulses{mod(i, m)+1})
                pulsePhase = obj.xy2phase(xyPulses{mod(i, m)+1}, ddPhases{mod(i, m)+1});
                ddSeq.frequency = [ddSeq.frequency, obj.frequency{1}(2)];
                ddSeq.amplitude = [ddSeq.amplitude, obj.amplitude{1}(2)];
                ddSeq.phase = [ddSeq.phase, pulsePhase];
                
                if i < length(xyPulses)*cycles % we wan't to add another tau only if we have another pulse afterwards
                    ddSeq.sequence.addEvent(obj.tau(end), '', 'tau');
                end
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
            numberOfPermutations = length(obj.startReadPairs);
            obj.detectionPeriodsPerRepeat = 2 * numberOfPermutations * (1 + double(obj.doubleMeasurement));
            obj.runsPerPerform = 1;

            if obj.useAWG
                obj.MWChannel_detuned = obj.MWChannel;
                obj.MWChannel = {obj.MWChannel{1}, obj.MWChannel{1}};
                if ~obj.isRunning % saving the parameters to an internal parameter only before the experiment starts
                    obj.frequencyInternal = obj.frequency;
                    obj.amplitudeInternal = obj.amplitude;
                    obj.phaseInternal = obj.phase;
                end
            end

            obj.privateSequencesFreq = cell(length(obj.cycles),1);
            obj.privateSequencesAmp = cell(length(obj.cycles),1);
            obj.privateSequencesPhase = cell(length(obj.cycles),1);
            sequenceFrequencies = {};
            sequenceAmplitudes = {};
            sequencePhases = {};
            S = Sequence;
            for j = 1:numberOfPermutations
                startReadPair = obj.startReadPairs{j};
                startFrom = startReadPair(1);
                readFrom = startReadPair(2);

                if any(strcmpi(obj.experimentType, {'t1', 't1-piz'}))
                    S.addEvent(Experiment.DEFAULT_LAST_DELAY*obj.detectionPeriodsPerRepeat/2,   '',             'lastDelay');       % Last delay
                    S.addEvent(obj.laserInitializationDuration, 'greenLaser');                      % Initialization
                end

                for k = 1:1+obj.doubleMeasurement
                                       
                    
                    switch startFrom
                        case 0
                            % Nothing
                        case 1
                            S.addEvent(obj.piTime(1), obj.MWChannel{1});
                            sequenceFrequencies = [sequenceFrequencies, obj.frequency{1}(1)];
                            sequenceAmplitudes = [sequenceAmplitudes, obj.amplitude{1}(1)];
                            sequencePhases = [sequencePhases, obj.phase{1}(1)];
                        case -1
                            S.addEvent(obj.piTime(2), obj.MWChannel{2});
                            sequenceFrequencies = [sequenceFrequencies, obj.frequency{1}(3)];
                            sequenceAmplitudes = [sequenceAmplitudes, obj.amplitude{1}(3)];
                            sequencePhases = [sequencePhases, obj.phase{1}(3)];
                        case 2
                            % Nothing, but can be used to create an equal pre-pulse to match the timing when applying an mw field
                    end

                    if obj.addHalfPi
                        S.addEvent(0.05,                       '',                  '');

                        S.addEvent(obj.halfPiTime,                  obj.MWChannel_detuned);
                        sequenceFrequencies = [sequenceFrequencies, obj.frequency{1}(2)];
                        sequenceAmplitudes = [sequenceAmplitudes, obj.amplitude{1}(2)];
                        sequencePhases = [sequencePhases, obj.phase{1}(2)];
                    end

                    switch lower(obj.experimentType)
                        case 'ramsey'
                            obj.parameterName = 'taus';

                            S.addEvent(obj.tau(end), '', 'tau');
                        case 'echo'
                            obj.parameterName = 'taus';

                            S.addEvent(obj.tau(end), '', 'tau');

                            S.addEvent(obj.piTime_detuned, obj.MWChannel_detuned);
                            sequenceFrequencies = [sequenceFrequencies, obj.frequency{1}(2)];
                            sequenceAmplitudes = [sequenceAmplitudes, obj.amplitude{1}(2)];
                            sequencePhases = [sequencePhases, obj.phase{1}(2)];

                            S.addEvent(obj.tau(end), '', 'tau');
                        case 't1'
                            obj.parameterName = 'taus';

                            S.addEvent(obj.tau(end),        '',                         'tau');
                        case 't1-piz'
                            obj.parameterName = 'taus';

                            S.addEvent(obj.tau(end)/2, '', 'tau');

                            S.addEvent(obj.halfPiTime, obj.MWChannel_detuned, 'X');
                            S.addEvent(obj.piTime_detuned, obj.MWChannel_detuned, 'Y');
                            S.addEvent(obj.halfPiTime, obj.MWChannel_detuned, '-X');

                            sequenceFrequencies = [sequenceFrequencies, obj.frequency{1}(2), obj.frequency{1}(2), obj.frequency{1}(2)];
                            sequenceAmplitudes = [sequenceAmplitudes, obj.amplitude{1}(2), obj.amplitude{1}(2), obj.amplitude{1}(2)];
                            sequencePhases = [sequencePhases, {[0,0]}, {[pi/4, -pi/4]}, {[pi/2, -pi/2]}];

                            S.addEvent(obj.tau(end)/2, '', 'tau');

                        case 'dd'
                            % In this case obj.tau is a scalar and obj.cycles is a vector to run over
                            obj.parameterName = 'cycles';

                            S.addEvent(obj.tau(end)/2, '', 'start-tau');

                            obj.ddType = {obj.pulsesMode};
                            obj.ddSeq = obj.createSequence(obj.cycles(1), obj.ddType, obj.ddPhase);
                            sequenceFrequencies = [sequenceFrequencies, obj.ddSeq.frequency];
                            sequenceAmplitudes = [sequenceAmplitudes, obj.ddSeq.amplitude];
                            sequencePhases = [sequencePhases, obj.ddSeq.phase];
                            S.addSequenceAtGivenTime(obj.ddSeq.sequence)

                            S.addEvent(obj.tau(end)/2, '', 'end-tau');
                        case 'dd-tau'
                            % In this case obj.cycles is a scalar and obj.tau is a vector to run over
                            obj.parameterName = 'taus';

                            S.addEvent(obj.tau(end)/2, '', 'half-tau');

                            obj.ddType = {obj.pulsesMode};
                            obj.ddSeq = obj.createSequence(obj.cycles(end), obj.ddType, obj.ddPhase);
                            sequenceFrequencies = [sequenceFrequencies, obj.ddSeq.frequency];
                            sequenceAmplitudes = [sequenceAmplitudes, obj.ddSeq.amplitude];
                            sequencePhases = [sequencePhases, obj.ddSeq.phase];
                            S.addSequenceAtGivenTime(obj.ddSeq.sequence)

                            S.addEvent(obj.tau(end)/2, '', 'half-tau');
                    end

                    if obj.addHalfPi
                        if k == 1 % first measurement in the double measurement
                            S.addEvent(obj.halfPiTime,                  obj.MWChannel_detuned);
                            sequenceFrequencies = [sequenceFrequencies, obj.frequency{1}(2)];
                            sequenceAmplitudes = [sequenceAmplitudes, obj.amplitude{1}(2)];
                            pulsePhase = obj.xy2phase(obj.lastPhase);
                            sequencePhases = [sequencePhases, pulsePhase];
                        else % second measurement in the double measurement
                            if ~obj.useThreeHalvePi
                                S.addEvent(obj.halfPiTime,                  obj.MWChannel_detuned);
                                sequenceFrequencies = [sequenceFrequencies, obj.frequency{1}(2)];
                                sequenceAmplitudes = [sequenceAmplitudes, obj.amplitude{1}(2)];
                                pulsePhase = obj.xy2phase(['-', obj.lastPhase]);
                                sequencePhases = [sequencePhases, pulsePhase];
                            else
                                S.addEvent(obj.threeHalvesPiTime,   obj.MWChannel_detuned);                         % MW in -x
                                sequenceFrequencies = [sequenceFrequencies, obj.frequency{1}(2)];
                                sequenceAmplitudes = [sequenceAmplitudes, obj.amplitude{1}(2)];
                                pulsePhase = obj.xy2phase(obj.lastPhase);
                                sequencePhases = [sequencePhases, pulsePhase];
                            end
                        end

                        S.addEvent(0.05,                       '',                  '');
                    end

                    switch readFrom
                        case 0
                            % Nothing
                        case 1
                            S.addEvent(obj.piTime(1), obj.MWChannel{1});
                            sequenceFrequencies = [sequenceFrequencies, obj.frequency{1}(1)];
                            sequenceAmplitudes = [sequenceAmplitudes, obj.amplitude{1}(1)];
                            sequencePhases = [sequencePhases, obj.phase{1}(1)];
                        case -1
                            S.addEvent(obj.piTime(2), obj.MWChannel{2});
                            sequenceFrequencies = [sequenceFrequencies, obj.frequency{1}(3)];
                            sequenceAmplitudes = [sequenceAmplitudes, obj.amplitude{1}(3)];
                            sequencePhases = [sequencePhases, obj.phase{1}(3)];
                        case 2
                            % Nothing, but can be used to create an equal pre-pulse to match the timing when applying a mw field
                    end

                    if ~any(strcmpi(obj.experimentType, {'t1', 't1-piz', 'dd-tau'}))
                        S.addEvent(Experiment.DEFAULT_LAST_DELAY*obj.detectionPeriodsPerRepeat/2,   '',             'lastDelay');       % Last delay
                    end
                    if strcmpi(obj.experimentType, 'dd-tau')
                        S.addEvent(Experiment.DEFAULT_LAST_DELAY*obj.detectionPeriodsPerRepeat/4,   '',             'lastDelay');       % Last delay

                        S.addEvent(obj.halfPiTime, obj.MWChannel_detuned, 'X');
                        S.addEvent(obj.piTime_detuned, obj.MWChannel_detuned, 'Y');
                        S.addEvent(obj.halfPiTime, obj.MWChannel_detuned, '-X');

                        sequenceFrequencies = [sequenceFrequencies, obj.frequency{1}(2), obj.frequency{1}(2), obj.frequency{1}(2)];
                        sequenceAmplitudes = [sequenceAmplitudes, obj.amplitude{1}(2), obj.amplitude{1}(2), obj.amplitude{1}(2)];
                        sequencePhases = [sequencePhases, {[0,0]}, {[pi/4, -pi/4]}, {[pi/2, -pi/2]}];

                        S.addEvent(Experiment.DEFAULT_LAST_DELAY*obj.detectionPeriodsPerRepeat/4,   '',             'lastDelay');       % Last delay
                    end
                    S.addEvent(obj.detectionDuration,...
                        {'greenLaser', 'detector'});        % Detection
                    S.addEvent(initDuration,                    'greenLaser');                      % Initialization
                    S.addEvent(obj.referenceDetectionDuration,...
                        {'greenLaser', 'detector'});        % Reference detection
                end
            end
            obj.privateSequencesFreq{1} = {sequenceFrequencies};
            obj.privateSequencesAmp{1} = {sequenceAmplitudes};
            obj.privateSequencesPhase{1} = {sequencePhases};

            if obj.useAWG % this currently assumes we're using only one signal generator in this experiment
                obj.MWChannel = obj.MWChannel(1);
            end

            

            % Set parameter, for saving
            switch lower(obj.experimentType)
                case 'ramsey'
                    obj.mCurrentXAxisParam.value = obj.tau;
                    obj.maxLastDelay = Experiment.DEFAULT_LAST_DELAY*obj.detectionPeriodsPerRepeat/2 + max(obj.tau); % we multiply by obj.detectionPeriodsPerRepeat/2 to correct for the number of concatenated sequences
                case 'echo'
                    obj.mCurrentXAxisParam.value = 2*obj.tau;
                    obj.maxLastDelay = Experiment.DEFAULT_LAST_DELAY*obj.detectionPeriodsPerRepeat/2 + 2*max(obj.tau); % we multiply by obj.detectionPeriodsPerRepeat/2 to correct for the number of concatenated sequences
                case 't1'
                    obj.mCurrentXAxisParam.value = obj.tau;
                    obj.maxLastDelay = Experiment.DEFAULT_LAST_DELAY*obj.detectionPeriodsPerRepeat/2 + max(obj.tau); % we multiply by obj.detectionPeriodsPerRepeat/2 to correct for the number of concatenated sequences
                case 't1-piz'
                    obj.mCurrentXAxisParam.value = 2*obj.tau; % we have 2 taus in this sequences
                    obj.maxLastDelay = Experiment.DEFAULT_LAST_DELAY*obj.detectionPeriodsPerRepeat/2 + max(obj.tau); % we multiply by obj.detectionPeriodsPerRepeat/2 to correct for the number of concatenated sequences
                case 'dd'
                    obj.mCurrentXAxisParam.value = obj.cycles*obj.tau; % obj.cycles is a vector, obj.tau is a scalar
                    obj.maxLastDelay = Experiment.DEFAULT_LAST_DELAY*obj.detectionPeriodsPerRepeat/2 + obj.ddSeq.sequence.duration*max(obj.cycles) + obj.tau(end); % tau should be a scalar, we multiply by obj.detectionPeriodsPerRepeat/2 to correct for the number of concatenated sequences
                case 'dd-tau'
                    obj.mCurrentXAxisParam.value = obj.cycles*obj.tau; % obj.cycles is a scalar, obj.tau is a vector
                    % obj.maxLastDelay = Experiment.DEFAULT_LAST_DELAY*obj.detectionPeriodsPerRepeat/2 + obj.ddSeq.sequence.duration*obj.cycles(end) + obj.cycles(end)*max(obj.tau); % cycles should be a scalar, we multiply by obj.detectionPeriodsPerRepeat/2 to correct for the number of concatenated sequences
                    obj.maxLastDelay = ( Experiment.DEFAULT_LAST_DELAY*obj.detectionPeriodsPerRepeat/2 + obj.ddSeq.sequence.duration*obj.cycles(end) + obj.cycles(end)*max(obj.tau) ) / 2; % adding a piZ pulse in the lastDelay
            end

            obj.prepareInternal(S)

            obj.isPlotAlternateAvailable = obj.doubleMeasurement;
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
            
            %%% Run - Go over all experiment parameters, in random order
            if strcmp(obj.parameterName, 'taus')
                indices = randperm(length(obj.tau));
            elseif strcmp(obj.parameterName, 'cycles')
                indices = randperm(length(obj.cycles));
            end

            for t = indices
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
                        obj.changeSequence(t);
                        
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
                            obj.prepareInternal(obj.sequencesList{t}); % maybe the experiment task is deleted
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
            
            if obj.useAWG
                obj.frequency = obj.frequencyInternal;
                obj.amplitude = obj.amplitudeInternal;
                obj.phase = obj.phaseInternal;
            end
            
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

