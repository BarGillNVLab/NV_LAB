classdef ViewSequenceBuilder < ViewVBox
    %VIEWSEQUENCEBUILDER Build, preview and run a pulse sequence by hand
    %   Four panes, top to bottom: the pulses, the variables, the
    %   measurement points, and a preview drawn as one lane per channel.
    %
    %   Pulses are time slices - a duration and the set of channels on
    %   during it - which is exactly what Sequence runs. Durations are
    %   expressions over the variables, so one variable can drive several
    %   pulses at once.
    %
    %   A variable drives either a pulse duration or an MW setting
    %   (frequency, amplitude or phase on a channel). Any number of them can
    %   be swept; the points table then has one column per swept variable
    %   and one row per measurement, so a scan over MW frequency and a delay
    %   together is just a four-row table.
    %
    %   The preview never touches hardware.
    %
    %   See also USERSEQUENCESPEC, EXPUSERSEQUENCE, USERSEQUENCEEXPORTER

    properties (Constant)
        PULSE_COLUMNS = {'Nickname', 'Duration', 'Channels'}
        PULSE_WIDTHS = {110, 110, 240}

        VARIABLE_COLUMNS = {'Variable', 'Value', 'Drives', 'Channel', 'Swept'}
        VARIABLE_WIDTHS = {110, 80, 100, 80, 50}
        VAR_NAME = 1, VAR_VALUE = 2, VAR_BINDING = 3, VAR_CHANNEL = 4, VAR_SWEPT = 5

        LANE_HEIGHT = 26        % px per channel lane in the preview

        % Past this many points, generating the grid is worth confirming:
        % each point is its own sequence upload and measurement, per average.
        MAX_POINTS = 400
    end

    properties (Access = private)
        edtName
        tblPulses
        tblVariables
        tblPoints
        popXAxis
        popSignal
        popReference
        vAxes
        lblStatus

        spec
        selectedPulse = []
        selectedPoint = []

        drag = []           % struct while a block edge is being dragged
    end

    methods
        function obj = ViewSequenceBuilder(parent, controller, spec)
            obj@ViewVBox(parent, controller, 5, 4);

            if exist('spec', 'var') && isa(spec, 'UserSequenceSpec')
                obj.spec = spec;
            else
                obj.spec = ViewSequenceBuilder.exampleSpec();
            end

            box = obj.component;

            %%% Name and files
            hTop = uix.HBox('Parent', box, 'Spacing', 4);
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', hTop, 'String', 'Name');
            obj.edtName = uicontrol(obj.PROP_EDIT_SMALL{:}, 'Parent', hTop, ...
                'String', obj.spec.name, 'Callback', @obj.nameCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hTop, 'String', 'Load', 'Callback', @obj.loadCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hTop, 'String', 'Save', 'Callback', @obj.saveCallback);
            hTop.Widths = [40, -1, 60, 60];

            %%% Pulses
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', box, ...
                'String', 'Pulses   -   a duration and the channels on during it. Durations may use the variables below.');
            obj.tblPulses = uitable('Parent', box, ...
                'ColumnName', obj.PULSE_COLUMNS, 'ColumnEditable', [true true true], ...
                'ColumnWidth', obj.PULSE_WIDTHS, 'RowName', [], 'FontSize', 9, ...
                'CellEditCallback', @obj.pulseEditCallback, ...
                'CellSelectionCallback', @(h,e) obj.selectCallback('pulse', e));
            hPulseBtns = uix.HBox('Parent', box, 'Spacing', 4);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hPulseBtns, 'String', 'Add pulse', 'Callback', @obj.addPulseCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hPulseBtns, 'String', 'Remove', 'Callback', @obj.removePulseCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hPulseBtns, 'String', 'Move up', 'Callback', @(h,e) obj.movePulseCallback(-1));
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hPulseBtns, 'String', 'Move down', 'Callback', @(h,e) obj.movePulseCallback(+1));
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', hPulseBtns, 'String', 'Signal');
            obj.popSignal = uicontrol(obj.PROP_POPUP{:}, 'Parent', hPulseBtns, ...
                'String', {'-'}, ...
                'TooltipString', 'Which detection window is the signal', ...
                'Callback', @obj.windowCallback);
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', hPulseBtns, 'String', 'Reference');
            obj.popReference = uicontrol(obj.PROP_POPUP{:}, 'Parent', hPulseBtns, ...
                'String', {'-'}, ...
                'TooltipString', 'Which detection window is the reference', ...
                'Callback', @obj.windowCallback);
            uix.Empty('Parent', hPulseBtns);
            hPulseBtns.Widths = [80, 70, 70, 80, 45, 120, 65, 120, -1];

            %%% Variables
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', box, ...
                'String', 'Variables   -   tick every one you want to sweep. "Drives" says what it changes.');
            obj.tblVariables = uitable('Parent', box, ...
                'ColumnName', obj.VARIABLE_COLUMNS, 'ColumnEditable', [true true true true true], ...
                'ColumnFormat', {'char', 'numeric', UserSequenceSpec.BINDINGS, 'char', 'logical'}, ...
                'ColumnWidth', obj.VARIABLE_WIDTHS, 'RowName', [], 'FontSize', 9, ...
                'CellEditCallback', @obj.variableEditCallback);
            hVarBtns = uix.HBox('Parent', box, 'Spacing', 4);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hVarBtns, 'String', 'Add variable', 'Callback', @obj.addVariableCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hVarBtns, 'String', 'Remove', 'Callback', @obj.removeVariableCallback);
            uix.Empty('Parent', hVarBtns);
            hVarBtns.Widths = [90, 70, -1];

            %%% Measurement points
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', box, ...
                'String', 'Measurement points   -   one row per point, one column per swept variable.');
            obj.tblPoints = uitable('Parent', box, ...
                'ColumnName', {'(no variables swept)'}, 'ColumnEditable', true, ...
                'RowName', [], 'FontSize', 9, 'Data', cell(0, 1), ...
                'CellEditCallback', @obj.pointEditCallback, ...
                'CellSelectionCallback', @(h,e) obj.selectCallback('point', e));
            hPointBtns = uix.HBox('Parent', box, 'Spacing', 4);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hPointBtns, 'String', 'Add point', 'Callback', @obj.addPointCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hPointBtns, 'String', 'Remove', 'Callback', @obj.removePointCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hPointBtns, 'String', 'Fill grid...', ...
                'TooltipString', ['Give each swept variable its own range - lengths may ', ...
                    'differ - and generate every combination'], ...
                'Callback', @obj.fillGridCallback);
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', hPointBtns, 'String', 'x axis');
            obj.popXAxis = uicontrol(obj.PROP_POPUP{:}, 'Parent', hPointBtns, ...
                'String', {'Point number'}, 'Callback', @obj.xAxisCallback);
            uix.Empty('Parent', hPointBtns);
            hPointBtns.Widths = [80, 70, 90, 50, 170, -1];

            %%% Preview
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', box, ...
                'String', ['Preview of the first point   -   drag a block''s right edge to ', ...
                    'change its duration (numeric durations only)']);
            obj.vAxes = axes('Parent', uicontainer('Parent', box), ...
                'NextPlot', 'replacechildren', 'FontSize', 8, 'UserData', 'builderPreview');

            %%% Actions
            hActions = uix.HBox('Parent', box, 'Spacing', 4);
            uicontrol(obj.PROP_BUTTON{:}, 'Parent', hActions, 'String', 'Run this sequence', 'Callback', @obj.runCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hActions, 'String', 'Export as Exp*.m', 'Callback', @obj.exportCallback);
            hActions.Widths = [-1, 140];

            obj.lblStatus = uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', box, 'String', '');

            box.Heights = [26, 16, -3, 26, 16, 110, 26, 16, -2, 26, 16, -3, 30, 18];

            obj.refreshAll();
            obj.width = 720;
            obj.height = 820;
        end

        function s = currentSpec(obj)
            s = obj.spec;
        end

        function setSpec(obj, spec)
            if ~isa(spec, 'UserSequenceSpec'); return; end
            obj.spec = spec;
            obj.selectedPulse = [];
            obj.selectedPoint = [];
            obj.refreshAll();
        end
    end

    %% Refresh
    methods (Access = private)
        function refreshAll(obj)
            obj.edtName.String = obj.spec.name;
            obj.refreshPulses();
            obj.refreshWindows();
            obj.refreshVariables();
            obj.refreshPoints();
            obj.refreshPreview();
        end

        function refreshPulses(obj)
            n = numel(obj.spec.pulses);
            data = cell(n, 3);
            for i = 1 : n
                data{i, 1} = obj.spec.pulses(i).nickname;
                data{i, 2} = obj.spec.pulses(i).duration;
                data{i, 3} = strjoin(obj.spec.pulses(i).channels, ', ');
            end
            obj.tblPulses.Data = data;
            obj.tblPulses.TooltipString = obj.channelHint();
        end

        function refreshVariables(obj)
            n = numel(obj.spec.variables);
            data = cell(n, 5);
            for i = 1 : n
                v = obj.spec.variables(i);
                data{i, obj.VAR_NAME} = v.name;
                data{i, obj.VAR_VALUE} = v.value;
                data{i, obj.VAR_BINDING} = v.binding;
                data{i, obj.VAR_CHANNEL} = v.channel;
                data{i, obj.VAR_SWEPT} = any(strcmp(obj.spec.sweptNames, v.name));
            end
            obj.tblVariables.Data = data;
        end

        function refreshPoints(obj)
            swept = obj.spec.sweptNames;
            if isempty(swept)
                obj.tblPoints.ColumnName = {'(no variables swept)'};
                obj.tblPoints.ColumnEditable = false;
                obj.tblPoints.Data = cell(0, 1);
            else
                headers = cell(1, numel(swept));
                for i = 1 : numel(swept)
                    idx = obj.spec.variableIndex(swept{i});
                    units = UserSequenceSpec.unitsFor(obj.spec.variables(idx).binding);
                    headers{i} = sprintf('%s [%s]', swept{i}, units);
                end
                obj.tblPoints.ColumnName = headers;
                obj.tblPoints.ColumnEditable = true(1, numel(swept));
                obj.tblPoints.Data = obj.spec.combinations;
            end

            % x-axis picker follows the swept set
            labels = [{'Point number'}, swept];
            obj.popXAxis.String = labels;
            chosen = find(strcmp(swept, obj.spec.xAxisName), 1);
            if isempty(chosen)
                obj.popXAxis.Value = 1;
            else
                obj.popXAxis.Value = chosen + 1;
            end
        end

        function refreshWindows(obj)
            detectors = obj.spec.detectorPulseIndices();
            if isempty(detectors)
                labels = {'(no detection windows)'};
                obj.popSignal.String = labels;    obj.popSignal.Value = 1;
                obj.popReference.String = labels; obj.popReference.Value = 1;
                return
            end

            labels = cell(1, numel(detectors));
            for i = 1 : numel(detectors)
                labels{i} = sprintf('%d: %s', i, obj.spec.pulses(detectors(i)).nickname);
            end

            signalIdx = min(max(1, obj.spec.signalWindow), numel(labels));
            referenceIdx = min(max(1, obj.spec.referenceWindow), numel(labels));
            % Clamping can collapse both onto the same window whenever the
            % count drops to one and grows again. Push them apart, or the
            % pair stays invalid with no way for the user to see why.
            if signalIdx == referenceIdx && numel(labels) >= 2
                candidates = 1 : numel(labels);
                referenceIdx = candidates(find(candidates ~= signalIdx, 1));
            end

            obj.popSignal.String = labels;    obj.popSignal.Value = signalIdx;
            obj.popReference.String = labels; obj.popReference.Value = referenceIdx;
            obj.spec.signalWindow = signalIdx;
            obj.spec.referenceWindow = referenceIdx;
        end

        function refreshPreview(obj)
            [isOk, message] = obj.spec.validate();
            try
                S = obj.spec.buildSequence(1);
            catch err
                obj.clearAxes(err.message);
                return
            end
            if isempty(S) || S.duration == 0
                obj.clearAxes('Sequence is empty.');
                return
            end

            try
                obj.drawLanes(S);
            catch err
                obj.clearAxes(sprintf('Cannot draw: %s', err.message));
                return
            end

            if isOk
                obj.setStatus(sprintf('%s us at the first point, %d point(s), %d pulse(s). Ready.', ...
                    StringHelper.formatNumber(S.duration, 3), obj.spec.numberOfParams(), ...
                    numel(obj.spec.pulses)));
            else
                obj.setStatus(message);
            end
        end

        function drawLanes(obj, S)
            % One lane per channel, blocks drawn as filled rectangles, with
            % nicknames along the top.
            %
            % Sequence.plotSequence stacks everything on one axes and writes
            % every nickname at the middle of its pulse rotated 270 degrees,
            % which for a sequence of short pulses turns into an unreadable
            % pile. Here each nickname is placed once, horizontally, and one
            % is skipped whenever it would collide with the last one drawn.
            ax = obj.vAxes;
            cla(ax, 'reset');
            hold(ax, 'on');

            channelsStruct = S.perChannelEdgeTimes();
            names = {channelsStruct.name};
            keep = ~cellfun(@isempty, names);       % last entry marks empty pulses
            channelsStruct = channelsStruct(keep);
            names = names(keep);
            nLanes = numel(names);
            if nLanes == 0
                obj.clearAxes('No channels are used by this sequence.');
                return
            end

            total = S.duration;
            laneColour = [0.20 0.45 0.75];

            for i = 1 : nLanes
                y = nLanes - i;     % first channel at the top
                % lane background
                % Vertex order matters: x and y are walked in step, so the
                % second corner must stay on the baseline or the patch comes
                % out as a bowtie with a diagonal across the lane.
                patch(ax, [0 total total 0], [y y y+0.62 y+0.62], [0.94 0.94 0.94], ...
                    'EdgeColor', [0.85 0.85 0.85]);
                for j = 1 : channelsStruct(i).numOfPulses
                    t0 = channelsStruct(i).pulsesStartTime(j);
                    t1 = channelsStruct(i).pulsesEndTime(j);
                    if t1 <= t0; continue; end
                    % Tagged by the pulse that *ends* here, not the one that
                    % starts: contiguous pulses sharing a channel render as
                    % one bar, and it is the right-hand edge being dragged.
                    pulseIndex = obj.pulseEndingAt(t1);
                    patch(ax, [t0 t1 t1 t0], [y y y+0.62 y+0.62], laneColour, ...
                        'EdgeColor', laneColour * 0.6, ...
                        'UserData', pulseIndex, ...
                        'ButtonDownFcn', @obj.blockDownCallback);
                end
            end

            % Nicknames across the top, skipping any that would overlap
            edges = S.edgeTimes();
            pulses = S.getPulses();
            lastRight = -inf;
            minGap = total / 28;    % about 28 labels fit across the axes
            for j = 1 : numel(pulses)
                label = pulses(j).nickname;
                if isempty(label); continue; end
                centre = (edges(j) + edges(j+1)) / 2;
                if centre - lastRight < minGap; continue; end
                text(ax, centre, nLanes + 0.15, label, 'Parent', ax, ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                    'FontSize', 7, 'Color', [0.25 0.25 0.25], ...
                    'Interpreter', 'none');
                lastRight = centre;
            end

            set(ax, 'YTick', (0 : nLanes-1) + 0.31, 'YTickLabel', fliplr(names), ...
                'TickLabelInterpreter', 'none', ...
                'FontSize', 8, 'Box', 'on', 'Layer', 'top', 'TickDir', 'out');
            xlim(ax, [0 total]);
            ylim(ax, [-0.1 nLanes + 0.75]);
            xlabel(ax, 't [\mus]');
            hold(ax, 'off');
        end
    end

    %% Callbacks
    methods (Access = private)
        function index = pulseEndingAt(obj, endTime)
            % Which pulse finishes at this time, or [] if none does
            index = [];
            durations = obj.spec.resolveDurations(1);
            edges = [0 cumsum(durations)];
            tolerance = max(edges(end) * 1e-9, eps);
            hit = find(abs(edges(2:end) - endTime) <= tolerance, 1, 'last');
            if ~isempty(hit); index = hit; end
        end

        function blockDownCallback(obj, src, ~)
            % Grab the right-hand edge of a block to change its duration
            pulseIndex = src.UserData;
            if isempty(pulseIndex) || pulseIndex < 1 || pulseIndex > numel(obj.spec.pulses)
                return
            end

            pulse = obj.spec.pulses(pulseIndex);
            if isnan(str2double(pulse.duration))
                % Driven by an expression - dragging would overwrite it with a
                % number and quietly drop the pulse out of the sweep.
                obj.setStatus(sprintf(['"%s" has the duration %s, which is an expression. ', ...
                    'Edit it in the table - dragging would replace it with a number.'], ...
                    pulse.nickname, pulse.duration));
                return
            end

            durations = obj.spec.resolveDurations(1);
            edges = [0 cumsum(durations)];
            total = edges(end);
            rightEdge = edges(pulseIndex + 1);

            clickX = obj.vAxes.CurrentPoint(1, 1);
            grabWidth = max(total * 0.02, durations(pulseIndex) * 0.5);
            if abs(clickX - rightEdge) > grabWidth
                obj.setStatus(sprintf(['Grab the right-hand edge of "%s" to resize it ', ...
                    '(within %s us of it).'], pulse.nickname, StringHelper.formatNumber(grabWidth, 3)));
                return
            end

            fig = ancestor(obj.component, 'figure');
            if isempty(fig); return; end

            obj.drag = struct( ...
                'pulseIndex', pulseIndex, ...
                'startTime',  edges(pulseIndex), ...
                'figure',     fig, ...
                'oldMotion',  fig.WindowButtonMotionFcn, ...
                'oldUp',      fig.WindowButtonUpFcn, ...
                'oldPointer', fig.Pointer);

            fig.Pointer = 'left';
            fig.WindowButtonMotionFcn = @obj.dragMotionCallback;
            fig.WindowButtonUpFcn = @obj.dragUpCallback;
        end

        function dragMotionCallback(obj, ~, ~)
            if isempty(obj.drag); return; end
            index = obj.drag.pulseIndex;

            newDuration = obj.vAxes.CurrentPoint(1, 1) - obj.drag.startTime;
            minimum = PulseGenerator.MINIMAL_TIME;
            if ~isfinite(newDuration) || newDuration < minimum
                newDuration = minimum;
            end

            % Round to something a person would have typed, and skip the
            % redraw when nothing has actually changed.
            newText = StringHelper.formatNumber(newDuration, 4);
            if strcmp(newText, obj.spec.pulses(index).duration); return; end

            obj.spec.pulses(index).duration = newText;
            obj.refreshPreview();
            obj.setStatus(sprintf('%s = %s us', obj.spec.pulses(index).nickname, newText));
        end

        function dragUpCallback(obj, ~, ~)
            if isempty(obj.drag); return; end
            fig = obj.drag.figure;
            if ~isempty(fig) && isvalid(fig)
                fig.WindowButtonMotionFcn = obj.drag.oldMotion;
                fig.WindowButtonUpFcn = obj.drag.oldUp;
                fig.Pointer = obj.drag.oldPointer;
            end
            obj.drag = [];
            obj.refreshPulses();    % the table has to catch up with the drag
            obj.refreshPreview();
        end

        function nameCallback(obj, ~, ~)
            obj.spec.name = strtrim(obj.edtName.String);
            obj.refreshPreview();
        end

        function selectCallback(obj, which, event)
            row = [];
            if ~isempty(event.Indices); row = event.Indices(1); end
            switch which
                case 'pulse'; obj.selectedPulse = row;
                case 'point'; obj.selectedPoint = row;
            end
        end

        %% Pulses
        function pulseEditCallback(obj, ~, event)
            if isempty(event.Indices); return; end
            row = event.Indices(1); col = event.Indices(2);
            if row < 1 || row > numel(obj.spec.pulses); return; end
            text = obj.asText(event.NewData);
            switch col
                case 1; obj.spec.pulses(row).nickname = text;
                case 2; obj.spec.pulses(row).duration = text;
                case 3
                    parts = strtrim(strsplit(text, ','));
                    obj.spec.pulses(row).channels = parts(~cellfun(@isempty, parts));
            end
            obj.refreshWindows();
            obj.refreshPreview();
        end

        function addPulseCallback(obj, ~, ~)
            obj.spec.addPulse(sprintf('pulse%d', numel(obj.spec.pulses)+1), '1', {});
            obj.refreshPulses(); obj.refreshWindows(); obj.refreshPreview();
        end

        function removePulseCallback(obj, ~, ~)
            row = obj.rowOr(obj.selectedPulse, numel(obj.spec.pulses));
            if isempty(row); return; end
            obj.spec.removePulse(row);
            obj.selectedPulse = [];
            obj.refreshPulses(); obj.refreshWindows(); obj.refreshPreview();
        end

        function movePulseCallback(obj, offset)
            row = obj.rowOr(obj.selectedPulse, numel(obj.spec.pulses));
            if isempty(row); return; end
            obj.selectedPulse = obj.spec.movePulse(row, offset);
            obj.refreshPulses(); obj.refreshWindows(); obj.refreshPreview();
        end

        %% Variables
        function variableEditCallback(obj, ~, event)
            if isempty(event.Indices); return; end
            row = event.Indices(1); col = event.Indices(2);
            if row < 1 || row > numel(obj.spec.variables); return; end
            v = obj.spec.variables(row);

            switch col
                case obj.VAR_NAME
                    newName = obj.asText(event.NewData);
                    if ~SequenceExpression.isValidName(newName)
                        obj.setStatus(sprintf('"%s" is not a usable variable name.', newName));
                        obj.refreshVariables(); return
                    end
                    obj.spec.renameVariable(v.name, newName);
                case obj.VAR_VALUE
                    if ~isnumeric(event.NewData) || ~isscalar(event.NewData)
                        obj.setStatus('A variable value must be a single number.');
                        obj.refreshVariables(); return
                    end
                    obj.spec.variables(row).value = event.NewData;
                case obj.VAR_BINDING
                    obj.spec.variables(row).binding = obj.asText(event.NewData);
                case obj.VAR_CHANNEL
                    obj.spec.variables(row).channel = obj.asText(event.NewData);
                case obj.VAR_SWEPT
                    names = obj.spec.sweptNames;
                    if logical(event.NewData)
                        if ~any(strcmp(names, v.name)); names{end+1} = v.name; end
                    else
                        names = names(~strcmp(names, v.name));
                    end
                    obj.spec.setSwept(names);
                    if isempty(obj.spec.combinations) && ~isempty(obj.spec.sweptNames)
                        obj.spec.addCombination();  % start the table off with one row
                    end
            end

            obj.refreshVariables(); obj.refreshPoints(); obj.refreshPreview();
        end

        function addVariableCallback(obj, ~, ~)
            n = 1;
            while ~isempty(obj.spec.variableIndex(sprintf('var%d', n))); n = n + 1; end
            obj.spec.setVariable(sprintf('var%d', n), 1);
            obj.refreshVariables(); obj.refreshPreview();
        end

        function removeVariableCallback(obj, ~, ~)
            if isempty(obj.spec.variables); return; end
            obj.spec.removeVariable(obj.spec.variables(end).name);
            obj.refreshVariables(); obj.refreshPoints(); obj.refreshPreview();
        end

        %% Points
        function pointEditCallback(obj, ~, event)
            if isempty(event.Indices); return; end
            row = event.Indices(1); col = event.Indices(2);
            if row < 1 || row > size(obj.spec.combinations, 1); return; end
            if ~isnumeric(event.NewData) || ~isscalar(event.NewData) || ~isfinite(event.NewData)
                obj.setStatus('A measurement point must be a finite number.');
                obj.refreshPoints(); return
            end
            obj.spec.combinations(row, col) = event.NewData;
            obj.refreshPreview();
        end

        function addPointCallback(obj, ~, ~)
            if isempty(obj.spec.sweptNames)
                obj.setStatus('Tick a variable as swept first - points need a column.');
                return
            end
            obj.spec.addCombination();
            obj.refreshPoints(); obj.refreshPreview();
        end

        function removePointCallback(obj, ~, ~)
            row = obj.rowOr(obj.selectedPoint, size(obj.spec.combinations, 1));
            if isempty(row); return; end
            obj.spec.removeCombination(row);
            obj.selectedPoint = [];
            obj.refreshPoints(); obj.refreshPreview();
        end

        function fillGridCallback(obj, ~, ~)
            % One range per swept variable, then every combination of them.
            % Lengths are independent, so 20 taus against 3 frequencies gives
            % 60 points.
            swept = obj.spec.sweptNames;
            if isempty(swept)
                obj.setStatus('Tick a variable as swept first - points need a column.');
                return
            end

            prompts = cell(1, numel(swept));
            defaults = cell(1, numel(swept));
            for i = 1 : numel(swept)
                idx = obj.spec.variableIndex(swept{i});
                units = UserSequenceSpec.unitsFor(obj.spec.variables(idx).binding);
                prompts{i} = sprintf('%s [%s]', swept{i}, units);

                existing = obj.spec.columnValues(swept{i});
                if numel(existing) > 1
                    defaults{i} = ExpGuiParam.valueToString(existing);
                else
                    defaults{i} = ExpGuiParam.valueToString(obj.spec.variables(idx).value);
                end
            end

            answer = inputdlg(prompts, 'Fill grid - one range per variable', 1, defaults);
            if isempty(answer); return; end

            ranges = cell(1, numel(swept));
            for i = 1 : numel(swept)
                [values, isOk] = ExpGuiParam.parseVector(answer{i});
                if ~isOk || isempty(values)
                    obj.setStatus(sprintf(['Could not read the range for %s. Try ', ...
                        '"0.1 : 0.1 : 2" or "[1 2 5]".'], swept{i}));
                    return
                end
                ranges{i} = values;
            end

            counts = cellfun(@numel, ranges);
            total = prod(counts);
            if total > obj.MAX_POINTS
                shape = strjoin(arrayfun(@(n) sprintf('%d', n), counts, ...
                    'UniformOutput', false), ' x ');
                if ~QuestionUserYesNo('Rather a lot of points', sprintf( ...
                        ['%s would make %d measurement points. Every point is a ', ...
                        'separate sequence upload and measurement, repeated for ', ...
                        'each average. Go ahead?'], shape, total))
                    return
                end
            end

            try
                obj.spec.fillGrid(ranges);
            catch err
                obj.setStatus(sprintf('Could not fill the table: %s', err.message));
                return
            end

            obj.refreshPoints();
            obj.refreshPreview();
            obj.setStatus(sprintf('%s = %d point(s).', ...
                strjoin(arrayfun(@(n) sprintf('%d', n), counts, ...
                    'UniformOutput', false), ' x '), total));
        end

        function xAxisCallback(obj, ~, ~)
            value = obj.popXAxis.Value;
            if value <= 1
                obj.spec.xAxisName = '';
            else
                swept = obj.spec.sweptNames;
                obj.spec.xAxisName = swept{value - 1};
            end
        end

        %% Actions
        function runCallback(obj, ~, ~)
            [isOk, message] = obj.spec.validate();
            if ~isOk; obj.setStatus(message); return; end

            exp = getObjByName(ExpUserSequence.NAME);
            if isempty(exp) || ~isvalid(exp)
                exp = ExpUserSequence(obj.spec);
            else
                exp.setSpec(obj.spec);
            end

            obj.setStatus(sprintf('Running "%s" over %d point(s) ...', ...
                obj.spec.name, obj.spec.numberOfParams()));
            drawnow limitrate
            try
                exp.run();
                obj.setStatus(sprintf('"%s" finished.', obj.spec.name));
            catch err
                obj.setStatus(sprintf('Run failed: %s', err.message));
            end
        end

        function exportCallback(obj, ~, ~)
            [isOk, message] = obj.spec.validate();
            if ~isOk; obj.setStatus(message); return; end
            target = UserSequenceExporter.defaultPathFor(obj.spec);
            if ~QuestionUserYesNo('Export experiment', sprintf( ...
                    ['Write a new experiment class?\n\n%s\n\n', ...
                    'It will appear in the experiment list as "%s".'], target, obj.spec.name))
                return
            end
            [written, ok, why] = UserSequenceExporter.export(obj.spec, target);
            if ok; obj.setStatus(sprintf('Exported to %s', written));
            else;  obj.setStatus(why); end
        end

        function saveCallback(obj, ~, ~)
            folder = UserSequenceSpec.defaultFolder();
            fileName = [obj.spec.name, UserSequenceSpec.FILE_SUFFIX];
            try
                obj.spec.save(fullfile(folder, fileName));
                obj.setStatus(sprintf('Saved to %s', fullfile(folder, fileName)));
            catch err
                obj.setStatus(sprintf('Could not save: %s', err.message));
            end
        end

        function loadCallback(obj, ~, ~)
            [fileName, chosenFolder] = uigetfile(['*', UserSequenceSpec.FILE_SUFFIX], ...
                'Load sequence', UserSequenceSpec.defaultFolder());
            if isequal(fileName, 0); return; end
            try
                obj.setSpec(UserSequenceSpec.load(fullfile(chosenFolder, fileName)));
                obj.setStatus(sprintf('Loaded %s', fileName));
            catch err
                obj.setStatus(sprintf('Could not load: %s', err.message));
            end
        end
    end

    %% Helpers
    methods (Access = private)
        function row = rowOr(obj, selected, fallback) %#ok<INUSL>
            % Act on the highlighted row, or the last one if none is
            row = [];
            if fallback < 1; return; end
            if ~isempty(selected) && selected >= 1 && selected <= fallback
                row = selected;
            else
                row = fallback;
            end
        end

        function str = channelHint(obj) %#ok<MANU>
            str = 'Comma separated, e.g. greenLaser, detector';
            try
                pg = getObjByName(PulseGenerator.NAME);
                if ~isempty(pg) && isvalid(pg)
                    names = pg.channelNames();
                    if ~isempty(names)
                        str = sprintf('Available channels: %s', strjoin(names, ', '));
                    end
                end
            catch
                % No pulse generator loaded - the generic hint will do
            end
        end

        function str = asText(obj, value) %#ok<INUSL>
            if ischar(value)
                str = strtrim(value);
            elseif isempty(value)
                str = '';
            else
                str = strtrim(char(string(value)));
            end
        end

        function clearAxes(obj, message)
            if isvalid(obj.vAxes); cla(obj.vAxes, 'reset'); end
            obj.setStatus(message);
        end

        function setStatus(obj, message)
            if isvalid(obj.lblStatus); obj.lblStatus.String = message; end
        end
    end

    methods (Static)
        function spec = exampleSpec()
            % Something runnable to start from, rather than a blank table
            spec = UserSequenceSpec();
            spec.name = 'MySequence';
            spec.setVariable('tau', 1);
            spec.setVariable('piTime', 0.05);

            spec.addPulse('pi_half', 'piTime/2', {'MW'});
            spec.addPulse('tau1',    'tau',      {});
            spec.addPulse('pi',      'piTime',   {'MW'});
            spec.addPulse('tau2',    'tau',      {});
            spec.addPulse('readout', 'piTime/2', {'MW'});
            spec.addPulse('detect',  '0.3',      {'greenLaser', 'detector'});
            spec.addPulse('init',    '2',        {'greenLaser'});
            spec.addPulse('ref',     '0.3',      {'greenLaser', 'detector'});

            spec.setSwept({'tau'});
            spec.combinations = (0.1 : 0.1 : 2)';
            spec.xAxisName = 'tau';
            spec.signalWindow = 1;
            spec.referenceWindow = 2;
        end
    end
end
