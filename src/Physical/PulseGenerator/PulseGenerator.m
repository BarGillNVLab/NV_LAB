classdef (Abstract) PulseGenerator < EventSender
    %PULSEGENERATOR Class for representing a pulse generator (PulseBlaster or PulseStreamer)
    % An abstract class, which knows to handle objects of class Sequence
    
    properties
        repeats                     % int. How many times each sequence is to be repeated.
        sequencePeriodMultiple = 0; % We might need to add some blank time
                                    % @ end of sequence, so all of the
                                    % devices have the same period.
                                    % This value tells us what (if at all)
                                    % is the period of the system.
                                    % Default is 0.
        fixDelays = true;           % logical. Flag for whether the PG should automatically fix delays.
                                    % Default is true.
    end
    
    properties (Access = protected)
        sequenceInMemory            % logical. Flag for whether obj.sequence is the same as the one in the hardware.
        delayFixed                  % logical. Flag for whether the delay fixed version of the current seqeunce, stored in 'delayFixedSequence', is valid.
        sequence                    % Sequence object, configured in experiment.
        userSequence                % Sequence object, to be loaded to the hardware (usually the same as sequence).
        delayFixedSequence          % A version of sequence which fixed the delays. The flag 'delayFixed' indicates whether it is updated.
        delayFixedSequenceMap       % A map object that saves previously calculated delayed sequences for better performance.
        onChannelsBinary = 0;       % Stores in binary the state of each of
                                    % the channels e.g. 11 (= 1 + 2 + 8)
                                    % means that only channels 0, 1 and 3
                                    % are on.
        channels = []               % Channel array. Stores registered channels.
    end
    
    properties (Constant, Hidden)
        NAME = 'pulseGenerator'
        NAME_PULSE_BLASTER = 'pulseBlaster'
        NAME_PULSE_STREAMER = 'pulseStreamer'
    end
    
    properties (Constant)
        MINIMAL_TIME = 1e-6; % 1 ps
    end
    
    properties (Abstract, Constant, Hidden)
        % TOTAL_CHANNEL_NUMBER    % int. channels are indexed in the range (1:obj.TOTAL_CHANNEL_NUMBER)
        MAX_REPEATS             % int. Maximum value for obj.repeats
        MAX_PULSES              % int. Maximum number of pulses in acceptable sequences
        MAX_DURATION            % double. Maximum duration of pulse.
        
        AVAILABLE_ADDRESSES     % List of all available physical addresses.
                                % Should be either vector of doubles or cell of char arrays
    end
    
    methods (Access = protected)
        function obj = PulseGenerator
            % Default constructor.
            name = PulseGenerator.NAME;
            obj@EventSender(name);
        end
        
        function initSequence(obj)
            obj.sequence = Sequence;
            obj.sequenceInMemory = false;
            obj.delayFixedSequenceMap = containers.Map();
            obj.removeDelays();
        end
        
        function uploadSequence(obj)
            validateSequence(obj)
            
            if obj.fixDelays && ~obj.delayFixed
                obj.fixSequenceDelays();
            end
            
            % We might need to add some blank time @ end of sequence, for
            % synchroniztion purposes
            seq = BooleanHelper.ifTrueElse(obj.delayFixed, obj.delayFixedSequence, obj.sequence);
            t = obj.sequencePeriodMultiple;
            remainder = rem(seq.duration, t);       % returns NaN if t==0; returns 0 if duration is multiple of t
            if ~isnan(remainder) && remainder ~= 0  % That is, we need to add a dummy pulse
                p = Pulse(remainder);
                seq.addPulse(p);
            end
            
            obj.sendToHardware;
            obj.sequenceInMemory = true;
        end
        
        function validateSequence(obj)
            % Checks that all of the channels in the sequence are known. If
            % additional checks are needed, this function can be
            % overwritten.
            if isempty(obj.sequence)
                error('Cannot upload empty sequence!')
            end
            
            onCh = obj.sequence.activeChannelNames;
            mNames = obj.channelNames;
            for i = 1:length(onCh)
                chan = onCh{i};
                if ~contains(mNames, chan)
                    errMsg = sprintf('Channel %s could not be found! Aborting.', chan);
                    obj.sendError(errMsg)
                end
            end
        end
        
        function removeDelays(obj)
            if obj.sequenceInMemory && obj.delayFixed
                obj.sequenceInMemory = false;
            end
            obj.delayFixed = false;
            obj.delayFixedSequence = [];
        end
        
        function fixSequenceDelays(obj)
            % Create a sequence which delays the channels as needed and 
            % stores it in obj.delayFixedSequence. Saves previously stored
            % seqeunces in a map, to save calculation time.
            
            % If we upgrade to 2018+, we can switch to https://www.mathworks.com/help/releases/R2020a/rptgen/ug/mlreportgen.utils.hash.html
            sequenceKey = DataHash(obj.sequence); % Calculates a key for the current sequence.
            if obj.delayFixedSequenceMap.isKey(sequenceKey) % key exists, so just load the previously found sequence.
                S = obj.delayFixedSequenceMap(sequenceKey);
            else % otherwise, create the delayed sequence.
                warning off Sequence:Merge:NicknameRemoved
                channelsStruct = obj.sequence.perChannelEdgeTimes();
                warning on Sequence:Merge:NicknameRemoved
                
                % Go over all channels and pulses, change the start & end
                % time due to delays. In case of negative time we fold the
                % sequence of the chnnel and shift the negative duration to
                % the end. 08/05/22 Yachel and Ty
                for i = 1:length(channelsStruct) - 1 % Do not go over the empty pulses (last entry)
                    [onDelay, offDelay] = obj.channelName2Delays(channelsStruct(i).name);
                    startTimes = channelsStruct(i).pulsesStartTime;
                    endTimes = channelsStruct(i).pulsesEndTime;
                    % delays fix by json:
                    startTimes = startTimes - onDelay;
                    endTimes = endTimes - offDelay;
                    % search for pulse with negative start time and postive
                    % end time, and split.
                    indSplit = find((startTimes < 0) & (endTimes > 0));
                    if ~isempty(indSplit)
                        insert = @(a, x, n)cat(2,  x(1:n), a, x(n+1:end));
                        startTimes = insert(0, startTimes, indSplit);
                        endTimes = insert(0, endTimes, indSplit-1);
                        channelsStruct(i).numOfPulses = channelsStruct(i).numOfPulses + 1;
                    end
                    % shift  the negative times to the end of the sequence
                    % essentially foldinf the repeated sequence
                    startTimes = startTimes + (startTimes<0) * obj.sequenceDuration();
                    endTimes = endTimes + (endTimes<=0) * obj.sequenceDuration();
                    % insert back to the struct
                    channelsStruct(i).pulsesStartTime = startTimes;
                    channelsStruct(i).pulsesEndTime = endTimes;
                end
                
                % Start by creating a sequence for an empty pulse for the
                % duration of the entire seqeunce. This will make sure that an
                % empty pulse at the end isn't lost.
                S = Sequence(Pulse(obj.sequenceDuration(), '', ''));
                
                % Go over all channels, fix for negative times, and add to
                % sequence.
                for i = 1:length(channelsStruct)
                    for j = 1:channelsStruct(i).numOfPulses
                        pulseStartTime = channelsStruct(i).pulsesStartTime(j);
                        pulseEndTime = channelsStruct(i).pulsesEndTime(j);
                        S.addEventAtGivenTime(pulseStartTime, pulseEndTime - pulseStartTime, channelsStruct(i).name)
                    end
                end
                
                S.repairSequence();
                
                obj.delayFixedSequenceMap(sequenceKey) = S; % Saved delayed sequence in map.
            end
            
            obj.delayFixedSequence = S;
            obj.delayFixed = true;
            obj.sequenceInMemory = false;
        end
    end
    
    methods
        function setSequence(obj, S)
            % Whenever we change the current sequence, we necessarily have
            % a different sequence than the one on the hardware, until we
            % uploadSequence()
            % Changing S outside of the PG after setting it may result in
            % errors.
            if ~isa(S, 'Sequence')
                obj.sendError('New sequence must be of class ''Sequence''!')
            end
            obj.userSequence = S; % added by rotem 15.12.24
            obj.sequence = obj.userSequence.copySequence();
            % obj.sequence.changePulseToTrigger(varargin); % added by rotem - 15.12.24
            obj.sequenceInMemory = false;
            obj.delayFixed = false;
            obj.validateSequence();
        end
        
        function changeSequence(obj, nickname, what, newValue, varargin)
            % Used to change the sequence.
            % obj.sequence = obj.userSequence.copySequence(); % added by rotem 15.12.24
            % obj.sequence.change(nickname, what, newValue)
            % obj.userSequence = obj.sequence.copySequence(); % added by rotem 15.12.24
            obj.userSequence.change(nickname, what, newValue)
            obj.sequence = obj.userSequence.copySequence();
            % obj.sequence.changePulseToTrigger(varargin); % added by rotem - 15.12.24
            obj.sequenceInMemory = false;
            obj.delayFixed = false;
        end
        
        function time = sequenceDuration(obj)
            % Returns the seqeunce total duration
            time = obj.sequence.duration();
        end
        
        function axisHandle = plotSequence(obj, varargin)
            % Plots the sequence, can input an optional axis handle
            axisHandle = obj.sequence.plotSequence(varargin{:});
        end
        
        function axisHandle = plotDelayedSequence(obj, varargin)
            % Plots the sequence, can input an optional axis handle
            if ~obj.delayFixed
                obj.fixSequenceDelays()
            end
            axisHandle = obj.delayFixedSequence.plotSequence(varargin{:});
            if ~obj.fixDelays % Sequence is not meant to run with the delays fixed, so remove them
                obj.removeDelays
            end
        end
    end
    
    methods % Setters & getters
        function set.repeats(obj, r)
            % Validating for strictly positive integer
            if ~ValidationHelper.isValuePositiveInteger(r)
                error('Number of repeats must be a positive integer!') 
            elseif (r > obj.MAX_REPEATS)
                error('I can''t keep up with it! Try using less repeats.')
            end
            obj.repeats = r;
            obj.sequenceInMemory = false; %#ok<MCSUP>
        end
    end
    
    %% Channel registration and retrieval
    methods
        function registerChannel(obj, channels)
            % Supports arrays of Channels
            
            %%% Validation %%%
            % Channel data is in correct format
            if ~isa(channels, 'Channel')
                error('Object to be registered is not a channel! Ignoring.')
            end
            warnMsg = '';
            % Name is not yet taken
            name = {channels.name};
            occupiedName = obj.channelNames;        % list of channel names already taken
            nameValid = ~ismember(name, occupiedName);
            if any(~nameValid)
                warnMsg = [warnMsg, 'Some of the channels could not be registered, since their name already exists in the registrar.'];
            end
            % Physical addresses is available
            address = [channels.address];       % Careful! if channels.address is a char array, this might break!
            addressValid = ismember(address, obj.AVAILABLE_ADDRESSES);
            % & Not taken already
            occupiedAdd = obj.channelAddresses; % List of physical addresses already taken
            addressTaken = ismember(address, occupiedAdd);
            if any(addressTaken)
                % Maybe we are trying to register the same channel again,
                % and that's fine
                ind = find(addressTaken);
                for k = 1:length(ind)
                    pgInd = find(occupiedAdd == address(ind(k)));   % index of channel IN THE PG CHANNEL ARRAY
                    if strcmp(name, occupiedName(pgInd)) %#ok<FNDSB>
                        addressTaken(ind(k)) = false;
                        nameValid(ind(k)) = true;
                    end
                end
            end
            if any(~addressValid || addressTaken)
                warnMsg = [warnMsg, 'Some of the channels could not be registered in specified adresses.\n'];
            end
            % Let user know what's going on
            tf = nameValid && addressValid && ~addressTaken;
            if ~any(tf)
                obj.sendError('No channel was registered.')
            elseif any(~tf)
                obj.sendWarning(warnMsg);
            end
            
            %%% Registration %%%
            % Valid channels are added to channel array
            obj.channels = [obj.channels, channels(tf)];

        end
        
        function tf = isOn(obj, channelName)
            address = obj.channelName2Address(channelName);
            ind = address + 1;  % Addresses start at 0, but MATLAB vectors start at 1
            tf = bitget(obj.onChannelsBinary, ind);
        end
        
        function names = channelNames(obj)
            if isempty(obj.channels)
                names = {};
                return
            end
            names = {obj.channels.name};
        end
        
        function addresses = channelAddresses(obj)
            %{
            format = class(obj.AVAILABLE_ADDRESSES);
            switch format
                case {'int', 'double'}
            %}
            if isempty(obj.channels)
                addresses = [];
                return
            end
            addresses = [obj.channels.address];
            %{
                case 'cell'
                    if isempty(obj.channels)
                        addresses = {};
                        return
                    end
                    addresses = {obj.channels.address};
                otherwise
                    error('Unknown address type!')
            end
            %}
        end
    end
       
    methods (Access = protected)
        function address = channelName2Address(obj, name)
            % Supports cell arrays of 'name'
            if iscell(name)
                % find for each name seperately
                len = length(name);
                address = -ones(0, len);
                for i = 1:len
                    index = find(strcmp(name{i}, obj.channelNames));
                    if ~isempty(index)
                        address(i) = obj.channels(index).address;
                    end
                end
                invalidNum = sum(address < 0);
                if invalidNum ~= 0
                    msg = sprintf('%d channels could not be found', invalidNum);
                    obj.sendWarning(msg);
                end
            else
                % simpler case: only one name
                index = find(strcmp(name, obj.channelNames)); % Should return the index of the channel in obj.channels
                if isempty(index)
                    obj.sendWarning('Could not find requested channel!');
                    address = -1;
                else
                    address = obj.channels(index).address;
                end
            end
        end
    end
       
    methods % Should be protected, but isn't for now, because of how delays are implemented
        function [onDelay, offDelay] = channelName2Delays(obj, name)
            % Name must be single char array ("string")
            index = find(strcmp(name, obj.channelNames)); % Should return the index of the channel in obj.channels
            if isempty(index)
                if ~isempty(name)
                    obj.sendWarning('Could not find requested channel!');
                end
                onDelay = 0;
                offDelay = 0;
            else
                chan = obj.channels(index);
                onDelay = chan.onDelay;
                offDelay = chan.offDelay;
            end
        end
    end
    
    %% Wrapper methods
    methods (Abstract)
%         Initialize(obj) ????
        % Loads dll's. Maybe also create default sequence
        
        on(obj, channel)
        %   obj.pulseGeneratorPrivate.On(channel);
        
        off(obj)
        %   obj.pulseGeneratorPrivate.Off;
        
        run(obj)
        % Upload sequence to hardware (if needed) and actually start it
        
        sendToHardware(obj)
        % After all validation is done - upload the sequence to PG hardware

    end
    
    %%
    methods (Static)
        function obj = create(struct)
            type = PulseGenerator.generatorType(struct);
            switch type
                case 'dummy'
                    obj = PulseGeneratorDummyClass.GetInstance(struct);
                case PulseGenerator.NAME_PULSE_BLASTER
                    obj = PulseBlasterNewClass.GetInstance(struct);
                case PulseGenerator.NAME_PULSE_STREAMER
                    obj = PulseStreamerNewClass.getInstance(struct);
                otherwise
                    EventStation.anonymousWarning('Could not create Pulse Generator of type %s!', type)
            end
        end
        
        function type = generatorType(struct)
            % type - string. Type of pulse generator. For now, either
            % 'pulseBlaster' or 'pulseStreamer'
            if ~isfield(struct, 'type')
                type = PulseGenerator.NAME_PULSE_BLASTER;
            else
                type = struct.type;
            end
        end
    end
end