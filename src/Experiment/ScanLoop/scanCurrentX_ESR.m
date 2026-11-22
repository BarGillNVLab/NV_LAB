function fig = scanCurrentX_ESR()
%SCANCURRENTX_ESR Start window for the current x X scan with an ESR at every point
%   For each wire current I:
%       for each X position x:
%           Z back (retract), X to x, Z back to its start height, ESR
%
%   Type the values as from:step:to ranges - several are allowed, e.g.
%   "0:5:25, 0:100:400" - check the plan (it shows the absolute X and Z the
%   stages will visit) and press Start. A final dialog lists every range
%   before anything moves.
%
%   Load last: the settings of the last scan started. Load... / Save...:
%   a .json of these settings - every scan also leaves one next to its CSV
%   (ScanLoop_<time>.params.json), so an old scan can be loaded and rerun.
%
%   Before Start: select ESR in mainExp (its parameters are used as they
%   are), free COM5 (`clear ps`, close E3631A_gui), and put the stages
%   where X should be centred - X and Z are relative to where they are.
%
%   Stop here, or Pause/Halt in the ESR window: the loop stops after that
%   point and nothing moves further. Each point is saved as it happens to
%   ScanLoop_<time>.mat and .csv (SaveLoad default folder \ScanLoops).
%
%   See also BUILDCURRENTXSCAN, SCANLOOP

PREF_GROUP = 'NVLab_scanCurrentX';
DEFAULTS = struct('I', '0:50:400', 'x', '-150:5:150', 'zBack', -10, 'settle', 0.5, 'esrS', 60, 'order', 'current-outer');
s0 = DEFAULTS;
try
    if ispref(PREF_GROUP, 'last'); s0 = withDefaults(getpref(PREF_GROUP, 'last')); end
catch
end
L = [];
t0 = [];            % tic after the first point, for the live time estimate
paramsWritten = false;
runSettings = [];   % the settings the running scan was started with
lastFolder = '';

% Time model for the estimate (the ESR itself is measured - see fillEsrTime)
MOVE_S = 0.5;       % one stage move, incl. waiting for arrival
MOVES_PER_X = 3;    % Z back, X, Z down
CURRENT_S = 0.6;    % one change of the wire current
ESR_START_S = 3;    % per ESR run, on top of its averages (prepare, plot window)

fig = uifigure('Name', 'Current x X scan with ESR', 'Position', [200 150 560 600]);
g = uigridlayout(fig, [15 4]);
g.RowHeight = repmat({'fit'}, 1, 15);
g.ColumnWidth = {170, '1x', '1x', '1x'};

uilabel(g, 'Text', 'Scan parameters', 'FontWeight', 'bold');
uibutton(g, 'Text', 'Load last', 'Tooltip', 'The settings of the last scan started', ...
    'ButtonPushedFcn', @(~, ~) loadLast());
uibutton(g, 'Text', 'Load...', 'Tooltip', 'A saved .json - e.g. the .params.json next to an old scan''s CSV', ...
    'ButtonPushedFcn', @(~, ~) loadFile());
uibutton(g, 'Text', 'Save...', 'ButtonPushedFcn', @(~, ~) saveFile());

RANGE_TIP = ['from:step:to, several separated by commas, e.g. 0:5:25, 0:100:400. ', ...
    'Single values are fine too. Duplicates are dropped and the values sorted.'];
uilabel(g, 'Text', 'Wire current [mA]');
edI = textField(g, s0.I);
uilabel(g, 'Text', 'X [um], from where X is now');
edX = textField(g, s0.x);
lblValues = uilabel(g, 'Text', '', 'FontColor', [0.4 0.4 0.4], 'WordWrap', 'on');
lblValues.Layout.Column = [1 4];

uilabel(g, 'Text', 'Order');
ddOrder = uidropdown(g, ...
    'Items', {'Current outer: a full X scan per current', 'X outer: all currents at each X position'}, ...
    'ItemsData', {'current-outer', 'x-outer'}, 'Value', s0.order, ...
    'Tooltip', ['Current outer: the current changes only between X scans. ', ...
        'X outer: the stage stays put while every current is measured, then moves on.'], ...
    'ValueChangedFcn', @(~, ~) updatePlan());
ddOrder.Layout.Column = [2 4];

uilabel(g, 'Text', 'Z retract [um]');
edZ = numField(g, s0.zBack);
lblZ = uilabel(g, 'Text', 'negative = back (smaller Z)', 'FontColor', [0.4 0.4 0.4]);
lblZ.Layout.Column = [3 4];

uilabel(g, 'Text', 'Settle before ESR [s]');
edSettle = numField(g, s0.settle);
uilabel(g, 'Text', ''); uilabel(g, 'Text', '');

uilabel(g, 'Text', 'One ESR run [s]');
edEsr = numField(g, s0.esrS);
lblEsrTime = uilabel(g, 'Text', '', 'FontColor', [0.4 0.4 0.4], 'WordWrap', 'on');
lblEsrTime.Layout.Column = [3 4];

lblNow = uilabel(g, 'Text', '', 'WordWrap', 'on');
lblNow.Layout.Column = [1 3];
uibutton(g, 'Text', 'Refresh', 'ButtonPushedFcn', @(~, ~) refreshAll());

lblPlan = uilabel(g, 'Text', '', 'WordWrap', 'on', 'FontName', 'Consolas');
lblPlan.Layout.Column = [1 4];
lblEsr = uilabel(g, 'Text', '', 'WordWrap', 'on');
lblEsr.Layout.Column = [1 4];

btnStart = uibutton(g, 'Text', 'Start', 'FontWeight', 'bold', 'FontColor', [0 0.5 0], ...
    'ButtonPushedFcn', @(~, ~) startScan());
btnStart.Layout.Column = [1 2];
btnStop = uibutton(g, 'Text', 'Stop', 'FontWeight', 'bold', 'FontColor', [0.8 0 0], ...
    'Enable', 'off', 'ButtonPushedFcn', @(~, ~) stopScan());
btnStop.Layout.Column = [3 4];

lblStatus = uilabel(g, 'Text', '', 'WordWrap', 'on');
lblStatus.Layout.Column = [1 4];

refreshAll();

    function refreshAll()
        fillEsrTime();
        updatePlan();
    end

    function fillEsrTime()
        % Seconds per ESR run, for the ESR's CURRENT averages and frequency
        % list. Measured from the timestamps of its last run (one per
        % finished average), scaled by frequencies now / frequencies then -
        % an average is one sweep over all of them. With fewer than 2
        % finished averages there is nothing to measure, so it falls back
        % on the ESR's own theoretical figure (no overhead - too low).
        % Leaves the field alone when neither is available.
        lblEsrTime.Text = 'estimate - run the ESR (2+ averages) to measure it';
        try
            e = getObjByName('ESR');
            if isempty(e); return; end
            nNow = esrFrequencyCount(e);
            ts = e.averagesTimeStamp;
            ts = ts(any(ts, 2), :);                 % finished averages only
            if size(ts, 1) >= 2
                perAverage = median(diff(datenum(ts))) * 86400; %#ok<DATNM>
                nThen = numel(e.mCurrentXAxisParam.value);
                if perAverage > 0 && nThen > 0
                    perAverageNow = perAverage * nNow / nThen;
                    edEsr.Value = round(perAverageNow * e.averages + ESR_START_S);
                    lblEsrTime.Text = sprintf('measured %.1f s/avg (%d freq); now %d freq x %d avg', ...
                        perAverage, nThen, nNow, e.averages);
                    return
                end
            end
            pg = getObjByName(PulseGenerator.NAME);
            perAverage = e.repeats * pg.sequenceDuration() * 1e-6 * nNow * max(1, e.runsPerPerform);
            if perAverage > 0
                edEsr.Value = round(perAverage * e.averages + ESR_START_S);
                lblEsrTime.Text = sprintf('theoretical %.1f s/avg (no overhead, too low) - run 2+ averages to measure', perAverage);
            end
        catch
        end
    end

    function n = esrFrequencyCount(e)
        % The frequency list the next run will use: what was typed in the
        % sidebar since the last run, or else the last run's list (a run
        % replaces e.frequency with a single value while it goes).
        f = e.frequency;
        if isnumeric(f) && numel(f) > 1
            n = numel(f);
        else
            n = numel(e.frequencyInternal);
        end
    end

    function f = numField(parent, v)
        f = uieditfield(parent, 'numeric', 'Value', v, 'ValueChangedFcn', @(~, ~) updatePlan());
    end

    function f = textField(parent, v)
        f = uieditfield(parent, 'text', 'Value', v, 'Tooltip', RANGE_TIP, ...
            'ValueChangedFcn', @(~, ~) updatePlan());
        f.Layout.Column = [2 4];
    end

    function s = settings()
        s = struct('I', edI.Value, 'x', edX.Value, 'zBack', edZ.Value, 'settle', edSettle.Value, ...
            'esrS', edEsr.Value, 'order', ddOrder.Value);
    end

    function applySettings(s)
        s = withDefaults(s);
        edI.Value = s.I; edX.Value = s.x; edZ.Value = s.zBack; edSettle.Value = s.settle;
        edEsr.Value = s.esrS; ddOrder.Value = s.order;
        updatePlan();
    end

    function loadLast()
        try
            assert(ispref(PREF_GROUP, 'last'), 'No scan has been started from this window yet');
            applySettings(getpref(PREF_GROUP, 'last'));
            lblStatus.Text = 'Loaded the settings of the last scan started.';
        catch err
            uialert(fig, err.message, 'Load last');
        end
    end

    function loadFile()
        [f, p] = uigetfile({'*.json', 'Scan parameters (*.json)'}, 'Load scan parameters', defaultFolder());
        figure(fig);
        if isequal(f, 0); return; end
        try
            applySettings(jsondecode(fileread(fullfile(p, f))));
            lastFolder = p;
            lblStatus.Text = ['Loaded ' f];
        catch err
            uialert(fig, ['Could not load ' f ': ' err.message], 'Load');
        end
    end

    function saveFile()
        [f, p] = uiputfile({'*.json', 'Scan parameters (*.json)'}, 'Save scan parameters', ...
            fullfile(defaultFolder(), 'scan.params.json'));
        figure(fig);
        if isequal(f, 0); return; end
        try
            writeParams(fullfile(p, f), settings());
            lastFolder = p;
            lblStatus.Text = ['Saved ' f];
        catch err
            uialert(fig, err.message, 'Save');
        end
    end

    function d = defaultFolder()
        d = lastFolder;
        if isempty(d) && ~isempty(L) && ~isempty(L.file); d = fileparts(L.file); end
        if isempty(d); d = pwd; end
    end

    function v = range(str, what)
        v = parseRanges(str, what);
    end

    function s = withDefaults(s)
        % Fill what a file or an old preference lacks; old preferences kept
        % each range as a [from step to] vector.
        for f = fieldnames(DEFAULTS)'
            if ~isfield(s, f{1}) || isempty(s.(f{1})); s.(f{1}) = DEFAULTS.(f{1}); end
        end
        for f = {'I', 'x'}
            v = s.(f{1});
            if isnumeric(v)
                if numel(v) == 3; s.(f{1}) = sprintf('%g:%g:%g', v);
                else; s.(f{1}) = strjoin(compose('%g', v), ', '); end
            end
            s.(f{1}) = char(s.(f{1}));
        end
        s = rmfield(s, setdiff(fieldnames(s), fieldnames(DEFAULTS)));
    end

    function writeParams(file, s)
        fid = fopen(file, 'w');
        assert(fid > 0, 'Cannot write %s', file);
        c = onCleanup(@() fclose(fid));
        fprintf(fid, '%s', jsonencode(s, 'PrettyPrint', true));
    end

    function ok = updatePlan()
        ok = false;
        s = settings();
        lines = {};
        try
            I = range(s.I, 'Current');
            x = range(s.x, 'X');
            assert(s.zBack ~= 0, 'Z retract must not be 0');
            assert(s.settle >= 0, 'Settle must be 0 or more');
            assert(all(I >= 0) && max(I) <= 5000, 'Current must be within 0..5000 mA');
        catch err
            showPlan({err.message}, false);
            lblValues.Text = '';
            btnStart.Enable = 'off';
            return
        end
        lblValues.Text = sprintf('Current (%d): %s mA\nX (%d): %s um', ...
            numel(I), listText(I), numel(x), listText(x));

        lines{end+1} = sprintf('%d currents x %d X positions = %d ESR runs', numel(I), numel(x), numel(I) * numel(x));
        nPoints = numel(I) * numel(x);
        if strcmp(s.order, 'x-outer')
            % stage moves once per X position; the current changes at every point
            nMoves = numel(x) * MOVES_PER_X;  nCurrent = nPoints;
            lines{end+1} = 'Order: X outer - at each X position every current, then the stage moves';
        else
            % stage moves at every point; the current changes once per X scan
            nMoves = nPoints * MOVES_PER_X;   nCurrent = numel(I);
            lines{end+1} = 'Order: current outer - a full X scan per current';
        end
        total = nPoints * (s.esrS + s.settle) + nMoves * MOVE_S + nCurrent * CURRENT_S;
        perPoint = total / nPoints;
        lines{end+1} = sprintf('Time: about %s (%.0f s per point) - done ~%s if started now', ...
            fmtDuration(total), perPoint, char(datetime('now') + seconds(total), 'eee HH:mm'));
        ok = true;
        try
            zs = KinesisStage.get('Z'); xs = KinesisStage.get('X');
            z0 = zs.position; x0 = xs.position;
            lblNow.Text = sprintf('Now:  X = %.4f mm,  Z = %.4f mm', x0, z0);
            xa = x0 + [min(x) max(x)] / 1000;
            za = z0 + s.zBack / 1000;
            lines{end+1} = sprintf('X:  %.4f .. %.4f mm  (%+g .. %+g um)', xa(1), xa(2), min(x), max(x));
            lines{end+1} = sprintf('Z:  %.4f (measure) <-> %.4f mm (retracted)', z0, za);
            if xa(1) < xs.minPosition || xa(2) > xs.maxPosition
                lines{end+1} = sprintf('X OUT OF RANGE: limits %g .. %g mm', xs.minPosition, xs.maxPosition); ok = false;
            end
            if za < zs.minPosition || za > zs.maxPosition
                lines{end+1} = sprintf('Z OUT OF RANGE: limits %g .. %g mm', zs.minPosition, zs.maxPosition); ok = false;
            end
        catch err
            lblNow.Text = ['Stages: ' err.message];
            ok = false;
        end
        showPlan(lines, ok);

        e = getObjByName('ESR');
        if isempty(e)
            lblEsr.Text = 'ESR: not selected - choose ESR in mainExp (Experiment card) first.';
            lblEsr.FontColor = [0.8 0 0]; ok = false;
        else
            nf = '?';
            try; nf = num2str(esrFrequencyCount(e)); catch; end
            lblEsr.Text = sprintf('ESR: %d averages, %s frequencies per run (parameters as set in mainExp)', ...
                e.averages, nf);
            lblEsr.FontColor = [0 0 0];
        end
        if isempty(L) || ~L.isRunning
            btnStart.Enable = matlab.lang.OnOffSwitchState(ok);
        end
    end

    function t = listText(v)
        % All values when few, else the first and last few
        c = compose('%g', v);
        if numel(c) > 16; c = [c(1:6), {'...'}, c(end-5:end)]; end
        t = strjoin(c, ' ');
    end

    function showPlan(lines, ok)
        lblPlan.Text = strjoin(lines, newline);
        if ok; lblPlan.FontColor = [0 0 0]; else; lblPlan.FontColor = [0.8 0 0]; end
    end

    function startScan()
        if ~updatePlan(); return; end
        s = settings();
        runSettings = s;
        try; setpref(PREF_GROUP, 'last', s); catch; end
        L = buildCurrentXScan(struct('current_mA', range(s.I, 'Current'), 'x_um', range(s.x, 'X'), ...
            'zBack_um', s.zBack, 'settle_s', s.settle, 'order', s.order));
        L.onPoint = @(loop) showProgress(loop);
        assignin('base', 'scanLoop', L);
        btnStart.Enable = 'off'; btnStop.Enable = 'on';
        lblStatus.Text = 'Waiting for your confirmation...';
        t0 = [];
        paramsWritten = false;
        try
            L.run();    % shows every range and asks before anything moves
            if L.pointIndex == 0
                lblStatus.Text = 'Cancelled - nothing moved.';
            else
                showProgress(L);
            end
        catch err
            lblStatus.Text = ['Error: ' err.message];
        end
        if isvalid(fig)
            btnStop.Enable = 'off';
            updatePlan();
        end
    end

    function stopScan()
        if ~isempty(L); L.stop(); end
        lblStatus.Text = 'Stopping after this point...';
    end

    function showProgress(loop)
        if ~paramsWritten && ~isempty(loop.file)
            % These settings next to the scan's CSV, for Load... later
            paramsWritten = true;
            [folder, base] = fileparts(loop.file);
            try; writeParams(fullfile(folder, [base '.params.json']), runSettings); catch; end
        end
        if ~isvalid(fig); return; end
        if isempty(t0); t0 = tic; end          % first point done: the clock runs from here
        if loop.isRunning
            state = 'Running';
            d = [];
            if ~isempty(loop.data); d = loop.data(end); end
            if ~isempty(d)
                state = sprintf('Running - last: I = %g mA, x = %+g um', d.I, d.x);
            end
        elseif loop.completed
            state = 'Finished';
        else
            state = 'Stopped';
        end
        timing = '';
        done = numel(loop.data);
        if loop.isRunning && done >= 2
            elapsed = toc(t0);
            perPoint = elapsed / (done - 1);       % the clock started after the first point
            left = perPoint * (loop.nPoints - done);
            timing = sprintf('\nElapsed %s, about %s left - done ~%s  (%.0f s per point)', ...
                fmtDuration(elapsed + perPoint), fmtDuration(left), ...
                char(datetime('now') + seconds(left), 'eee HH:mm'), perPoint);
        end
        lblStatus.Text = sprintf('%s   (%d / %d points)%s\n%s', state, loop.pointIndex, loop.nPoints, timing, loop.csvFile());
        drawnow limitrate
    end

    function t = fmtDuration(sec)
        sec = round(sec);
        if sec >= 3600
            t = sprintf('%d h %02d min', floor(sec / 3600), floor(mod(sec, 3600) / 60));
        elseif sec >= 60
            t = sprintf('%d min %02d s', floor(sec / 60), mod(sec, 60));
        else
            t = sprintf('%d s', sec);
        end
    end
end
