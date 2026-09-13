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
        cbxGate
        lblHeader

        channel         % the FGchannel struct from SignalGenerator
        channelIndex    % its position in SignalGenerator.FGchannels
    end

    methods
        function obj = ViewMwChannel(parent, controller, channel, channelIndex)
            switchName = channel.pgChannelName;

            obj@EventListener({switchName, SignalGenerator.NAME});
            obj@ViewVBox(parent, controller, 2, 2);

            obj.channel = channel;
            obj.channelIndex = channelIndex;

            box = obj.component;

            obj.lblHeader = uicontrol(obj.PROP_LABEL{:}, 'Parent', box, ...
                'String', obj.headerText(), ...
                'TooltipString', obj.detailText());

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
            obj.cbxGate = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', hToggles, ...
                'String', 'Gate', ...
                'TooltipString', sprintf('Pulse-generator fast switch "%s"', switchName), ...
                'Callback', @obj.gateCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hToggles, ...
                'String', 'Read', ...
                'TooltipString', 'Query the instrument for its current values', ...
                'Callback', @obj.readCallback);
            hToggles.Widths = [-1, -1, 52];

            box.Heights = obj.ROW_HEIGHT * ones(1, 5);

            obj.width = obj.TOTAL_WIDTH;
            obj.height = obj.ROW_HEIGHT * 5 + 12;

            obj.refresh();
        end

        function refresh(obj)
            % Show the cached values, without touching the instrument
            if ~isvalid(obj); return; end

            sg = obj.signalGeneratorOrEmpty();
            if isempty(sg)
                obj.setEnable(false);
                return
            end
            obj.setEnable(true);

            obj.edtFrequency.String = obj.cachedText(sg, 'frequency');
            obj.edtAmplitude.String = obj.cachedText(sg, 'amplitude');
            obj.edtPhase.String     = obj.cachedText(sg, 'phase');

            obj.cbxOutput.Value = obj.cachedLogical(sg, 'output');

            sw = getObjByName(obj.channel.pgChannelName);
            if isempty(sw) || ~isvalid(sw)
                obj.cbxGate.Enable = 'off';
            else
                obj.cbxGate.Enable = 'on';
                obj.cbxGate.Value = logical(sw.isEnabled);
            end
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
            try
                sw.isEnabled = logical(obj.cbxGate.Value);
            catch err
                EventStation.anonymousWarning('Could not switch the gate: %s', err.message);
            end
            obj.refresh();
        end

        function readCallback(obj, ~, ~)
            % Ask the instrument, rather than trusting the cache
            sg = obj.signalGeneratorOrEmpty();
            if isempty(sg); return; end

            channelNumber = obj.channel.pgChannelNumber;
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
            obj.cbxGate.Enable = onOff;
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
end
