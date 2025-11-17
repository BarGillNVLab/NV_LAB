classdef (Abstract) Daq < EventSender
    % Daq - Abstract base class + strict factory for DAQ backends.
    %
    % Subclasses MUST implement:
    %   - registerChannel(obj, newChannel, newChannelName, minValueOptional, maxValueOptional)
    %   - writeVoltage(obj, channelOrChannelName, newVoltage)
    %   - readVoltage(obj, channelOrChannelName, varargin)
    %
    % This base class provides:
    %   • Shared channel table utilities (index/name/range accessors)
    %   • Dummy-mode helpers (cache last written values)
    %   • Optional digital I/O stubs (override in hardware subclasses)
    %   • A STRICT factory Daq.create(cfg) – no backend guessing.
    %
    % Expected cfg for Daq.create:
    %   cfg.type             : 'nidaq' | 'arduinodaq'          (REQUIRED)
    %   cfg.deviceName       : e.g. 'Dev1' or 'COM6'           (REQUIRED)
    %   cfg.dummy            : logical                         (optional, default false)
    %   cfg.outputMaxVoltage : 5 or 10                         (REQUIRED for 'arduinodaq')
    %
    % Example:
    %   d1 = Daq.create(struct('type','nidaq','deviceName','Dev1'));
    %   d2 = Daq.create(struct('type','arduinodaq','deviceName','COM6','outputMaxVoltage',10));

    %% --------- Abstract properties to be provided by concrete backends ---------
    properties (Abstract)
        dummyMode                 % logical, if true do not talk to hardware
        dummyChannel              % numeric vector, caches last written values per registered channel
        channelArray              % cell Nx4: {channel, name, min, max}
        deviceName                % string/char identifying the hardware (e.g., 'Dev1', 'COM6', '/dev/ttyACM0')
        analogInputMaxVoltage     % numeric scalar
        analogInputMinVoltage     % numeric scalar
    end

    %% --------- Abstract API to be implemented by subclasses ---------
    methods (Abstract)
        registerChannel(obj, newChannel, newChannelName, minValueOptional, maxValueOptional)
        writeVoltage(obj, channelOrChannelName, newVoltage)
        voltage = readVoltage(obj, channelOrChannelName, varargin)
    end

    %% --------- Shared channel utilities (work for both NI & Arduino) ---------
    methods
        function idx = getIndexFromChannelOrName(obj, channelOrChannelName)
            % Locate a row in channelArray by its hardware channel or by its given name.
            if isempty(obj.channelArray)
                error('Daq:ChannelTableEmpty','No channels registered in channelArray.');
            end
            channelOrChannelName = char(channelOrChannelName);

            channelNames = obj.channelArray(:, 2);
            channelIds   = obj.channelArray(:, 1);

            idx = find(strcmp(channelNames, channelOrChannelName), 1, 'first');
            if ~isempty(idx); return; end

            idx = find(strcmp(channelIds, channelOrChannelName), 1, 'first');
            if ~isempty(idx); return; end

            error('Daq:ChannelNotFound','Channel or channel name "%s" not found.', channelOrChannelName);
        end

        function name = getChannelNameFromIndex(obj, idx)
            name = obj.channelArray{idx, 2};
        end

        function chan = getChannelFromIndex(obj, idx)
            chan = obj.channelArray{idx, 1};
        end

        function minVal = getChannelMinimumFromIndex(obj, idx)
            minVal = obj.channelArray{idx, 3};
            if ~isnumeric(minVal), minVal = str2double(minVal); end
            if isnan(minVal), minVal = 0; end
        end

        function maxVal = getChannelMaximumFromIndex(obj, idx)
            maxVal = obj.channelArray{idx, 4};
            if ~isnumeric(maxVal), maxVal = str2double(maxVal); end
            if isnan(maxVal), maxVal = 1; end
        end

        function [minVal, maxVal] = getChannelRange(obj, channelOrChannelName)
            idx = obj.getIndexFromChannelOrName(channelOrChannelName);
            minVal = obj.getChannelMinimumFromIndex(idx);
            maxVal = obj.getChannelMaximumFromIndex(idx);
        end

        function setChannelDummyValue(obj, channelOrChannelName, value)
            idx = obj.getIndexFromChannelOrName(channelOrChannelName);
            obj.dummyChannel(idx) = value;
        end

        function value = getChannelDummyValue(obj, channelOrChannelName)
            idx = obj.getIndexFromChannelOrName(channelOrChannelName);
            value = obj.dummyChannel(idx);
        end
    end

    %% --------- Optional digital I/O (stubs). Override in hardware backends if needed ---------
    methods
        function val = readDigital(obj, varargin) %#ok<INUSD>
            warning('Daq:readDigital:NotImplemented','Digital read not implemented in base Daq.');
            val = false;
        end

        function writeDigital(obj, varargin) %#ok<INUSD>
            warning('Daq:writeDigital:NotImplemented','Digital write not implemented in base Daq.');
        end
    end

    %% --------- Reset / error utilities (can be overridden by backends) ---------
    methods
        function reset(obj) %#ok<MANU>
            % Default: no hardware-specific reset in base class.
            fprintf('[Daq] Reset requested (override in subclass if needed).\n');
        end

        function checkError(obj, status) %#ok<INUSD>
            % Base helper: treat nonzero numeric status as error.
            if isnumeric(status) && ~isscalar(status)
                error('Daq:HardwareError','Non-scalar status returned from hardware.');
            end
            if isnumeric(status) && status ~= 0
                error('Daq:HardwareError','Hardware returned error status: %d', status);
            end
            % Subclasses (e.g., NiDaq) should override this to query vendor error strings.
        end
    end

    %% --------- Static helpers ---------
    methods (Static)
        function d = countDiff(counts)
            % Edge-count overflow-safe diff (uint32 counters)
            maxCounts = 2^32;
            d = diff(counts);
            d(d < 0) = d(d < 0) + maxCounts;
        end
    end

    %% --------- STRICT factory (no backend guessing) ---------
    methods (Static)
        function obj = create(cfg)
            % Create a concrete DAQ from a config struct.
            % Required fields:
            %   cfg.type        : 'nidaq' | 'arduinodaq'
            %   cfg.deviceName  : string/char
            % Optional:
            %   cfg.dummy       : logical (default false)
            %   cfg.outputMaxVoltage : 5 or 10 (REQUIRED for arduinodaq)
            %
            % Example:
            %   d = Daq.create(struct('type','nidaq','deviceName','Dev1'));
            %   a = Daq.create(struct('type','arduinodaq','deviceName','COM6','outputMaxVoltage',10));

            if ~isstruct(cfg)
                error('Daq:create:BadInput','Expected a struct with fields "type" and "deviceName".');
            end
            if ~isfield(cfg,'type') || isempty(cfg.type)
                error('Daq:create:MissingType','Field "type" is required (e.g., "nidaq" or "arduinodaq").');
            end
            if ~isfield(cfg,'deviceName') || isempty(cfg.deviceName)
                error('Daq:create:MissingDevice','Field "deviceName" is required.');
            end
            dummy = Daq.i_get(cfg,'dummy',false);

            switch lower(string(cfg.type))
                case "nidaq"
                    % Constructor signature: NiDaq(deviceName, dummy)
                    obj = NiDaq(cfg.deviceName, dummy);

                case "arduinodaq"
                    % Constructor signature: ArduinoGP8413Daq(deviceName, outputMaxVoltage(5|10), dummy)
                    if ~isfield(cfg,'outputMaxVoltage') || isempty(cfg.outputMaxVoltage)
                        error('Daq:create:MissingOutputMaxVoltage', ...
                              'Arduino DAQ requires "outputMaxVoltage" (5 or 10).');
                    end
                    omv = cfg.outputMaxVoltage;
                    if ~ismember(omv,[5 10])
                        error('Daq:create:BadOutputMaxVoltage', ...
                              '"outputMaxVoltage" must be 5 or 10 (got %s).', mat2str(omv));
                    end
                    obj = ArduinoGP8413Daq(cfg.deviceName, omv, dummy);

                otherwise
                    error('Daq:create:UnknownType','Unknown Daq type: %s', cfg.type);
            end

            % Optional: register in your object system, if present.
            try
                addBaseObject(obj);
            catch
                % ignore if your framework doesn't use addBaseObject
            end
        end
    end

    methods (Static, Access = private)
        function v = i_get(s, f, def)
            if isfield(s,f) && ~isempty(s.(f)), v = s.(f); else, v = def; end
        end
    end
end
