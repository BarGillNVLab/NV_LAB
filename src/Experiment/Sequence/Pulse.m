classdef Pulse < matlab.mixin.Copyable 
    %PULSE Single pulse of all devices
    %   A pulse is defined by duration, and channels which are on in this
    %   pulse (could be empty)
    %   Pulses can be added, which creates a new pulse whose 'on channels'
    %   is a union of the 'on channels' from both pulses.
    
    properties (SetAccess = {?Pulse, ?Sequence})
        duration        % double. Duration of pulse in microseconds
        nickname = '';	% char array. Optional name for the pulse.
    end
    
    properties (SetAccess = private)
        onChannels = struct;    % struct of char arrays. We assume, for now, 
                                % only digital cahnnels, so we only need to
                                % know which ones are on.
        % phase?
    end
    
    methods
        function obj = Pulse(duration, channelNames, nickame) % Constructor
            narginchk(1,3)
            obj@matlab.mixin.Copyable;  % Superclass providing copy functionality for handle objects
            
            try     % Property uses setters, and might result in error.
                obj.duration = duration;
            catch err
                delete(obj)
                rethrow(err)
            end
            
            switch nargin
                case 1
                    obj.nickname = '';
                case 2
                    obj.changeChannels(channelNames);
                    obj.nickname = '';
                case 3
                    obj.changeChannels(channelNames);
                    obj.nickname = nickame;
            end
        end
    end
        
    methods
        function [pulse1, pulse2] = split(obj, time)
            % Split current Pulse into two parts.
            % Method: create two copies of the current Pulse, and change
            % their duration accordingly
            remainder = obj.duration - time;
            if time < 0 || remainder < 0
                error('Pulse could not be split in requested time')
            end
            
            pulse1 = obj.copy;
            pulse1.duration = time;
            
            pulse2 = obj.copy;
            pulse2.duration = remainder;
        end
    end
    
    %% Setters and getters
    methods
        function set.duration(obj, newDuration)
            if ~isscalar(newDuration) || ~isnumeric(newDuration)
                error('Duration must be a scalar numeric value!')
            end
            if newDuration < 0
                error('Duration must not be negative! Requested: %d', newDuration)
            end
            obj.duration = newDuration;
        end
    end
       
    methods (Access = {?Pulse, ?Sequence, ?PulseGenerator})
        function changeChannels(obj, channels, levels)
            % Sets the levels for each channel.
            % This only changes from current levels. Otherwise, create new
            % pulse.
            %
            % channels - char array or cell of char arrays. Names of the
            % channels refered to in this pulse
            % levels - array of logicals. Whether the channel is on or off.
            % channel and level must be of the same length!
            
            if isempty(channels)
                channels = {};
            elseif ~iscell(channels)
                % Convert to cell, for ease of use
                channels = {channels};
            end
            if ~exist('levels', 'var')
                % Allows for syntax obj.changeChannels(channels), which
                % only adds channels.
                levels = true(size(channels));
            elseif length(channels) ~= length(levels)
                error('Channel names and channel levels must be of the same length!')
            elseif length(unique(channels)) ~= length(channels)
                error('Channel names include repetitions. Each channel must have a unique name!')
            end
            
            oc = obj.onChannels; % for brevity
            for i = 1:length(channels)
                channel = channels{i};
                if levels(i)
                    % Add channels which are (true)
                    oc.(channel) = true;
                elseif isfield(oc, channel)
                    % Remove channels which are (false), if they exist
                    oc = rmfield(oc, channel);
                end
            end
            obj.onChannels = oc;     % After changes are done, we assign them back to object property
        end
        
        function clear(obj)
            % Removes all active channels in Pulse
            obj.onChannels = struct;
        end
        
        function chans = getOnChannels(obj)
            % Get list (cell array) of on channels
            chans = fields(obj.onChannels);
        end
    end
    
    %% Operator Overriding
    methods
        function P = plus(P1, P2)
            % Creates a new pulse whose 'on channels' are a union of the 
            % 'on channels' from both pulses. Pulses duration must be the
            % same, and have the same nickname. If only one has a nickname,
            % then the new pulse will get it.
            if abs(P1.duration - P2.duration) > PulseGenerator.MINIMAL_TIME
                error('Can only add channels which have the same duration');
            end
            
            newDuration = P1.duration;
            channelNames = union(P1.getOnChannels, P2.getOnChannels);
            
%             if P1.nickname == P2.nickname % change to strcmp - rotem 3.12.24
            if strcmp(P1.nickname, P2.nickname)
                newNickname = P1.nickname;
            elseif isempty(P1.nickname)
                newNickname = P2.nickname;
            elseif isempty(P2.nickname)
                newNickname = P1.nickname;
            else
                error('Pulses have different nicknames!');
            end
            P = Pulse(newDuration, channelNames, newNickname);
        end
        
        function newPulses = combinePulses(pulses, pulse)
            % Adds the 'on channels' in pulse to the 'on channels' in
            % pulses. Pulses can be an array of pulses whose total duration
            % is equal to pulse's duration.
            if abs(sum([pulses.duration]) - pulse.duration) > PulseGenerator.MINIMAL_TIME
                error('Durations mismatch')
            end
            newPulses = [];
            while length(pulses) ~= 1
                [cutPulse, pulse] = pulse.split(pulses(1).duration);
                newPulse = cutPulse + pulses(1);
                newPulses = [newPulses newPulse]; %#ok<AGROW>
                pulses = pulses(2:end);
            end
            newPulse = pulse + pulses;
            newPulses = [newPulses newPulse];
        end
    end
end