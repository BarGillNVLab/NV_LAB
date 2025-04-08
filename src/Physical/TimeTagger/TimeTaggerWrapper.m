classdef TimeTaggerWrapper < EventSender
    %TimeTaggerWrapper Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        tagger
        
        channelArray
        % 2D array.         (Better make it a struct, when we get to it)
        % 1st column - channel numbers, e.g. {0,7}
        % 2nd column - channel names, e.g. {'spcm','laser'}
    end
    
    properties (Constant, Hidden)
       IDX_CHANNEL = 1;
       IDX_CHANNEL_NAME = 2;
    end
    
    properties(Constant = true)
        NAME = 'TimeTagger';
        
        EVENT_TIMETAGGER_RESET = 'TimeTagger_reset';
        CHANNEL_UNUSED = TimeTagger.CHANNEL_UNUSED;
    end
    
    methods(Access = protected)
        function obj = TimeTaggerWrapper()
            obj@EventSender(TimeTaggerWrapper.NAME);
            addBaseObject(obj);  % so it can be reached by getObjByName()
            obj.channelArray = {};
            
            obj.tagger = TimeTagger.createTimeTagger();
            obj.tagger.reset();
        end
        
        function [index, channel] = getIndexFromChannelOrName(obj, channelOrChannelName)
            if isnumeric(channelOrChannelName)
                [~, channelIndexes] = intersect([obj.channelArray{:, TimeTaggerWrapper.IDX_CHANNEL}], channelOrChannelName, 'stable');
                if (length(channelIndexes) == length(channelOrChannelName))
                    index = channelIndexes;
                    channel = obj.getChannelFromIndex(index);
                    return;
                end
            else
                channelNamesIndexes = find(ismember({obj.channelArray{:, TimeTaggerWrapper.IDX_CHANNEL_NAME}}, channelOrChannelName));
                if (iscell(channelOrChannelName) && (length(channelNamesIndexes) == length(channelOrChannelName))) ...
                        || (ischar(channelOrChannelName) && (length(channelNamesIndexes) == 1))
                    index = channelNamesIndexes;
                    channel = obj.getChannelFromIndex(index);
                    return;
                end
            end
            error('%s couldn''t find channel', obj.name);
        end
        
        function channelName = getChannelNameFromIndex(obj, index)
            if length(index) == 1
                channelName = obj.channelArray{index, TimeTaggerWrapper.IDX_CHANNEL_NAME};
            else
                channelName = {obj.channelArray{index, TimeTaggerWrapper.IDX_CHANNEL_NAME}};
            end
        end
        
        function channel = getChannelFromIndex(obj, index)
            channel = [obj.channelArray{index, TimeTaggerWrapper.IDX_CHANNEL}];
        end
    end
  
    methods(Static)
        function obj = create() %#ok<*INUSD>
            % This method is used to load the TimeTagger as new
            removeObjIfExists(TimeTaggerWrapper.NAME); 
            obj = TimeTaggerWrapper();
        end
    end
    
    methods
        function registerChannel(obj, newChannel, newChannelName, delayOptional)
            % delayOptional is in ps, it can be empty (default is 0)            
            if isempty(obj.channelArray)
                obj.channelArray{end + 1, TimeTaggerWrapper.IDX_CHANNEL} = newChannel;
                obj.channelArray{end, TimeTaggerWrapper.IDX_CHANNEL_NAME} = newChannelName;
                if exist('delayOptional', 'var')
                    obj.setInputDelay(newChannel, delayOptional);
                end
                return
            end
                
            channelAlreadyInIndexes = find([obj.channelArray{:, TimeTaggerWrapper.IDX_CHANNEL}] == newChannel);
            if ~isempty(channelAlreadyInIndexes)
                errorMsg = 'Can''t assign channel "%s" to "%s", as it has already been captured by "%s"!';
                channelIndex = channelAlreadyInIndexes;
                channelCapturedName = obj.getChannelNameFromIndex(channelIndex);
                error(errorMsg, newChannel, newChannelName, channelCapturedName);
            end
            obj.channelArray{end + 1, TimeTaggerWrapper.IDX_CHANNEL} = newChannel;
            obj.channelArray{end, TimeTaggerWrapper.IDX_CHANNEL_NAME} = newChannelName;
            if exist('delayOptional', 'var')
                obj.setInputDelay(newChannel, delayOptional);
            end
        end % func registerChannel
    end % methods
    
    methods % TimeTagger class methods
        function free(obj)
            % Removes the Time Tagger from memory in order to allow others
            % to connect to it.
            obj.tagger.freeTimeTagger();
        end
        
        function reset(obj)
            % Reset the Time Tagger to the startup state
            obj.tagger.reset();
            fprintf('Time Taggger ready! (reset)\n');
            obj.sendEvent(struct(TimeTaggerWrapper.EVENT_TIMETAGGER_RESET, true));
        end
        
        function setInputDelay(obj, channelOrChannelName, delay)
            % Set the input delay of a channel in picoseconds
            [~, channel] = obj.getIndexFromChannelOrName(channelOrChannelName);
            obj.tagger.setInputDelay(channel, delay)
        end
        
        function setTriggerLevel(obj, channelOrChannelName, triggerLevel)
            % Set the triger level of a channel in volts
            [~, channel] = obj.getIndexFromChannelOrName(channelOrChannelName);
            obj.tagger.setTriggerLevel(channel, triggerLevel)
        end
        
        function delay = getChannelDelay(obj, channelOrChannelName)
            % Return the input delay of a channel in picoseconds
            [~, channel] = obj.getIndexFromChannelOrName(channelOrChannelName);
            delay = obj.tagger.setInputDelay(channel);
        end
        
        function setConditionalFilter(obj, triggerChannels, filteredChannels)
            % Activates or deactivates the event filter. Time tags on the
            % filtered channels are discarded unless they were preceded by
            % a time tag on one of the trigger channels which reduces the
            % data rate.
            [~, triggerChannels] = obj.getIndexFromChannelOrName(triggerChannels);
            [~, filteredChannels] = obj.getIndexFromChannelOrName(filteredChannels);
            obj.tagger.setConditionalFilter(triggerChannels, filteredChannels)
        end
        
        function filteredChannels = getConditionalFilterEnable(obj)
            % Returns the collection of channels to which the conditional
            % filter is currently applied.
            filteredChannels = obj.taggger.getConditionalFilterEnable;
        end
        
        function triggerChannels = getConditionalFilterTrigger(obj)
            % Returns the collection of trigger channels for the 
            % conditional filter.
            triggerChannels = obj.taggger.getConditionalFilterTrigger;
        end
        
        function deadtime = setDeadtime(obj, channelOrChannelName, deadtime)
            % Sets the dead time of a channel in picoseconds. The requested
            % time will be rounded to the nearest multiple of the clock
            % time, which is 6 ns for the Time Tagger 20 and 2.25 ns for
            % the Time Tagger Ultra. The minimum dead time is one clock
            % cycle. As the deadtime passed as an input will be altered to
            % the rounded value, the rounded value will be returned. The
            % maximum dead time is 393.21 µs for the Time Tagger 20 and
            % 147.45375 µs for the Time Tagger Ultra.
            [~, channel] = obj.getIndexFromChannelOrName(channelOrChannelName);
            deadtime = obj.tagger.setDeadtime(channel, deadtime);
        end
        
        function deadtime = getDeadtime(obj, channelOrChannelName)
            % Returns the dead time of a channel in picoseconds
            [~, channel] = obj.getIndexFromChannelOrName(channelOrChannelName);
            deadtime = obj.tagger.getDeadtime(channel);
        end
        
        function channel = getInvertedChannel(obj, channelOrChannelName)
            % Returns the channel number for the inverted edge of the 
            % channel passed in via the channel parameter. In case the 
            % given channel has no inverted channel, CHANNEL_UNUSED is 
            % returned.
            [~, channel] = obj.getIndexFromChannelOrName(channelOrChannelName);
            channel = obj.tagger.getInvertedChannel(channel);
        end
        
        function ret = getOverflowsAndClear(obj)
            % Returns the number of overflows that occurred since start-up
            % and sets them to zero.
            ret = obj.tagger.getOverflowsAndClear();
        end
        
        function sync(obj)
            % Ensure that all hardware settings such as trigger levels,
            % channel registrations, etc., have propagated to the FPGA and
            % are physically active. Synchronizes the Time Tagger internal
            % memory, so that all tags arriving after a sync call were
            % actually produced after the sync call. The sync function
            % waits until all tags, which are present at the time of the
            % function call within the internal memory of the Time Tagger,
            % are processed.
            obj.tagger.sync();
        end
        
        function fence = getFence(obj)
            % Generate a new fence object, which validates the current
            % configuration and the current time. This fence is uploaded to
            % the earliest pipeline stage of the Time Tagger. Waiting on
            % this fence ensures that all hardware settings such as trigger
            % levels, channel registrations, etc., have propagated to the
            % FPGA and are physically active. Synchronizes the Time Tagger
            % internal memory, so that all tags arriving after the
            % waitForFence call were actually produced after the getFence
            % call. The waitForFence function waits until all tags, which
            % are present at the time of the function call within the
            % internal memory of the Time Tagger, are processed. This call
            % might block to limit the amount of active fences.
            fence = obj.tagger.getFence();
        end
        
        function waitForFence(obj, fence)
            % Wait for a fence in the data stream. See getFence() for more details.
            obj.tagger.waitForFence(fence);
        end
        
        function varargout = SendTTCommand(obj, command, varargin) %#ok<STOUT>
            % A function to use any of the other TimeTagger functions as
            % documented by the API at https://www.swabianinstruments.com/static/documentation/TimeTagger/sections/api.html
            for i=1:length(varargin)
                if isstring(varargin{i}) || ischar((varargin{i}))
                    [~, channel] = obj.getIndexFromChannelOrName(varargin{i});
                    varargin{i} = channel;
                end
            end
            eval(sprintf('[varargout{1:nargout}] = obj.tagger.%s(varargin{:});', command));
        end
        
        function measurement = createMeasurement(obj, type, varargin) %#ok<STOUT>
            % Returns a measurment class from the list documented at:
            % https://www.swabianinstruments.com/static/documentation/TimeTagger/sections/api.html#measurement-classes
            % A vector of channels can be inputed as a cell of strings.
            tagger_exists = false;
            
            for i=1:length(varargin)
                if isstring(varargin{i}) || ischar((varargin{i}))
                    [~, channel] = obj.getIndexFromChannelOrName(varargin{i});
                    varargin{i} = channel;
                elseif iscell(varargin{i})
                    vector = zeros(size(varargin{i}));
                    for j=1:length(varargin{i})
                        vector(j) = varargin{i}(j);
                        if isstring(vector(j)) || ischar((vector(j)))
                            [~, channel] = obj.getIndexFromChannelOrName(vector(j));
                            vector(j) = channel;
                        end
                    end
                    varargin{i} = vector;
                elseif isa(varargin{i}, 'TTTimeTaggerBase') %changed from 'TimeTagger' due to a SDK update 2023.04.13
                    tagger_exists = true;
                end
            end
            if ~tagger_exists
                varargin = {obj.tagger, varargin{:}};
            end
            className = sprintf('TT%s', type);
%             eval(sprintf('measurement = %s(varargin{:});', className));
            eval(sprintf('measurement = %s(varargin{:});', className)); %commented out by rotem 14.1.21
        end
        
        function virtualChannel = createVirtualChannel(obj, type, varargin) %#ok<STOUT>
            % Returns a virtual channel class from the list documented at:
            % https://www.swabianinstruments.com/static/documentation/TimeTagger/sections/api.html#id1
            % A vector of channels can be inputed as a cell of strings.
            for i=1:length(varargin)
                if isstring(varargin{i}) || ischar((varargin{i}))
                    [~, channel] = obj.getIndexFromChannelOrName(varargin{i});
                    varargin{i} = channel;
                elseif iscell(varargin{i})
                    vector = zeros(size(varargin{i}));
                    for j=1:length(varargin{i})
                        if isstring(varargin{i}{j}) || ischar((varargin{i}{j}))
                            [~, channel] = obj.getIndexFromChannelOrName(varargin{i}{j});
                            vector(j) = channel;
                        else
                            vector(j) = varargin{i}{j};
                        end
                    end
                    varargin{i} = vector;
                end
            end
            className = sprintf('TT%s', type);
            eval(sprintf('virtualChannel = %s(obj.tagger, varargin{:});', className));
        end
    end
end