classdef ThorlabsMC2000B < SerialControlled
    % Thorlabs MC2000B Optical Chopper driver (ASCII over virtual COM)
    % Inherits your SerialControlled (fprintf/fscanf, CR terminator).
    %
    % Example:
    %   chop = ThorlabsMC2000B('COM5');
    %   chop.open();
    %   chop.setBladeByName('MC1F10');
    %   chop.setRefMode('internal');
    %   chop.setFrequency(1000);  % Hz
    %   chop.run();
    %   pause(2);
    %   f = chop.getFrequency()
    %   chop.stop(); chop.close();

    properties
        name = 'Thorlabs MC2000B'
    end

    methods
        function obj = ThorlabsMC2000B(port)
            % Call parent (creates serial object)
            obj@SerialControlled(port);

            % Recommended defaults for MC2000B
            obj.baudRate    = 115200;
            obj.dataBits    = 8;
            obj.stopBits    = 1;
            obj.parity      = 'none';
            obj.flowControl = 'none';
            obj.terminator  = 'CR';     % commands end with <CR>
            obj.keepConnected = true;   % keep the port open
            obj.commDelay   = 0.02;     % small delay between ops

            % Clear any banner/prompt noise on first open
            try
                obj.open();
                obj.sendCommand(''); pause(0.05); %#ok<*NASGU>
                obj.readAll();
            catch
                % Port might be unopened/unavailable yet; that's fine.
            end
        end

        %------------------ High-level control ------------------%
        function out = getID(obj)
            out = strtrim(obj.query('id?'));
        end

        function run(obj)
            obj.setEnable(true);
        end

        function stop(obj)
            obj.setEnable(false);
        end

        function setEnable(obj, on)
            obj.sendKV('enable', obj.bool01(on));
        end

        function tf = getEnable(obj)
            tf = obj.readBool01('enable?');
        end

        function setFrequency(obj, Hz)
            validateattributes(Hz, {'numeric'}, {'real','finite','positive','scalar'});
            obj.sendKV('freq', Hz);
        end

        function f = getFrequency(obj)
            f = obj.readFirstNumber('freq?');
        end

        function setPhase(obj, deg)
            validateattributes(deg, {'numeric'}, {'real','finite','scalar'});
            obj.sendKV('phase', deg);
        end

        function p = getPhase(obj)
            p = obj.readFirstNumber('phase?');
        end

        function setBladeByIndex(obj, idx)
            validateattributes(idx, {'numeric'}, {'integer','nonnegative','scalar'});
            obj.sendKV('blade', idx);
        end

        function idx = getBladeIndex(obj)
            idx = obj.readFirstInteger('blade?');
        end

        function setBladeByName(obj, bladeName)
            % Common single-frequency blades. Extend if needed.
            idx = obj.bladeNameToIndex(bladeName);
            obj.setBladeByIndex(idx);
        end

        function setRefMode(obj, mode)
            % mode: 'internal' or 'external'
            mode = lower(string(mode));
            switch mode
                case "internal", n = 0;
                case "external", n = 1;
                otherwise, error('setRefMode: mode must be "internal" or "external".');
            end
            obj.sendKV('ref', n);
        end

        function mode = getRefMode(obj)
            n = obj.readFirstInteger('ref?');
            mode = ternary(n==0, "internal", "external");
        end

        function setRefOut(obj, mode)
            % Reference output selection on the back panel BNC:
            % 'target' (internal synth) or 'actual' (wheel sensor)
            mode = lower(string(mode));
            switch mode
                case "target", n = 0;
                case "actual", n = 1;
                otherwise, error('setRefOut: mode must be "target" or "actual".');
            end
            obj.sendKV('output', n);
        end

        function fin = getExternalRefFrequency(obj)
            fin = obj.readFirstNumber('input?'); % measured external ref (Hz)
        end

        function setHarmonics(obj, N, D)
            % Multiply/divide external reference: freq = fin * N / D
            arguments
                obj
                N (1,1) double {mustBeInteger,mustBePositive} = 1
                D (1,1) double {mustBeInteger,mustBePositive} = 1
            end
            obj.sendKV('nharmonic', N);
            obj.sendKV('dharmonic', D);
        end

        function setBacklight(obj, level)
            % LCD backlight intensity 1..10
            validateattributes(level, {'numeric'}, {'real','finite','>=',1,'<=',10});
            obj.sendKV('intensity', round(level));
        end

        function restoreFactory(obj)
            obj.sendCommand('restore');
        end
    end

    %------------------ Private helpers ------------------%
    methods (Access = private)
        function sendKV(obj, key, val)
            if ischar(val) || isstring(val)
                cmd = sprintf('%s=%s', key, string(val));
            else
                % Avoid scientific notation when possible
                if mod(val,1)==0
                    cmd = sprintf('%s=%d', key, round(val));
                else
                    cmd = sprintf('%s=%g', key, val);
                end
            end
            obj.sendCommand(cmd);
        end

        function n = readFirstNumber(obj, q)
            s = obj.query(q);
            m = regexp(s, '([-+]?\d+(\.\d+)?)', 'once', 'match');
            n = iffEmptyToNaN(m);
            if ischar(n); n = str2double(n); end
        end

        function n = readFirstInteger(obj, q)
            s = obj.query(q);
            m = regexp(s, '([-+]?\d+)', 'once', 'match');
            if isempty(m), n = NaN; else, n = str2double(m); end
        end

        function tf = readBool01(obj, q)
            n = obj.readFirstInteger(q);
            tf = logical(n~=0);
        end

        function idx = bladeNameToIndex(~, bladeName)
            bladeName = upper(strrep(string(bladeName),' ',''));
            % Map common single-frequency blades (adjust per your firmware table)
            switch bladeName
                case "MC1F2",   idx = 0;
                case "MC1F6",   idx = 1;
                case "MC1F10",  idx = 2;
                case "MC1F15",  idx = 3;
                case "MC1F30",  idx = 4;
                case "MC1F60",  idx = 5;
                case "MC1F100", idx = 6;
                otherwise
                    error('Unknown blade name "%s". Add it to bladeNameToIndex().', bladeName);
            end
        end

        function b = bool01(~, x), b = double(logical(x)); end
    end
end

% ---------- tiny local utilities ----------
function out = ternary(cond, a, b), if cond, out=a; else, out=b; end, end
function n = iffEmptyToNaN(m), if isempty(m), n = NaN; else, n = m; end, end
