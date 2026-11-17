classdef LaserSourceLaserquantumSmd12 < LaserPartAbstract & SerialControlled
    %LASERSOURCELASERQUANTUMSMD12 Laser Quantum SMD12 / MPC laser controller, via RS232
    %   Also drives the MPC-C (e.g. Ventus lasers): same commands, but 19200
    %   baud and power replies without decimals ("0038mW"). JSON fields:
    %     port (required), baudRate (default 9600; MPC-C: 19200),
    %     maxPower in mW (default 120 - set it to your laser's rating),
    %   The laser is never switched off automatically - see onlyUserTurnsOff.
    %   Creating it only reads from the laser; it never sets power or on/off.
    
    properties
        canSetEnabled = true;
        canSetValue = true;
        % Turning this laser off needs a physical enable on the controller
        % to bring it back, so only an explicit user action may do it: the
        % "Source" checkbox in mainExp (which asks first) or obj.off() in
        % code. Closing, clear all, loading a saved state or the tracker
        % never switch it off. On exit the AOM is closed instead.
        onlyUserTurnsOff = true;
    end
       
    properties (Access = private)
        valueInternal % Keeps Laser power even when it is off
        busy = false  % a query is in flight; the GUI's periodic reading skips
    end
    
    properties (Constant, Hidden)
        %%%% Commands %%%%
        COMMAND_ON = 'ON'
        COMMAND_OFF = 'OFF'
        COMMAND_ON_QUERY = 'STATUS?'
        
        COMMAND_POWER_FORMAT_SPEC = 'POWER=%4.2f'
        COMMAND_POWER_QUERY = 'POWER?'          % measured
        COMMAND_SETPOINT_QUERY = 'SETPOWER?'    % set point
        POWER_REGEX = '(\d+(?:\.\d+)?)mW'      % "38.000mW" (SMD12) or "0038mW" (MPC-C)
        
        NEEDED_FIELDS = {'port'};
        
        POWER_VALUE_DEFAULT = 6 %mW
    end
    
    methods (Access = private)
        % constructor
        function obj = LaserSourceLaserquantumSmd12(name, port, baudRate, maxPower)
            obj@LaserPartAbstract(name);
            obj@SerialControlled(port);

            obj.minValue = 0;
            obj.maxValue = maxPower;
            obj.valueInternal = obj.POWER_VALUE_DEFAULT;
            obj.units = 'mW';
            
            obj.baudRate = baudRate;
            obj.stopBits = 1;
            obj.terminator = 'CR/LF';
            
            obj.commDelay = 0.05;
            try
                obj.open;
                pause(0.2);
                obj.readAll;    % drop anything left in the controller's buffer
                if isempty(obj.query(obj.COMMAND_ON_QUERY))
                    error('No reply from the laser on %s at %d baud. Is it switched on?', port, baudRate);
                end
                obj.valueInternal = obj.readPower(obj.COMMAND_SETPOINT_QUERY);
            catch err
                % We can't communicate with the laser, so what's the point?
                obj.delete
                rethrow(err)
            end
        end
    end
       
    methods
        function delete(~)
            % Deliberately does NOT switch the laser off (clear all, closing
            % mainExp or MATLAB): re-enabling it needs a physical button on
            % the controller. Closing the serial port leaves it running.
        end
    end
    
    %% Interact with physical laser. Be careful!
    methods (Access = protected)
        function setEnabledRealWorld(obj, newBoolValue)
            % Validating value is assumed to have been done
            if newBoolValue
                obj.query(obj.COMMAND_ON);
            else
                obj.query(obj.COMMAND_OFF);
            end
        end
        
        function setValueRealWorld(obj, newValue)
            % Validating value is assumed to have been done
            commandPower = sprintf(obj.COMMAND_POWER_FORMAT_SPEC, newValue);
            obj.query(commandPower);
            
            % Save value for when laser is turned off
            obj.valueInternal = newValue;
        end
        
        function val = getValueRealWorld(obj)
            % The set point, which is what the slider controls
            val = obj.readPower(obj.COMMAND_SETPOINT_QUERY);
            if isnan(val)   % SMD12 without SETPOWER?: measured power, which is 0 when off
                if obj.getEnabledRealWorld
                    val = obj.readPower(obj.COMMAND_POWER_QUERY);
                else
                    val = obj.valueInternal;
                end
            end
        end
        
        function val = getEnabledRealWorld(obj)
            str = obj.query(obj.COMMAND_ON_QUERY);
            if isempty(str)
                val = false;
%                 warning('Cannot Connect with %s\n', obj.name)
            elseif contains(str, 'DISABLED')
                val = false;
            elseif contains(str, 'ENABLED')
                val = true;
            else
                warning('Problem in query!!')
            end
        end
    end
    
    methods
        function string = query(obj, command, regex)
            obj.busy = true;
            c = onCleanup(@() obj.setIdle);
            if nargin < 3
                string = query@SerialControlled(obj, command);
            else
                string = query@SerialControlled(obj, command, regex);
            end
        end

        function mW = measuredPower(obj)
            % Power the laser head reports now [mW]; NaN while another query is running
            mW = NaN;
            if obj.busy; return; end
            mW = obj.readPower(obj.COMMAND_POWER_QUERY);
        end
    end

    methods (Access = private)
        function mW = readPower(obj, command)
            mW = str2double(obj.query(command, obj.POWER_REGEX));
        end

        function setIdle(obj)
            obj.busy = false;
        end
    end

    %% Factory
    methods (Static)
        function obj = create(name, jsonStruct)
            missingField = FactoryHelper.usualChecks(jsonStruct, LaserSourceLaserquantumSmd12.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'While trying to create a source part for laser "%s", could not find "%s" field. Aborting', ...
                    name, missingField);
            end
            
            baudRate = 9600;
            if isfield(jsonStruct, 'baudRate'); baudRate = jsonStruct.baudRate; end
            maxPower = 120;
            if isfield(jsonStruct, 'maxPower'); maxPower = jsonStruct.maxPower; end
            obj = LaserSourceLaserquantumSmd12(name, jsonStruct.port, baudRate, maxPower);
            if isfield(jsonStruct, 'offOnClose') && jsonStruct.offOnClose
                EventStation.anonymousWarning(['%s: "offOnClose" in the JSON is ignored - this laser is ', ...
                    'only switched off from its Source checkbox. You can delete that line.'], name);
            end
        end
    end
    
end

