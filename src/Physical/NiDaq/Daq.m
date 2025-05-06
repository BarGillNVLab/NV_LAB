classdef Daq < EventSender
    %Daq Abstract base class for DAQ devices.
    %   This class provides a common interface for interacting with
    %   data acquisition (DAQ) hardware such as NI-DAQ and MyRIO devices.
    %   Subclasses must implement device-specific functionality.

    properties (Access = protected)
        deviceName  % String. Device name used by driver functions.
        dummyMode = false;   % Logical. If true, no hardware interaction.
        dummyChannel = [];   % Vector of doubles for dummy channel values.
        channelArray = {};
        % 2D cell array:
        % 1st column - channel IDs ('dev/...')
        % 2nd column - channel names ('signal_1')
        % 3rd column - channel minimum value
        % 4th column - channel maximum value
    end

    properties (Constant, Hidden)
        % Indices for channelArray columns
        IDX_CHANNEL = 1;
        IDX_CHANNEL_NAME = 2;
        IDX_CHANNEL_MIN = 3;
        IDX_CHANNEL_MAX = 4;

        % Default voltage range
        DEFAULT_MIN_VOLTAGE = 0;
        DEFAULT_MAX_VOLTAGE = 1;
    end

    methods (Access = protected)
        function obj = Daq(deviceName, subclassName, dummyMode)
            %Daq Constructor.
            %   deviceName: String identifying the DAQ device.
            %   subclassName:  Name of the specific DAQ subclass (e.g., 'NiDaq').
            %   dummyMode:  Optional logical to enable dummy mode (default: false).
            if nargin < 3
                dummyMode = false;
            end
            obj@EventSender(subclassName); % Call superclass constructor
            obj.deviceName = deviceName;
            obj.dummyMode = dummyMode;
            obj.initDaq(); % Initialize DAQ
        end

        function initDaq(obj)
            %initDaq Initializes the DAQ device.
            %   This method should be overridden by subclasses to perform
            %   device-specific initialization.
            %   For example, loading libraries, setting up basic channels
            %   Subclasses MUST call this parent's version.
           
            obj.registerChannel('100MHzTimebase', '100MHz');
            obj.registerChannel('100kHzTimebase', '100kHz');
        end

        function index = getIndexFromChannelOrName(obj, channelOrChannelName)
            %getIndexFromChannelOrName Gets index of a channel by ID or name.
            %   Finds the index of a channel within the channelArray,
            %   given either the channel ID (e.g., 'ai0') or the channel
            %   name (e.g., 'my_signal').  Throws an error if not found.
            if startsWith(channelOrChannelName, '_')
                %Handle virtual channels (example from NiDaq.m)
                 channelOrChannelName = regexprep(channelOrChannelName, '_.*$', '');
            end
            
            channelNamesIndexes = find(strcmp(obj.channelArray(:, obj.IDX_CHANNEL_NAME), channelOrChannelName));
            if ~isempty(channelNamesIndexes)
                index = channelNamesIndexes(1);
                return;
            end
            
            channelIndexes = find(strcmp(obj.channelArray(:, obj.IDX_CHANNEL), channelOrChannelName));
            if ~isempty(channelIndexes)
                index = channelIndexes(1);
                return;
            end
            
            error('%s: Channel or channel name "%s" not found.', obj.Name, channelOrChannelName);
        end

        function channelName = getChannelNameFromIndex(obj, index)
            %getChannelNameFromIndex Gets the channel name from its index.
            channelName = obj.channelArray{index, obj.IDX_CHANNEL_NAME};
        end

        function channel = getChannelFromIndex(obj, index)
            %getChannelFromIndex Gets the channel ID from its index.
            channel = obj.channelArray{index, obj.IDX_CHANNEL};
        end

        function minVal = getChannelMinimumFromIndex(obj, index)
            %getChannelMinimumFromIndex Gets the minimum value for a channel.
            minVal = obj.channelArray{index, obj.IDX_CHANNEL_MIN};
            if ~isnumeric(minVal)
                minVal = str2double(minVal);
            end
            if isnan(minVal)
                minVal = obj.DEFAULT_MIN_VOLTAGE;
            end
        end

        function maxVal = getChannelMaximumFromIndex(obj, index)
            %getChannelMaximumFromIndex Gets the maximum value for a channel.
            maxVal = obj.channelArray{index, obj.IDX_CHANNEL_MAX};
            if ~isnumeric(maxVal)
                maxVal = str2double(maxVal);
            end
            if isnan(maxVal)
                maxVal = obj.DEFAULT_MAX_VOLTAGE;
            end
        end

        function task = createTask(obj)
            %createTask Creates a DAQ task.
            %   This should be overridden if the syntax is different
            %   for other hardware
            if obj.dummyMode
                task = []; % Or some dummy value
                return
            end
            [status, ~, task] = DAQmxCreateTask([]);
            obj.checkError(status);
        end

        function clearTask(obj, task)
            %clearTask Clears a DAQ task.
            %   This should be overridden if the syntax is different
            %   for other hardware
            if obj.dummyMode
                return
            end
            status = DAQmxClearTask(task);
            obj.checkError(status)
        end

        function startTask(obj, task)
            %startTask Starts a DAQ task.
            %   This should be overridden if the syntax is different
            %   for other hardware
            if obj.dummyMode; return; end
            
            status = DAQmxStartTask(task);
            obj.checkError(status)
        end
        
         function stopTask(obj, task)
            %stopTask Stops a DAQ task.
            %   This should be overridden if the syntax is different
            %   for other hardware
            if obj.dummyMode; return; end
            
            status = DAQmxStopTask(task);
            obj.checkError(status)
        end

        function endTask(obj, task)
            %endTask Stops and clears a DAQ task.
            %   This should be overridden if the syntax is different
            %   for other hardware
            if obj.dummyMode; return; end
            
            obj.stopTask(task);
            obj.clearTask(task)
        end
    end

    methods
        function registerChannel(obj, newChannel, newChannelName, minValue, maxValue)
            %registerChannel Registers a channel.
            %   Adds a channel to the channelArray.
            %   newChannel:     Channel ID (e.g., 'ai0', 'port1/line3').
            %   newChannelName: User-friendly name (e.g., 'input_signal', 'laser_trigger').
            %   minValue:       Minimum expected value (optional, default: 0).
            %   maxValue:       Maximum expected value (optional, default: 1).
            if nargin < 4
                maxValue = obj.DEFAULT_MAX_VOLTAGE;
            end
            if nargin < 3
                minValue = obj.DEFAULT_MIN_VOLTAGE;
            end

            % Check for duplicate channels
            if ~isempty(obj.channelArray)
                existingChannels = obj.channelArray(:, obj.IDX_CHANNEL);
                if any(strcmp(existingChannels, newChannel))
                    error('%s: Channel "%s" already exists.', obj.Name, newChannel);
                end
                existingNames = obj.channelArray(:, obj.IDX_CHANNEL_NAME);
                 if any(strcmp(existingNames, newChannelName))
                    error('%s: Channel name "%s" already exists.', obj.Name, newChannelName);
                end
            end

            % Add the channel
            obj.channelArray(end+1, :) = {newChannel, newChannelName, minValue, maxValue};

            %Dummy mode default value
            if obj.dummyMode
                obj.dummyChannel(length(obj.channelArray)) = -1;
            end
        end
    end

    methods (Static)
         function create(daqStruct)
            %create Factory method to create DAQ objects.
            %   daqStruct:  Struct containing deviceName (required) and
            %               optionally 'dummy' (logical).
            %               Now also requires 'daqType' (e.g., 'nidaq', 'myrio').
            %               Example:
            %               struct with fields:
            %               daqType: 'nidaq'
            %               dummy: 0
            %               deviceName: 'dev1'

            missingField = FactoryHelper.usualChecks(daqStruct, {'deviceName', 'daqType'});
            if ~isnan(missingField)
                error('Daq:MissingField', 'Missing field: %s', missingField);
            end

            if isfield(daqStruct, 'dummy')
                dummy = daqStruct.dummy;
            else
                dummy = false;
            end
            
            switch lower(daqStruct.daqType)
                case 'nidaq'
                    className = 'NiDaq';
                case 'myrio'
                    className = 'MyRioDaq'; % Assuming you'll create this
                otherwise
                    error('Daq:UnknownDaqType', 'Unknown DAQ type: %s', daqStruct.daqType);
            end
            
            obj = getObjByName(className); % Assuming getObjByName exists
            if ~isempty(obj)
                % Initialize existing object
                obj.init(daqStruct.deviceName, dummy); % Assuming init exists
            else
                % Create new object
                obj = feval(className, daqStruct.deviceName, dummy);
                addBaseObject(obj); % Assuming addBaseObject exists
            end
         end
    end
    
    methods (Access = protected)
        function checkError(obj, status)
            %checkError Checks for errors and sends an event.
            %   Override this in subclasses to customize error handling
            %   for specific DAQ drivers.
            if status ~= 0
                bufferSize = uint32(500);
                errorString = char(ones(1,bufferSize));
                [statusInternal, errorString]=daq.ni.NIDAQmx.DAQmxGetErrorString(status, errorString, bufferSize);
                obj.reset;
                if statusInternal ~= 0 || isempty(errorString)
                    obj.sendError(['DAQ Error ' num2str(status)])
                else
                    obj.sendError(['DAQ Error ' num2str(status) ': ' errorString]);
                end
            end
        end

        function reset(obj)
            %reset Resets the DAQ device.
            %   Override this in subclasses if a device-specific reset
            %   procedure is needed.
            DAQmxResetDevice(obj.deviceName);
            fprintf('DAQ Card Ready! (reset)\n');
            % Assuming you have a method to send events
            obj.sendEvent(struct('DaqReset', true));
        end
    end
end