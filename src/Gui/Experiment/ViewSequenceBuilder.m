classdef ViewSequenceBuilder < ViewVBox
    %VIEWSEQUENCEBUILDER Build and run a pulse sequence by hand
    %   Pulses are rows in a table: a nickname, a duration, and the channels
    %   that are on. Durations are expressions over named variables, so one
    %   variable can drive several pulses at once - write 'tau' in two gaps
    %   and both follow the sweep.
    %
    %   Exactly one variable is marked as swept; its values are the x axis.
    %   Two detection windows are nominated as signal and reference.
    %
    %   The preview redraws on every edit and never touches hardware.
    %
    %   See also USERSEQUENCESPEC, EXPUSERSEQUENCE, USERSEQUENCEEXPORTER

    properties (Constant)
        PULSE_COLUMNS = {'Nickname', 'Duration', 'Channels'}
        PULSE_WIDTHS = {90, 90, 170}

        VARIABLE_COLUMNS = {'Variable', 'Value', 'Swept'}
        VARIABLE_WIDTHS = {110, 90, 50}
        COL_SWEPT = 3
    end

    properties (Access = private)
        edtName
        tblPulses
        tblVariables
        edtSweepValues
        popSignal
        popReference
        vAxes
        lblStatus

        spec                % UserSequenceSpec being edited
        selectedRow = []    % row highlighted in the pulse table
    end

    methods
        function obj = ViewSequenceBuilder(parent, controller)
            padding = 5;
            spacing = 3;
            obj@ViewVBox(parent, controller, padding, spacing);

            obj.spec = ViewSequenceBuilder.exampleSpec();

            box = obj.component;

            %%% Name, load, save
            hName = uix.HBox('Parent', box, 'Spacing', 4);
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', hName, 'String', 'Name');
            obj.edtName = uicontrol(obj.PROP_EDIT_SMALL{:}, 'Parent', hName, ...
                'String', obj.spec.name, 'Callback', @obj.nameCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hName, 'String', 'Load', ...
                'Callback', @obj.loadCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hName, 'String', 'Save', ...
                'Callback', @obj.saveCallback);
            hName.Widths = [35, -1, 50, 50];

            %%% Pulses
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', box, ...
                'String', 'Pulses   (duration may use the variables below)');
            obj.tblPulses = uitable('Parent', box, ...
                'ColumnName', obj.PULSE_COLUMNS, ...
                'ColumnEditable', [true true true], ...
                'ColumnWidth', obj.PULSE_WIDTHS, ...
                'RowName', [], 'FontSize', 8, ...
                'CellEditCallback', @obj.pulseEditCallback, ...
                'CellSelectionCallback', @obj.pulseSelectCallback);

            hPulseButtons = uix.HBox('Parent', box, 'Spacing', 4);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hPulseButtons, 'String', 'Add', ...
                'Callback', @obj.addPulseCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hPulseButtons, 'String', 'Remove', ...
                'Callback', @obj.removePulseCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hPulseButtons, 'String', 'Up', ...
                'Callback', @(h,e) obj.movePulseCallback(-1));
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hPulseButtons, 'String', 'Down', ...
                'Callback', @(h,e) obj.movePulseCallback(+1));

            %%% Variables
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', box, ...
                'String', 'Variables   (tick one to sweep it)');
            obj.tblVariables = uitable('Parent', box, ...
                'ColumnName', obj.VARIABLE_COLUMNS, ...
                'ColumnEditable', [true true true], ...
                'ColumnFormat', {'char', 'numeric', 'logical'}, ...
                'ColumnWidth', obj.VARIABLE_WIDTHS, ...
                'RowName', [], 'FontSize', 8, ...
                'CellEditCallback', @obj.variableEditCallback);

            hVarButtons = uix.HBox('Parent', box, 'Spacing', 4);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hVarButtons, 'String', 'Add variable', ...
                'Callback', @obj.addVariableCallback);
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', hVarButtons, 'String', 'Sweep values');
            obj.edtSweepValues = uicontrol(obj.PROP_EDIT_SMALL{:}, 'Parent', hVarButtons, ...
                'TooltipString', 'e.g. 0.1 : 0.1 : 5   or   [1 2 5 10]', ...
                'Callback', @obj.sweepValuesCallback);
            hVarButtons.Widths = [80, 70, -1];

            %%% Detection windows
            hWindows = uix.HBox('Parent', box, 'Spacing', 4);
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', hWindows, 'String', 'Signal');
            obj.popSignal = uicontrol(obj.PROP_POPUP{:}, 'Parent', hWindows, ...
                'String', {'-'}, 'Callback', @obj.windowCallback);
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', hWindows, 'String', 'Reference');
            obj.popReference = uicontrol(obj.PROP_POPUP{:}, 'Parent', hWindows, ...
                'String', {'-'}, 'Callback', @obj.windowCallback);
            hWindows.Widths = [45, -1, 60, -1];

            %%% Preview
            obj.vAxes = axes('Parent', uicontainer('Parent', box), ...
                'NextPlot', 'replacechildren', 'FontSize', 7, ...
                'UserData', 'builderPreview');

            %%% Actions
            hActions = uix.HBox('Parent', box, 'Spacing', 4);
            uicontrol(obj.PROP_BUTTON{:}, 'Parent', hActions, 'String', 'Run this sequence', ...
                'Callback', @obj.runCallback);
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hActions, 'String', 'Export as Exp*.m', ...
                'Callback', @obj.exportCallback);
            hActions.Widths = [-1, 120];

            obj.lblStatus = uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', box, 'String', '');

            box.Heights = [26, 16, -1, 24, 16, 90, 24, 24, 130, 28, 16];

            obj.refreshAll();

            obj.width = 400;
            obj.height = 620;
        end

        function s = currentSpec(obj)
            s = obj.spec;
        end

        function setSpec(obj, spec)
            % Replace what is being edited, e.g. when restoring a session
            if ~isa(spec, 'UserSequenceSpec'); return; end
            obj.spec = spec;
            obj.selectedRow = [];
            obj.refreshAll();
        end
    end

    %% Refreshing the widgets from the spec
    methods (Access = private)
        function refreshAll(obj)
            obj.edtName.String = obj.spec.name;
            obj.refreshPulses();
            obj.refreshVariables();
            obj.refreshWindows();
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
            data = cell(n, 3);
            for i = 1 : n
                data{i, 1} = obj.spec.variables(i).name;
                data{i, 2} = obj.spec.variables(i).value;
                data{i, 3} = strcmp(obj.spec.variables(i).name, obj.spec.sweepName);
            end
            obj.tblVariables.Data = data;
            obj.edtSweepValues.String = ExpGuiParam.valueToString(obj.spec.sweepValues);
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

            % Clamping can collapse both onto the same window - it does
            % whenever the count drops to one and then grows again. Push
            % them apart, otherwise the pair stays invalid with no way for
            % the user to see why.
            if signalIdx == referenceIdx && numel(labels) >= 2
                candidates = 1 : numel(labels);
                referenceIdx = candidates(find(candidates ~= signalIdx, 1));
            end

            obj.popSignal.String = labels;
            obj.popSignal.Value = signalIdx;
            obj.popReference.String = labels;
            obj.popReference.Value = referenceIdx;
            % Keep the spec in step, in case a window disappeared
            obj.spec.signalWindow = signalIdx;
            obj.spec.referenceWindow = referenceIdx;
        end

        function refreshPreview(obj)
            % Redraw the sequence. Never touches hardware, so this is safe
            % to call on every keystroke-commit.
            [isOk, message] = obj.spec.validate();

            try
                S = obj.spec.buildSequence(obj.spec.sweepValueAt(1));
            catch err
                obj.clearAxes(err.message);
                return
            end

            if isempty(S) || S.duration == 0
                obj.clearAxes('Sequence is empty.');
                return
            end

            try
                cla(obj.vAxes);
                S.plotSequence(obj.vAxes);
            catch err
                obj.clearAxes(sprintf('Cannot plot: %s', err.message));
                return
            end

            if isOk
                obj.setStatus(sprintf('%s us at the first sweep point, %d points. Ready.', ...
                    StringHelper.formatNumber(S.duration, 3), obj.spec.numberOfParams()));
            else
                obj.setStatus(message);
            end
        end
    end

    %% Callbacks
    methods (Access = private)
        function nameCallback(obj, ~, ~)
            obj.spec.name = strtrim(obj.edtName.String);
            obj.refreshPreview();
        end

        function pulseEditCallback(obj, ~, event)
            if isempty(event.Indices); return; end
            row = event.Indices(1);
            col = event.Indices(2);
            if row < 1 || row > numel(obj.spec.pulses); return; end

            text = obj.asText(event.NewData);
            switch col
                case 1
                    obj.spec.pulses(row).nickname = text;
                case 2
                    obj.spec.pulses(row).duration = text;
                case 3
                    parts = strtrim(strsplit(text, ','));
                    obj.spec.pulses(row).channels = parts(~cellfun(@isempty, parts));
            end

            obj.refreshWindows();   % channels may have added or removed a window
            obj.refreshPreview();
        end

        function pulseSelectCallback(obj, ~, event)
            % Remember which row is highlighted, so Remove/Up/Down act on it
            if isempty(event.Indices)
                obj.selectedRow = [];
            else
                obj.selectedRow = event.Indices(1);
            end
        end

        function addPulseCallback(obj, ~, ~)
            obj.spec.addPulse(sprintf('pulse%d', numel(obj.spec.pulses)+1), '1', {});
            obj.refreshPulses();
            obj.refreshWindows();
            obj.refreshPreview();
        end

        function removePulseCallback(obj, ~, ~)
            row = obj.selectedPulseRow();
            if isempty(row); return; end
            obj.spec.removePulse(row);
            obj.refreshPulses();
            obj.refreshWindows();
            obj.refreshPreview();
        end

        function movePulseCallback(obj, offset)
            row = obj.selectedPulseRow();
            if isempty(row); return; end
            obj.spec.movePulse(row, offset);
            obj.refreshPulses();
            obj.refreshWindows();
            obj.refreshPreview();
        end

        function variableEditCallback(obj, ~, event)
            if isempty(event.Indices); return; end
            row = event.Indices(1);
            col = event.Indices(2);
            if row < 1 || row > numel(obj.spec.variables); return; end

            switch col
                case 1
                    newName = obj.asText(event.NewData);
                    if ~SequenceExpression.isValidName(newName)
                        obj.setStatus(sprintf('"%s" is not a usable variable name.', newName));
                        obj.refreshVariables();
                        return
                    end
                    oldName = obj.spec.variables(row).name;
                    obj.spec.variables(row).name = newName;
                    if strcmp(obj.spec.sweepName, oldName)
                        obj.spec.sweepName = newName;
                    end
                case 2
                    value = event.NewData;
                    if ~isnumeric(value) || ~isscalar(value)
                        obj.setStatus('A variable value must be a single number.');
                        obj.refreshVariables();
                        return
                    end
                    obj.spec.variables(row).value = value;
                case obj.COL_SWEPT
                    if logical(event.NewData)
                        % Only one variable can be swept
                        obj.spec.sweepName = obj.spec.variables(row).name;
                    else
                        obj.spec.sweepName = '';
                    end
                    obj.refreshVariables();
            end

            obj.refreshPreview();
        end

        function addVariableCallback(obj, ~, ~)
            base = 'var';
            n = 1;
            while any(strcmp({obj.spec.variables.name}, sprintf('%s%d', base, n)))
                n = n + 1;
            end
            obj.spec.setVariable(sprintf('%s%d', base, n), 1);
            obj.refreshVariables();
            obj.refreshPreview();
        end

        function sweepValuesCallback(obj, ~, ~)
            [values, isOk] = ExpGuiParam.parseVector(obj.edtSweepValues.String);
            if ~isOk
                obj.setStatus('Sweep values must look like "0.1 : 0.1 : 5" or "[1 2 5]".');
                return
            end
            obj.spec.sweepValues = values;
            obj.refreshPreview();
        end

        function windowCallback(obj, ~, ~)
            obj.spec.signalWindow = obj.popSignal.Value;
            obj.spec.referenceWindow = obj.popReference.Value;
            obj.refreshPreview();
        end

        function runCallback(obj, ~, ~)
            [isOk, message] = obj.spec.validate();
            if ~isOk
                obj.setStatus(message);
                return
            end

            exp = getObjByName(ExpUserSequence.NAME);
            if isempty(exp) || ~isvalid(exp)
                exp = ExpUserSequence(obj.spec);
            else
                exp.setSpec(obj.spec);
            end

            obj.setStatus(sprintf('Running "%s" as %s ...', obj.spec.name, ExpUserSequence.NAME));
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
            if ~isOk
                obj.setStatus(message);
                return
            end

            target = UserSequenceExporter.defaultPathFor(obj.spec);
            if ~QuestionUserYesNo('Export experiment', sprintf( ...
                    ['Write a new experiment class?\n\n%s\n\n', ...
                    'It will appear in the experiment list as "%s".'], ...
                    target, obj.spec.name))
                return
            end

            [written, ok, why] = UserSequenceExporter.export(obj.spec, target);
            if ok
                obj.setStatus(sprintf('Exported to %s', written));
            else
                obj.setStatus(why);
            end
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
            folder = UserSequenceSpec.defaultFolder();
            [fileName, chosenFolder] = uigetfile( ...
                ['*', UserSequenceSpec.FILE_SUFFIX], 'Load sequence', folder);
            if isequal(fileName, 0); return; end
            try
                obj.spec = UserSequenceSpec.load(fullfile(chosenFolder, fileName));
                obj.refreshAll();
                obj.setStatus(sprintf('Loaded %s', fileName));
            catch err
                obj.setStatus(sprintf('Could not load: %s', err.message));
            end
        end
    end

    %% Small helpers
    methods (Access = private)
        function row = selectedPulseRow(obj)
            % Which pulse the row buttons act on: whatever is highlighted,
            % or the last one if nothing is.
            row = [];
            n = numel(obj.spec.pulses);
            if n == 0; return; end
            if ~isempty(obj.selectedRow) && obj.selectedRow >= 1 && obj.selectedRow <= n
                row = obj.selectedRow;
            else
                row = n;    % nothing highlighted - act on the last pulse
            end
        end

        function str = channelHint(obj) %#ok<MANU>
            % List the channels the pulse generator actually knows about,
            % when there is one to ask.
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
            if isvalid(obj.vAxes); cla(obj.vAxes); end
            obj.setStatus(message);
        end

        function setStatus(obj, message)
            if isvalid(obj.lblStatus)
                obj.lblStatus.String = message;
            end
        end
    end

    methods (Static, Access = private)
        function spec = exampleSpec()
            % Something runnable to start from, rather than a blank table
            spec = UserSequenceSpec();
            spec.name = 'MySequence';
            spec.setVariable('tau', 1);
            spec.setVariable('piTime', 0.05);
            spec.sweepName = 'tau';
            spec.sweepValues = 0.1 : 0.1 : 2;

            spec.addPulse('pi_half', 'piTime/2', {'MW'});
            spec.addPulse('tau1',    'tau',      {});
            spec.addPulse('pi',      'piTime',   {'MW'});
            spec.addPulse('tau2',    'tau',      {});
            spec.addPulse('readout', 'piTime/2', {'MW'});
            spec.addPulse('detect',  '0.3',      {'greenLaser', 'detector'});
            spec.addPulse('init',    '2',        {'greenLaser'});
            spec.addPulse('ref',     '0.3',      {'greenLaser', 'detector'});

            spec.signalWindow = 1;
            spec.referenceWindow = 2;
        end
    end
end
