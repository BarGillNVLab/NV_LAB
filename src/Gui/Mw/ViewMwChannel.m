classdef ViewMwChannel < ViewVBox & EventListener
    %VIEWMWCHANNEL Controls for one microwave channel
    %   Everything a frequency-generator channel exposes: frequency,
    %   amplitude, phase, the generator output, and the pulse-generator fast
    %   switch that gates it.
    %
    %   Values shown are the ones last sent, which SignalGenerator caches
    %   per channel. "Read" asks the instrument itself, which costs a round
    %   trip over serial and so is not done on its own.
    %
    %   Bounds are checked here. SignalGenerator's own range checks are
    %   commented out (see set.frequency and friends), so without this a
    %   typo goes straight to the hardware.
    %
    %   See also VIEWMWCONTAINER, SIGNALGENERATOR, SWITCHPGCONTROLLED

    properties (Constant)
        GATE_MODES = {'Off', 'CW', 'Pulsed'}
        GATE_OFF = 1
        GATE_CW = 2
        GATE_PULSED = 3

        DEFAULT_ON_TIME = 1     % us
        DEFAULT_DUTY = 1        % percent - two orders of magnitude below CW

        %% Indicator colours: the state of MW at the sample, at a glance
        COLOUR_OFF = [0.75 0.75 0.75]    % nothing reaching the sample
        COLOUR_ARMED = [0.95 0.75 0.20]  % generator live, switch closed
        COLOUR_CW = [0.80 0.15 0.15]     % continuous - the one that heats
        COLOUR_PULSED = [0.15 0.55 0.25] % duty-cycled

        ROW_HEIGHT = 24
        LABEL_WIDTH = 66
        UNITS_WIDTH = 34
        TOTAL_WIDTH = 300
    end

    properties (Access = private)
        edtFrequency
        edtAmplitude
        edtPhase
        cbxOutput
        popGate
        edtOnTime
        edtDuty
        lblPulse
        lblHeader
        lblState

        channel         % the FGchannel struct from SignalGenerator
        channelIndex    % its position in SignalGenerator.FGchannels

        heldChannels = {}   % PG channels held on before we took the PG over
        isStreaming = false % whether we are currently looping a sequence
    end

    methods
        function obj = ViewMwChannel(parent, controller, channel, channelIndex)
            switchName = channel.pgChannelName;

            obj@EventListener({switchName, SignalGenerator.NAME});
            obj@ViewVBox(parent, controller, 2, 2);

            obj.channel = channel;
            obj.channelIndex = channelIndex;

            box = obj.component;

            % Name and live-state indicator share the header row, so the
            % indicator costs no extra height.
            hHeader = uix.HBox('Parent', box, 'Spacing', 3);
            obj.lblHeader = uicontrol(obj.PROP_LABEL{:}, 'Parent', hHeader, ...
                'String', obj.headerText(), ...
                'TooltipString', obj.detailText());
            obj.lblState = uicontrol(...
                'Parent', hHeader, ...
                'Style', 'edit', ...
                'Enable', 'inactive', ...
                'FontSize', 9, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', ...
                'ForegroundColor', 'white', ...
                'BackgroundColor', obj.COLOUR_OFF, ...
                'String', '');
            hHeader.Widths = [70, -1];

            obj.edtFrequency = obj.addValueRow(box, 'Frequency', 'MHz', @obj.frequencyCallback, ...
                obj.limitText('frequency'));
            obj.edtAmplitude = obj.addValueRow(box, 'Amplitude', 'dBm', @obj.amplitudeCallback, ...
                obj.limitText('amplitude'));
            obj.edtPhase = obj.addValueRow(box, 'Phase', 'deg', @obj.phaseCallback, ...
                obj.limitText('phase'));

            hToggles = uix.HBox('Parent', box, 'Spacing', 4);
            obj.cbxOutput = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', hToggles, ...
                'String', 'Output', ...
                'TooltipString', 'Enable the frequency generator output for this channel', ...
                'Callback', @obj.outputCallback);
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', hToggles, 'String', 'Gate');
            obj.popGate = uicontrol(obj.PROP_POPUP{:}, 'Parent', hToggles, ...
                'String', obj.GATE_MODES, ...
                'Value', obj.GATE_OFF, ...
                'TooltipString', sprintf(['Fast switch "%s":  Off, CW (held open), or ', ...
                    'Pulsed (looped on the pulse generator)'], switchName), ...
                'Callback', @obj.gateCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hToggles, ...
                'String', 'Read', ...
                'TooltipString', 'Query the instrument for its current values', ...
                'Callback', @obj.readCallback);
            hToggles.Widths = [-1, 32, 90, 52];

            % Pulsed-mode settings. Duty cycle is the knob that matters:
            % average power, and so heating, scales with it directly.
            hPulse = uix.HBox('Parent', box, 'Spacing', 3);
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', hPulse, 'String', 'On');
            obj.edtOnTime = uicontrol(obj.PROP_EDIT{:}, 'Parent', hPulse, ...
                'String', num2str(obj.DEFAULT_ON_TIME), ...
                'TooltipString', 'MW on-time per cycle, in microseconds', ...
                'Callback', @obj.pulseCallback);
            uicontrol(obj.PROP_TEXT_UNITS{:}, 'Parent', hPulse, 'String', 'us');
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', hPulse, 'String', 'Duty');
            obj.edtDuty = uicontrol(obj.PROP_EDIT{:}, 'Parent', hPulse, ...
                'String', num2str(obj.DEFAULT_DUTY), ...
                'TooltipString', 'Percent of each cycle the MW is on. Lower means less heating.', ...
                'Callback', @obj.pulseCallback);
            uicontrol(obj.PROP_TEXT_UNITS{:}, 'Parent', hPulse, 'String', '%');
            hPulse.Widths = [22, -1, 24, 32, -1, 18];

            obj.lblPulse = uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', box, 'String', '');

            box.Heights = obj.ROW_HEIGHT * ones(1, 7);

            obj.width = obj.TOTAL_WIDTH;
            obj.height = obj.ROW_HEIGHT * 7 + 12;

            obj.refresh();
        end

        function refresh(obj)
            % Show the cached values, without touching the instrument
            if ~isvalid(obj); return; end

            sg = obj.signalGeneratorOrEmpty();
            if isempty(sg)
                obj.setEnable(false);
                obj.showState('no generator', obj.COLOUR_OFF, ...
                    'There is no signal generator on this setup.');
                return
            end
            obj.setEnable(true);

            obj.edtFrequency.String = obj.cachedText(sg, 'frequency');
            obj.edtAmplitude.String = obj.cachedText(sg, 'amplitude');
            obj.edtPhase.String     = obj.cachedText(sg, 'phase');

            obj.cbxOutput.Value = obj.cachedLogical(sg, 'output');

            sw = getObjByName(obj.channel.pgChannelName);
            if isempty(sw) || ~isvalid(sw)
                obj.popGate.Enable = 'off';
            else
                obj.popGate.Enable = 'on';
                % Only Off and CW can be read back from the switch. Pulsed is
                % our own state - the switch has no idea it is being looped -
                % so it is never overwritten from hardware here.
                if obj.popGate.Value ~= obj.GATE_PULSED
                    obj.popGate.Value = BooleanHelper.ifTrueElse( ...
                        logical(sw.isEnabled), obj.GATE_CW, obj.GATE_OFF);
                end
            end
            obj.updatePulseLabel();
            obj.refreshIndicator();
        end
    end

    %% Building rows
    methods (Access = private)
        function edt = addValueRow(obj, box, labelText, unitsText, callback, tooltip)
            row = uix.HBox('Parent', box, 'Spacing', 3);
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', row, 'String', labelText);
            edt = uicontrol(obj.PROP_EDIT{:}, 'Parent', row, ...
                'TooltipString', tooltip, 'Callback', callback);
            uicontrol(obj.PROP_TEXT_UNITS{:}, 'Parent', row, 'String', unitsText);
            row.Widths = [obj.LABEL_WIDTH, -1, obj.UNITS_WIDTH];
        end

        function refreshIndicator(obj)
            % Whether MW is reaching the sample on this channel.
            %
            % Two things have to be true: the generator output is enabled and
            % the fast switch is passing. Either one alone means no MW, which
            % is why this is worth stating in one place rather than leaving it
            % to be inferred from two separate controls.
            %
            % The decision itself is in stateFor, which needs no hardware.
            if ~isvalid(obj.lblState); return; end

            sg = obj.signalGeneratorOrEmpty();
            if isempty(sg)
                obj.showState('no generator', obj.COLOUR_OFF, ...
                    'There is no signal generator on this setup.');
                return
            end

            [text, colour, tooltip] = ViewMwChannel.stateFor( ...
                obj.cachedLogical(sg, 'output'), ...
                obj.popGate.Value, ...
                str2double(obj.edtDuty.String));
            obj.showState(text, colour, tooltip);
        end

        function showState(obj, text, colour, tooltip)
            obj.lblState.String = text;
            obj.lblState.BackgroundColor = colour;
            obj.lblState.TooltipString = tooltip;
        end

        function str = headerText(obj)
            str = obj.channel.pgChannelName;
        end

        function str = detailText(obj)
            % Everything about this channel that is worth knowing but not
            % worth a widget
            parts = {sprintf('Switch channel: %s (#%d)', ...
                obj.channel.pgChannelName, obj.channel.pgChannelNumber)};
            try
                parts{end+1} = sprintf('Device: %s (%s)', ...
                    obj.channel.device.name, obj.channel.device.TYPE);
            catch
            end
            if ~isempty(obj.channel.deviceChannel)
                parts{end+1} = sprintf('Device channel: %s', ...
                    ExpGuiParam.valueToString(obj.channel.deviceChannel));
            end
            if isfield(obj.channel, 'linkedAWG') && ~isempty(obj.channel.linkedAWG)
                parts{end+1} = sprintf('Linked AWG: %s', ...
                    strjoin(cellstr(obj.channel.linkedAWG), ', '));
            end
            if isfield(obj.channel, 'opMode') && ~isempty(obj.channel.opMode)
                parts{end+1} = sprintf('Mode: %s', ExpGuiParam.valueToString(obj.channel.opMode));
            end
            str = strjoin(parts, sprintf('\n'));
        end

        function str = limitText(obj, what)
            [minimum, maximum, units] = obj.limitsOf(what);
            if isempty(minimum) || isempty(maximum)
                str = sprintf('%s for this channel', what);
            else
                str = sprintf('%s to %s %s', ...
                    StringHelper.formatNumber(minimum, 3), ...
                    StringHelper.formatNumber(maximum, 3), units);
            end
        end

        function [minimum, maximum, units] = limitsOf(obj, what)
            minimum = [];
            maximum = [];
            try
                device = obj.channel.device;
                switch what
                    case 'frequency'
                        minimum = device.minFreq;  maximum = device.maxFreq;  units = 'MHz';
                    case 'amplitude'
                        minimum = device.minAmpl;  maximum = device.maxAmpl;  units = 'dBm';
                    case 'phase'
                        minimum = device.minPhase; maximum = device.maxPhase; units = 'deg';
                    otherwise
                        units = '';
                end
            catch
                units = '';
            end
        end
    end

    %% Callbacks
    methods (Access = private)
        function frequencyCallback(obj, ~, ~)
            obj.applyValue('frequency', obj.edtFrequency);
        end

        function amplitudeCallback(obj, ~, ~)
            obj.applyValue('amplitude', obj.edtAmplitude);
        end

        function phaseCallback(obj, ~, ~)
            obj.applyValue('phase', obj.edtPhase);
        end

        function isOk = applyValue(obj, what, edit)
            % Validate first, and only then look for the instrument: an
            % out-of-range value should be reported whatever else is going
            % on, and this order keeps the check testable on its own.
            isOk = false;

            value = str2double(edit.String);
            if isnan(value)
                EventStation.anonymousWarning('"%s" is not a number.', edit.String);
                obj.refresh();
                return
            end

            [minimum, maximum, units] = obj.limitsOf(what);
            if ~isempty(minimum) && ~isempty(maximum) && ...
                    ~ValidationHelper.isInBorders(value, minimum, maximum)
                EventStation.anonymousWarning('%s must be between %g and %g %s. Ignoring %g.', ...
                    what, minimum, maximum, units, value);
                obj.refresh();
                return
            end

            sg = obj.signalGeneratorOrEmpty();
            if isempty(sg); return; end
            isOk = true;

            try
                % The [value, channel] form addresses this channel alone
                sg.(what) = [value, obj.channel.pgChannelNumber];
            catch err
                EventStation.anonymousWarning('Could not set %s: %s', what, err.message);
            end
            obj.refresh();
        end

        function outputCallback(obj, ~, ~)
            sg = obj.signalGeneratorOrEmpty();
            if isempty(sg); return; end
            try
                sg.output = [double(obj.cbxOutput.Value), obj.channel.pgChannelNumber];
            catch err
                EventStation.anonymousWarning('Could not switch the output: %s', err.message);
            end
            obj.refresh();
        end

        function gateCallback(obj, ~, ~)
            sw = getObjByName(obj.channel.pgChannelName);
            if isempty(sw) || ~isvalid(sw)
                EventStation.anonymousWarning('No fast switch called "%s".', obj.channel.pgChannelName);
                return
            end

            mode = obj.popGate.Value;

            % Leaving Pulsed means giving the pulse generator back
            if obj.wasPulsing && mode ~= obj.GATE_PULSED
                obj.stopPulsed();
            end

            try
                switch mode
                    case obj.GATE_OFF
                        sw.isEnabled = false;
                    case obj.GATE_CW
                        sw.isEnabled = true;
                    case obj.GATE_PULSED
                        obj.startPulsed();
                end
            catch err
                EventStation.anonymousWarning('Could not switch the gate: %s', err.message);
            end
            obj.refresh();
        end

        function pulseCallback(obj, ~, ~)
            % Re-apply the timings if we are already pulsing; otherwise just
            % show what they would mean.
            if obj.wasPulsing
                obj.startPulsed();
            end
            obj.updatePulseLabel();
            obj.refreshIndicator();
        end

        function tf = wasPulsing(obj)
            % True when we have taken the pulse generator over. heldChannels
            % and isStreaming are set and cleared together, so one suffices.
            tf = obj.isStreaming;
        end

        function [onTime, offTime, period, isOk] = pulseTimings(obj)
            % On-time and duty cycle in, the three derived numbers out
            onTime = str2double(obj.edtOnTime.String);
            duty = str2double(obj.edtDuty.String);
            offTime = NaN;
            period = NaN;
            isOk = false;

            if isnan(onTime) || onTime <= 0
                EventStation.anonymousWarning('MW on-time must be a positive number of microseconds.');
                return
            end
            if isnan(duty) || duty <= 0 || duty >= 100
                EventStation.anonymousWarning('Duty cycle must be between 0 and 100 percent (100 would be CW).');
                return
            end

            period = onTime * 100 / duty;
            offTime = period - onTime;

            minimum = PulseGenerator.MINIMAL_TIME;
            if onTime < minimum || offTime < minimum
                EventStation.anonymousWarning(['With on = %g us at %g percent, the off-time is ', ...
                    '%g us, and the pulse generator cannot resolve anything below %g us. ', ...
                    'Raise the on-time or lower the duty cycle.'], onTime, duty, offTime, minimum);
                return
            end
            isOk = true;
        end

        function startPulsed(obj)
            % Loop the MW channel on the pulse generator, so the average
            % power - and the heating with it - falls with the duty cycle.
            [onTime, offTime, period, isOk] = obj.pulseTimings();
            if ~isOk
                obj.popGate.Value = obj.GATE_OFF;
                return
            end

            % The pulse generator is shared with the experiments
            runningExp = Experiment.current();
            if ~isempty(runningExp)
                exp = getObjByName(runningExp);
                if ~isempty(exp) && isvalid(exp) && exp.isRunning
                    EventStation.anonymousWarning(['"%s" is running and owns the pulse ', ...
                        'generator. Pause it before pulsing the MW from here.'], runningExp);
                    obj.popGate.Value = obj.GATE_OFF;
                    return
                end
            end

            pg = getObjByName(PulseGenerator.NAME);
            if isempty(pg) || ~isvalid(pg)
                EventStation.anonymousWarning('No pulse generator, so the MW cannot be pulsed.');
                obj.popGate.Value = obj.GATE_OFF;
                return
            end

            % Uploading a sequence replaces every held channel state, so
            % whatever is currently on - the green laser above all - has to be
            % carried through both halves of the cycle, or the counts go to
            % zero the moment we start.
            held = obj.currentlyOnChannels(pg);
            mwChannel = obj.channel.pgChannelName;
            withMw = [held, {mwChannel}];
            withoutMw = held;
            if isempty(withoutMw)
                withoutMw = '';
            end

            S = Sequence;
            S.addEvent(onTime, withMw, 'mwOn');
            S.addEvent(offTime, withoutMw, 'mwOff');

            try
                pg.streamContinuously(S);
            catch err
                EventStation.anonymousWarning('Could not pulse the MW: %s', err.message);
                obj.popGate.Value = obj.GATE_OFF;
                return
            end

            obj.heldChannels = held;
            obj.isStreaming = true;
            obj.updatePulseLabel(onTime, offTime, period);
        end

        function stopPulsed(obj)
            % Hand the pulse generator back, restoring the channels that were
            % held on before we took it over.
            pg = getObjByName(PulseGenerator.NAME);
            if ~isempty(pg) && isvalid(pg)
                try
                    if isempty(obj.heldChannels)
                        pg.off([]);
                    else
                        % Re-asserting a constant output is what ends the stream
                        pg.on(obj.heldChannels);
                    end
                catch err
                    EventStation.anonymousWarning('Could not restore the pulse generator: %s', err.message);
                end
            end
            obj.heldChannels = {};
            obj.isStreaming = false;
        end

        function names = currentlyOnChannels(obj, pg)
            % Channels the pulse generator is holding on, excluding ours
            names = {};
            try
                allNames = pg.channelNames();
            catch
                return
            end
            for i = 1 : numel(allNames)
                if strcmp(allNames{i}, obj.channel.pgChannelName)
                    continue
                end
                try
                    if pg.isOn(allNames{i})
                        names{end+1} = allNames{i}; %#ok<AGROW>
                    end
                catch
                    % A channel we cannot query is one we leave alone
                end
            end
        end

        function updatePulseLabel(obj, onTime, offTime, period)
            if ~isvalid(obj.lblPulse)
                return
            end
            if obj.popGate.Value ~= obj.GATE_PULSED
                obj.lblPulse.String = '';
                return
            end
            if nargin < 4
                [onTime, offTime, period, isOk] = obj.pulseTimings();
                if ~isOk
                    obj.lblPulse.String = 'Pulse timings are not usable.';
                    return
                end
            end
            obj.lblPulse.String = sprintf( ...
                'on %g / off %g us, period %g us - %.3g x less average power than CW', ...
                onTime, offTime, period, period / onTime);
        end

        function readCallback(obj, ~, ~)
            % Ask the instrument, rather than trusting the cache
            sg = obj.signalGeneratorOrEmpty();
            if isempty(sg); return; end

            channelNumber = obj.channel.pgChannelNumber;

            % The output state too, so the indicator reflects the instrument
            % rather than whatever was last sent to it.
            try
                value = sg.queryValue('enableOutput', channelNumber);
                if ~isempty(value) && isfinite(value(1))
                    obj.cbxOutput.Value = logical(value(1));
                end
            catch err
                EventStation.anonymousWarning('Could not read the output state of %s: %s', ...
                    obj.channel.pgChannelName, err.message);
            end

            pairs = {'frequency', obj.edtFrequency; 'amplitude', obj.edtAmplitude; 'phase', obj.edtPhase};
            for i = 1 : size(pairs, 1)
                try
                    value = sg.queryValue(pairs{i, 1}, channelNumber);
                    if ~isempty(value)
                        pairs{i, 2}.String = StringHelper.formatNumber(value(1), 4);
                    end
                catch err
                    EventStation.anonymousWarning('Could not read %s from %s: %s', ...
                        pairs{i, 1}, obj.channel.pgChannelName, err.message);
                end
            end
            obj.refreshIndicator();
        end
    end

    %% Reading cached state
    methods (Access = private)
        function sg = signalGeneratorOrEmpty(obj) %#ok<MANU>
            sg = getObjByName(SignalGenerator.NAME);
            if ~isempty(sg) && (~isvalid(sg) || ~isa(sg, 'SignalGenerator'))
                sg = [];
            end
        end

        function str = cachedText(obj, sg, what)
            str = '';
            try
                values = sg.(what);
                if numel(values) >= obj.channelIndex
                    str = StringHelper.formatNumber(values(obj.channelIndex), 4);
                end
            catch
            end
        end

        function tf = cachedLogical(obj, sg, what)
            tf = false;
            try
                values = sg.(what);
                if numel(values) >= obj.channelIndex
                    tf = logical(values(obj.channelIndex));
                end
            catch
            end
        end

        function setEnable(obj, tf)
            onOff = BooleanHelper.boolToOnOff(tf);
            obj.edtFrequency.Enable = onOff;
            obj.edtAmplitude.Enable = onOff;
            obj.edtPhase.Enable = onOff;
            obj.cbxOutput.Enable = onOff;
            obj.popGate.Enable = onOff;
            obj.edtOnTime.Enable = onOff;
            obj.edtDuty.Enable = onOff;
        end
    end

    %% overridden from EventListener
    methods
        function onEvent(obj, event)
            % The fast switch announces its own changes, and so does anyone
            % driving the signal generator. Either way, re-read the cache.
            if ~isvalid(obj); return; end
            if isfield(event.extraInfo, 'isEnabled') || isstruct(event.extraInfo)
                obj.refresh();
            end
        end
    end
    methods (Static)
        function [text, colour, tooltip] = stateFor(outputOn, gateMode, duty)
            % What the indicator should say, given the generator output, the
            % gate mode, and the duty cycle. No hardware, no handles - so
            % every state can be checked on its own.
            if ~outputOn
                text = 'OFF';
                colour = ViewMwChannel.COLOUR_OFF;
                tooltip = ['The generator output is disabled, so no MW reaches ', ...
                    'the sample whatever the gate is doing.'];
                return
            end

            switch gateMode
                case ViewMwChannel.GATE_OFF
                    text = 'ARMED';
                    colour = ViewMwChannel.COLOUR_ARMED;
                    tooltip = ['The generator is putting out MW, but the fast switch ', ...
                        'is closed, so nothing reaches the sample. Set the gate to ', ...
                        'CW or Pulsed to let it through.'];

                case ViewMwChannel.GATE_CW
                    text = 'ON - CW';
                    colour = ViewMwChannel.COLOUR_CW;
                    tooltip = ['MW is reaching the sample continuously. This is the ', ...
                        'mode that heats the sample - watch the counts, and prefer ', ...
                        'Pulsed for anything long.'];

                case ViewMwChannel.GATE_PULSED
                    colour = ViewMwChannel.COLOUR_PULSED;
                    if isnan(duty) || duty <= 0 || duty >= 100
                        text = 'ON - pulsed';
                        tooltip = 'MW is pulsed, but the duty cycle is not usable yet.';
                    else
                        text = sprintf('ON - pulsed %g%%', duty);
                        tooltip = sprintf(['MW is reaching the sample at a %g percent ', ...
                            'duty cycle, so about %.3g times less average power ', ...
                            'than CW.'], duty, 100 / duty);
                    end

                otherwise
                    text = '';
                    colour = ViewMwChannel.COLOUR_OFF;
                    tooltip = '';
            end
        end
    end

end
