classdef (Sealed) PulseStreamerNewClass < PulseGenerator
    
    properties (Constant, Hidden)
%         TOTAL_CHANNEL_NUMBER = 8;	% int. channels are indexed (1:obj.TOTAL_CHANNEL_NUMBER)
        MAX_REPEATS = Inf;       	% int. Maximum value for obj.repeats
        MAX_PULSES = 10e6;          % int. Maximum number of pulses in acceptable sequences
        MAX_DURATION = Inf;         % double. Maximum duration of pulse.
        
        AVAILABLE_ADDRESSES = 0:7;	% List of all available physical addresses.
                                    % Should be either vector of doubles or cell of char arrays
        NEEDED_FIELDS = {'ipAddress', 'trigger'}
    end
    
    properties (Access = private)
        ps          % PulseStreamer object. Scalar local variable for communication with PS.
        trigger     % PSStart object.
        automaticRearm % PSTriggerMode object
        currentOnChannels
    end
    
    %% 
    methods (Access = private)
        function obj = PulseStreamerNewClass()
            % Private default constructor
            obj@PulseGenerator;
        end
        
        function Initialize(obj, ip, trigType)
            % Normal mode
            obj.ps = PulseStreamer(ip);

            % Debug mode
%             obj.ps = debug.PulseStreamer_RPCLogger(ip);
%             obj.ps.enableLog(10000, sprintf('C:\\Users\\OWNER\\Google Drive\\NV Lab\\Control code\\prod\\PSdebug%s.mat', ip));
            
            obj.initSequence;
            switch lower(trigType)
                % PSTriggerStart is an enumeration with the options 'Immediate', 'Software', 'HardwareRising', 'HardwareFalling' or 'HardwareBoth'.
                case 'hardwarerising'
                    obj.trigger = PSTriggerStart.HardwareRising;
                case 'software'
                    obj.trigger = PSTriggerStart.Software;
                otherwise
                    obj.sendError('%s trigger type is not yet implemented', trigType)
            end
            obj.automaticRearm = PSTriggerMode.Single; % can be 'Normal' or 'Single'.
            obj.ps.setTrigger(obj.trigger, obj.automaticRearm)
        end
    end
    
    %% Channel operation
    methods
        function on(obj, channels)
            obj.On(channels);
        end
        
        function off(obj, channels)
            if ~exist('channels', 'var')
                obj.Off([]);
            else
                obj.Off(channels);
            end
        end
        
        function run(obj)
            if obj.sequenceInMemory % The PS already has it in memory
                if obj.automaticRearm == PSTriggerMode.Single
                    obj.ps.rearm(); % Need to rearm the trigger
                end
            else % The PS doesn't have it in memory
                obj.uploadSequence; 
            end
            if obj.trigger == PSTriggerStart.Software
                obj.ps.startNow;
            end
            
            seqTime = obj.sequence.duration * obj.repeats;
            tic
            TF = hasFinished(obj);
            % tic_vec = []
            while TF == 0
                % pause(seqTime/1e6)
                % start_time = tic
                TF = hasFinished(obj);
                % tic_vec = [tic_vec, toc(start_time)];
                if toc > 5*seqTime
                    error('pulse streamer time out')
                end 
            end
        end

        function sendToHardware(obj)
            % Creates sequence in form legible to hardware
            finalOutputState = OutputState(0,0,0);
            
            % settings for sequence generation
            seq = BooleanHelper.ifTrueElse(obj.delayFixed, obj.delayFixedSequence, obj.sequence);
            pulses = seq.getPulses();
            numberOfSequences = length(pulses);
            
            sequences = [];
            for i = 1:numberOfSequences
                p = pulses(i);
                onChannels = obj.channelName2Address(p.getOnChannels);
                newSequence = P(p.duration * 1e3, onChannels, 0, 0);
                sequences = sequences + newSequence;
            end
            seq_new = convert_PPH_to_PSSequence(sequences); % In the future, need to use the new builder functions
            obj.ps.stream(seq_new, obj.repeats, finalOutputState);
        end
        
        function TF = hasFinished(obj)
            TF = obj.ps.hasFinished();
        end
    end
    
    %% Old methods
        methods
            function inputChannels = On(obj, inputChannels)
                % Turns on channels specified b yname.
                % Also outputs channels to be opened (0,1,2,...,), as a double
                % vector
                inputChannels = obj.channelName2Address(inputChannels); %converts from a cell of names to channel numbers, if needed
                if isempty(inputChannels)
                    channelsBinary = 0;
                    obj.sendWarning('Warning! No channel was turned on or off!');
                else
                    if sum(rem(inputChannels,1)) || min(inputChannels) <0 || max(inputChannels)> max(obj.AVAILABLE_ADDRESSES)
                        error('Input must be integers from 0 to %f', obj.maxDigitalChannels)
                    end
                    channelsBinary = sum(2.^inputChannels);
                end
                % Channles should be on either if they were on until now, or if we asked to turn them on now.
                channelsBinary = bitor(obj.onChannelsBinary, channelsBinary);
                
                obj.chooseOnChannels(channelsBinary);
            end

            function Off(obj, channelNames)
                if isempty(channelNames)
                    % We want everything off
                    channels = 0;
                else
                    inputChannels = obj.channelName2Address(channelNames); % converts from a cell of names to channel numbers, if needed
                    minChan = min(obj.AVAILABLE_ADDRESSES); % Probably 0, but just in case
                    maxChan = max(obj.AVAILABLE_ADDRESSES);
                    if sum(rem(inputChannels,1)) || min(inputChannels) < minChan || max(inputChannels)> maxChan
                        error('Input must be valid channels! Ignoring.')
                    end
                    % We want on only channels which were on before AND NOT
                    % channels which are turned off.
                    channels = bitget(obj.onChannelsBinary,1:8); 
                    channels(inputChannels+1) = false;  % Channels are internally labeled 0:7, but the matlab vector is 1:8
                    channels = binaryVectorToDecimal(channels, 'LSBFirst');
                end

                obj.chooseOnChannels(channels);
            end

            function chooseAnalogOutput(obj, channel, value)
                if channel == 0
                    output = OutputState(obj.onChannelsBinary,value,0);
                elseif channel == 1
                    output = OutputState(obj.onChannelsBinary,0,value);
                else
                    obj.sendError('incorrect channel input')
                    return
                end
                obj.ps.constant(output);
            end
           
        end
        
    methods (Access = private)
        function chooseOnChannels(obj, channels)
            % Turn (or keep) on only the channels referred to by channels.
            % 
            % input:
            % - channels:   binary representation of the channels which are
            %               on. For example, 11 (= 1 + 2 + 8) means that
            %               only channels 0, 1 and 3 are on.
            
            % Set in Streamer
            output = OutputState(channels,0,0);
            obj.ps.constant(output);
            
            % Save state internally
            obj.onChannelsBinary = channels;
        end

    end
    
    
    %% Get instance constructor
    methods (Static, Access = public)
        function obj = getInstance(struct)
            % Returns a singelton instance.
            obj = getObjByName(PulseGenerator.NAME);
            if isempty(obj)
                % None exists, so we create a new one
                missingField = FactoryHelper.usualChecks(struct, PulseStreamerNewClass.NEEDED_FIELDS);
                if ~isnan(missingField)
                    error('Error while creating a PulseStreamer object: missing field "%s"!', missingField);
                end
                
                obj = PulseStreamerNewClass();
                ip = struct.ipAddress;
                trigType = struct.trigger;
                Initialize(obj, ip, trigType)
                
                addBaseObject(obj);
            end
        end
    end
end