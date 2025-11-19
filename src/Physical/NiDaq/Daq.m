classdef (Abstract) Daq < EventSender
    % Daq - Abstract base class + strict factory for DAQ backends.
    %
    % Subclasses MUST implement:
    %   • registerChannel(obj, newChannel, newChannelName, minVal, maxVal)
    %   • writeVoltage(obj, channelOrChannelName, newVoltage)
    %   • readVoltage(obj, channelOrChannelName)
    %
    % This class defines:
    %   • Shared channel table utilities (index/name/range)
    %   • Dummy-mode helpers
    %   • Optional digital I/O (default stubs)
    %   • Strict factory Daq.create(cfg)
    %

    %% -------- Abstract properties implemented by concrete DAQs --------
    properties (Abstract)
        dummyMode                 % logical
        dummyChannel              % numeric vector of last-written values
        channelArray              % cell Nx4 {hardwareID, logicalName, min, max}
        deviceName                % string identifying the hardware (Dev1, COM6, etc.)
        analogInputMaxVoltage
        analogInputMinVoltage
    end

    %% -------- Constructor --------
    methods
        function obj = Daq(name)
            % The EventSender constructor requires a name.
            % DAQ subclasses call:  obj = obj@Daq('SomeName')
            if nargin < 1
                name = 'daq';
            end
            obj@EventSender(name);
        end
    end

    %% -------- Abstract Interface --------
    methods (Abstract)
        registerChannel(obj, newChannel, newChannelName, minValueOptional, maxValueOptional)
        writeVoltage(obj, channelOrChannelName, newVoltage)
        voltage = readVoltage(obj, channelOrChannelName, varargin)
    end

    %% -------- Shared Channel Utilities --------
    methods
        function idx = getIndexFromChannelOrName(obj, channelOrChannelName)
            if isempty(obj.channelArray)
                error('Daq:ChannelTableEmpty', ...
                    'No channels registered in channelArray.');
            end
            target = char(channelOrChannelName);

            names  = obj.channelArray(:,2);
            ids    = obj.channelArray(:,1);

            % Try by logical name
            idx = find(strcmp(names, target), 1);
            if ~isempty(idx), return; end

            % Try by hardware ID
            idx = find(strcmp(ids, target), 1);
            if ~isempty(idx), return; end

            error('Daq:ChannelNotFound', ...
                  'Channel or channelName "%s" not found.', target);
        end

        function out = getChannelNameFromIndex(obj, idx)
            out = obj.channelArray{idx,2};
        end

        function out = getChannelFromIndex(obj, idx)
            out = obj.channelArray{idx,1};
        end

        function minVal = getChannelMinimumFromIndex(obj, idx)
            minVal = obj.channelArray{idx,3};
            if ~isnumeric(minVal)
                minVal = str2double(minVal);
            end
            if isnan(minVal)
                minVal = 0;
            end
        end

        function maxVal = getChannelMaximumFromIndex(obj, idx)
            maxVal = obj.channelArray{idx,4};
            if ~isnumeric(maxVal)
                maxVal = str2double(maxVal);
            end
            if isnan(maxVal)
                maxVal = 1;
            end
        end

        function [minVal, maxVal] = getChannelRange(obj, channelOrChannelName)
            idx       = obj.getIndexFromChannelOrName(channelOrChannelName);
            minVal    = obj.getChannelMinimumFromIndex(idx);
            maxVal    = obj.getChannelMaximumFromIndex(idx);
        end

        function setChannelDummyValue(obj, channelOrChannelName, val)
            idx = obj.getIndexFromChannelOrName(channelOrChannelName);
            obj.dummyChannel(idx) = val;
        end

        function val = getChannelDummyValue(obj, channelOrChannelName)
            idx = obj.getIndexFromChannelOrName(channelOrChannelName);
            val = obj.dummyChannel(idx);
        end
    end

    %% -------- Optional Digital I/O (Overridden by •NiDaq •Arduino) --------
    methods
        function val = readDigital(obj, varargin)
            warning('Daq:readDigital:NotImplemented', ...
                'Digital read not implemented for this backend.');
            val = false;
        end

        function writeDigital(obj, varargin)
            warning('Daq:writeDigital:NotImplemented', ...
                'Digital write not implemented for this backend.');
        end
    end

    %% -------- Reset / Error Handling --------
    methods
        function reset(obj)
            % Default behavior: no hardware reset (subclasses override)
            fprintf('[Daq] reset() called — no hardware reset in base class.\n');
        end

        function checkError(obj, status)
            if isnumeric(status) && ~isscalar(status)
                error('Daq:HardwareError', ...
                      'Non-scalar hardware status returned.');
            end
            if isnumeric(status) && status ~= 0
                error('Daq:HardwareError', ...
                      'Hardware returned error status %d', status);
            end
        end
    end

    %% -------- Helper Tools --------
    methods (Static)
        function d = countDiff(counts)
            maxCnt = 2^32;
            d = diff(counts);
            d(d < 0) = d(d < 0) + maxCnt;
        end
    end

    %% -------- STRICT Factory --------
    methods (Static)
        function obj = create(cfg)
            if ~isstruct(cfg)
                error('Daq:create:BadInput', ...
                      'Input must be a config struct.');
            end

            if ~isfield(cfg,'type')
                error('Daq:create:MissingType', ...
                      '"Daq.type" is required in JSON.');
            end
            if ~isfield(cfg,'deviceName')
                error('Daq:create:MissingDevice', ...
                      '"deviceName" field is required in JSON.');
            end

            dummy = Daq.i_get(cfg,'dummy',false);

            switch lower(string(cfg.type))

                case "nidaq"
                    obj = NiDaq(cfg.deviceName, dummy);

                case "arduinodac"
                    if ~isfield(cfg,'outputMaxVoltage')
                        error('Daq:create:MissingOutputMaxVoltage', ...
                              'For ArduinoDAC specify outputMaxVoltage.');
                    end
                    maxV = cfg.outputMaxVoltage;
                    obj  = ArduinoGP8413Dac(cfg.deviceName, maxV, dummy);

                otherwise
                    error('Daq:create:UnknownType', ...
                          'Unknown Daq type "%s".', cfg.type);
            end

            % Register into global object system (if present)
            try
                addBaseObject(obj);
            catch
                % Ignore if not used
            end
        end
    end

    methods (Static, Access = private)
        function v = i_get(s, field, default)
            if isfield(s,field) && ~isempty(s.(field))
                v = s.(field);
            else
                v = default;
            end
        end
    end
end
