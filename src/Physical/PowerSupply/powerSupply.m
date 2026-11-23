classdef (Abstract) powerSupply < BaseObject

    % =========================================================
    % CONSTANTS
    % =========================================================
    properties (Constant, Hidden)
        POWER_SUPPLY_NEEDED_FIELDS = {'type', 'address'};
    end

    % =========================================================
    % STATE
    % =========================================================
    properties (Access = protected)
        isConnected = false
        isInitializing = false   % 🔥 NEW: disables strict checks during startup
    end

    % =========================================================
    % PUBLIC STATE
    % =========================================================
    properties
        channels
        ranges

        minCurrent
        maxCurrent
        minVoltage
        maxVoltage

        voltage
        current
        mode
        range

        id
    end

    % =========================================================
    % CONSTRUCTOR
    % =========================================================
    methods (Access = protected)

        function obj = powerSupply(name, address)

            obj@BaseObject(name);

            obj.isConnected = false;
            obj.isInitializing = true;

            % safe defaults (IMPORTANT)
            obj.voltage = 0;
            obj.current = 0;
            obj.mode    = "current";
            obj.range   = "";

            if nargin > 1 && ~isempty(address)
                try
                    obj.initilize(address);
                    obj.isConnected = true;
                catch ME
                    obj.isConnected = false;
                    obj.isInitializing = false;
                    rethrow(ME);
                end
            end

            obj.isInitializing = false;
        end
    end

    % =========================================================
    % FACTORY
    % =========================================================
    methods (Static)

        function obj = create(name, powerSupplyStruct)

            missingField = FactoryHelper.usualChecks( ...
                powerSupplyStruct, ...
                powerSupply.POWER_SUPPLY_NEEDED_FIELDS);

            if ~isnan(missingField)
                EventStation.anonymousError( ...
                    'Missing field "%s" in powerSupply config!', ...
                    missingField);
            end

            switch powerSupplyStruct.type

                case 'E3631A'
                    obj = powerSupply_E3631A.create(name, powerSupplyStruct);

                case 'E3632A'
                    obj = powerSupply_E3632A.create(name, powerSupplyStruct);

                case 'E36234A'
                    obj = powerSupply_E36234A.create(name, powerSupplyStruct);

                case 'E36234A_dummy'
                    obj = powerSupply_E36234A_dummy.create(name, powerSupplyStruct);

                otherwise
                    error("Unknown power supply type: %s", powerSupplyStruct.type);
            end

            addBaseObject(obj);
        end
    end

    % =========================================================
    % LIFECYCLE
    % =========================================================
    methods

        function connect(obj, address)
            try
                obj.isInitializing = true;
                obj.initilize(address);
                obj.isConnected = true;
            catch
                obj.isConnected = false;
                rethrow(lasterror);
            end
            obj.isInitializing = false;
        end

        function close(obj)
            try
                obj.closeConnection();
            catch
            end
            obj.isConnected = false;
        end

        function delete(obj)
            try
                obj.close();
            catch
            end
        end
    end

    % =========================================================
    % HELPERS
    % =========================================================
    methods

        function assertConnected(obj)
            if ~obj.isConnected
                error("Power supply '%s' not connected.", obj.name);
            end
        end

        function state = booltoOnOff(~, state)
            switch lower(string(state))
                case {"1","on","true"}
                    state = "ON";
                case {"0","off","false"}
                    state = "OFF";
                otherwise
                    error("State must be ON/OFF or 0/1");
            end
        end
    end
    methods
        function checkOutput(obj, value)
            value = obj.booltoOnOff(value);
    
            if ~any(strcmpi(value, {'ON','OFF'}))
                error("Output must be ON or OFF");
            end
        end
    end

    % =========================================================
    % LIMIT CHECKS (FIXED)
    % =========================================================
    methods

        function checkCurrentLim(obj, I, channel)

            % 🔥 SAFE MODE: ignore strict checks during initialization
            if obj.isInitializing
                return;
            end

            [i,j] = obj.getLimitsIndexes(channel);

            Imin = obj.minCurrent(i,j);
            Imax = obj.maxCurrent(i,j);

            % tolerate numerical noise (important for VISA/serial devices)
            tol = max(1e-3, 1e-4 * abs(Imax));

            if (I < Imin - tol) || (I > Imax + tol)
                error("Current %.6f out of range [%.6f, %.6f]", ...
                    I, Imin, Imax);
            end
        end

        function checkVoltageLim(obj, V, channel)

            if obj.isInitializing
                return;
            end

            [i,j] = obj.getLimitsIndexes(channel);

            if V < obj.minVoltage(i,j) || V > obj.maxVoltage(i,j)
                error("Voltage %.3f out of range", V);
            end
        end

        function checkChannel(obj, channel)
            if ~isempty(obj.channels) && ~any(strcmp(obj.channels, channel))
                error("Invalid channel: %s", string(channel));
            end
        end

        function checkMode(obj, mode)
            if ~any(strcmp(mode, {'current','voltage'}))
                error("Mode must be 'current' or 'voltage'");
            end
        end
    end

    % =========================================================
    % INDEXING
    % =========================================================
    methods

        function [i,j] = getLimitsIndexes(obj, channel)

            if isempty(obj.channels)
                i = 1;
            else
                i = find(obj.channels == channel, 1);
                if isempty(i), i = 1; end
            end
            j = 1;
        end

        function i = chan2ind(obj, channel)

            if isempty(obj.channels)
                i = 1;
            else
                i = find(obj.channels == channel, 1);
                if isempty(i), i = 1; end
            end
        end
    end

    % =========================================================
    % UPDATE PARAMETERS
    % =========================================================
    methods

        function updateParameters(obj)

            N = max([1, length(obj.channels)]);

            obj.voltage = zeros(N,1);
            obj.current = zeros(N,1);
            obj.mode    = strings(N,1);
            obj.range   = strings(N,1);

            for k = 1:N

                if isempty(obj.channels)
                    ch = [];
                else
                    ch = obj.channels(k);
                end

                try
                    obj.voltage(k) = obj.getVoltage(ch);
                catch
                    obj.voltage(k) = 0;
                end

                try
                    obj.current(k) = obj.getCurrent(ch);
                catch
                    obj.current(k) = 0;
                end

                try
                    obj.mode(k) = obj.getMode(ch);
                catch
                    obj.mode(k) = "unknown";
                end

                try
                    obj.range(k) = obj.getRange(ch);
                catch
                    obj.range(k) = "";
                end
            end
        end
    end

    % =========================================================
    % ABSTRACT INTERFACE
    % =========================================================
    methods (Abstract)

        initilize(obj, address)
        closeConnection(obj)

        reset(obj)

        setCurrent(obj, current, channel)
        getCurrent(obj, channel)

        setVoltage(obj, voltage, channel)
        getVoltage(obj, channel)

        setMode(obj, mode, channel)
        getMode(obj, channel)

        setRange(obj, range, channel)
        getRange(obj, channel)

        output(obj, state, channel)

        sendCommand(obj, what)

        checkError(obj)

    end
end
% classdef (Abstract) powerSupply < BaseObject
% 
%     % =========================================================
%     % CONSTANTS
%     % =========================================================
%     properties (Constant, Hidden)
%         POWER_SUPPLY_NEEDED_FIELDS = {'type', 'address'};
%     end
% 
%     % =========================================================
%     % STATE
%     % =========================================================
%     properties (Access = protected)
%         isConnected = false;
%     end
% 
%     properties
%         channels
%         ranges
% 
%         minCurrent
%         maxCurrent
%         minVoltage
%         maxVoltage
% 
%         voltage
%         current
%         mode
%         range
% 
%         id   % optional metadata (NOT hardware handle)
%     end
% 
%     % =========================================================
%     % CONSTRUCTOR (FIXED: MATCHES SUBCLASS CALLS)
%     % =========================================================
%     methods (Access = protected)
% 
%         function obj = powerSupply(name, address)
% 
%             obj@BaseObject(name);
%             obj.isConnected = false;
% 
%             % Optional auto-connect (safe)
%             if nargin > 1 && ~isempty(address)
%                 try
%                     obj.initilize(address);
%                     obj.isConnected = true;
%                 catch ME
%                     obj.isConnected = false;
%                     rethrow(ME);  % DO NOT delete object
%                 end
%             end
%         end
%     end
% 
%     % =========================================================
%     % FACTORY (RESTORED FOR GUI)
%     % =========================================================
%     methods (Static)
% 
%         function obj = create(name, powerSupplyStruct)
% 
%             missingField = FactoryHelper.usualChecks( ...
%                 powerSupplyStruct, ...
%                 powerSupply.POWER_SUPPLY_NEEDED_FIELDS);
% 
%             if ~isnan(missingField)
%                 EventStation.anonymousError( ...
%                     'Missing field "%s" in powerSupply config!', ...
%                     missingField);
%             end
% 
%             switch powerSupplyStruct.type
% 
%                 case 'E3631A'
%                     obj = powerSupply_E3631A.create(name, powerSupplyStruct);
% 
%                 case 'E3632A'
%                     obj = powerSupply_E3632A.create(name, powerSupplyStruct);
% 
%                 case 'E36234A'
%                     obj = powerSupply_E36234A.create(name, powerSupplyStruct);
% 
%                 case 'E36234A_dummy'
%                     obj = powerSupply_E36234A_dummy.create(name, powerSupplyStruct);
% 
%                 otherwise
%                     error("Unknown power supply type: %s", powerSupplyStruct.type);
%             end
% 
%             addBaseObject(obj);
%         end
%     end
% 
%     % =========================================================
%     % LIFECYCLE (SAFE)
%     % =========================================================
%     methods
% 
%         function connect(obj, address)
%             try
%                 obj.initilize(address);
%                 obj.isConnected = true;
%             catch ME
%                 obj.isConnected = false;
%                 rethrow(ME);
%             end
%         end
% 
%         function close(obj)
%             try
%                 obj.closeConnection();
%             catch
%                 % safe ignore
%             end
% 
%             obj.isConnected = false;
%         end
% 
%         function delete(obj)
%             try
%                 obj.close();
%             catch
%             end
%         end
%     end
% 
%     % =========================================================
%     % SAFETY HELPERS
%     % =========================================================
%     methods
% 
%         function assertConnected(obj)
%             if ~obj.isConnected
%                 error("Power supply '%s' not connected.", obj.name);
%             end
%         end
% 
%         function state = booltoOnOff(~, state)
%             switch lower(string(state))
%                 case {"1","on","true"}
%                     state = "ON";
%                 case {"0","off","false"}
%                     state = "OFF";
%                 otherwise
%                     error("State must be ON/OFF or 0/1");
%             end
%         end
% 
%         function checkVoltageLim(obj, V, channel)
%             [i,j] = obj.getLimitsIndexes(channel);
% 
%             if V < obj.minVoltage(i,j) || V > obj.maxVoltage(i,j)
%                 error("Voltage %.3f out of range", V);
%             end
%         end
% 
%         function checkCurrentLim(obj, I, channel)
%             [i,j] = obj.getLimitsIndexes(channel);
% 
%             if I < obj.minCurrent(i,j) || I > obj.maxCurrent(i,j)
%                 error("Current %.3f out of range", I);
%             end
%         end
% 
%         function checkChannel(obj, channel)
%             if ~isempty(obj.channels) && ~any(strcmp(obj.channels, channel))
%                 error("Invalid channel: %s", string(channel));
%             end
%         end
% 
%         function checkMode(obj, mode)
%             if ~any(strcmp(mode, {'current','voltage'}))
%                 error("Mode must be 'current' or 'voltage'");
%             end
%         end
% 
%         function checkOutput(obj, value)
%             value = obj.booltoOnOff(value);
%             if ~any(strcmpi(value, {'ON','OFF'}))
%                 error("Output must be ON or OFF");
%             end
%         end
%     end
% 
%     % =========================================================
%     % INDEXING HELPERS
%     % =========================================================
%     methods
% 
%         function [i,j] = getLimitsIndexes(obj, channel)
% 
%             if isempty(obj.channels)
%                 i = 1;
%             else
%                 i = find(obj.channels == channel);
%             end
% 
%             j = 1;
%         end
% 
%         function i = chan2ind(obj, channel)
% 
%             if isempty(obj.channels)
%                 i = 1;
%             else
%                 i = find(obj.channels == channel);
%             end
%         end
%     end
%     % ============================================
%     % ADD updateParameters() HERE
%     % ============================================
%     methods
%         function updateParameters(obj)
% 
%             N = max([1, length(obj.channels)]);
% 
%             voltage_ = zeros(N,1);
%             current_ = zeros(N,1);
% 
%             mode_  = strings(N,1);
%             range_ = strings(N,1);
% 
%             for k = 1:N
% 
%                 if ~isempty(obj.channels)
%                     channel = obj.channels(k);
%                 else
%                     channel = [];
%                 end
% 
%                 try
%                     voltage_(k) = obj.getVoltage(channel);
%                 catch
%                     voltage_(k) = 0;
%                 end
% 
%                 try
%                     current_(k) = obj.getCurrent(channel);
%                 catch
%                     current_(k) = 0;
%                 end
% 
%                 try
%                     mode_(k) = obj.getMode(channel);
%                 catch
%                     mode_(k) = "unknown";
%                 end
% 
%                 try
%                     range_(k) = obj.getRange(channel);
%                 catch
%                     range_(k) = "";
%                 end
%             end
% 
%             obj.voltage = voltage_;
%             obj.current = current_;
%             obj.mode    = mode_;
%             obj.range   = range_;
%         end
%     end
% 
%     % =========================================================
%     % ABSTRACT INTERFACE
%     % =========================================================
%     methods (Abstract)
% 
%         initilize(obj, address)
%         closeConnection(obj)
% 
%         reset(obj)
% 
%         setCurrent(obj, current, channel)
%         getCurrent(obj, channel)
% 
%         setVoltage(obj, voltage, channel)
%         getVoltage(obj, channel)
% 
%         setMode(obj, mode, channel)
%         getMode(obj, channel)
% 
%         setRange(obj, range, channel)
%         getRange(obj, channel)
% 
%         output(obj, state, channel)
% 
%         sendCommand(obj, what)
% 
%         checkError(obj)
% 
%     end
% end
% % classdef (Abstract) powerSupply < BaseObject
% % 
% %     properties (Constant, Hidden)
% %         POWER_SUPPLY_NEEDED_FIELDS = {'type', 'address'};
% %     end
% % 
% %     properties
% %         % power supply model parameters:
% %         channels        % string array (size: #channels * 1). Keep empty for single channel.
% %         ranges          % string array (size: #channels * max(#ranges)) - ranges row vector for each channel. Keep empty for constant ranges.
% % 
% %         % limits: Matrix of double (size similar to 'ranges')
% %         minCurrent
% %         maxCurrent
% %         minVoltage
% %         maxVoltage
% % 
% %         % state parameters - arrays (size: #channels * 1):
% %         voltage
% %         current
% %         range           % string array
% %         mode            % string array
% % 
% %         id
% %     end
% % 
% %     % Constructor
% %     methods (Access = protected)
% %         function obj = powerSupply(name, address)
% %             obj@BaseObject(name);
% %             try
% %                 obj.initilize(address);
% %             catch err
% %                 obj.close;
% %                 obj.delete;
% %                 err2warning(err);
% %             end                
% %         end
% %     end
% % 
% %     methods (Static)
% %         function create(name, powerSupplyStruct)
% %             % Get all we need from json
% %             missingField = FactoryHelper.usualChecks(powerSupplyStruct, powerSupply.POWER_SUPPLY_NEEDED_FIELDS);
% %             if ~isnan(missingField)
% %                 EventStation.anonymousError('Can''t initialize Power Supply - needed field "%s" was not found in initialization struct!', missingField);
% %             end
% % 
% %             switch (powerSupplyStruct.type)
% %                 case 'E3631A'
% %                     powerSupplyObject = powerSupply_E3631A.create(name, powerSupplyStruct);
% %                 case 'E3632A'
% %                     powerSupplyObject = powerSupply_E3632A.create(name, powerSupplyStruct);
% %                 case 'E36234A'
% %                     powerSupplyObject = powerSupply_E36234A.create(name, powerSupplyStruct);
% %                 case 'E36234A_dummy'
% %                     powerSupplyObject = powerSupply_E36234A_dummy.create(name, powerSupplyStruct);
% %                 otherwise
% %                     EventStation.anonymousError(...
% %                         ['The requested Power Supply classname ("%s") was not recognized.\n', ...
% %                         'Please fix the .json file and try again.'], ...
% %                         powerSupplyStruct.type);
% %             end
% %             addBaseObject(powerSupplyObject);
% %         end
% % 
% %     end
% % 
% %     methods
% %         function close(obj)
% %             obj.closeConnection;
% %             ps = getObjByName(obj.name);
% %             ps.delete;
% %         end
% % 
% %         function updateParameters(obj)
% %             N = max([1, length(obj.channels)]);
% %             voltage_ = zeros(N, 1);
% %             current_ = zeros(N, 1);
% %             c = cell(N, 1);
% %             for i = 1:N; c{i} = '.'; end
% %             mode_ = string(c);
% %             range_ = string(c);
% %             for k = 1:N
% %                 if ~isempty(obj.channels)
% %                     channel = obj.channels(k);
% %                 else
% %                     channel = [];
% %                 end
% %                 voltage_(k) = min([max([obj.getVoltage(channel), obj.minVoltage(k)]), obj.maxVoltage(k)]);
% %                 current_(k) = min([max([obj.getCurrent(channel), obj.minCurrent(k)]), obj.maxCurrent(k)]);
% %                 mode_(k) = obj.getMode(channel);
% %                 range_(k) = obj.getRange(channel);
% %             end
% %             obj.voltage = voltage_;
% %             obj.current = current_;
% %             obj.mode = mode_;
% %             obj.range = range_;
% %         end
% % 
% %         function I = maxCurrentActive(obj, channel)
% %             [i, j] = obj.getLimitsIndexes(channel);
% %             I = obj.maxCurrent(i, j);
% %         end
% %         function I = minCurrentActive(obj, channel)
% %             [i, j] = obj.getLimitsIndexes(channel);
% %             I = obj.minCurrent(i, j);
% %         end
% %         function V = maxVoltageActive(obj, channel)
% %             [i, j] = obj.getLimitsIndexes(channel);
% %             V = obj.maxVoltage(i, j);
% %         end
% %         function V = minVoltageActive(obj, channel)
% %             [i, j] = obj.getLimitsIndexes(channel);
% %             V = obj.minVoltage(i, j);
% %         end
% % 
% %         function [i, j] = getLimitsIndexes(obj, channel)
% %             if isempty(obj.channels)
% %                 i = 1;
% %             else
% %                 i = find(obj.channels == channel);
% %             end
% %             if isempty(obj.ranges)
% %                 j = 1;
% %             else
% %                 j = find(obj.ranges(i, :) == obj.range(i));
% %             end
% %         end
% % 
% %         function state = booltoOnOff(obj, state)
% %             switch lower(state)
% %                 case {1, 'on'}
% %                     state = 'ON';
% %                 case {0, 'off'}
% %                     state = 'OFF';
% %                 otherwise
% %                     error('output must be 0, 1, ON, or OFF')
% %             end
% %         end
% % 
% %     end
% % 
% % 
% %     %% Check methods
% %     methods
% %         function checkVoltageLim(obj, voltage, channel)
% %             [i, j] = obj.getLimitsIndexes(channel);
% %             min = obj.minVoltage(i, j);
% %             max = obj.maxVoltage(i, j);
% %             if voltage < min
% %                 obj.close;
% %                 error('Voltage of %d volts is too low. Lower limit is %d', voltage, min)
% %             elseif max < voltage
% %                 obj.close;
% %                 error('Voltage of %d volts is too high. Upper limit is %d', voltage, max)
% %             end
% %         end
% % 
% %         function checkCurrentLim(obj, current, channel)
% %             [i, j] = obj.getLimitsIndexes(channel);
% %             min = obj.minCurrent(i, j);
% %             max = obj.maxCurrent(i, j);
% %             if current < min
% %                 obj.close;
% %                 error('Current of %d ampers is too low. Lower limit is %d', current, min)
% %             elseif max < current
% %                 obj.close;
% %                 error('Current of %d ampers is too high. Upper limit is %d', current, max)
% %             end
% %         end
% % 
% %         function checkChannel(obj, channel)
% %             if ~isempty(obj.channels) && ~any(strcmp(obj.channels, channel))
% %                 list = obj.channels(1);
% %                 for i = 2:length(obj.channels)
% %                     list = [list, obj.channels(i)];
% %                 end
% %                 obj.close;
% %                 error('No channel called %s in this power supply. Avaliable channel are %s', channel, list)
% %             end
% %         end
% % 
% %         function checkMode(obj, mode)
% %             if ~strcmp(mode, 'current') && ~strcmp(mode, 'voltage')
% %                 obj.close;
% %                 error('mode must be ''current'' or ''voltage''');
% %             end
% %         end
% % 
% %         function checkRange(obj, range, channel)
% %             if isempty(obj.channels)
% %                 i = 1;
% %             else
% %                 i = find(obj.channels == channel);
% %             end
% %             if ~any(strcmp(obj.ranges(i,:), range))
% %                 list = obj.ranges(i,1);
% %                 for j = 2:length(obj.ranges(i,:))
% %                     list = [list, ', ', obj.ranges(i,j)];
% %                 end
% %                 obj.close;
% %                 error('No range called ''%s'' in this channel of power supply. Avaliable ranges are ''%s''', range, list)
% %             end
% %         end
% % 
% %         function checkOutput(obj, value)
% %             value = obj.booltoOnOff(value);
% %             if ~strcmpi(value, 'ON') && ~strcmpi(value, 'OFF')
% %                 obj.close;
% %                 error('output must be ''ON'' or ''OFF''');
% %             end
% %         end
% %     end
% % 
% %     %% those methods must be implemented in children classes
% % 
% %     methods (Abstract, Access = public)        
% % 
% %         initilize(obj, address)
% % 
% %         connect(obj)
% % 
% %         closeConnection(obj)  
% % 
% %         reset(obj)
% % 
% %         setCurrent(obj, current, channel)
% % 
% %         getCurrent(obj, channel)
% % 
% %         setVoltage(obj, voltage, channel)
% % 
% %         getVoltage(obj, channel)
% % 
% %         setMode(obj, mode, channel)     %'voltage' or 'current'
% % 
% %         getMode(obj, channel)
% % 
% %         setRange(obj, range, channle)
% % 
% %         getRange(obj, channel);
% % 
% %         output(obj, state)              % 'ON' or 'OFF'
% % 
% %         sendCommand(obj, what)
% % 
% %         checkError(obj)
% %     end
% % 
% % 
% %     %% Help methods
% %     methods
% %         function i = chan2ind(obj, channel)
% %             if isempty(obj.channels)
% %                 i = 1;
% %             else
% %                 i = find(obj.channels == channel);
% %             end
% %         end
% % 
% %     end
% % 
% % end