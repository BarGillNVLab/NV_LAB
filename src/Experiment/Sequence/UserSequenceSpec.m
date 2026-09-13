classdef UserSequenceSpec < handle
    %USERSEQUENCESPEC A pulse sequence a user built in the GUI
    %   Holds everything needed to run a free-form sequence: the pulses,
    %   the named variables their durations are written in terms of, which
    %   variable is swept, and which detection windows are signal and
    %   reference.
    %
    %   Durations are expressions over the declared variables ('tau',
    %   '2*tau', 'piTime/2'), evaluated by SequenceExpression - never eval.
    %   One variable is nominated as the sweep; the sequence is rebuilt for
    %   each of its values, and those values are the x axis.
    %
    %   A spec can be saved as JSON, reloaded, and exported as a real
    %   Exp*.m class.
    %
    %   See also SEQUENCEEXPRESSION, EXPUSERSEQUENCE

    properties (Constant)
        % The channel that marks a counting window. Matches the convention
        % used throughout the existing experiments.
        DETECTOR_CHANNEL = 'detector'

        FILE_SUFFIX = '.seq.json'
        FORMAT_VERSION = 1
    end

    properties
        name = 'MySequence'     % char. Used for the file and the generated class

        % struct array: nickname (char), duration (char expression), channels (cellstr)
        pulses = struct('nickname', {}, 'duration', {}, 'channels', {})

        % struct array: name (char), value (double scalar)
        variables = struct('name', {}, 'value', {})

        sweepName = ''          % char. Which variable is swept; '' for none
        sweepValues = []        % double vector. The x axis

        signalWindow = 1        % which detection window is the signal
        referenceWindow = 2     % which detection window is the reference
    end

    methods
        function obj = UserSequenceSpec()
            obj@handle;
        end

        %% Editing
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

        function setVariable(obj, name, value)
            idx = find(strcmp({obj.variables.name}, name), 1);
            if isempty(idx)
                obj.variables(end+1) = struct('name', name, 'value', value);
            else
                obj.variables(idx).value = value;
            end
        end

        function removeVariable(obj, name)
            idx = find(strcmp({obj.variables.name}, name), 1);
            if ~isempty(idx); obj.variables(idx) = []; end
            if strcmp(obj.sweepName, name)
                obj.sweepName = '';
                obj.sweepValues = [];
            end
        end

        %% Queries
        function s = variableStruct(obj, sweepValue)
            % The variables as a plain struct, with the swept one overridden
            s = struct();
            for i = 1 : numel(obj.variables)
                s.(obj.variables(i).name) = obj.variables(i).value;
            end
            if exist('sweepValue', 'var') && ~isempty(obj.sweepName) && ~isempty(sweepValue)
                s.(obj.sweepName) = sweepValue;
            end
        end

        function n = numberOfParams(obj)
            if isempty(obj.sweepName) || isempty(obj.sweepValues)
                n = 1;
            else
                n = numel(obj.sweepValues);
            end
        end

        function value = sweepValueAt(obj, index)
            if isempty(obj.sweepName) || isempty(obj.sweepValues)
                value = [];
            else
                value = obj.sweepValues(min(max(1, index), numel(obj.sweepValues)));
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

        function [durations, isOk, message] = resolveDurations(obj, sweepValue)
            % Evaluate every pulse duration for one value of the sweep
            durations = zeros(1, numel(obj.pulses));
            isOk = true;
            message = '';

            vars = obj.variableStruct(sweepValue);
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

        function [isOk, message] = validate(obj)
            % Everything that must be true before this can be run
            isOk = false;

            if ~SequenceExpression.isValidName(obj.name)
                message = sprintf('"%s" is not a usable name. Use letters, digits and underscores, starting with a letter.', obj.name);
                return
            end
            if isempty(obj.pulses)
                message = 'The sequence has no pulses.';
                return
            end

            for i = 1 : numel(obj.variables)
                if ~SequenceExpression.isValidName(obj.variables(i).name)
                    message = sprintf('"%s" is not a usable variable name.', obj.variables(i).name);
                    return
                end
            end

            if ~isempty(obj.sweepName)
                if ~any(strcmp({obj.variables.name}, obj.sweepName))
                    message = sprintf('The swept variable "%s" is not declared.', obj.sweepName);
                    return
                end
                if isempty(obj.sweepValues)
                    message = sprintf('"%s" is swept but has no values.', obj.sweepName);
                    return
                end
            end

            % Durations must resolve at both ends of the sweep, so that a
            % sequence that only breaks at the last point is caught now
            [~, ok, why] = obj.resolveDurations(obj.sweepValueAt(1));
            if ~ok; message = why; return; end
            [~, ok, why] = obj.resolveDurations(obj.sweepValueAt(obj.numberOfParams()));
            if ~ok; message = why; return; end

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
                message = sprintf(['The sequence has %d detection windows. ', ...
                    'An even number is required, because the shared count ', ...
                    'processing works in signal/reference pairs.'], numel(detectors));
                return
            end

            isOk = true;
            message = '';
        end

        %% Building
        function S = buildSequence(obj, sweepValue)
            % The Sequence for one value of the swept variable.
            % Touches no hardware.
            if ~exist('sweepValue', 'var'); sweepValue = obj.sweepValueAt(1); end

            [durations, isOk, message] = obj.resolveDurations(sweepValue);
            if ~isOk
                error('UserSequenceSpec:badDuration', '%s', message);
            end

            S = Sequence;
            for i = 1 : numel(obj.pulses)
                channels = obj.pulses(i).channels;
                if isempty(channels)
                    channels = '';
                end
                S.addEvent(durations(i), channels, obj.pulses(i).nickname);
            end
        end

        function [signalDuration, referenceDuration] = windowDurations(obj, sweepValue)
            % Durations of the chosen signal and reference windows, which
            % processData needs in order to convert counts to kcps
            if ~exist('sweepValue', 'var'); sweepValue = obj.sweepValueAt(1); end
            durations = obj.resolveDurations(sweepValue);
            detectors = obj.detectorPulseIndices();
            signalDuration = durations(detectors(obj.signalWindow));
            referenceDuration = durations(detectors(obj.referenceWindow));
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
                'sweepName',       obj.sweepName, ...
                'sweepValues',     obj.sweepValues, ...
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
            closeFile = onCleanup(@() fclose(fid));
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
                c{i} = struct('name', obj.variables(i).name, 'value', obj.variables(i).value);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = UserSequenceSpec();
            if isfield(s, 'name');            obj.name = char(s.name); end
            if isfield(s, 'sweepName');       obj.sweepName = char(s.sweepName); end
            if isfield(s, 'sweepValues');     obj.sweepValues = s.sweepValues(:)'; end
            if isfield(s, 'signalWindow');    obj.signalWindow = s.signalWindow; end
            if isfield(s, 'referenceWindow'); obj.referenceWindow = s.referenceWindow; end

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
                    obj.setVariable(char(v.name), v.value);
                end
            end
        end

        function obj = load(fullPath)
            text = fileread(fullPath);
            obj = UserSequenceSpec.fromStruct(jsondecode(text));
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
