classdef ArduinoDaq < Daq
    %ArduinoDaq DAQ implementation for Arduino analog and digital I/O via serial.
    %   Supports up to 8 analog output channels (0-5V) and digital I/O (d0-d13).
    %   Expects Arduino firmware that receives commands:
    %   "SET n v\n" for analog out, "DSET n v\n" for digital out, "DGET n\n" for digital in.

    properties (Access = protected)
        serialObj      % MATLAB serialport object
        port           % Serial port (e.g., 'COM5')
        baudRate = 115200
        nChannels = 8  % Number of analog output channels
        lastValues     % Cache of last set values for each channel
    end

    properties (Constant)
        NAME = 'ArduinoDaq';
        UNITS = ' V';
    end

    methods
        function obj = ArduinoDaq(deviceName, dummyMode)
            % deviceName: serial port (e.g., 'COM5')
            if nargin < 2, dummyMode = false; end
            obj@Daq(deviceName, ArduinoDaq.NAME, dummyMode);
            obj.port = deviceName;
            obj.lastValues = zeros(1, obj.nChannels);
            if ~obj.dummyMode
                obj.serialObj = serialport(obj.port, obj.baudRate);
                configureTerminator(obj.serialObj, "LF");
            end
        end
        
        function writePWM(obj, channelOrChannelName, dutyCycle)
            % Set PWM output on specified digital channel (e.g., d0-d13)
            % dutyCycle: 0-255 (or 0-100 for percent, adjust as needed)
            idx = obj.getIndexFromChannelOrName(channelOrChannelName);
            chStr = obj.getChannelFromIndex(idx);
            chNum = sscanf(chStr, 'd%d');
            if isempty(chNum)
                error('ArduinoDaq: PWM channels must be named d0, d1, ..., d13');
            end
            if dutyCycle < 0, dutyCycle = 0; end
            if dutyCycle > 255, dutyCycle = 255; end
            if obj.dummyMode, return; end
            cmd = sprintf('PWM %d %d\n', chNum, round(dutyCycle));
            write(obj.serialObj, cmd, "char");
        end

        function delete(obj)
            if ~obj.dummyMode && ~isempty(obj.serialObj)
                try
                    clear obj.serialObj;
                catch
                end
            end
        end

        function registerChannel(obj, newChannel, newChannelName, minValue, maxValue)
            % Register an analog output channel (0-7)
            if nargin < 4, minValue = 0; end
            if nargin < 5, maxValue = 5; end
            chNum = sscanf(newChannel, 'ao%d');
            if isempty(chNum) || chNum < 0 || chNum >= obj.nChannels
                error('ArduinoDaq: Only ao0-ao7 are supported.');
            end
            registerChannel@Daq(obj, newChannel, newChannelName, minValue, maxValue);
        end

        function writeVoltage(obj, channelOrChannelName, newVoltage)
            % Set analog output voltage on specified channel
            idx = obj.getIndexFromChannelOrName(channelOrChannelName);
            chStr = obj.getChannelFromIndex(idx);
            achNum = sscanf(chStr, 'ao%d');
            dchNum = sscanf(chStr, 'd%d');
            minVal = obj.getChannelMinimumFromIndex(idx);
            maxVal = obj.getChannelMaximumFromIndex(idx);
            if isempty(achNum) && isempty(dchNum)
                error('ArduinoDaq: channels must be named d0, d1, ..., d13 or ao0, ao1, ...');
            elseif ~isempty(dchNum)
                % Set PWM output on specified digital channel (e.g., d0-d13)
                writePWM(obj, channelOrChannelName, newVoltage/5)
            elseif ~isempty(achNum)
                v = min(max(newVoltage, minVal), maxVal);
                obj.lastValues(achNum+1) = v;
                if obj.dummyMode, return; end
                cmd = sprintf('SET %d %.3f\n', achNum, v);
                write(obj.serialObj, cmd, "char");
            end
            
        end

        function voltage = readVoltage(obj, channelOrChannelName, ~, ~)
            % Return last set value (Arduino can't read back analog out)
            idx = obj.getIndexFromChannelOrName(channelOrChannelName);
            chStr = obj.getChannelFromIndex(idx);
            chNum = sscanf(chStr, 'ao%d');
            voltage = obj.lastValues(chNum+1);
        end

        function reset(obj)
            % Optionally reset all outputs to 0V
            for k = 0:obj.nChannels-1
                obj.writeVoltage(sprintf('ao%d', k), 0);
            end
            obj.sendEvent(struct('DaqReset', true));
        end

        function writeDigital(obj, channelOrChannelName, newLogicalValue)
            % Set digital output on specified channel (e.g., d0-d13)
            idx = obj.getIndexFromChannelOrName(channelOrChannelName);
            chStr = obj.getChannelFromIndex(idx);
            chNum = sscanf(chStr, 'd%d');
            if isempty(chNum)
                error('ArduinoDaq: Digital channels must be named d0, d1, ..., d13');
            end
            v = logical(newLogicalValue);
            if obj.dummyMode, return; end
            cmd = sprintf('DSET %d %d\n', chNum, v);
            write(obj.serialObj, cmd, "char");
        end

        function digitalValue = readDigital(obj, channelOrChannelName)
            % Read digital input from specified channel (e.g., d0-d13)
            idx = obj.getIndexFromChannelOrName(channelOrChannelName);
            chStr = obj.getChannelFromIndex(idx);
            chNum = sscanf(chStr, 'd%d');
            if isempty(chNum)
                error('ArduinoDaq: Digital channels must be named d0, d1, ..., d13');
            end
            if obj.dummyMode
                digitalValue = false;
                return;
            end
            cmd = sprintf('DGET %d\n', chNum);
            write(obj.serialObj, cmd, "char");
            digitalValue = str2double(readline(obj.serialObj)) > 0;
        end
    end

    methods (Static)
        function create(daqStruct)
            % Factory method for Daq.create
            missingField = FactoryHelper.usualChecks(daqStruct, {'deviceName'});
            if ~isnan(missingField)
                error('ArduinoDaq: Missing field: %s', missingField);
            end
            if isfield(daqStruct, 'dummy')
                dummy = daqStruct.dummy;
            else
                dummy = false;
            end
            obj = getObjByName(ArduinoDaq.NAME);
            if ~isempty(obj)
                obj.initDaq();
            else
                obj = ArduinoDaq(daqStruct.deviceName, dummy);
                addBaseObject(obj);
            end
        end
    end
end