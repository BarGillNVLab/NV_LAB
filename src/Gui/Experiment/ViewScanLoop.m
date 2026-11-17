classdef ViewScanLoop < ViewVBox
    %VIEWSCANLOOP Build and run a ScanLoop from the experiment column
    %   Variables table: nested, top = outer. Values like 0:0.01:0.1 or 0, 0.2, 0.5.
    %   Steps table: done in order at every point.
    %     set        Knob := Value (an expression of the variables), optionally
    %                relative to the knob's value when the loop starts
    %     experiment run the experiment selected in the Experiment card
    %     wait       Value = seconds
    %     function   Value = a function name on the path, called f() or f(loop)
    %   Start checks all stage targets and asks before anything moves.
    %   The run is saved as ScanLoop_<time>.mat and left in the base
    %   workspace as `scanLoop`.
    %
    %   See also SCANLOOP

    properties (Constant)
        STEP_TYPES = {'set', 'experiment', 'wait', 'function'}
        BUTTON_ROW = 26
    end

    properties (Access = private)
        tblVars
        tblSteps
        cbxReturn
        lblStatus
        loop = []
    end

    methods
        function obj = ViewScanLoop(parent, controller)
            obj@ViewVBox(parent, controller, 4, 4);
            box = obj.component;

            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', box, 'String', 'Variables (top = outer loop)');
            obj.tblVars = uitable('Parent', box, 'CellSelectionCallback', @(t, e) set(t, 'UserData', e.Indices), 'ColumnName', {'Name', 'Values'}, ...
                'ColumnEditable', [true true], 'ColumnWidth', {70, 300}, 'RowName', [], ...
                'Data', {'x', '0:0.01:0.05'; 'z', '0:0.01:0.05'});
            obj.buttonRow(box, @(d) obj.editRows(obj.tblVars, d, {'v', '0'}));

            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', box, 'String', 'Steps at every point (in order)');
            obj.tblSteps = uitable('Parent', box, 'CellSelectionCallback', @(t, e) set(t, 'UserData', e.Indices), 'RowName', [], ...
                'ColumnName', {'Type', 'Knob', 'Value', 'Relative'}, ...
                'ColumnEditable', [true true true true], 'ColumnWidth', {75, 110, 120, 55}, ...
                'Data', {'set', 'X', 'x', true; 'set', 'Z', 'z', true; 'experiment', '-', '', false});
            obj.refreshKnobs();
            obj.buttonRow(box, @(d) obj.editRows(obj.tblSteps, d, {'set', '-', '0', false}));

            r = uix.HBox('Parent', box, 'Spacing', 3);
            obj.cbxReturn = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', r, 'Value', 1, ...
                'String', 'Return knobs at end', ...
                'TooltipString', 'After a normal finish, put every knob back where it was at Start');
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', r, 'String', 'Knobs', ...
                'TooltipString', 'Refresh the knob list (exp.* comes from the selected experiment)', ...
                'Callback', @(~, ~) obj.refreshKnobs());
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', r, 'String', 'Save', 'Callback', @(~, ~) obj.saveSpec());
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', r, 'String', 'Load', 'Callback', @(~, ~) obj.loadSpec());
            r.Widths = [-1, 45, 40, 40];

            r = uix.HBox('Parent', box, 'Spacing', 6);
            uicontrol(obj.PROP_BUTTON{:}, 'Parent', r, 'String', 'Start loop', ...
                'ForegroundColor', [0 0.5 0], 'Callback', @(~, ~) obj.start());
            uicontrol(obj.PROP_BUTTON{:}, 'Parent', r, 'String', 'Stop', ...
                'ForegroundColor', [0.8 0 0], 'Callback', @(~, ~) obj.stop());
            obj.lblStatus = uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', box, 'String', '', 'Max', 2);

            obj.setHeights([16, 110, obj.BUTTON_ROW, 16, 170, obj.BUTTON_ROW, obj.BUTTON_ROW, 34, -1]);
            obj.width = 410;
            obj.height = 560;
        end
    end

    methods (Access = private)
        function buttonRow(obj, box, fn)
            r = uix.HBox('Parent', box, 'Spacing', 3);
            labels = {'Add', 'Remove', 'Up', 'Down'};
            for k = 1:4
                uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', r, 'String', labels{k}, ...
                    'Callback', @(~, ~) fn(labels{k}));
            end
        end

        function editRows(~, tbl, action, newRow)
            d = tbl.Data;
            sel = size(d, 1);
            if ~isempty(tbl.UserData); sel = min(tbl.UserData(1), max(1, sel)); end   % last selected cell
            switch action
                case 'Add';    d = [d(1:sel, :); newRow; d(sel+1:end, :)];
                case 'Remove'; if ~isempty(d); d(min(sel, end), :) = []; end
                case 'Up';     if sel > 1; d([sel-1 sel], :) = d([sel sel-1], :); end
                case 'Down';   if sel < size(d, 1); d([sel sel+1], :) = d([sel+1 sel], :); end
            end
            tbl.Data = d;
        end

        function refreshKnobs(obj)
            names = ScanLoop().knobNames();
            obj.tblSteps.ColumnFormat = {obj.STEP_TYPES, [{'-'}, names], 'char', 'logical'};
        end

        function L = buildLoop(obj)
            L = ScanLoop();
            v = obj.tblVars.Data;
            for k = 1:size(v, 1)
                if ~isempty(strtrim(v{k, 1})); L.addVariable(strtrim(v{k, 1}), v{k, 2}); end
            end
            s = obj.tblSteps.Data;
            for k = 1:size(s, 1)
                switch s{k, 1}
                    case 'set';        L.addSet(s{k, 2}, s{k, 3}, s{k, 4});
                    case 'experiment'; L.addExperiment();
                    case 'wait';       L.addWait(str2double(s{k, 3}));
                    case 'function';   L.addFunction(strtrim(s{k, 3}));
                end
            end
            L.returnAtEnd = logical(obj.cbxReturn.Value);
        end

        function start(obj)
            if ~isempty(obj.loop) && obj.loop.isRunning; return; end
            try
                obj.loop = obj.buildLoop();
                obj.loop.onPoint = @(L) obj.showProgress(L);
                assignin('base', 'scanLoop', obj.loop);
                obj.lblStatus.String = 'Checking targets...';
                obj.loop.run();
                obj.showProgress(obj.loop);
            catch err
                obj.lblStatus.String = ['Error: ' err.message];
            end
        end

        function stop(obj)
            if ~isempty(obj.loop); obj.loop.stop(); end
            obj.lblStatus.String = 'Stopping...';
        end

        function showProgress(obj, L)
            if ~isvalid(obj.lblStatus); return; end
            state = 'done';
            if L.isRunning; state = 'running'; end
            obj.lblStatus.String = sprintf('%s: point %d of %d\n%s', state, L.pointIndex, L.nPoints, L.file);
            drawnow;
        end

        function saveSpec(obj)
            [f, p] = uiputfile('*.loop.json', 'Save scan loop');
            if isequal(f, 0); return; end
            try; obj.buildLoop().saveSpec(fullfile(p, f)); catch err; errordlg(err.message); end
        end

        function loadSpec(obj)
            [f, p] = uigetfile('*.loop.json', 'Load scan loop');
            if isequal(f, 0); return; end
            try
                L = ScanLoop(); L.loadSpec(fullfile(p, f));
                obj.tblVars.Data = [{L.variables.name}', cellfun(@ViewScanLoop.asText, {L.variables.values}, 'UniformOutput', false)'];
                st = L.steps;
                obj.tblSteps.Data = [{st.type}', {st.knob}', cellfun(@ViewScanLoop.asText, {st.value}, 'UniformOutput', false)', num2cell([st.relative])'];
                obj.cbxReturn.Value = L.returnAtEnd;
            catch err
                errordlg(err.message);
            end
        end
    end

    methods (Static, Access = private)
        function t = asText(v)
            if isnumeric(v); t = num2str(v(:)'); else; t = char(v); end
        end
    end
end
