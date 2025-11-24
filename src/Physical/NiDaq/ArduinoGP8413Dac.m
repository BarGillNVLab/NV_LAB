classdef ArduinoGP8413Dac < Daq
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
        digitalChannels   % cell array like {'d0','d1',...}
        digitalPins       % numeric array holding the underlying Arduino pin index
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
        function obj = ArduinoGP8413Dac(port, outputMaxV, dummyMode)
            % CONSTRUCTOR
            obj@Daq(ArduinoGP8413Dac.NAME);    

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
        %REGISTERCHANNEL Register an analog (DAC) or digital channel.
        %
        % newChannel:
        %   - 'ao0', 'ao1', ...  : GP8413 DAC channels
        %   - 'd2', 'd3', ...    : Arduino digital pins (used e.g. as SPCM gate)
        %
        % newChannelName:
        %   Logical name, e.g. 'greenLaserAOM', 'spcm_gate', etc.
        %
        % minValueOptional / maxValueOptional:
        %   - For analog channels: range in volts (defaults to [outputMinVoltage, outputMaxVoltage])
        %   - For digital channels: ignored, fixed to [0, 1].

        % ---------- Decide if this is digital or analog ----------
        isDigital = startsWith(newChannel, 'd', 'IgnoreCase', true);

        if isDigital
            % Digital channel: must be of the form 'dN'
            pin = sscanf(newChannel(2:end), '%d');
            if isempty(pin) || pin < 0
                error('ArduinoGP8413Daq:BadDigitalChannel', ...
                      'Digital channel "%s" must be of the form dN (e.g. "d2").', ...
                      newChannel);
            end

            % Digital channels are treated as [0,1] logical.
            minValue = 0;
            maxValue = 1;

        else
            % Analog channel: we expect 'aoN'
            if ~startsWith(newChannel, 'ao', 'IgnoreCase', true)
                error('ArduinoGP8413Daq:BadAnalogChannel', ...
                      'Analog channel "%s" must be of the form aoN (e.g. "ao0").', ...
                      newChannel);
            end

            chNum = sscanf(newChannel(3:end), '%d');
            if isempty(chNum) || chNum < 0 || chNum >= obj.nChannels
                error('ArduinoGP8413Daq:BadAnalogChannelIndex', ...
                      'Analog channel "%s" must be ao0..ao%d.', ...
                      newChannel, obj.nChannels-1);
            end

            % Determine analog range
            if exist('minValueOptional','var') && ~isempty(minValueOptional)
                minValue = minValueOptional;
            else
                minValue = obj.outputMinVoltage; % typically 0 V
            end
            if exist('maxValueOptional','var') && ~isempty(maxValueOptional)
                maxValue = maxValueOptional;
            else
                % You MUST have a property outputMaxVoltage in this class
                % set from the constructor (5 or 10 V).
                maxValue = obj.outputMaxVoltage;
            end
        end

        % ---------- Check for duplicate hardware channel ----------
        if ~isempty(obj.channelArray)
            takenChannels = obj.channelArray(:, obj.IDX_CHANNEL);
            alreadyIdx = find(strcmp(takenChannels, newChannel));
            if ~isempty(alreadyIdx)
                channelIndex = alreadyIdx(1);
                existingName = obj.getChannelNameFromIndex(channelIndex);
                if ~strcmp(newChannelName, existingName)
                    % Same physical channel, different logical name -> error
                    errorTemplate = ['Can''t assign channel "%s" to "%s", ', ...
                                     'as it has already been taken by "%s"!'];
                    errorMsg = sprintf(errorTemplate, newChannel, newChannelName, existingName);
                    obj.sendError(errorMsg);
                end
                % If the name is the same, we just return (re-registering is fine)
                return;
            end
        end

        % ---------- Append to channelArray ----------
        newIndex = size(obj.channelArray, 1) + 1;
        obj.channelArray{newIndex, obj.IDX_CHANNEL}      = newChannelName;
        obj.channelArray{newIndex, obj.IDX_CHANNEL_NAME} = newChannel;
        obj.channelArray{newIndex, obj.IDX_CHANNEL_MIN}  = minValue;
        obj.channelArray{newIndex, obj.IDX_CHANNEL_MAX}  = maxValue;

        % Ensure dummyChannel is large enough
        if numel(obj.dummyChannel) < newIndex
            obj.dummyChannel(newIndex) = 0;
        end
    end
        
    function writeVoltage(obj, channelOrChannelName, newVoltage)
            idx = obj.getIndexFromChannelOrName(channelOrChannelName);
            chStr = obj.channelArray{idx, 2}; 
            achNum = sscanf(chStr, 'ao%d');
            
            if isempty(achNum)
                error('ArduinoGP8413Daq: Channel "%s" is not a valid analog output.', chStr);
            end
            
            minVal = obj.outputMinVoltage;
            maxVal = obj.outputMaxVoltage;
            
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
        
    function writeDigital(obj, channelOrChannelName, newLogicalValue)
        % Simple digital output via Arduino.
        % channelOrChannelName: e.g. 'd2' or a registered logical name.
        %
        % newLogicalValue: logical or 0/1 numeric.

        if obj.dummyMode
            % Just cache it in dummyChannel if you want; or ignore.
            return;
        end
        idx = obj.getIndexFromChannelOrName(channelOrChannelName);
        chStr = obj.channelArray{idx, 2}; 
        achNum = sscanf(chStr, 'd%d');
        
        if isempty(achNum)
            error('ArduinoGP8413Daq: Channel "%s" is not a valid digital output.', chStr);
        end
        % Resolve logical name to channel string if needed
        % If you want, you can re-use Daq.getIndexFromChannelOrName here,
        % but for gate-only use we can also assume direct 'dN' naming.

        if ~startsWith(chStr,'d','IgnoreCase',true)
            error('ArduinoGP8413Daq:writeDigital', ...
                  'Arduino digital lines must be named like "dN" (got "%s").', ...
                  chStr);
        end

        pin = sscanf(chStr(2:end),'%d');
        if isempty(pin)
            error('ArduinoGP8413Daq:writeDigital', ...
                  'Could not parse digital pin from "%s".', chStr);
        end

        v = logical(newLogicalValue);
        cmd = sprintf('DSET %d %d\n', pin, v);
        try
            write(obj.serialObj, cmd, "char");
        catch ME
            error('ArduinoGP8413Daq:writeDigitalFailed', ...
                  'Failed to write digital to Arduino: %s', ME.message);
        end
    end

    function digitalValue = readDigital(obj, channelOrChannelName)
        % Optional digital read; not strictly needed for SPCM gate,
        % but we provide a simple implementation.
        if obj.dummyMode
            digitalValue = false;
            return;
        end

        chStr = channelOrChannelName;
        if ~startsWith(chStr,'d','IgnoreCase',true)
            error('ArduinoGP8413Daq:readDigital', ...
                  'Arduino digital lines must be named like "dN" (got "%s").', ...
                  chStr);
        end

        pin = sscanf(chStr(2:end),'%d');
        if isempty(pin)
            error('ArduinoGP8413Daq:readDigital', ...
                  'Could not parse digital pin from "%s".', chStr);
        end

        cmd = sprintf('DGET %d\n', pin);
        try
            write(obj.serialObj, cmd, "char");
            resp = strtrim(readline(obj.serialObj));
            digitalValue = (str2double(resp) ~= 0);
        catch ME
            error('ArduinoGP8413Daq:readDigitalFailed', ...
                  'Failed to read digital from Arduino: %s', ME.message);
        end
    end
        
    end
    methods
        function isDig = isDigitalChannel(obj, ch)
            isDig = ischar(ch) && ~isempty(regexp(ch, '^d\d+$','once'));
        end
    
        function isAn = isAnalogChannel(obj, ch)
            isAn = ischar(ch) && ~isempty(regexp(ch, '^ao\d+$','once'));
        end
    end

end