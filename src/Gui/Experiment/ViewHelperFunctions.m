classdef ViewHelperFunctions < ViewVBox
    %VIEWHELPERFUNCTIONS Browse and run the functions in helperFunctions\
    %   Every .m file under helperFunctions is listed. Selecting one shows
    %   its signature and a row per input argument, pre-filled where the
    %   argument name gives it away: an argument called exp gets the
    %   experiment currently selected in the GUI, toPlot gets true, toSave
    %   gets false.
    %
    %   Arguments left blank at the end are simply not passed, so each
    %   function keeps its own defaults.
    %
    %   Functions plot as they always have - the GUI does not intercept
    %   their figures - and any returned values are summarised in the panel.
    %
    %   See also HELPERFUNCTIONCATALOG

    properties (Constant)
        COLUMN_NAMES = {'Argument', 'Value'}
        COLUMN_EDITABLE = [false, true]
        COLUMN_WIDTHS = {110, 235}

        COL_VALUE = 2
    end

    properties (Access = private)
        edtFilter
        lbxFunctions
        lblSignature
        tblArguments
        btnRun
        txtOutput

        entries = []        % everything discovered
        shown = []          % those passing the filter
        current = []        % the selected entry

        expName = ''        % experiment the <current experiment> token resolves to
    end

    methods
        function obj = ViewHelperFunctions(parent, controller)
            padding = 5;
            spacing = 4;
            obj@ViewVBox(parent, controller, padding, spacing);

            box = obj.component;

            obj.edtFilter = uicontrol(obj.PROP_EDIT_SMALL{:}, ...
                'Parent', box, ...
                'String', '', ...
                'TooltipString', 'Type to filter the list', ...
                'Callback', @obj.filterCallback);

            obj.lbxFunctions = uicontrol(...
                'Parent', box, ...
                'Style', 'listbox', ...
                'FontSize', 9, ...
                'String', {}, ...
                'Callback', @obj.listCallback);

            obj.lblSignature = uicontrol(obj.PROP_TEXT_NORMAL{:}, ...
                'Parent', box, ...
                'Max', 2, 'Min', 0, ...
                'String', 'Select a function.');

            obj.tblArguments = uitable(...
                'Parent', box, ...
                'ColumnName', obj.COLUMN_NAMES, ...
                'ColumnEditable', obj.COLUMN_EDITABLE, ...
                'ColumnWidth', obj.COLUMN_WIDTHS, ...
                'RowName', [], ...
                'FontSize', 8, ...
                'Data', cell(0, 2));

            obj.btnRun = uicontrol(obj.PROP_BUTTON{:}, ...
                'Parent', box, ...
                'String', 'Run', ...
                'Enable', 'off', ...
                'Callback', @obj.runCallback);

            obj.txtOutput = uicontrol(...
                'Parent', box, ...
                'Style', 'edit', ...
                'Max', 2, 'Min', 0, ...           % multi-line
                'Enable', 'inactive', ...         % read-only, still scrollable
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', 'white', ...
                'FontName', 'Monospaced', ...
                'FontSize', 8, ...
                'String', '');

            box.Heights = [25, -1, 40, 110, 28, 95];

            obj.refreshList();

            obj.height = 520;
            obj.width = 400;
        end

        function showExperiment(obj, expName)
            % Which experiment the <current experiment> token refers to
            obj.expName = expName;
            % A pre-filled experiment argument now has something to resolve to
            obj.populateArguments();
        end

        function refreshList(obj)
            try
                obj.entries = HelperFunctionCatalog.discover();
            catch err
                EventStation.anonymousWarning('Could not list helper functions: %s', err.message);
                obj.entries = [];
            end
            obj.applyFilter();
        end
    end

    %% Callbacks
    methods (Access = private)
        function filterCallback(obj, ~, ~)
            obj.applyFilter();
        end

        function applyFilter(obj)
            if isempty(obj.entries)
                obj.shown = [];
                obj.lbxFunctions.String = {};
                obj.btnRun.Enable = 'off';
                return
            end

            text = strtrim(obj.edtFilter.String);
            if isempty(text)
                obj.shown = obj.entries;
            else
                haystack = strcat({obj.entries.name}, ' ', {obj.entries.group});
                obj.shown = obj.entries(contains(haystack, text, 'IgnoreCase', true));
            end

            labels = cell(1, numel(obj.shown));
            for i = 1 : numel(obj.shown)
                e = obj.shown(i);
                if strcmp(e.group, '.')
                    where = '';
                else
                    where = sprintf('  -  %s', e.group);
                end
                if e.isScript
                    labels{i} = sprintf('%s   [script]%s', e.name, where);
                else
                    labels{i} = sprintf('%s%s', e.name, where);
                end
            end
            obj.lbxFunctions.String = labels;
            obj.lbxFunctions.Value = min(max(1, obj.lbxFunctions.Value), max(1, numel(labels)));

            obj.listCallback();
        end

        function listCallback(obj, ~, ~)
            if isempty(obj.shown)
                obj.current = [];
                obj.lblSignature.String = 'No function selected.';
                obj.tblArguments.Data = cell(0, 2);
                obj.btnRun.Enable = 'off';
                return
            end

            idx = obj.lbxFunctions.Value;
            idx = min(max(1, idx), numel(obj.shown));
            obj.current = obj.shown(idx);
            obj.btnRun.Enable = 'on';

            obj.lblSignature.String = obj.signatureText(obj.current);
            obj.populateArguments();
        end

        function populateArguments(obj)
            % One row per declared input, pre-filled where we can guess
            if isempty(obj.current)
                obj.tblArguments.Data = cell(0, 2);
                return
            end

            inputs = obj.current.inputs;
            data = cell(numel(inputs), 2);
            for i = 1 : numel(inputs)
                data{i, 1} = inputs{i};
                data{i, 2} = HelperFunctionCatalog.defaultFor(inputs{i});
            end
            obj.tblArguments.Data = data;
        end

        function runCallback(obj, ~, ~)
            if isempty(obj.current); return; end
            entry = obj.current;

            % A script runs whatever it likes, including driving the setup -
            % alignmentScript moves the field, runScriptBasicExpAWG opens a
            % second GUI. Always ask first.
            if entry.isScript
                if ~QuestionUserYesNo('Run script', sprintf( ...
                        ['"%s" is a script, not a function.\n\n', ...
                        'It runs in the base workspace and may drive the setup ', ...
                        'or change its state. Run it?'], entry.name))
                    return
                end
                args = {};
            else
                raw = obj.tblArguments.Data;
                if isempty(raw)
                    rawValues = {};
                else
                    rawValues = raw(:, obj.COL_VALUE)';
                    rawValues = cellfun(@obj.asText, rawValues, 'UniformOutput', false);
                end

                [args, isOk, message] = HelperFunctionCatalog.resolveArguments( ...
                    rawValues, obj.experimentOrEmpty());
                if ~isOk
                    obj.setOutput(sprintf('Could not run %s.\n\n%s', entry.name, message));
                    return
                end

                [isOk, message] = obj.checkSavePath(entry, args);
                if ~isOk
                    obj.setOutput(sprintf('Could not run %s.\n\n%s', entry.name, message));
                    return
                end
            end

            obj.setOutput(sprintf('Running %s ...', entry.name));
            fig = ancestor(obj.component, 'figure');
            oldPointer = '';
            if ~isempty(fig); oldPointer = fig.Pointer; fig.Pointer = 'watch'; end
            drawnow limitrate

            [outputs, names, errorMessage] = HelperFunctionCatalog.run(entry, args);

            if ~isempty(fig) && isvalid(fig); fig.Pointer = oldPointer; end

            if ~isempty(errorMessage)
                obj.setOutput(sprintf('%s failed:\n\n%s', entry.name, errorMessage));
                return
            end

            obj.setOutput(sprintf('%s\n\n%s', entry.name, ...
                HelperFunctionCatalog.summarize(names, outputs)));
        end
    end

    %% Helpers
    methods (Access = private)
        function str = signatureText(obj, entry) %#ok<INUSL>
            if entry.isScript
                signature = sprintf('%s   (script - no arguments)', entry.name);
            else
                if isempty(entry.outputs)
                    lhs = '';
                else
                    lhs = sprintf('[%s] = ', strjoin(entry.outputs, ', '));
                end
                signature = sprintf('%s%s(%s)', lhs, entry.name, strjoin(entry.inputs, ', '));
            end
            if isempty(entry.summary)
                str = signature;
            else
                str = sprintf('%s\n%s', signature, entry.summary);
            end
        end

        function [isOk, message] = checkSavePath(obj, entry, args) %#ok<INUSL>
            % A function with both toSave and path builds its filename as
            % [path, '\name_timestamp']. Saving with path left empty would
            % write to the drive root, so refuse instead.
            isOk = true;
            message = '';

            iSave = find(strcmpi(entry.inputs, 'toSave'), 1);
            iPath = find(strcmpi(entry.inputs, 'path'), 1);
            if isempty(iSave) || isempty(iPath); return; end
            if iSave > numel(args); return; end

            wantsToSave = args{iSave};
            if ~(islogical(wantsToSave) || isnumeric(wantsToSave)) || ~any(wantsToSave); return; end

            if iPath > numel(args) || isempty(args{iPath})
                isOk = false;
                message = sprintf(['toSave is true but path is empty, so the results would ', ...
                    'be written to the root of the drive.\n\nSet path to a folder ', ...
                    '(in quotes, e.g. ''C:\\lab\\fits''), or set toSave to false.']);
            end
        end

        function str = asText(obj, value) %#ok<INUSL>
            % uitable hands back '' for a cleared cell, but can also hold []
            if ischar(value)
                str = value;
            elseif isempty(value)
                str = '';
            else
                str = char(string(value));
            end
        end

        function setOutput(obj, str)
            if ~isvalid(obj.txtOutput); return; end
            obj.txtOutput.String = strsplit(str, sprintf('\n'));
        end

        function exp = experimentOrEmpty(obj)
            exp = [];
            if isempty(obj.expName); return; end
            candidate = getObjByName(obj.expName);
            if ~isempty(candidate) && isvalid(candidate) && isa(candidate, 'Experiment')
                exp = candidate;
            end
        end
    end

end
