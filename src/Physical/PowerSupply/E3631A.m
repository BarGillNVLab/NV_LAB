classdef E3631A < handle
    % Minimal driver for the HP/Agilent E3631A triple supply over RS-232,
    % used as a current source (constant-current mode).
    %
    %   ps = E3631A('COM5');          % default channel P6V (0-5 A)
    %   ps = E3631A('COM5', 'P25V');  % or P25V / N25V (0-1 A)
    %   ps.setCurrent(0.5);           % amps; compliance voltage = ps.vLimit
    %   ps.on;                        % OUTP ON (affects all 3 channels)
    %   I = ps.current;               % measured current [A]
    %   V = ps.voltage;               % measured voltage [V]
    %   ps.off;
    %   E3631A_gui(ps)                % GUI on the same connection
    %
    % In CC mode the supply raises the voltage up to vLimit to push the set
    % current through the load. For a low-resistance wire leave vLimit at
    % the channel maximum, or lower it to protect the load.

    properties
        vLimit      % compliance voltage [V]; defaults to the channel maximum
    end
    properties (SetAccess = private)
        channel     % "P6V" | "P25V" | "N25V"
        port        % serialport object
    end
    properties (Access = private)
        busy = false    % a command is in progress: the GUI timer skips its refresh
        lastWrite = []  % tic of the last set command
    end
    properties (Constant)
        QUERY_TRIES = 3 % a query with no reply is asked again, up to this many times in all
        QUIET_S = 0.5   % the supply ignores anything sent this soon after a set command (measured 0.3-0.5 s)
        MAX_I = struct('P6V', 5, 'P25V', 1, 'N25V', 1)
        MAX_V = struct('P6V', 6, 'P25V', 25, 'N25V', -25)
    end

    methods
        function obj = E3631A(portName, channel)
            if nargin < 1; portName = "COM5"; end
            if nargin < 2; channel = "P6V"; end
            obj.channel = upper(string(channel));
            assert(isfield(obj.MAX_I, obj.channel), 'Channel must be P6V, P25V or N25V');
            obj.vLimit = obj.MAX_V.(obj.channel);

            % E3631A RS-232: 9600 baud, 8N2, LF terminated, needs DTR
            obj.port = serialport(portName, 9600, "StopBits", 2, "Timeout", 1.5);   % replies take < 0.3 s; a lost one is asked again
            configureTerminator(obj.port, "LF");
            setDTR(obj.port, true);
            flush(obj.port);
            obj.write("SYST:REM");   % RS-232 commands are rejected unless in remote
            % Opening the port can glitch the line, which the supply logs as
            % +511 framing error; clear it so the next checkError doesn't report it
            obj.write("*CLS");
            idn = obj.query("*IDN?");
            assert(contains(idn, "E3631A"), 'Unexpected instrument on %s: %s', portName, idn);
        end

        function setCurrent(obj, I)
            Imax = obj.MAX_I.(obj.channel);
            assert(I >= 0 && I <= Imax, 'Current must be within 0..%g A on %s', Imax, obj.channel);
            obj.write(sprintf("APPL %s,%g,%g", obj.channel, obj.vLimit, I));
            obj.checkError;
        end

        function set.vLimit(obj, V)
            Vmax = obj.MAX_V.(obj.channel); %#ok<MCSUP>
            assert(V / Vmax >= 0 && abs(V) <= abs(Vmax), 'vLimit must be within 0..%g V', Vmax);
            obj.vLimit = V;
        end

        function I = setpoint(obj)
            % Programmed current limit [A]
            r = sscanf(strip(obj.query("APPL? " + obj.channel), '"'), '%f,%f');
            I = r(2);
        end

        function I = current(obj)
            I = str2double(obj.query("MEAS:CURR? " + obj.channel));
        end

        function V = voltage(obj)
            V = str2double(obj.query("MEAS:VOLT? " + obj.channel));
        end

        function on(obj);  obj.write("OUTP ON");  obj.checkError; end
        function off(obj); obj.write("OUTP OFF"); obj.checkError; end
        function tf = isOn(obj); tf = obj.query("OUTP?") == "1"; end

        function r = query(obj, cmd)
            obj.busy = true;
            c = onCleanup(@() obj.setIdle);
            obj.waitQuiet();
            % A query changes nothing, so a lost one (e.g. a byte garbled on
            % the line: +511 framing error) is simply asked again
            for attempt = 1:obj.QUERY_TRIES
                flush(obj.port, "input");   % a late reply to an earlier question must not be read as this answer
                writeline(obj.port, cmd);
                r = readline(obj.port);
                if ~isempty(r); r = strtrim(r); return; end
                if attempt < obj.QUERY_TRIES
                    warning('E3631A: no reply to "%s" - asking again', cmd);
                    pause(0.5);
                end
            end
            flush(obj.port, "input");
            error('E3631A: no reply to "%s" after %d tries (check cable, 9600 8N2, and RS-232 selected on the front panel)', ...
                cmd, obj.QUERY_TRIES);
        end

        function write(obj, cmd)
            % The supply discards anything sent within ~0.3-0.5 s of a set
            % command (measured; the FTDI cable has no DSR handshake), so
            % every command first waits until that time has passed.
            obj.busy = true;
            c = onCleanup(@() obj.setIdle);
            obj.waitQuiet();
            writeline(obj.port, cmd);
            obj.lastWrite = tic;
        end

        function tf = isBusy(obj); tf = obj.busy; end

        function checkError(obj)
            % Read the whole queue (up to 20 entries), so an old error is not
            % reported again by the next call
            errs = strings(0);
            for k = 1:20
                e = obj.query("SYST:ERR?");
                if startsWith(e, "+0"); break; end
                errs(end+1) = e; %#ok<AGROW>
            end
            if ~isempty(errs)
                error('E3631A error: %s', strjoin(errs, '; '));
            end
        end

        function delete(obj)
            % Output is left as is, so the current keeps flowing after the
            % script ends. Call off() first if you want it off.
            if ~isempty(obj.port) && isvalid(obj.port)
                try; writeline(obj.port, "SYST:LOC"); catch; end
            end
        end
    end

    methods (Access = private)
        function setIdle(obj); obj.busy = false; end

        function waitQuiet(obj)
            % Wait out what is left of QUIET_S since the last set command.
            % The GUI timer may fire during this pause; it sees busy and skips.
            if isempty(obj.lastWrite); return; end
            w = obj.QUIET_S - toc(obj.lastWrite);
            if w > 0; pause(w); end
        end
    end
end
