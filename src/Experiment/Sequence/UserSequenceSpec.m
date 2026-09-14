classdef UserSequenceSpec < handle
    %USERSEQUENCESPEC A pulse sequence a user built in the GUI
    %   Holds everything needed to run a free-form sequence: the pulses, the
    %   named variables, which of those are swept, the explicit list of
    %   combinations to measure, and which detection windows are signal and
    %   reference.
    %
    %   A variable is bound to one of two things:
    %
    %     duration    - usable in pulse duration expressions ('tau',
    %                   '2*tau', 'piTime/2'), evaluated by SequenceExpression
    %     an MW setting - frequency, amplitude or phase on a named channel,
    %                   applied to the SignalGenerator before each point
    %
    %   That distinction is what lets a single scan sweep a pulse length and
    %   an MW frequency together.
    %
    %   Sweeping is an explicit table, not a grid: sweptNames names the
    %   columns and each row of combinations is one measurement point. The
    %   run loop stays one-dimensional - it walks the rows - so results come
    %   out as a table of one column per swept variable plus the counts.
    %
    %   A spec saves as JSON and can be exported as a real Exp*.m class.
    %
    %   See also SEQUENCEEXPRESSION, EXPUSERSEQUENCE, USERSEQUENCEEXPORTER

    properties (Constant)
        % The channel that marks a counting window. Matches the convention
        % used throughout the existing experiments.
        DETECTOR_CHANNEL = 'detector'

        FILE_SUFFIX = '.seq.json'
        FORMAT_VERSION = 2

        %% What a variable drives
        BIND_DURATION = 'duration'
        BIND_FREQUENCY = 'mwFrequency'
        BIND_AMPLITUDE = 'mwAmplitude'
        BIND_PHASE = 'mwPhase'

        BINDINGS = {'duration', 'mwFrequency', 'mwAmplitude', 'mwPhase'}
        % Plain text, not TeX: these are used in uitable headers and in
        % generated comments, neither of which renders an escape.
        BINDING_UNITS = {'us', 'MHz', 'dBm', 'deg'}
    end

    properties
        name = 'MySequence'     % char. Used for the file and the generated class

        % struct array: nickname (char), duration (char expression), channels (cellstr)
        pulses = struct('nickname', {}, 'duration', {}, 'channels', {})

        % struct array: name (char), value (double), binding (char), channel (char)
        % 'channel' is only meaningful for the MW bindings.
        variables = struct('name', {}, 'value', {}, 'binding', {}, 'channel', {})

        sweptNames = {}         % cellstr. Column order of 'combinations'
        combinations = []       % nPoints x numel(sweptNames) double
        xAxisName = ''          % which swept variable is the x axis; '' = point number

        signalWindow = 1        % which detection window is the signal
        referenceWindow = 2     % which detection window is the reference
    end

    methods
        function obj = UserSequenceSpec()
            obj@handle;
        end

        %% Pulses
        function addPulse(obj, nickname, duration, channels)
            if ~exist('nickname', 'var'); nickname = sprintf('pulse%d', numel(obj.pulses)+1); end
            if ~exist('duration', 'var'); duration = '1'; end
            if ~exist('channels', 'var'); channels = {}; end
            obj.pulses(end+1) = struct('nickname', nickname, 'duration', duration, ...
                'channels', {UserSequenceSpec.asCellstr(channels)});
        end

        function removePulse(obj, index)
            if index < 1 || index > numel(obj.pulses); return; end
            obj.pulses(index) = [];
        end

        function newIndex = movePulse(obj, index, offset)
            % Move a pulse up or down; returns where it ended up
            newIndex = index;
            target = index + offset;
            if index < 1 || index > numel(obj.pulses); return; end
            if target < 1 || target > numel(obj.pulses); return; end
            order = 1 : numel(obj.pulses);
            order([index target]) = order([target index]);
            obj.pulses = obj.pulses(order);
            newIndex = target;
        end

        %% Variables
        function setVariable(obj, name, value, binding, channel)
            if ~exist('binding', 'var') || isempty(binding); binding = UserSequenceSpec.BIND_DURATION; end
            if ~exist('channel', 'var'); channel = ''; end

            idx = obj.variableIndex(name);
            if isempty(idx)
                obj.variables(end+1) = struct('name', name, 'value', value, ...
                    'binding', binding, 'channel', channel);
            else
                obj.variables(idx).value = value;
                obj.variables(idx).binding = binding;
                obj.variables(idx).channel = channel;
            end
        end

        function removeVariable(obj, name)
            idx = obj.variableIndex(name);
            if ~isempty(idx); obj.variables(idx) = []; end
            obj.setSwept(setdiff(obj.sweptNames, {name}, 'stable'));
            if strcmp(obj.xAxisName, name); obj.xAxisName = ''; end
        end

        function renameVariable(obj, oldName, newName)
            idx = obj.variableIndex(oldName);
            if isempty(idx); return; end
            obj.variables(idx).name = newName;
            swept = obj.sweptNames;
            swept(strcmp(swept, oldName)) = {newName};
            obj.sweptNames = swept;
            if strcmp(obj.xAxisName, oldName); obj.xAxisName = newName; end
        end

        function idx = variableIndex(obj, name)
            if isempty(obj.variables); idx = []; return; end
            idx = find(strcmp({obj.variables.name}, name), 1);
        end

        function names = durationVariableNames(obj)
            % Variables an expression is allowed to refer to
            names = {};
            for i = 1 : numel(obj.variables)
                if strcmp(obj.variables(i).binding, UserSequenceSpec.BIND_DURATION)
                    names{end+1} = obj.variables(i).name; %#ok<AGROW>
                end
            end
        end

        %% Sweeping
        function setSwept(obj, names)
            % Choose which variables are swept, keeping any combination
            % columns that survive the change.
            names = UserSequenceSpec.asCellstr(names);
            names = names(cellfun(@(n) ~isempty(obj.variableIndex(n)), names));

            oldNames = obj.sweptNames;
            oldRows = obj.combinations;

            nPoints = size(oldRows, 1);
            newRows = zeros(nPoints, numel(names));
            for c = 1 : numel(names)
                was = find(strcmp(oldNames, names{c}), 1);
                if ~isempty(was) && size(oldRows, 2) >= was
                    newRows(:, c) = oldRows(:, was);
                else
                    % A newly swept variable starts at its own default
                    idx = obj.variableIndex(names{c});
                    newRows(:, c) = obj.variables(idx).value;
                end
            end

            obj.sweptNames = names;
            obj.combinations = newRows;

            if ~isempty(obj.xAxisName) && ~any(strcmp(names, obj.xAxisName))
                obj.xAxisName = '';
            end
        end

        function addCombination(obj, row)
            % Append one measurement point. With no argument, repeats the
            % last row, or the variables' own defaults if there is none.
            if isempty(obj.sweptNames); return; end
            if ~exist('row', 'var') || isempty(row)
                if isempty(obj.combinations)
                    row = cellfun(@(n) obj.variables(obj.variableIndex(n)).value, ...
                        obj.sweptNames);
                else
                    row = obj.combinations(end, :);
                end
            end
            row = reshape(double(row), 1, []);
            if numel(row) ~= numel(obj.sweptNames); return; end
            obj.combinations(end+1, :) = row;
        end

        function fillGrid(obj, ranges)
            % Replace the points with every combination of one range per
            % swept variable. The ranges are independent: 20 values of tau
            % against 3 frequencies is 60 points, and neither list has to
            % match the other's length.
            %
            % The first column varies slowest, so the table reads the way a
            % pair of nested loops would be written.
            if isempty(obj.sweptNames); return; end
            if ~iscell(ranges) || numel(ranges) ~= numel(obj.sweptNames)
                error('UserSequenceSpec:badRanges', ...
                    'Expected one range per swept variable (%d).', numel(obj.sweptNames));
            end

            counts = cellfun(@numel, ranges);
            if any(counts == 0)
                error('UserSequenceSpec:emptyRange', 'Every swept variable needs at least one value.');
            end
            total = prod(counts);

            % How many times each value of a column repeats consecutively:
            % the product of the counts of every column to its right.
            repeatEach = ones(1, numel(counts));
            for c = 1 : numel(counts) - 1
                repeatEach(c) = prod(counts(c+1 : end));
            end

            rows = zeros(total, numel(ranges));
            for c = 1 : numel(ranges)
                values = reshape(double(ranges{c}), [], 1);
                block = repelem(values, repeatEach(c));
                rows(:, c) = repmat(block, total / numel(block), 1);
            end
            obj.combinations = rows;
        end

        function values = columnValues(obj, name)
            % The distinct values a swept variable currently takes, in order
            values = [];
            c = find(strcmp(obj.sweptNames, name), 1);
            if isempty(c) || isempty(obj.combinations); return; end
            values = unique(obj.combinations(:, c)', 'stable');
        end

        function removeCombination(obj, index)
            if index < 1 || index > size(obj.combinations, 1); return; end
            obj.combinations(index, :) = [];
        end

        function n = numberOfParams(obj)
            if isempty(obj.sweptNames) || isempty(obj.combinations)
                n = 1;
            else
                n = size(obj.combinations, 1);
            end
        end

        function values = xAxisValues(obj)
            % What to put on the x axis: the nominated swept variable's
            % column, or the point number when none is nominated.
            n = obj.numberOfParams();
            column = find(strcmp(obj.sweptNames, obj.xAxisName), 1);
            if isempty(column) || isempty(obj.combinations)
                values = 1 : n;
            else
                values = obj.combinations(:, column)';
            end
        end

        function label = xAxisLabel(obj)
            if isempty(obj.xAxisName)
                label = 'Point';
            else
                label = obj.xAxisName;
            end
        end

        %% Resolving one measurement point
        function s = variableStruct(obj, pointIndex)
            % The duration-bound variables as a plain struct, with any swept
            % ones overridden by the given combination row.
            s = struct();
            for i = 1 : numel(obj.variables)
                v = obj.variables(i);
                if strcmp(v.binding, UserSequenceSpec.BIND_DURATION)
                    s.(v.name) = v.value;
                end
            end
            if ~exist('pointIndex', 'var') || isempty(pointIndex); return; end
            if isempty(obj.combinations); return; end

            pointIndex = min(max(1, pointIndex), size(obj.combinations, 1));
            for c = 1 : numel(obj.sweptNames)
                name = obj.sweptNames{c};
                idx = obj.variableIndex(name);
                if isempty(idx); continue; end
                if strcmp(obj.variables(idx).binding, UserSequenceSpec.BIND_DURATION)
                    s.(name) = obj.combinations(pointIndex, c);
                end
            end
        end

        function settings = mwSettings(obj, pointIndex)
            % What to send to the SignalGenerator for this point, as a struct
            % array of (what, value, channel). Covers both swept MW variables
            % and MW-bound variables that are held fixed.
            settings = struct('what', {}, 'value', {}, 'channel', {});

            for i = 1 : numel(obj.variables)
                v = obj.variables(i);
                what = UserSequenceSpec.mwPropertyFor(v.binding);
                if isempty(what); continue; end

                value = v.value;
                if exist('pointIndex', 'var') && ~isempty(pointIndex) && ~isempty(obj.combinations)
                    c = find(strcmp(obj.sweptNames, v.name), 1);
                    if ~isempty(c)
                        row = min(max(1, pointIndex), size(obj.combinations, 1));
                        value = obj.combinations(row, c);
                    end
                end

                settings(end+1) = struct('what', what, 'value', value, ...
                    'channel', v.channel); %#ok<AGROW>
            end
        end

        function idx = detectorPulseIndices(obj)
            % Which pulses are counting windows, in sequence order
            idx = [];
            for i = 1 : numel(obj.pulses)
                if any(strcmp(obj.pulses(i).channels, UserSequenceSpec.DETECTOR_CHANNEL))
                    idx(end+1) = i; %#ok<AGROW>
                end
            end
        end

        function [durations, isOk, message] = resolveDurations(obj, pointIndex)
            % Evaluate every pulse duration at one measurement point
            durations = zeros(1, numel(obj.pulses));
            isOk = true;
            message = '';

            if ~exist('pointIndex', 'var'); pointIndex = 1; end
            vars = obj.variableStruct(pointIndex);

            for i = 1 : numel(obj.pulses)
                [value, ok, why] = SequenceExpression.evaluate(obj.pulses(i).duration, vars);
                if ~ok
                    isOk = false;
                    message = sprintf('Pulse %d ("%s"): %s', i, obj.pulses(i).nickname, why);
                    return
                end
                if value < 0
                    isOk = false;
                    message = sprintf('Pulse %d ("%s") has a negative duration (%g).', ...
                        i, obj.pulses(i).nickname, value);
                    return
                end
                durations(i) = value;
            end
        end

        function S = buildSequence(obj, pointIndex)
            % The Sequence for one measurement point. Touches no hardware.
            if ~exist('pointIndex', 'var'); pointIndex = 1; end

            [durations, isOk, message] = obj.resolveDurations(pointIndex);
            if ~isOk
                error('UserSequenceSpec:badDuration', '%s', message);
            end

            S = Sequence;
            for i = 1 : numel(obj.pulses)
                channels = obj.pulses(i).channels;
                if isempty(channels); channels = ''; end
                S.addEvent(durations(i), channels, obj.pulses(i).nickname);
            end
        end

        function [signalDuration, referenceDuration] = windowDurations(obj, pointIndex)
            % Durations of the chosen signal and reference windows, which
            % processData needs in order to convert counts to kcps
            if ~exist('pointIndex', 'var'); pointIndex = 1; end
            durations = obj.resolveDurations(pointIndex);
            detectors = obj.detectorPulseIndices();
            signalDuration = durations(detectors(obj.signalWindow));
            referenceDuration = durations(detectors(obj.referenceWindow));
        end

        %% Validation
        function [isOk, message] = validate(obj)
            isOk = false;

            if ~SequenceExpression.isValidName(obj.name)
                message = sprintf(['"%s" is not a usable name. Use letters, digits and ', ...
                    'underscores, starting with a letter.'], obj.name);
                return
            end
            if isempty(obj.pulses)
                message = 'The sequence has no pulses.';
                return
            end

            for i = 1 : numel(obj.variables)
                v = obj.variables(i);
                if ~SequenceExpression.isValidName(v.name)
                    message = sprintf('"%s" is not a usable variable name.', v.name);
                    return
                end
                if ~any(strcmp(v.binding, UserSequenceSpec.BINDINGS))
                    message = sprintf('Variable "%s" has an unknown binding "%s".', v.name, v.binding);
                    return
                end
                if ~strcmp(v.binding, UserSequenceSpec.BIND_DURATION) && isempty(v.channel)
                    message = sprintf(['Variable "%s" drives an MW setting, so it needs ', ...
                        'a channel.'], v.name);
                    return
                end
            end

            % Swept variables and combination columns must line up
            for i = 1 : numel(obj.sweptNames)
                if isempty(obj.variableIndex(obj.sweptNames{i}))
                    message = sprintf('The swept variable "%s" is not declared.', obj.sweptNames{i});
                    return
                end
            end
            if ~isempty(obj.sweptNames)
                if isempty(obj.combinations)
                    message = 'Variables are marked as swept but there are no combinations to measure.';
                    return
                end
                if size(obj.combinations, 2) ~= numel(obj.sweptNames)
                    message = sprintf(['The combinations table has %d column(s) but %d ', ...
                        'variable(s) are swept.'], size(obj.combinations, 2), numel(obj.sweptNames));
                    return
                end
                if any(~isfinite(obj.combinations(:)))
                    message = 'The combinations table has a missing or non-finite value.';
                    return
                end
            end

            % Durations must resolve at every point, not just the first: a
            % sequence that only breaks at row 12 is worth catching now.
            for p = 1 : obj.numberOfParams()
                [~, ok, why] = obj.resolveDurations(p);
                if ~ok
                    message = sprintf('At point %d: %s', p, why);
                    return
                end
            end

            detectors = obj.detectorPulseIndices();
            if numel(detectors) < 2
                message = sprintf(['The sequence has %d detection window(s). Two are needed: ', ...
                    'one for signal and one for reference. Add the "%s" channel to a pulse.'], ...
                    numel(detectors), UserSequenceSpec.DETECTOR_CHANNEL);
                return
            end
            if obj.signalWindow < 1 || obj.signalWindow > numel(detectors) || ...
                    obj.referenceWindow < 1 || obj.referenceWindow > numel(detectors)
                message = sprintf('Signal and reference must each be between 1 and %d.', numel(detectors));
                return
            end
            if obj.signalWindow == obj.referenceWindow
                message = 'Signal and reference cannot be the same detection window.';
                return
            end
            if mod(numel(detectors), 2) ~= 0
                % Experiment.processData normalises counts to kcps using a
                % two-element [signal reference] duration pair, which it can
                % only tile across an even number of windows.
                message = sprintf(['The sequence has %d detection windows. An even number ', ...
                    'is required, because the shared count processing works in ', ...
                    'signal/reference pairs.'], numel(detectors));
                return
            end

            isOk = true;
            message = '';
        end
    end

    %% Persistence
    methods
        function s = toStruct(obj)
            s = struct( ...
                'formatVersion',   UserSequenceSpec.FORMAT_VERSION, ...
                'name',            obj.name, ...
                'pulses',          {obj.pulsesAsCell()}, ...
                'variables',       {obj.variablesAsCell()}, ...
                'sweptNames',      {obj.sweptNames}, ...
                'combinations',    obj.combinations, ...
                'xAxisName',       obj.xAxisName, ...
                'signalWindow',    obj.signalWindow, ...
                'referenceWindow', obj.referenceWindow);
        end

        function save(obj, fullPath)
            folder = fileparts(fullPath);
            if ~isempty(folder) && ~PathHelper.isFolderExists(folder)
                mkdir(folder);
            end
            text = jsonencode(obj.toStruct(), 'PrettyPrint', true);
            fid = fopen(fullPath, 'w');
            if fid == -1
                error('UserSequenceSpec:cannotWrite', 'Could not write to "%s".', fullPath);
            end
            closeFile = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fwrite(fid, text, 'char');
        end
    end

    methods (Access = private)
        function c = pulsesAsCell(obj)
            % A cell of structs, so that jsonencode always produces an array
            c = cell(1, numel(obj.pulses));
            for i = 1 : numel(obj.pulses)
                c{i} = struct('nickname', obj.pulses(i).nickname, ...
                    'duration', obj.pulses(i).duration, ...
                    'channels', {obj.pulses(i).channels});
            end
        end

        function c = variablesAsCell(obj)
            c = cell(1, numel(obj.variables));
            for i = 1 : numel(obj.variables)
                c{i} = struct('name', obj.variables(i).name, ...
                    'value', obj.variables(i).value, ...
                    'binding', obj.variables(i).binding, ...
                    'channel', obj.variables(i).channel);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = UserSequenceSpec();
            if isfield(s, 'name');            obj.name = char(s.name); end
            if isfield(s, 'signalWindow');    obj.signalWindow = s.signalWindow; end
            if isfield(s, 'referenceWindow'); obj.referenceWindow = s.referenceWindow; end
            if isfield(s, 'xAxisName');       obj.xAxisName = char(s.xAxisName); end

            if isfield(s, 'pulses')
                items = UserSequenceSpec.asItemList(s.pulses);
                for i = 1 : numel(items)
                    p = items{i};
                    obj.addPulse(char(p.nickname), char(p.duration), p.channels);
                end
            end

            if isfield(s, 'variables')
                items = UserSequenceSpec.asItemList(s.variables);
                for i = 1 : numel(items)
                    v = items{i};
                    binding = UserSequenceSpec.BIND_DURATION;
                    channel = '';
                    if isfield(v, 'binding') && ~isempty(v.binding); binding = char(v.binding); end
                    if isfield(v, 'channel') && ~isempty(v.channel); channel = char(v.channel); end
                    obj.setVariable(char(v.name), v.value, binding, channel);
                end
            end

            if isfield(s, 'sweptNames') && ~isempty(s.sweptNames)
                obj.sweptNames = UserSequenceSpec.asCellstr(s.sweptNames);
                if isfield(s, 'combinations') && ~isempty(s.combinations)
                    rows = s.combinations;
                    if numel(obj.sweptNames) == 1; rows = rows(:); end
                    obj.combinations = rows;
                end
            elseif isfield(s, 'sweepName') && ~isempty(s.sweepName)
                % Format 1: a single swept variable with a vector of values
                obj.sweptNames = {char(s.sweepName)};
                if isfield(s, 'sweepValues')
                    obj.combinations = reshape(double(s.sweepValues), [], 1);
                end
                if isempty(obj.xAxisName); obj.xAxisName = obj.sweptNames{1}; end
            end
        end

        function obj = load(fullPath)
            text = fileread(fullPath);
            obj = UserSequenceSpec.fromStruct(jsondecode(text));
        end

        function what = mwPropertyFor(binding)
            % The SignalGenerator property a binding drives, or '' if none
            switch binding
                case UserSequenceSpec.BIND_FREQUENCY; what = 'frequency';
                case UserSequenceSpec.BIND_AMPLITUDE; what = 'amplitude';
                case UserSequenceSpec.BIND_PHASE;     what = 'phase';
                otherwise;                            what = '';
            end
        end

        function units = unitsFor(binding)
            idx = find(strcmp(UserSequenceSpec.BINDINGS, binding), 1);
            if isempty(idx)
                units = '';
            else
                units = UserSequenceSpec.BINDING_UNITS{idx};
            end
        end

        function folder = defaultFolder()
            % Where sequences live. Configurable per setup through
            % setupInfo.json; otherwise next to the other saved data.
            folder = '';
            try
                json = JsonInfoReader.getJson();
                if isfield(json, 'userSequencesPath') && ~isempty(json.userSequencesPath)
                    folder = json.userSequencesPath;
                end
            catch
                % No setup file, or it could not be read - fall through
            end
            if isempty(folder)
                folder = fullfile(SaveLoad.PATH_DEFAULT_SAVE, 'UserSequences');
            end
            folder = PathHelper.appendBackslashIfNeeded(folder);
        end

        function list = available()
            % Sequence files in the default folder
            list = {};
            folder = UserSequenceSpec.defaultFolder();
            if ~PathHelper.isFolderExists(folder); return; end
            found = dir(fullfile(folder, ['*', UserSequenceSpec.FILE_SUFFIX]));
            list = {found(~[found.isdir]).name};
        end
    end

    methods (Static, Access = private)
        function items = asItemList(value)
            % jsondecode gives a struct array for uniform records and a cell
            % for ragged ones. Normalise to a cell of structs.
            if iscell(value)
                items = value(:)';
            elseif isstruct(value)
                items = arrayfun(@(x) x, value(:)', 'UniformOutput', false);
            else
                items = {};
            end
        end

        function c = asCellstr(value)
            if isempty(value)
                c = {};
            elseif ischar(value)
                c = {value};
            elseif iscell(value)
                c = value(:)';
            elseif isstring(value)
                c = cellstr(value(:)');
            else
                c = {};
            end
        end
    end
end
