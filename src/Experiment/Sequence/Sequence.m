classdef Sequence < handle
    %SEQUENCE Ordered set pulses, each with settings for a number of channels
    %   To be interpreted by a pulse generator (PulseBlaster or
    %   PulseStreamer).
    %   The set of sequences has the nice property of being closed under
    %   addition (concatenation). Multiplication by scalar is defined only
    %   for integers, as repeated addition.
    
    properties (Access = private)
        pulses = [];	% array of Pulses.
    end

    properties
        name
    end
    
    methods
        function obj = Sequence(varargin)
            % Optional input parameters: Pulses to create the Sequence with
            % This also acts as casting a pulse into a sequence
            obj@handle;
            isPulse = @(x) isa(x, 'Pulse');
            isInputValid = all(cellfun(isPulse, varargin));
            if isInputValid
                obj.pulses = [varargin{:}];
            else
                EventStation.anonymousWarning(['All inputs to Sequence constructor must be of class ''Pulse''! ', ...
                    'Sequence was created empty.'])
            end
        end
        
        % Get methods
        function time = duration(obj, idx)
            % Returns the seqeunce duration up to idx. If idx isn't
            % supplied, returns the full sequens duration.
            if ~exist('idx', 'var')
                idx = length(obj.pulses);
            end

            if isempty(obj.pulses)
                time = 0;
            else
                time = sum([obj.pulses(1:idx).duration]);
            end
        end
        
        function pulsesCopy = getPulses(obj)
            % Returns a copy of the pulses in the seqeunce
            pulsesCopy = obj.pulses;
            for i = 1:length(pulsesCopy)
                pulsesCopy(i) = pulsesCopy(i).copy;
            end
        end
        
        function timeVector = edgeTimes(obj)
            % Returns the start time of pulses. Normally, every pulse will
            % indicate a change in the on channels, but there might be
            % exceptions (for example, when a pulse is changed)
            timeVector = cumsum([obj.pulses.duration]);
            timeVector = [0 timeVector];    % By definition, we always have an edge at 0
        end
        
        function channelsStruct = perChannelEdgeTimes(obj)
            % Returns a structure which contains the channels' names,
            % number of pulses that the channel is active on, and their
            % start and end times.
            % The last entry will mark the empty pulses.
            channelsNames = obj.activeChannelNames();
            channelsNames{end+1} =  '';
            timeVector = edgeTimes(obj);
            channelsStruct = struct('name', channelsNames, ...
                'numOfPulses', 0, 'pulsesStartTime', [], 'pulsesEndTime', [], 'pulseNickname', {''});
            for i = 1:length(channelsNames)
                for j = 1:length(obj.pulses)
                    pulse = obj.pulses(j);
                    if i < length(channelsNames) && ... % last entry is empty pulses
                            any(strcmp(fieldnames(pulse.onChannels), channelsNames{i}))
                        pulseNumber = channelsStruct(i).numOfPulses + 1;
                        channelsStruct(i).numOfPulses = pulseNumber;
                        channelsStruct(i).pulsesStartTime = [channelsStruct(i).pulsesStartTime timeVector(j)];
                        channelsStruct(i).pulsesEndTime = [channelsStruct(i).pulsesEndTime timeVector(j+1)];
                        channelsStruct(i).pulseNickname{pulseNumber} = pulse.nickname;
                    elseif i == length(channelsNames) && isempty(fieldnames(pulse.onChannels))
                        pulseNumber = channelsStruct(i).numOfPulses + 1;
                        channelsStruct(i).numOfPulses = channelsStruct(i).numOfPulses + 1;
                        channelsStruct(i).pulsesStartTime = [channelsStruct(i).pulsesStartTime timeVector(j)];
                        channelsStruct(i).pulsesEndTime = [channelsStruct(i).pulsesEndTime timeVector(j+1)];
                        channelsStruct(i).pulseNickname{pulseNumber} = pulse.nickname;
                    end
                end
            end
            
            for i = 1:length(channelsStruct) - 1 % Go over all pulses and merge touching pulses
                j = 1;
                while j < channelsStruct(i).numOfPulses
                    if channelsStruct(i).pulsesEndTime(j) - channelsStruct(i).pulsesStartTime(j+1) >= -PulseGenerator.MINIMAL_TIME
                        channelsStruct(i).numOfPulses = channelsStruct(i).numOfPulses-1;
                        channelsStruct(i).pulsesStartTime = channelsStruct(i).pulsesStartTime([1:j, j+2:end]);
                        channelsStruct(i).pulsesEndTime = channelsStruct(i).pulsesEndTime([1:j-1, j+1:end]);
                        if ~strcmp(channelsStruct(i).pulseNickname{j}, channelsStruct(i).pulseNickname{j+1})
                            warning('Sequence:Merge:NicknameRemoved', 'Nickname lost while merging pulses');
                        end
                        channelsStruct(i).pulseNickname = channelsStruct(i).pulseNickname([1:j-1, j+1:end]);
                    else
                        j = j+1;
                    end
                end
            end
        end
        
        function names = nicknames(obj)
            % Returns a list (cell array) of valid nicknames in the
            % sequence.
            names = {obj.pulses.nickname};
            names = unique(names);
        end
        
        function channelNames = activeChannelNames(obj)
            % Returns a list (cell array) of channels used in this
            % sequence.
            channelNames = StructHelper.getUniqueFieldNames(obj.pulses.onChannels);
        end
    end

    %% Manage Pulses
    methods
        function addPulse(obj, pulse)
            % Adds a pulse at the end of the sequence.
            assert(isa(pulse, 'Pulse'))
            obj.pulses = [obj.pulses, pulse];
        end
        
        function addEvent(obj, duration, channelNames, optName)
            % Creates a pulse, and adds it at the end of the sequence.
            if exist('optName', 'var')
                p = Pulse(duration, channelNames, optName);
            elseif exist('channelNames', 'var')
                p = Pulse(duration, channelNames);
            else
                p = Pulse(duration);
            end

            addPulse(obj, p);
        end
        
        function addPulseAtGivenTime(obj, time, pulse)
            % Insert given pulse at required time. on channels will be a
            % union of the "old" on channels and the new on channels.
            % We might need to add a dummy pulse between the sequence and 
            % the new pulse.
            
            assert(isa(pulse, 'Pulse'))
            pulseDuration = pulse.duration;
            seqDuration = obj.duration;
            
            % Timeline visualization of cases:
            % (each vector of equal numbers represents a pulse)
            %                 0             seqDuration             0             seqDuration
            % obj = ----------|1112222211222|------------           |             |
            %                 |             |                       |             |
            %                time           |                       |             | sD+pD+t
            % (1): ----------4444-----------|------------  -->  ----|445512222211222|-----------
            %         time    |             |                       |             |        sD-t
            % (2): ---4444----|-------------|------------  -->  ----|4444-----1112222211222|----
            %                 |             |    time               |             |        t+pD
            % (3): -----------|-------------|----4444----  -->  ----|1112222211222-----4444|----
            %                 |           time                      |             | sD+pD-t
            % (4): -----------|-----------4444-----------  -->  ----|111222221126644|-----------
            %                 |        time                         |             |
            % (5): -----------|--------4444-|------------  -->  ----|1112226655222|-------------
            if time < 0 && pulseDuration > abs(time)                    % (1)
                [~, timedPulses, postPulses] = getPulsesByTimes(obj, 0, pulseDuration - abs(time));
                [prePulse, pulse] = pulse.split(pulseDuration - abs(time));
                newPulses = combinePulses(timedPulses, pulse);
                S = Sequence(prePulse) + Sequence(newPulses) + Sequence(postPulses);
                
            elseif time < 0 % && pulseDuration <= abs(time)             % (2)
                deadTime = abs(time) - pulseDuration;
                S = Sequence(pulse) + Sequence(Pulse(deadTime)) + obj;  % Sequence with the pulse, an "empty" interval, and the rest of the seqeunce
                
            elseif time >= seqDuration                                  % (3)
                deadTime = time-seqDuration;
                S = obj + Sequence(Pulse(deadTime)) + Sequence(pulse);  % The original seqeunce, a equence with an "empty" interval and the pulse
                
            elseif time + pulseDuration > seqDuration                   % (4)
                [prePulses, timedPulses, ~] = getPulsesByTimes(obj, time, seqDuration);
                [pulse, postPulse] = pulse.split(seqDuration - time);
                newPulses = combinePulses(timedPulses, pulse);
                S = Sequence(prePulses) + Sequence(newPulses) + Sequence(postPulse);
                
            else % time + pulseDuration <= seqDuration                  % (5)
                [prePulses, timedPulses, postPulses] = getPulsesByTimes(obj, time, time + pulseDuration);
                newPulses = combinePulses(timedPulses, pulse);
                S = Sequence(prePulses) + Sequence(newPulses) + Sequence(postPulses);
            end
            obj.pulses = S.pulses;
        end
        
        function addEventAtGivenTime(obj, time, duration, channelNames, nickname)
            % Creates a pulse, and adds it to the sequence at a given time.
            % On channels will be a union of the "old" on channels and the
            % new on channels.
            % Note that if a nickname is given, it'll be given to
            % everything happening during the time, including what was
            % there before.
            if exist('nickname', 'var')
                p = Pulse(duration, channelNames, nickname);
            else
                p = Pulse(duration, channelNames);
            end
            addPulseAtGivenTime(obj, time, p)
        end
        
        function squeezeInPulseAtGivenTime(obj, time, pulse)
            % Insert given pulse at required time ("squeeze" in between
            % other pulses). We might need to add a dummy pulse between the
            % the sequence and the new pulse.
            
            assert(isa(pulse, 'Pulse'))
            S = Sequence(pulse);    % Sequence of a single pulse
            pulseDuration = S.duration;
            seqDuration = obj.duration;
            % Timeline visualization of cases:
            % (each vector of equal numbers represents a pulse)
            %                 0             seqDuration             0             seqDuration
            % obj = ----------|1112222211222|------------           |             |
            %                 |             |                       |             |
            %                time           |                       |             |   sD+pD
            % (1): ----------4444-----------|------------  -->  ----|44441112222211222|---------
            %         time    |             |                       |             |        sD-t
            % (2): ---4444----|-------------|------------  -->  ----|4444-----1112222211222|----
            %                 |             |    time               |             |        t+pD
            % (3): -----------|-------------|----4444----  -->  ----|1112222211222-----4444|----
            %                 |           time                      |             |   sD+pD
            % (4): -----------|-----------4444-----------  -->  ----|11122222112444422|---------
            %                 |        time                         |             |   sD+pD
            % (5): -----------|--------4444-|------------  -->  ----|11122244442211222|---------
            if time <= 0 && pulseDuration >= abs(time)          % (1)
                S = S + obj;
            elseif time < 0 && pulseDuration < abs(time)        % (2)
                S0 = Sequence(Pulse(abs(time)-pulseDuration));  % Sequence of "empty" interval in between
                S = S + S0 + obj;
            elseif time > seqDuration                           % (3)
                S0 = Sequence(Pulse(time-seqDuration));         % Sequence of "empty" interval in between
                S = obj + S0 + S;
            else                                                % (4) & (5)
                [S1, S2] = obj.splitByTime(time);
                S = S1 + S + S2;
            end
            obj.pulses = S.pulses;
        end
        
        function squeezeEventAtGivenTime(obj, time, duration, channelNames, nickname)
            % Creates a pulse, and adds it to the sequence at a given time,
            % squeezing it in between current pulses.
            if exist('nickname', 'var')
                p = Pulse(duration, channelNames, nickname);
            else
                p = Pulse(duration, channelNames);
            end
            squeezeInPulseAtGivenTime(obj, time, p)
        end
        
        function change(obj, nickname, what, newValue)
            index = obj.indexFromNickname(nickname);
            p = obj.pulses(index);
            % Maybe p is an array of multiple pulses, and we are then
            % forced to use a loop to handle it.
            for i = 1:length(p)
                switch lower(what)
                    case {'duration'}
                        p(i).duration = newValue;  % setter will take care of validation
                    case {'channels'}
                        % Decision: for now, pulse enables adding or removing
                        % individual channels. This function, however, always
                        % removes everything, and then adds *only* the
                        % requested channels.
                        p(i).clear();
                        p(i).changeChannels(newValue);  % We assume, for now, only digital channels.
                    case {''}
                        warning('Nothing to change. Changing Pulse to Trigger.')
                    otherwise
                        error('Error in sequence: unknown option')
                end
            end
        end
        
        function repairSequence(obj)
            % Goes over the list of pulses and merges consequtive pulses
            % which have the same channels and nickname
            i = 1;
            % Go over all pulses
            while i <= length(obj.pulses) - 1
                % Check if they can be merged.
                if isequal(obj.pulses(i).onChannels, obj.pulses(i+1).onChannels) ...
                        && isequal(obj.pulses(i).nickname, obj.pulses(i+1).nickname)
                    
                    % If so, start by creating a copy (and not editing the
                    % old pulse object) and then change the duration.
                    newPulse = obj.pulses(i).copy;
                    newPulse.duration = obj.pulses(i).duration + obj.pulses(i+1).duration;
                    obj.pulses(i) = newPulse;
                    
                    % Remove the old pulse.
                    obj.pulses(i+1) = [];
                else % If the pulses were merged, don't increase the index (otherwise, it can miss a merge if 3 pulses needed to be mereged).
                    i = i+1;
                end
            end
        end

        function addSequenceAtGivenTime(obj, S1, startTime)
            if ~exist('startTime', 'var')
                startTime = obj.duration; % if startTime isn't provided, add the sequence at the end.
            end
            
            for i = 1:length(S1.pulses)
                % obj.addPulseAtGivenTime(startTime, S1.pulses(i));
                obj.squeezeInPulseAtGivenTime(startTime, S1.pulses(i));
                startTime = startTime + S1.pulses(i).duration;
            end
        end

        function updateInternal(obj, fgChannel, awgChannel, triggerDuration, keepPGchannelOn, opMode) % update the sequence to use awg or triggering.
            % defaults = {'channel', 'SGT', 'channel_2', 'TRIGGER', 'trigger_duration', 50e-3, 'add_trigger', true, 'mode', 'sequnecer'}; % needs to be updated. % default MW channel is SGT, default trigger duration is 5 ns.
            % params = varargin2param(defaults, varargin{:});
            % params = {'channel', channel, 'channel_2', channel_2, 'trigger_duration', trigger_duration, 'add_trigger', add_trigger, 'mode', mode};
            [~, ~, pulseTimes] = obj.getPulsesByChannel(fgChannel);
            switch opMode
                case 'external'
                    obj.addEventAtGivenTime(pulseTimes(1), 0.1, awgChannel, ''); % should usually be run with keepPGchannelOn = true
                    % AWG might need 2 triggers: start trigger, next (sequence) trigger
                    % next trigger needs to happen in changeSequence/setSequence in the experiment
                case 'internal'
                    obj.keepChannelStatic(fgChannel, 'off') % turn off the channel
                    obj.addEventAtGivenTime(pulseTimes(1), triggerDuration, fgChannel, '') % and keep only a trigger pulse
                    % obj.addEventAtGivenTime(pulseTimes(1), triggerDuration, awgChannel, '') % and keep only a trigger pulse
                otherwise
                    EventStation.anonymousWarning('Cannot update sequence. Mode ''%s'' is not supported on channel ''%s''', type, fgChannel) % escape character for a single quote is a single quote (i.e. '')
            end
            if keepPGchannelOn
                % obj.keepChannelStatic(fgChannel, 'on')
            end
            obj.repairSequence(); % make sure the sequence doesn't have adjacent pulses in the same channel
        end
        
        % function changePulseToTrigger(obj, channel, trigger_duration, trigger_off)
        %     % 
        %     [~, idx, pulseTimes] = getPulsesByChannel(obj, channel);
        %     p1 = Pulse(trigger_duration, channel, '');
        %     for i = flip(idx)
        %         channels = fieldnames(obj.pulses(1,i).onChannels);
        %         obj.pulses(1,i).changeChannels(channels', ~strcmp(channels, channel)');
        %         obj.addPulseAtGivenTime(pulseTimes(i), p1); %trigger to turn on
        %         if trigger_off
        %             obj.addPulseAtGivenTime(pulseTimes(i+1), p1); %trigger to turn off
        %         end
        %     end
        % end
        
        function keepChannelStatic(obj, channel, state)
            % Determine if the channel is ment to be kept on or off
            isOnState = strcmp(state, 'on') || isequal(state, true) || isequal(state, 1);

            % Find pulses based on the (inverse) state
            pulses = find(cellfun(@(c) isfield(c, channel) ~= isOnState, {obj.pulses.onChannels}));
            % pulses = find(cellfun(@(c) isfield(c, channel) == isOnState, {obj.pulses.onChannels}));
            pulses = pulses(2:end);

            % Update channels for the found pulses
            for i = pulses
                onChannels = fieldnames(obj.pulses(1, i).onChannels);
                if isOnState
                    onChannels = [onChannels; {channel}]; % Add channel if state is 'on'
                    obj.pulses(1, i).changeChannels(onChannels, true(size(onChannels)));
                else
                    obj.pulses(1, i).changeChannels(onChannels, ~strcmp(onChannels, channel)');
                end
            end
        end

        % function addTrigger(obj, channel, trigger_channel, trigger_duration)
        %     % adds a trigger on a new channel (trigger_channel) at the end 
        %     % of a pulse in a desired channel (channel)
        %     [~, idx, ~] = getPulsesByChannel(obj, channel);
        %     pulseTimes = [0, zeros(1, length(obj.pulses))];
        %     for i = 2:length(pulseTimes)
        %         pulseTimes(i) = pulseTimes(i-1) + obj.pulses(1,i-1).duration;
        %     end
        %     trigger_pulse = Pulse(trigger_duration, trigger_channel, '');
        %     for i = flip(idx)
        %         obj.addPulseAtGivenTime(pulseTimes(i+1)+trigger_duration, trigger_pulse);
        %     end
        % end

        function axisHandle = plotSequence(obj, axisHandle)
            % Plots the sequence, can input an optional axis handle
            if nargin < 2
                figure;
                axisHandle = gca;
            end
            % Get channels info
            channelsStruct = obj.perChannelEdgeTimes();
            channelNames = {channelsStruct.name};
            numOfChannels = length(channelsStruct) - 1; % Do not go over the empty pulses (last entry)
            
            % Create time and y vectors
            t = unique(obj.edgeTimes); % Remove double values because of zero length pulses.
            t = reshape([t; t + PulseGenerator.MINIMAL_TIME], 1, []); % Add two points per edge
            y = zeros(numOfChannels, length(t));
            
            % Add data to y vector.
            for i = 1:numOfChannels
                y(i,:) = (2*(i-1)); % set "zero"
                for j = 1:channelsStruct(i).numOfPulses
                    ind = find(t > channelsStruct(i).pulsesStartTime(j) ...
                        & t <= channelsStruct(i).pulsesEndTime(j));
                    y(i,ind) = y(i,ind) + 1;
                end
            end
            
            % Plot
            plot(axisHandle, t, y)
            axis([0 t(end) -0.5 2*numOfChannels-0.5]);
            xlabel('t [\mus]')
            yticks(axisHandle, 0.5:2:(2*numOfChannels)-1.5)
            yticklabels(axisHandle, channelNames)
            
            % Add nicknames
            for i = 1:numOfChannels + 1
                for j = 1:channelsStruct(i).numOfPulses
                    if ~isempty(channelsStruct(i).pulseNickname{j})
                        tStr = mean([channelsStruct(i).pulsesStartTime(j), channelsStruct(i).pulsesEndTime(j)]);
                        if i <= numOfChannels
                            yStr = 2*i-1.5;
                            text(axisHandle, tStr, yStr, channelsStruct(i).pulseNickname{j}, ...
                                'HorizontalAlignment', 'center', 'Rotation', 270)
                        else
                            tStr = repmat(tStr, 1, numOfChannels);
                            yStr = 2*(1:numOfChannels)-1.5;
                            text(axisHandle, tStr, yStr, channelsStruct(i).pulseNickname{j}, ...
                                'HorizontalAlignment', 'center', 'Rotation', 270)
                        end
                    end
                end
            end
        end


        function S = copySequence(S1)
            S = Sequence;
            for i = 1:length(S1.pulses)
                p = Pulse(S1.pulses(i).duration, fieldnames(S1.pulses(i).onChannels), S1.pulses(i).nickname);
                S.addPulse(p);
            end
        end

        function [pulses, pulseIndexes, pulseTimes] = getPulsesByChannel(obj, channel)
            % Get all pulses and their start times for a specific channel
            pulseIndexes = find(cellfun(@(c) isfield(c, channel) , {obj.pulses.onChannels}));
            pulseTimes = [0, zeros(1, length(obj.pulses))]; % might need to be length(obj.pulseIndexes)
            pulses = obj.pulses(pulseIndexes);
            for i = 2:length(pulseTimes)
                pulseTimes(i) = pulseTimes(i-1) + obj.pulses(1,i-1).duration;
            end

            pulseTimes = zeros(1, length(pulseIndexes));
            seqEdgeTimes = edgeTimes(obj);
            for i = 1:length(pulseTimes)
                % idx = pulseIndexes(i);
                pulseTimes(i) = seqEdgeTimes(pulseIndexes(i));
            end
            % pulseTimes = sort(pulseTimes);
        end

        function ind = indexFromNickname(obj, name)
            % Returns index (or indices) of pulses that have the name
            % 'name'
            if isnumeric(name)
                ind = name;
                if ind > length(obj.pulses)
                    ind = double.empty;
                end
            elseif ischar(name)
                nicknames = {obj.pulses.nickname};
                ind = find(strcmp(name, nicknames));
            else
                error('Unknown indexing system')
            end
            if isempty(ind)
                error('Index not found')
            end
        end
    end
    
    methods (Access = private)    
        function [S1, S2] = splitByIndex(obj, ind)
            % Splits sequence into 2 parts: [obj(1:ind) obj(ind+1:end)]
            S1 = Sequence(obj.pulses(1:ind));
            S2 = Sequence(obj.pulses(ind+1:end));
        end
        
        function [S1, S2] = splitByTime(obj, time)
            % Cuts the sequence at 'time' and returns the sequence before
            % and the sequence after. The function will automatically cut a
            % pulse in the middle, if needed.
            assert(isscalar(time), 'Currently, we can''t split by vector of times. Sorry!')
            
            if time >= obj.duration
                % Return two sequences: one with extra time at the end, and
                % one zero-length pulse
                newDuration = time - obj.duration;
                S1 = obj + Sequence(Pulse(newDuration));
                S2 = Sequence(Pulse(0));
                return
            elseif time <= 0
                % Return two sequences: one zero-length pulse and one with
                % extra time at the start
                S1 = Sequence(Pulse(0));
                newDuration = abs(time);
                S2 = Sequence(Pulse(newDuration)) + obj;
                return
            end
            pulseEdges = obj.edgeTimes;
            
            ind = find(pulseEdges <= time, 1, 'last');
            if abs(pulseEdges(ind) - time) < PulseGenerator.MINIMAL_TIME
                % Easier: we just split the whole sequence into two parts
                % at time 'time'
                [S1, S2] = obj.splitByIndex(ind-1);
            else
                % Harder: we also need to split a pulse and add it to
                % relevent sequences. We need:
                % a. the pulse we want to split
                pulseToSplit = obj.pulses(ind);
                % b. the time we want to split it in
                pulseTime = time - pulseEdges(ind);
                % And now: the actual job
                [P1, P2] = pulseToSplit.split(pulseTime);
                
                S1 = Sequence(P1);
                if ind > 1 % The splitted pulse wasn't the 1st one
                    S1 = Sequence(obj.pulses(1:ind-1)) + S1;
                end
                
                S2 = Sequence(P2);
                if ind < length(obj.pulses) % The splitted pulse wasn't the last one
                    S2 = S2 + Sequence(obj.pulses(ind+1:end));
                end
            end
        end
        
        function [prePulses, timedPulses, postPulses] = getPulsesByTimes(obj, startTime, endTime)
            % Get the pulses before 'startTime', after 'endTime' and in
            % between. The function will automatically cut a pulse in the
            % middle, if needed.
            [preS, S] = obj.splitByTime(startTime);
            [S, postS] = S.splitByTime(endTime-startTime);
            prePulses = preS.pulses;
            timedPulses = S.pulses;
            postPulses = postS.pulses;
        end 
    end


    %% Operator Overriding
    methods
        function S = plus(S1, S2)
            S = Sequence;
            % We want to avoid adding empty pulses for nothing, which might
            % occur, due to the way we split Sequences.
            if duration(S1) < PulseGenerator.MINIMAL_TIME
                S = S2;
            elseif duration(S2) < PulseGenerator.MINIMAL_TIME
                S = S1;
            else
                S.pulses = [S1.pulses S2.pulses];
            end
        end
        
        function S = mtimes(in1, in2)
            if isnumeric(in1)
                n = in1;
                T = in2;
            elseif isnumeric(in2)
                n = in2;
                T = in1;
            end
            try
                S = Sequence(repmat(T.pulses, 1, n));
            catch err
                err.message = sprintf('%s\n%s', 'Operation is undefined! (for now?)', err.message);
                rethrow(err);
            end
        end
    end
end