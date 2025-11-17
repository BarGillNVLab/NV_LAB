classdef ArduinoGP8413Daq < Daq
    % --- (Properties are unchanged) ---
    %% --- Abstract Properties from Daq (Implemented) ---
    properties
        dummyMode;          % logical. if set to true nothing will actually be passed
        dummyChannel        % vector of doubles. Caches last written values.
        channelArray        % cell array {channel, name, min, max}
        deviceName          % string. The serial port (e.g., 'COM5' or '/dev/ttyACM0')
        analogInputMaxVoltage = 5;
        analogInputMinVoltage = 0;
    end
    
    %% --- Specific Properties for this class ---
    properties (Access = protected)
        serialObj      % MATLAB serialport object
        baudRate = 115200
        nChannels = 4
        outputMinVoltage = 0;
        outputMaxVoltage
    end
    
    properties (Constant, Hidden)
       IDX_CHANNEL = 1;
       IDX_CHANNEL_NAME = 2;
       IDX_CHANNEL_MIN = 3;
       IDX_CHANNEL_MAX = 4;
    end
    
    properties (Constant)
        NAME = 'ArduinoGP8413Daq';
        UNITS = ' V';
        EVENT_DAQR_RESET = 'Arduino_GP8413_Daq_reset';
    end

    %% --- Constructor & Factory ---
    methods
        function obj = ArduinoGP8413Daq(port, outputMaxV, dummyMode)
            % CONSTRUCTOR
            obj@Daq(ArduinoGP8413Daq.NAME); % Call superclass constructor
            
            if nargin < 3, dummyMode = false; end
            if nargin < 2
                error('ArduinoGP8413Daq:MissingArg', ...
                      'Must provide outputMaxVoltage (e.g., 5 or 10) for the GP8413 module.');
            end
            
            obj.deviceName = port;
            obj.dummyMode = dummyMode;
            obj.outputMaxVoltage = outputMaxV;
            obj.dummyChannel = zeros(1, obj.nChannels); 
            
            if ~obj.dummyMode
                try
                    % --- ROBUST HANDSHAKE (MODERN MATLAB SYNTAX) ---
                    
                    % 1. Connect and configure
                    obj.serialObj = serialport(obj.deviceName, obj.baudRate, "Timeout", 5); 
                    configureTerminator(obj.serialObj, "LF"); % MODERN SYNTAX
                    
                    % 2. Wait for Arduino to say "READY"
                    fprintf('ArduinoGP8413Daq: Waiting for Arduino to boot on %s...\n', obj.deviceName);
                    response = readline(obj.serialObj);
                    response = string(response); 
                    
                    if isempty(response) || ~contains(response, "READY")
                       error('ArduinoGP8413Daq:ConnectionFailed', ...
                             'Arduino did not send "READY" signal. Check sketch & serial monitor.');
                    end
                    
                    % 3. Send "PING" to confirm loop is running
                    write(obj.serialObj, "PING\n", "char");
                    response = readline(obj.serialObj);
                    response = string(response);
                    
                    if isempty(response) || ~contains(response, "PONG")
                       error('ArduinoGP8413Daq:ConnectionFailed', ...
                             'Arduino sent "READY", but did not send "PONG". Handshake failed.');
                    end
                    
                    % 4. Handshake complete! Set final timeout.
                    % --- THIS IS THE FIX ---
                    obj.serialObj.Timeout = 2; % Set property directly
                    % --- END FIX ---
                    
                    % --- END ROBUST HANDSHAKE ---
                        
                    fprintf('ArduinoGP8413Daq: Serial connection established on %s.\n', obj.deviceName);
                catch ME
                    errorMsg = sprintf('ArduinoGP8413Daq:FailedToConnect: Could not open serial port %s. Is it correct and available?\nUnderlying Error: %s', ...
                                       obj.deviceName, ME.message);
                    error(errorMsg); 
                end
            else
                fprintf('ArduinoGP8413Daq: Initialized in dummy mode.\n');
            end
        end
        
        % --- (Rest of the class is identical) ---
        
        function delete(obj)
            if ~obj.dummyMode && ~isempty(obj.serialObj)
                if isvalid(obj.serialObj)
                    try
                        for k = 0:obj.nChannels-1
                            cmd = sprintf('SET %d 0.0\n', k);
                            write(obj.serialObj, cmd, "char");
                        end
                    catch
                    end
                    clear obj.serialObj;
                end
            end
        end
    end
    
    methods (Static)
        function create(daqStruct)
            fields = {'deviceName', 'outputMaxVoltage'};
            missingField = FactoryHelper.usualChecks(daqStruct, fields);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Can''t find the reserved word "%s" in the ArduinoGP8413Daq struct', ...
                    missingField);
            end
            
            if isfield(daqStruct, 'dummy')
                dummy = daqStruct.dummy;
            else
                dummy = false;
            end
            
            obj = getObjByName(ArduinoGP8413Daq.NAME);
            if ~isempty(obj)
                delete(obj); 
            end
            
            obj = ArduinoGP8413Daq(daqStruct.deviceName, ...
                                 daqStruct.outputMaxVoltage, ...
                                 dummy);
            addBaseObject(obj); 
        end
    end
    
    %% --- Abstract Method Implementations (from Daq) ---
    methods
        function registerChannel(obj, newChannel, newChannelName, minValueOptional, maxValueOptional)
            
            chNum = sscanf(newChannel, 'ao%d');
            if isempty(chNum) || chNum < 0 || chNum >= obj.nChannels
                error('ArduinoGP8413Daq: Invalid channel "%s". Must be "ao0" to "ao%d".', ...
                      newChannel, obj.nChannels - 1);
            end
            
            if exist('minValueOptional', 'var') && ~isempty(minValueOptional)
                minValue = minValueOptional;
            else
                minValue = obj.outputMinVoltage; % Use hardware min
            end
            if exist('maxValueOptional', 'var') && ~isempty(maxValueOptional)
                maxValue = maxValueOptional;
            else
                maxValue = obj.outputMaxVoltage; % Use hardware max
            end
            
            if ~isempty(obj.channelArray)
                takenIndices = obj.channelArray(:, obj.IDX_CHANNEL);
                channelAlreadyInIndexes = find(strcmp(takenIndices, newChannel));
                if ~isempty(channelAlreadyInIndexes)
                    channelIndex = channelAlreadyInIndexes(1);
                    channelCapturedName = obj.getChannelNameFromIndex(channelIndex);
                    if ~strcmp(newChannelName, channelCapturedName)
                        errorTemplate = 'Can''t assign channel "%s" to "%s", as it has already been taken by "%s"!';
                        errorMsg = sprintf(errorTemplate, newChannel, newChannelName, channelCapturedName);
                        obj.sendError(errorMsg);
                    else
                        return
                    end
                end
            end
            
            newIndex = size(obj.channelArray, 1) + 1;
            obj.channelArray{newIndex, obj.IDX_CHANNEL} = newChannel;
            obj.channelArray{newIndex, obj.IDX_CHANNEL_NAME} = newChannelName;
            obj.channelArray{newIndex, obj.IDX_CHANNEL_MIN} = minValue;
            obj.channelArray{newIndex, obj.IDX_CHANNEL_MAX} = maxValue;
            
            obj.dummyChannel(newIndex) = 0; % Default to 0V
        end
        
        function writeVoltage(obj, channelOrChannelName, newVoltage)
            idx = obj.getIndexFromChannelOrName(channelOrChannelName);
            chStr = obj.getChannelFromIndex(idx); 
            achNum = sscanf(chStr, 'ao%d');
            
            if isempty(achNum)
                error('ArduinoGP8413Daq: Channel "%s" is not a valid analog output.', chStr);
            end
            
            minVal = obj.getChannelMinimumFromIndex(idx);
            maxVal = obj.getChannelMaximumFromIndex(idx);
            
            v = min(max(newVoltage, minVal), maxVal);
            
            obj.dummyChannel(idx) = v;
            
            if obj.dummyMode
                return;
            end
            
            cmd = sprintf('SET %d %.4f\n', achNum, v);
            try
                write(obj.serialObj, cmd, "char");
            catch ME
                errorMsg = sprintf('ArduinoGP8413Daq: Failed to write to serial port %s. Error: %s', ...
                                  obj.deviceName, ME.message);
                obj.sendError(errorMsg);
                obj.reset();
            end
        end
        
        function voltage = readVoltage(obj, channelOrChannelName, varargin)
            idx = obj.getIndexFromChannelOrName(channelOrChannelName);
            voltage = obj.dummyChannel(idx);
        end
    end
    
    %% --- Other Methods (Stubs/Overrides) ---
    methods
        function reset(obj)
            if ~isempty(obj.channelArray)
                for k = 1:size(obj.channelArray, 1)
                    chName = obj.channelArray{k, obj.IDX_CHANNEL};
                    if startsWith(chName, 'ao')
                        obj.writeVoltage(chName, obj.outputMinVoltage);
                    end
                end
            end
            
            if ~obj.dummyMode
                try
                    clear obj.serialObj; 
                    obj.serialObj = serialport(obj.deviceName, obj.baudRate, "Timeout", 2);
                    configureTerminator(obj.serialObj, "LF"); % MODERN SYNTAX
                    pause(2.0); 
                    fprintf('ArduinoGP8413Daq: Serial connection reset on %s.\n', obj.deviceName);
                catch ME
                    errorMsg = sprintf('ArduinoGP8413Daq: Failed to reset serial port %s. Error: %s', ...
                                      obj.deviceName, ME.message);
                    obj.sendError(errorMsg);
end
            end
            
            obj.sendEvent(struct(obj.EVENT_DAQR_RESET, true));
        end
        
        function writeDigital(obj, ~, ~)
            error('ArduinoGP8413Daq:NotSupported', ...
                  'Digital write is not supported by this hardware (GP8413).');
        end
        
        function digitalValue = readDigital(obj, ~)
            digitalValue = false;
            error('ArduinoGP8413Daq:NotSupported', ...
                  'Digital read is not supported by this hardware (GP8413).');
        end
    end
end