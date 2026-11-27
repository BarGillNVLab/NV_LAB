classdef ScanLoop < handle
    % A programmable measurement loop over stages, current, MW, experiment
    % parameters - anything with a "knob".
    %
    % Two parts:
    %   VARIABLES  nested, outer -> inner. Each has a list of values. Every
    %              combination is one "point".
    %   STEPS      done in order at every point:
    %                set   - move a knob to an expression of the variables
    %                        ('x', '0.2', 'z + 0.05', '2*I'). Optionally
    %                        relative to the knob's value when the loop started.
    %                        A knob already at that value is not touched.
    %                experiment - run the selected experiment (restarted per point)
    %                wait  - pause N seconds
    %                function   - call a function: f() or f(loop); its output is recorded
    %
    % After every set step the knob is read back (e.g. the stage position)
    % and recorded. Every point is appended to loop.data and saved to a .mat
    % file as it happens.
    %
    % Example - for each current, raster X; at each X lift Z, move, lower Z, measure:
    %   L = ScanLoop();
    %   L.addVariable('I', [0 0.1 0.2]);
    %   L.addVariable('x', '0:0.01:0.05');
    %   L.addSet('Current', 'I');
    %   L.addSet('Z', '0.2', true);       % lift 0.2 mm above the start position
    %   L.addSet('X', 'x', true);         % X relative to its start position
    %   L.addSet('Z', '0', true);         % back down to the start height
    %   L.addExperiment();
    %   L.run();                          % shows the planned moves and asks first
    %
    % Safety: run() checks every target against the stage limits before
    % anything moves, and asks for confirmation. Stop halts a moving stage.
    % After a normal finish, knobs return to their start values when
    % returnAtEnd is true; after Stop or an error nothing moves by itself.

    properties
        variables = struct('name', {}, 'values', {})                  % values: numeric or text like '0:0.1:1'
        steps = struct('type', {}, 'knob', {}, 'value', {}, 'relative', {}, 'onChange', {})  % onChange: see addSet
        finalSteps = struct('type', {}, 'knob', {}, 'value', {}, 'relative', {}, 'onChange', {})   % done once after a normal finish, in order (addFinalSet)
        returnAtEnd = true      % after a normal finish, put set knobs back to their start values
                                % (in no particular order - use finalSteps when the order matters,
                                % e.g. lift Z before moving X back)
        experimentName = ''     % '' = whichever experiment is selected when run() starts
        saveFolder = ''         % '' = SaveLoad default folder \ScanLoops
        onPoint = []            % optional callback @(loop) after every point (GUI progress)
    end

    properties (Hidden)
        returnPrompt = []       % tests: @(lines) answer, in place of the "Return to start?" dialog
        countReader = []        % tests: @() [kcps, sterr] for focus steps, in place of the SPCM + laser
    end

    properties (Constant)
        MOVE_TIMEOUT_S = 120    % a knob still busy after this is stopped, and so is the loop
    end

    properties (SetAccess = private)
        data = struct([])       % one element per point
        file = ''
        isRunning = false
        pointIndex = 0
        nPoints = 0
        completed = false       % the last run went through every point (not stopped, no error)
    end

    properties (Access = private)
        customKnobs = struct('name', {}, 'set', {}, 'get', {})
        knobs                   % containers.Map name -> knob struct, while running
        startValues             % containers.Map name -> value at start
        lastSet                 % containers.Map name -> last value sent
        stopFlag = false
        exp = []                % the Experiment being run, if any
    end

    %% Building the loop
    methods
        function addVariable(obj, name, values)
            assert(isvarname(name), '"%s" is not a valid variable name', name);
            obj.variables(end+1) = struct('name', name, 'values', values);
        end

        function addSet(obj, knob, value, relative, onChange)
            % onChange (optional): a variable name - the step is done only at
            % the first point and whenever that variable changed since the
            % previous point. E.g. lift/move/lower the stage only when x
            % changes, while an inner loop runs over currents.
            if nargin < 4; relative = false; end
            if nargin < 5; onChange = ''; end
            if isnumeric(value); value = num2str(value, 12); end
            obj.steps(end+1) = struct('type', 'set', 'knob', knob, 'value', value, ...
                'relative', logical(relative), 'onChange', char(onChange));
        end

        function addFinalSet(obj, knob, value, relative)
            % Like addSet, but done once after the last point (normal finish
            % only), in the order added. Expressions see the last point's
            % variables; relative means relative to the value at the start.
            if nargin < 4; relative = false; end
            if isnumeric(value); value = num2str(value, 12); end
            obj.finalSteps(end+1) = struct('type', 'set', 'knob', knob, 'value', value, 'relative', logical(relative), 'onChange', '');
        end

        function addExperiment(obj)
            obj.steps(end+1) = struct('type', 'experiment', 'knob', '', 'value', '', 'relative', false, 'onChange', '');
        end

        function addFocus(obj, knob, opts, onChange)
            % Z focus search on a stage knob, at the position where the
            % previous steps left it: steps it to the best SPCM count rate
            % and settles there from below (see zFocusSearch). opts:
            % stepUm, integrationS (one reading), subReads (each reading is
            % this many SPCM reads: their mean and std), stdWeight (score =
            % kcps - stdWeight * std), maxTravelUm (either way from where
            % the search starts), backlashUm, noiseSigma.
            % onChange: as in addSet. The green laser's AOM is switched on
            % for the readings and back as it was afterwards.
            if nargin < 3 || isempty(opts); opts = struct(); end
            if nargin < 4; onChange = ''; end
            obj.steps(end+1) = struct('type', 'focus', 'knob', knob, 'value', ScanLoop.focusOptions(opts), ...
                'relative', false, 'onChange', char(onChange));
        end

        function addWait(obj, seconds)
            obj.steps(end+1) = struct('type', 'wait', 'knob', '', 'value', num2str(seconds), 'relative', false, 'onChange', '');
        end

        function addFunction(obj, fn)
            % fn: a function name (char) or a function handle
            obj.steps(end+1) = struct('type', 'function', 'knob', '', 'value', fn, 'relative', false, 'onChange', '');
        end

        function addKnob(obj, name, setFcn, getFcn)
            % Any custom knob: setFcn(value), getFcn() -> readback (may be @() NaN)
            obj.customKnobs(end+1) = struct('name', name, 'set', setFcn, 'get', getFcn);
        end

        function names = knobNames(obj)
            names = [ScanLoop.builtInKnobNames(obj.experimentOrEmpty()), {obj.customKnobs.name}];
        end

        function f = csvFile(obj)
            [folder, base] = fileparts(obj.file);
            f = fullfile(folder, [base '.csv']);
        end

        function T = summaryTable(obj)
            % One row per point: variables, readbacks, time, and for each
            % experiment step the file it was saved to. Arrays (curves) are
            % left to the .mat and the experiment files.
            n = numel(obj.data);
            T = table((1:n)', 'VariableNames', {'point'});
            for f = fieldnames(obj.data)'
                name = f{1};
                vals = {obj.data.(name)};
                filled = vals(~cellfun(@isempty, vals));
                if isempty(filled); continue; end
                sample = filled{1};
                if isnumeric(sample) && isscalar(sample)
                    col = nan(n, 1);
                    for i = 1:n; if ~isempty(vals{i}); col(i) = vals{i}; end; end
                    T.(name) = col;
                elseif isdatetime(sample)
                    col = strings(n, 1);
                    for i = 1:n; if ~isempty(vals{i}); col(i) = string(vals{i}, 'yyyy-MM-dd HH:mm:ss'); end; end
                    T.(name) = col;
                elseif isstruct(sample) && isfield(sample, 'file')
                    fileName = strings(n, 1); fullPath = strings(n, 1); averages = nan(n, 1);
                    for i = 1:n
                        r = vals{i};
                        if isempty(r); continue; end
                        fullPath(i) = string(r.file);
                        [~, b, ext] = fileparts(r.file);
                        fileName(i) = string([b ext]);
                        averages(i) = r.averagesDone;
                    end
                    T.([name '_file']) = fileName;
                    T.([name '_averages']) = averages;
                    T.([name '_path']) = fullPath;
                end
            end
        end

        function stop(obj)
            obj.stopFlag = true;
            if ~isempty(obj.exp) && isvalid(obj.exp); obj.exp.pause(); end
        end
    end

    %% Running
    methods
        function run(obj, askFirst)
            if nargin < 2; askFirst = true; end
            assert(~obj.isRunning, 'This loop is already running');
            assert(~isempty(obj.steps), 'The loop has no steps');
            obj.stopFlag = false;
            obj.completed = false;
            obj.data = struct([]);
            obj.pointIndex = 0;

            [grid, names] = obj.grid();
            obj.nPoints = size(grid, 1);
            obj.connectKnobs();
            c = onCleanup(@() obj.releaseKnobs());

            targets = obj.preflight(grid, names);
            if askFirst && ~obj.confirm(targets)
                return
            end

            obj.file = obj.newFileName();
            obj.isRunning = true;
            finished = false;
            vars = cell2struct(num2cell(grid(1, :)), names, 2);
            try
                prevVars = [];
                for p = 1:obj.nPoints
                    vars = cell2struct(num2cell(grid(p, :)), names, 2);
                    obj.pointIndex = p;
                    rec = vars;
                    rec.time = datetime('now');
                    for k = 1:numel(obj.steps)
                        if obj.stopFlag; break; end
                        st = obj.steps(k);
                        if ~isempty(st.onChange) && ~isempty(prevVars) && prevVars.(st.onChange) == vars.(st.onChange)
                            % Its variable did not change since the last
                            % point: skip it, but still record where the knob is
                            if strcmp(st.type, 'set')
                                knob = obj.knobs(st.knob);
                                rec.(sprintf('s%d_%s', k, matlab.lang.makeValidName(st.knob))) = knob.get();
                            end
                            continue
                        end
                        rec = obj.doStep(st, k, vars, rec);
                    end
                    prevVars = vars;
                    if numel(fieldnames(rec)) > numel(names) + 1
                        % Keep what this point did, even if it was stopped
                        % part-way (e.g. the ESR paused from its window)
                        obj.data = ScanLoop.appendRecord(obj.data, rec);
                        obj.saveData();
                    end
                    if obj.stopFlag; break; end
                    if ~isempty(obj.onPoint); obj.onPoint(obj); end
                end
                finished = ~obj.stopFlag;
            catch err
                obj.saveData();
                if askFirst; obj.offerReturn(vars, err.message); end
                obj.isRunning = false;
                rethrow(err);
            end
            if finished
                obj.runFinalSteps(vars);
            elseif askFirst
                obj.offerReturn(vars, '');
            end
            obj.completed = finished;
            obj.isRunning = false;
            obj.saveData();
            if ~isempty(obj.onPoint); obj.onPoint(obj); end
        end
    end

    %% Saving the loop definition
    methods
        function s = toStruct(obj)
            s.variables = obj.variables;
            s.steps = obj.steps;
            for k = 1:numel(s.steps)
                if isa(s.steps(k).value, 'function_handle'); s.steps(k).value = func2str(s.steps(k).value); end
            end
            s.finalSteps = obj.finalSteps;
            s.returnAtEnd = obj.returnAtEnd;
        end

        function fromStruct(obj, s)
            obj.variables = struct('name', {}, 'values', {});
            obj.steps = struct('type', {}, 'knob', {}, 'value', {}, 'relative', {}, 'onChange', {});
            for v = ScanLoop.asCell(s.variables); obj.addVariable(v{1}.name, v{1}.values); end
            for t = ScanLoop.asCell(s.steps)
                st = t{1};
                onChange = ''; if isfield(st, 'onChange'); onChange = st.onChange; end
                obj.steps(end+1) = struct('type', st.type, 'knob', st.knob, 'value', st.value, ...
                    'relative', logical(st.relative), 'onChange', char(onChange));
            end
            obj.finalSteps = struct('type', {}, 'knob', {}, 'value', {}, 'relative', {}, 'onChange', {});
            if isfield(s, 'finalSteps') && ~isempty(s.finalSteps)
                for t = ScanLoop.asCell(s.finalSteps); obj.addFinalSet(t{1}.knob, t{1}.value, t{1}.relative); end
            end
            if isfield(s, 'returnAtEnd'); obj.returnAtEnd = logical(s.returnAtEnd); end
        end

        function saveSpec(obj, file)
            fid = fopen(file, 'w'); c = onCleanup(@() fclose(fid));
            fprintf(fid, '%s', jsonencode(obj.toStruct(), 'PrettyPrint', true));
        end

        function loadSpec(obj, file)
            obj.fromStruct(jsondecode(fileread(file)));
        end
    end

    %% Internals
    methods (Access = private)
        function [g, names] = grid(obj)
            % All points, one per row, inner variable changing fastest
            names = {obj.variables.name};
            vals = cellfun(@ScanLoop.parseValues, {obj.variables.values}, 'UniformOutput', false);
            if isempty(vals); g = zeros(1, 0); return; end
            c = cell(1, numel(vals));
            [c{end:-1:1}] = ndgrid(vals{end:-1:1});
            g = cell2mat(cellfun(@(x) x(:), c, 'UniformOutput', false));
        end

        function connectKnobs(obj)
            obj.knobs = containers.Map();
            obj.startValues = containers.Map();
            obj.lastSet = containers.Map();
            allSteps = [obj.steps, obj.finalSteps];
            for k = 1:numel(allSteps)
                st = allSteps(k);
                if ~any(strcmp(st.type, {'set', 'focus'})) || isKey(obj.knobs, st.knob); continue; end
                knob = obj.makeKnob(st.knob);
                obj.knobs(st.knob) = knob;
                obj.startValues(st.knob) = knob.start();
            end
        end

        function releaseKnobs(obj)
            if isempty(obj.knobs); return; end
            for name = obj.knobs.keys
                % Take the knob out first: a call chained onto the map lookup
                % asks for an output, which release() does not give
                knob = obj.knobs(name{1});
                try; knob.release(); catch err; err2warning(err); end
            end
            obj.knobs = containers.Map();
            obj.isRunning = false;
        end

        function targets = preflight(obj, grid, names)
            % Evaluate every set step at every point and check it against
            % the knob's limits, before anything moves.
            targets = containers.Map();
            for p = 1:size(grid, 1) + 1     % the extra pass: final steps, with the last point's variables
                if p <= size(grid, 1)
                    vars = cell2struct(num2cell(grid(p, :)), names, 2);
                    list = obj.steps;
                else
                    list = obj.finalSteps;
                end
                lastTarget = struct();  % knob -> its last set target at this point
                for k = 1:numel(list)
                    st = list(k);
                    switch st.type
                        case 'set'
                            v = obj.targetOf(st, k, vars);
                            lastTarget.(matlab.lang.makeValidName(st.knob)) = v;
                        case 'focus'
                            % The search goes either way from where the
                            % previous set left the knob, plus the backlash
                            % overshoot below
                            key = matlab.lang.makeValidName(st.knob);
                            c = obj.startValues(st.knob);
                            if isfield(lastTarget, key); c = lastTarget.(key); end
                            o = st.value;
                            v = c + [-(o.maxTravelUm + o.backlashUm), o.maxTravelUm] / 1000;
                        otherwise
                            continue
                    end
                    knob = obj.knobs(st.knob);
                    for vi = v; knob.check(vi); end   % not chained onto the lookup - see releaseKnobs
                    if isKey(targets, st.knob)
                        r = targets(st.knob); targets(st.knob) = [min(r(1), min(v)), max(r(2), max(v))];
                    else
                        targets(st.knob) = [min(v), max(v)];
                    end
                end
            end
        end

        function ok = confirm(obj, targets)
            lines = {sprintf('%d point(s), %d step(s) each.', obj.nPoints, numel(obj.steps)), ''};
            for name = targets.keys
                r = targets(name{1});
                lines{end+1} = sprintf('%s: now %.4g, will go %.4g .. %.4g', ...
                    name{1}, obj.startValues(name{1}), r(1), r(2)); %#ok<AGROW>
            end
            for st = obj.steps(strcmp({obj.steps.type}, 'focus'))
                o = st.value;
                lines{end+1} = sprintf(['%s focus search: %g um steps, %g s readings (score = kcps - %g x STD), ', ...
                    'up to %g um either way, final approach from %g um below. The green AOM is on during it.'], ...
                    st.knob, o.stepUm, o.integrationS, o.stdWeight, o.maxTravelUm, o.backlashUm); %#ok<AGROW>
            end
            if ~isempty(obj.finalSteps)
                lines{end+1} = ''; lines{end+1} = 'At the end, in this order:';
                for k = 1:numel(obj.finalSteps)
                    f = obj.finalSteps(k);
                    rel = ''; if f.relative; rel = ' (relative to start)'; end
                    lines{end+1} = sprintf('   %s := %s%s', f.knob, f.value, rel); %#ok<AGROW>
                end
            end
            if obj.returnAtEnd
                lines{end+1} = ''; lines{end+1} = 'At the end, set knobs return to their current values.';
            end
            ok = strcmp(questdlg(lines, 'Start scan loop?', 'Start', 'Cancel', 'Cancel'), 'Start');
        end

        function v = targetOf(obj, st, k, vars)
            [v, isOk, msg] = SequenceExpression.evaluate(st.value, vars);
            if ~isOk; error('Step %d (%s): "%s" - %s', k, st.knob, st.value, msg); end
            if st.relative; v = v + obj.startValues(st.knob); end
        end

        function rec = doStep(obj, st, k, vars, rec)
            field = sprintf('s%d_%s', k, matlab.lang.makeValidName(st.knob));
            switch st.type
                case 'set'
                    knob = obj.knobs(st.knob);
                    v = obj.targetOf(st, k, vars);
                    if ~isKey(obj.lastSet, st.knob) || abs(obj.lastSet(st.knob) - v) > 1e-12
                        obj.setAndConfirm(knob, st.knob, v);
                        obj.lastSet(st.knob) = v;
                    end
                    rec.(field) = knob.get();
                case 'focus'
                    r = obj.runFocus(st);
                    pre = sprintf('s%d_focus', k);
                    rec.([pre 'Z']) = r.bestZ;              % [mm]
                    rec.([pre 'ShiftUm']) = r.shiftUm;      % best - where the search started [um]
                    rec.([pre 'Kcps']) = r.bestKcps;
                    rec.([pre 'Std']) = r.bestStd;          % std between the sub-reads [kcps]
                    rec.([pre 'Score']) = r.bestScore;      % kcps - stdWeight * std
                    rec.([pre 'VerifyKcps']) = r.verifyKcps;
                    rec.([pre 'VerifyStd']) = r.verifyStd;
                    rec.([pre 'Reads']) = size(r.history, 1);
                    rec.([pre 'Travel']) = double(strcmp(r.reason, 'travel'));  % 1: hit the travel limit
                    rec.([pre 'SpcmError']) = double(strcmp(r.reason, 'spcm'));  % 1: SPCM failed, Z back at the start
                    rec.([pre 'History']) = r.history;      % [z kcps sterr std score] - .mat only
                case 'experiment'
                    rec.(sprintf('s%d_experiment', k)) = obj.runExperiment();
                case 'wait'
                    t = tic; s = str2double(st.value);
                    while toc(t) < s && ~obj.stopFlag; pause(0.05); end
                case 'function'
                    rec.(sprintf('s%d_function', k)) = obj.callFunction(st.value);
            end
        end

        function r = runFocus(obj, st)
            % SPCM trouble: a failed read is retried with a fresh counter task
            % (subRead). If the counter still cannot be read, the search is
            % given up for this point only: Z goes back to where it started
            % (from below, like the search's own final approach), the row is
            % flagged (focusSpcmError), and the scan goes on - the ESR has
            % its own recovery. A stage error still stops the scan.
            knob = obj.knobs(st.knob);
            o = st.value;
            z0 = knob.get();
            o.stopFcn = @() obj.stopFlag;
            moveTo = @(z) obj.setAndConfirm(knob, st.knob, z);
            try
                [read, done] = obj.openCounter(o.integrationS, o.subReads);
                c = onCleanup(done);
                r = zFocusSearch(moveTo, read, z0, o);
                clear c
            catch err
                if ~strcmp(err.identifier, 'ScanLoop:spcm'); rethrow(err); end
                clear c     % frees the counter and puts the AOM back
                warning('ScanLoop:focusSkipped', '%s - Z goes back to the scan height and the scan goes on.', err.message);
                r = struct('bestZ', z0, 'bestKcps', NaN, 'bestStd', NaN, 'bestScore', NaN, 'verifyKcps', NaN, ...
                    'verifyStd', NaN, 'finalZ', z0, 'shiftUm', 0, 'reason', 'spcm', 'direction', 0, 'history', zeros(0, 5));
                if ~obj.stopFlag && abs(knob.get() - z0) > KinesisStage.POSITION_TOL_MM
                    if o.backlashUm > 0; moveTo(z0 - o.backlashUm / 1000); end
                    moveTo(z0);
                end
            end
            obj.lastSet(st.knob) = r.finalZ;    % where it really is now, for the next "already there" check
        end

        function [read, done] = openCounter(obj, integrationS, subReads)
            % Readings of integrationS each, with the green AOM on: subReads
            % SPCM reads -> [mean kcps, its standard error, std between them].
            % done() puts the AOM back as it was and frees the counter.
            if ~isempty(obj.countReader)
                read = @() ScanLoop.subRead(obj.countReader, subReads, @() []); done = @() []; return
            end
            counter = getObjByName(SpcmCounter.NAME);
            if ~isempty(counter) && isvalid(counter) && counter.isRunning
                error('Stop the SPCM counter in mainExp first - the focus search needs the same counter.');
            end
            laser = getObjByName(LaserGate.GREEN_LASER_NAME);
            if isempty(laser); error('Focus search: no green laser on this setup'); end
            if laser.isSourceAvail && ~laser.source.isEnabled
                error('Focus search: the green laser source is off - turn it on in mainExp.');
            end
            spcm = getObjByName(Spcm.NAME);
            if isempty(spcm); error('Focus search: no SPCM on this setup'); end
            try; spcm.stopExperimentCount; catch; end   % the last ESR may still hold the counter
            spcm.setSPCMEnable(true);
            aomWasOn = [];      % [] = no AOM switch: nothing to put back
            if laser.isAomSwitchAvail
                aomWasOn = laser.aomSwitch.isEnabled;
                laser.aomSwitch.isEnabled = true;       % the AOM only - the laser source is never touched
            end
            t = integrationS / subReads;
            try
                spcm.prepareReadByTime(t);
            catch err
                try
                    ScanLoop.restartTimeRead(spcm, t);  % e.g. a DAQ error left from the ESR: one fresh try
                catch
                    ScanLoop.closeCounter([], laser, aomWasOn);
                    error('ScanLoop:spcm', 'Focus search: could not start the SPCM counter (%s)', err.message);
                end
            end
            read = @() ScanLoop.subRead(@() spcm.readFromTime(), subReads, @() ScanLoop.restartTimeRead(spcm, t));
            done = @() ScanLoop.closeCounter(spcm, laser, aomWasOn);
        end

        function runFinalSteps(obj, vars)
            % The end-of-scan steps, in order. A Stop during them halts here:
            % e.g. X must not move if lifting Z was cut short.
            for k = 1:numel(obj.finalSteps)
                if obj.stopFlag; return; end
                obj.doStep(obj.finalSteps(k), numel(obj.steps) + k, vars, struct());
            end
            if obj.returnAtEnd && ~obj.stopFlag
                obj.returnToStart();
            end
        end

        function offerReturn(obj, vars, errMsg)
            % After a stop or an error: ask (default: no) whether to run the
            % end-of-scan steps now. Nothing moves unless the user says so.
            if isempty(obj.finalSteps) && ~obj.returnAtEnd; return; end
            lines = {sprintf('The scan stopped at point %d of %d.', obj.pointIndex, obj.nPoints)};
            if ~isempty(errMsg)
                lines = [lines, {'', ['Reason: ' errMsg]}];
            end
            lines = [lines, {'', 'Return to the start? This will do, in this order:'}];
            for k = 1:numel(obj.finalSteps)
                f = obj.finalSteps(k);
                rel = ''; if f.relative; rel = ' (relative to start)'; end
                lines{end+1} = sprintf('   %s := %s%s', f.knob, f.value, rel); %#ok<AGROW>
            end
            if obj.returnAtEnd; lines{end+1} = '   every knob back to its value before the scan'; end
            lines = [lines, {'', 'Stay here: nothing moves.'}];
            if isempty(obj.returnPrompt)
                answer = questdlg(lines, 'Scan stopped', 'Return to start', 'Stay here', 'Stay here');
            else
                answer = obj.returnPrompt(lines);
            end
            if ~strcmp(answer, 'Return to start'); return; end
            obj.stopFlag = false;   % the Stop button can still interrupt the return
            try
                obj.runFinalSteps(vars);
            catch e
                errordlg(['Returning to the start failed - nothing else will move: ' e.message], 'Scan loop');
            end
        end

        function setAndConfirm(obj, knob, name, v)
            % Send the value, wait until the knob has really got there, and
            % refuse to go on if it has not - the next step (e.g. moving X)
            % may only be safe once this one (e.g. lifting Z) is complete.
            knob.set(v);
            obj.waitWhile(knob, name);
            if ~obj.stopFlag && ~knob.reached(v)
                error(['%s did not reach %.6g (it is at %.6g). The loop stopped here and ', ...
                    'nothing else will move.'], name, v, knob.get());
            end
        end

        function waitWhile(obj, knob, name)
            t = tic;
            while knob.isBusy()
                if obj.stopFlag; knob.abort(); return; end
                if toc(t) > obj.MOVE_TIMEOUT_S
                    knob.abort();
                    error('%s still busy after %d s - stopped it, and the loop.', name, obj.MOVE_TIMEOUT_S);
                end
                pause(0.05);
            end
        end

        function r = runExperiment(obj)
            % Run the experiment once with fresh data, using whatever
            % parameters it holds now (e.g. the ESR as set up in mainExp).
            % A Pause or Halt in its plot window also stops the loop.
            e = obj.experimentOrEmpty();
            if isempty(e); error('No experiment selected for the scan loop'); end
            obj.exp = e;
            e.askQuestions = false;     % unattended: no "Restart tracking?" at every point
            e.lastSavedFile = '';
            c = onCleanup(@() obj.afterExperiment(e));
            e.restart();
            clear c
            if e.emergencyStopFlag || e.currIter < e.averages
                obj.stopFlag = true;    % stopped from its own window: stop the loop too
            end
            % Every point gets its own file: if the run did not autosave
            % (Autosave unticked), save it now
            if isempty(e.lastSavedFile) && e.currIter > 0
                try; e.save(); catch err; err2warning(err); end
            end
            % Compact result only - the experiment's own file keeps the full
            % data. Storing every raw cube here would rewrite hundreds of MB
            % after each point.
            r = struct('name', e.name, 'file', e.lastSavedFile, 'averagesDone', e.currIter, ...
                'x', [], 'y', [], 'ySterr', [], 'meanKcps', []);
            try; r.x = e.mCurrentXAxisParam.value; catch; end
            try; r.y = e.signalParam.value; r.ySterr = e.signalParam.sterr; catch; end
            try; r.meanKcps = mean(e.signal(:, :, 1:e.currIter), 3); catch; end   % gates x parameters
        end

        function afterExperiment(obj, e)
            obj.exp = [];
            try; e.askQuestions = true; catch; end
        end

        function out = callFunction(obj, fn)
            if ischar(fn) || isstring(fn)
                assert(isvarname(fn), '"%s" is not a function name', fn);
                fn = str2func(fn);
            end
            args = {};
            if nargin(fn) ~= 0; args = {obj}; end
            out = [];
            try
                out = fn(args{:});
            catch err
                if ~strcmp(err.identifier, 'MATLAB:maxlhs') && ~strcmp(err.identifier, 'MATLAB:TooManyOutputs')
                    rethrow(err);
                end
                fn(args{:});
            end
        end

        function returnToStart(obj)
            for name = obj.lastSet.keys
                knob = obj.knobs(name{1});
                obj.setAndConfirm(knob, name{1}, obj.startValues(name{1}));
            end
        end

        function saveData(obj)
            if isempty(obj.file) || isempty(obj.data); return; end
            spec = obj.toStruct(); data = obj.data; %#ok<PROPLC,NASGU>
            save(obj.file, 'spec', 'data');
            try
                writetable(obj.summaryTable(), obj.csvFile());
            catch err
                err2warning(err);   % e.g. the CSV is open in Excel; the .mat is saved anyway
            end
        end


        function f = newFileName(obj)
            folder = obj.saveFolder;
            if isempty(folder)
                try
                    folder = fullfile(SaveLoad.PATH_DEFAULT_SAVE, 'ScanLoops');
                catch
                    folder = fullfile(tempdir, 'ScanLoops');
                end
            end
            if ~exist(folder, 'dir'); mkdir(folder); end
            f = fullfile(folder, sprintf('ScanLoop_%s.mat', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))));
        end

        function e = experimentOrEmpty(obj)
            e = [];
            name = obj.experimentName;
            if isempty(name)
                try; name = Experiment.current(); catch; end
            end
            if ~isempty(name); e = getObjByName(name); end
        end

        function knob = makeKnob(obj, name)
            % A knob: set(v), get() readback, start() value to come back to,
            % check(v) limits, isBusy() / abort() for moves, release() at the end
            knob = struct('set', [], 'get', [], 'start', [], 'check', @(v) [], ...
                'isBusy', @() false, 'abort', @() [], 'release', @() [], 'reached', @(v) true);
            custom = strcmp({obj.customKnobs.name}, name);
            if any(custom)
                c = obj.customKnobs(find(custom, 1));
                knob.set = c.set; knob.get = c.get; knob.start = c.get;
                return
            end
            if startsWith(name, 'exp.')
                e = obj.experimentOrEmpty(); prop = extractAfter(name, 'exp.');
                if isempty(e); error('Knob %s needs a selected experiment', name); end
                knob.set = @(v) ScanLoop.setProp(e, prop, v);
                knob.get = @() e.(prop); knob.start = knob.get;
                return
            end
            tok = regexp(name, '^MW(\d+) (power|frequency)$', 'tokens', 'once');
            if ~isempty(tok)
                sg = getObjByName(SignalGenerator.NAME);
                i = str2double(tok{1}); prop = 'amplitude';
                if strcmp(tok{2}, 'frequency'); prop = 'frequency'; end
                ch = sg.FGchannels{i}.pgChannelNumber;
                knob.set = @(v) ScanLoop.setSg(sg, prop, v, ch);
                knob.get = @() ScanLoop.getSg(sg, prop, i); knob.start = knob.get;
                return
            end
            if strcmp(name, 'Current')
                cs = JsonInfoReader.getJson().currentSource;
                ps = E3631A(cs.address, cs.channel);
                wasOn = ps.isOn;
                knob.set = @(v) ScanLoop.setCurrent(ps, v);
                knob.get = @() ps.current;
                knob.start = @() ps.setpoint;
                knob.check = @(v) assert(v >= 0 && v <= ps.MAX_I.(ps.channel), ...
                    'Current %g A is outside 0..%g A', v, ps.MAX_I.(ps.channel));
                knob.release = @() ScanLoop.releaseCurrent(ps, wasOn);
                return
            end
            s = KinesisStage.get(name);     % errors if there is no such knob
            knob.set = @(v) s.moveTo(v, false);
            knob.get = @() s.position;
            knob.start = knob.get;
            knob.check = @(v) s.checkTarget(v);
            knob.isBusy = @() s.isBusy;         % arrived at the target - not just the (lagging) motion flag
            knob.abort = @() s.stop;
            knob.reached = @(v) s.reached(v);
        end
    end

    methods (Static)
        function names = builtInKnobNames(exp)
            names = {};
            try; names = cellfun(@(s) s.name, KinesisStage.getStages(), 'UniformOutput', false); catch; end
            try
                if isfield(JsonInfoReader.getJson(), 'currentSource'); names{end+1} = 'Current'; end
            catch
            end
            try
                sg = getObjByName(SignalGenerator.NAME);
                for i = 1:numel(sg.FGchannels)
                    names = [names, {sprintf('MW%d power', i), sprintf('MW%d frequency', i)}]; %#ok<AGROW>
                end
            catch
            end
            if nargin > 0 && ~isempty(exp)
                props = properties(exp);
                for k = 1:numel(props)
                    try
                        v = exp.(props{k});
                        if isnumeric(v) && isscalar(v); names{end+1} = ['exp.' props{k}]; end %#ok<AGROW>
                    catch
                    end
                end
            end
        end

        function v = parseValues(spec)
            % '0:0.1:1', '1:5', '0, 0.2, 0.5' or '0 0.2 0.5', or numbers
            if isnumeric(spec); v = spec(:)'; return; end
            spec = strtrim(char(spec));
            if contains(spec, ':')
                p = str2double(strsplit(spec, ':'));
                assert(all(isfinite(p)) && any(numel(p) == [2 3]), 'Cannot read "%s" as start:step:stop', spec);
                if numel(p) == 2; v = p(1):p(2); else; v = p(1):p(2):p(3); end
            else
                v = str2double(strsplit(spec, {',', ' ', ';'}, 'CollapseDelimiters', true));
                assert(all(isfinite(v)), 'Cannot read "%s" as a list of numbers', spec);
            end
            assert(~isempty(v), '"%s" gives no values', spec);
        end
    end

    methods (Static, Access = private)
        function closeCounter(spcm, laser, aomWasOn)
            if ~isempty(spcm); try; spcm.clearTimeRead; catch err; err2warning(err); end; end
            if ~isempty(aomWasOn); try; laser.aomSwitch.isEnabled = aomWasOn; catch err; err2warning(err); end; end
        end
        function [m, e, sd] = subRead(readOne, n, recover)
            % n reads -> their mean, its standard error, and the std between
            % them (how steady the counts are: vibration, drift, blinking).
            % A read that errors, or gives no counts / not a number (a DAQ
            % glitch, not light), is not used: recover() makes a fresh
            % counter task and it is read again, up to 3 tries. Then
            % 'ScanLoop:spcm' - the focus search is given up for this point.
            TRIES = 3;
            k = zeros(1, n);
            for i = 1:n
                for attempt = 1:TRIES
                    try
                        v = readOne();
                        if isscalar(v) && isfinite(v) && v > 0; k(i) = v; break; end
                        msg = sprintf('it read %g kcps', v);
                    catch err
                        msg = err.message;
                    end
                    if attempt == TRIES
                        error('ScanLoop:spcm', 'Focus search: the SPCM failed %d reads in a row (%s)', TRIES, msg);
                    end
                    warning('ScanLoop:spcmRetry', 'Focus search: SPCM read failed (%s) - restarting the counter and reading again', msg);
                    try; recover(); catch; end   % if this fails, the next read fails too and is counted
                end
            end
            m = mean(k); sd = std(k); e = sd / sqrt(n);
        end
        function restartTimeRead(spcm, t)
            try; spcm.clearTimeRead; catch; end     % the task may already be gone (a DAQ reset)
            spcm.prepareReadByTime(t);
        end
        function o = focusOptions(o)
            D = struct('stepUm', 3, 'integrationS', 1, 'subReads', 10, 'stdWeight', 1, ...
                'maxTravelUm', 30, 'backlashUm', 10, 'noiseSigma', 2);
            for f = fieldnames(D)'
                if ~isfield(o, f{1}) || isempty(o.(f{1})); o.(f{1}) = D.(f{1}); end
            end
            o = rmfield(o, setdiff(fieldnames(o), fieldnames(D)));
            assert(o.stepUm > 0 && o.integrationS > 0 && o.maxTravelUm >= o.stepUm && o.backlashUm >= 0 ...
                && o.subReads >= 2 && o.stdWeight >= 0, ...
                'Focus search: step and reading time > 0, max travel >= step, backlash >= 0, sub-reads >= 2, STD weight >= 0');
        end
        function setProp(obj, prop, v)
            obj.(prop) = v;
        end
        function setSg(sg, prop, v, ch)
            sg.(prop) = [v, ch];
        end
        function v = getSg(sg, prop, i)
            all = sg.(prop); v = all(min(i, numel(all)));
        end
        function setCurrent(ps, v)
            ps.setCurrent(v);
            if ~ps.isOn; ps.on; end
        end
        function releaseCurrent(ps, wasOn)
            if ~wasOn; ps.off; end
            delete(ps);
        end
        function c = asCell(x)
            if iscell(x); c = x(:)'; else; c = num2cell(x(:)'); end
        end
        function data = appendRecord(data, rec)
            if isempty(data); data = rec; return; end
            for f = setdiff(fieldnames(rec), fieldnames(data))'; data(1).(f{1}) = []; end
            for f = setdiff(fieldnames(data), fieldnames(rec))'; rec.(f{1}) = []; end
            data(end+1) = orderfields(rec, data(1));
        end
    end
end
