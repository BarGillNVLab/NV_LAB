classdef ViewExperimentParams < ViewVBox & EventListener
    %VIEWEXPERIMENTPARAMS Table of the selected Experiment's parameters
    %   Which parameters are shown, and how, comes from
    %   Experiment.guiParameterSpec - by default reflection over the public
    %   properties, or a curated list where an Experiment overrides it.
    %
    %   Values are written straight back onto the Experiment, so the
    %   Experiment's own property setters stay the authority on what is
    %   valid. A rejected value is reverted in the table and the reason is
    %   reported, rather than being swallowed.

    properties (Constant)
        COLUMN_NAMES = {'Group', 'Parameter', 'Value', 'Units'}
        COLUMN_EDITABLE = [false, false, true, false]
        COLUMN_WIDTHS = {70, 150, 110, 50}

        COL_VALUE = 3   % index into COLUMN_NAMES
    end

    properties (Access = private)
        tblParams
        lblHint

        expName = ''
        specs = []          % struct array of ExpGuiParam specs, in display order
        isApplyingEdit = false  % guards against our own EVENT_PARAM_CHANGED

        changedCallback     % function handle, called after a successful edit
    end

    methods
        function obj = ViewExperimentParams(parent, controller, changedCallback)
            padding = 5;
            spacing = 3;
            obj@ViewVBox(parent, controller, padding, spacing);
            obj@EventListener({});      % re-targeted in showExperiment
            obj.changedCallback = changedCallback;

            obj.tblParams = uitable(...
                'Parent', obj.component, ...
                'ColumnName', obj.COLUMN_NAMES, ...
                'ColumnEditable', obj.COLUMN_EDITABLE, ...
                'ColumnWidth', obj.COLUMN_WIDTHS, ...
                'RowName', [], ...
                'FontSize', 8, ...
                'Data', cell(0, length(obj.COLUMN_NAMES)), ...
                'CellEditCallback', @obj.cellEditCallback);

            obj.lblHint = uicontrol(obj.PROP_TEXT_NO_BG{:}, ...
                'Parent', obj.component, ...
                'String', 'No experiment loaded.');

            obj.component.Heights = [-1, 16];

            obj.height = 260;
            obj.width = 400;
        end

        function showExperiment(obj, expName)
            % Point the table at a different Experiment
            if ~isempty(obj.expName)
                obj.stopListeningTo(obj.expName);
            end
            obj.expName = expName;
            if ~isempty(expName)
                obj.startListeningTo(expName);
            end

            obj.rebuild();
        end

        function showNotice(obj, message)
            % Put a one-off message in the hint line under the table
            if isvalid(obj.lblHint)
                obj.lblHint.String = message;
            end
        end

        function rebuild(obj)
            % Re-read the spec list and repopulate the table from scratch
            exp = obj.experimentOrEmpty();
            if isempty(exp)
                obj.specs = [];
                obj.tblParams.Data = cell(0, length(obj.COLUMN_NAMES));
                obj.lblHint.String = 'No experiment loaded.';
                return
            end

            try
                newSpecs = exp.guiParameterSpec();
            catch err
                EventStation.anonymousWarning('Could not read parameters of %s: %s', obj.expName, err.message);
                newSpecs = [];
            end

            % Group the rows together, keeping each group's internal order
            if ~isempty(newSpecs)
                [~, order] = sort({newSpecs.group});
                newSpecs = newSpecs(order);
            end
            obj.specs = newSpecs;

            obj.refreshValues();

            if isempty(obj.specs)
                obj.lblHint.String = sprintf('%s exposes no editable parameters.', obj.expName);
            else
                obj.lblHint.String = sprintf('%d parameters. Vectors accept "1 : 0.5 : 10" or "[1 2 3]".', ...
                    length(obj.specs));
            end
        end

        function refreshValues(obj)
            % Re-read every value from the Experiment into the table,
            % without rebuilding the row list
            exp = obj.experimentOrEmpty();
            if isempty(exp) || isempty(obj.specs)
                obj.tblParams.Data = cell(0, length(obj.COLUMN_NAMES));
                return
            end

            nRows = length(obj.specs);
            data = cell(nRows, length(obj.COLUMN_NAMES));
            for i = 1 : nRows
                spec = obj.specs(i);
                data{i, 1} = spec.group;
                data{i, 2} = spec.label;
                data{i, 3} = obj.readValueAsString(exp, spec);
                data{i, 4} = spec.units;
            end
            obj.tblParams.Data = data;
        end
    end

    %% Callbacks
    methods (Access = private)
        function cellEditCallback(obj, ~, event)
            if isempty(event.Indices); return; end
            row = event.Indices(1);
            col = event.Indices(2);
            if col ~= obj.COL_VALUE; return; end
            if row < 1 || row > length(obj.specs); return; end

            spec = obj.specs(row);
            exp = obj.experimentOrEmpty();
            if isempty(exp)
                obj.revert(row, event.PreviousData);
                return
            end

            % Decide the type now, from the live value, so that a property
            % which was empty when the table was built is still parsed
            % correctly once it has something in it.
            type = spec.type;
            if isempty(type)
                type = ExpGuiParam.inferType(exp.(spec.name));
            end

            [value, isOk] = ExpGuiParam.stringToValue(event.NewData, type);
            if ~isOk
                EventStation.anonymousWarning('"%s" is not a valid %s for %s.', ...
                    event.NewData, type, spec.label);
                obj.revert(row, event.PreviousData);
                return
            end

            if ~isempty(spec.options) && ~any(strcmp(value, spec.options))
                EventStation.anonymousWarning('%s must be one of: %s.', ...
                    spec.label, strjoin(spec.options, ', '));
                obj.revert(row, event.PreviousData);
                return
            end

            % Hand it to the Experiment, which gets the final say
            obj.isApplyingEdit = true;
            try
                exp.(spec.name) = value;
            catch err
                obj.isApplyingEdit = false;
                EventStation.anonymousWarning('%s rejected that value: %s', spec.label, err.message);
                obj.revert(row, event.PreviousData);
                return
            end
            obj.isApplyingEdit = false;

            % Show what the Experiment actually stored, which may have been
            % rounded or otherwise adjusted by its setter
            obj.setCell(row, obj.readValueAsString(exp, spec));

            if ~isempty(obj.changedCallback)
                obj.changedCallback();
            end
        end

        function revert(obj, row, previousData)
            obj.setCell(row, previousData);
        end

        function setCell(obj, row, value)
            data = obj.tblParams.Data;
            if row >= 1 && row <= size(data, 1)
                data{row, obj.COL_VALUE} = value;
                obj.tblParams.Data = data;
            end
        end

        function str = readValueAsString(obj, exp, spec) %#ok<INUSL>
            try
                str = ExpGuiParam.valueToString(exp.(spec.name));
            catch
                str = '<unreadable>';
            end
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

    %% overridden from EventListener
    methods
        function onEvent(obj, event)
            % Someone else changed a parameter (a script, or the Experiment
            % itself while preparing). Re-read, unless it was our own edit.
            if obj.isApplyingEdit; return; end
            if ~isvalid(obj); return; end
            if isfield(event.extraInfo, Experiment.EVENT_PARAM_CHANGED)
                obj.refreshValues();
            end
        end
    end

end
