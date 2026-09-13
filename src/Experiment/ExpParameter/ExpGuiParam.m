classdef ExpGuiParam
    %EXPGUIPARAM Description of one editable Experiment property, for the GUI
    %   A "spec" describes how a single Experiment property should be shown
    %   and edited in the experiment sidebar: its label, units, value type
    %   and (optionally) the closed set of values it accepts.
    %
    %   Specs are plain structs, so they are cheap to build and trivial to
    %   concatenate. The default list for any Experiment is built by
    %   reflection (see fromReflection). An Experiment which wants a nicer
    %   presentation overrides Experiment.guiParameterSpec and builds the
    %   list by hand, using ExpGuiParam.make.
    %
    %   Example, inside an Experiment subclass:
    %       function spec = guiParameterSpec(obj)
    %           spec = [ ...
    %               ExpGuiParam.make('frequency', 'units', 'MHz', 'group', 'MW'), ...
    %               ExpGuiParam.make('mode', 'options', {'CW', 'pulsed'}) ...
    %               ];
    %       end
    %
    %   See also EXPERIMENT, EXPPARAMETER

    properties (Constant)
        %% Value types
        TYPE_DOUBLE   = 'double'    % scalar number
        TYPE_VECTOR   = 'vector'    % vector of numbers, edited as "start:step:stop" or "[a b c]"
        TYPE_LOGICAL  = 'logical'   % checkbox
        TYPE_STRING   = 'string'    % free text
        TYPE_OPTIONS  = 'options'   % closed set, edited as a popup
        TYPE_READONLY = 'readonly'  % shown, never editable

        % StringHelper.formatNumber defaults to 3 decimal digits, which
        % would silently round a 1 ns tau (1e-3 us) down towards zero.
        DECIMAL_DIGITS = 6

        %% Fields of a spec struct
        FIELDS = {'name', 'label', 'units', 'type', 'options', 'minimum', 'maximum', 'tooltip', 'group'}

        %% Properties never offered for editing
        % Results, internal bookkeeping and machinery that the GUI must not
        % let a user poke at. A few experiment-specific entries are listed
        % too, so that reflection stays useful without every class needing
        % an override.
        BLACKLIST = { ...
            ... % Experiment results and run state
            'signal', 'sterr', 'currIter', 'currParamIter', 'averagesTimeStamp', ...
            'summaryData', 'voltageHistogram', 'autosaveReason', ...
            ... % ExpParameter objects - these describe axes and results, not knobs
            'mCurrentXAxisParam', 'mCurrentYAxisParam', 'topParam', 'rightParam', ...
            'signalParam', 'signalParam2', ...
            ... % Machinery which is set up by prepare(), not by a user
            'sequencesList', 'frequencyInternal', 'IQ', 'userWaveform', ...
            'envelope', 'create_triggers', 'detectionPeriodsPerRepeat', ...
            'runsPerPerform', 'restartAverageFlag', ...
            ... % Per-experiment internals
            'normSig', 'normSterr', 'freqMirrored', 'isRunningContinuously' ...
            }

        %% Properties which are shown, but never editable
        READONLY_LIST = {'name', 'category'}

        %% Sensible grouping for the properties defined on Experiment itself
        % Anything not listed here lands in the 'Experiment' group, which is
        % what you want for subclass properties.
        GROUP_OF_BASE_PROPERTY = { ...
            'averages',                     'Run'
            'repeats',                      'Run'
            'shouldAutosave',               'Run'
            'isTracking',                   'Tracking'
            'trackThreshhold',              'Tracking'
            'TrackWithIR',                  'Tracking'
            'detectionDuration',            'Detection'
            'referenceDetectionDuration',   'Detection'
            'laserInitializationDuration',  'Detection'
            'countWithLifeTime',            'Detection'
            'checkGlitchInData',            'Detection'
            'balancedMeas',                 'Detection'
            'inputConfig',                  'Detection'
            'GIMeas',                       'Photodiode'
            'acquisitionDuration',          'Photodiode'
            'GIresetDuration',              'Photodiode'
            'stabilizationDuration',        'Photodiode'
            'recordVoltageSpan',            'Photodiode'
            'voltageOffset',                'Photodiode'
            'digitizerFullDataAcquisition', 'Photodiode'
            'fixDelays',                    'Sequence'
            'lastDelay',                    'Sequence'
            'smallDelay',                   'Sequence'
            'MWChannel',                    'MW'
            'WindFreakChannels',            'MW'
            'phase',                        'MW'
            'useAWG',                       'MW'
            'baseband',                     'MW'
            'appendBlank',                  'MW'
            }

        %% Closed sets of values known for base-class properties
        OPTIONS_OF_BASE_PROPERTY = { ...
            'inputConfig', {'auto', 'norm', 'diff'}
            }
    end

    methods (Static)
        function spec = make(name, varargin)
            % SPEC = MAKE(NAME, ...) builds one parameter spec.
            %   Optional name/value pairs: 'label', 'units', 'type',
            %   'options', 'minimum', 'maximum', 'tooltip', 'group'.
            %   Anything not supplied gets a sensible default: 'label'
            %   defaults to a prettified NAME, and an empty 'type' means
            %   "infer it from the live value".

            if mod(length(varargin), 2) ~= 0
                EventStation.anonymousError('ExpGuiParam.make expects name/value pairs after the parameter name!')
            end

            spec = struct( ...
                'name',     name, ...
                'label',    ExpGuiParam.prettify(name), ...
                'units',    '', ...
                'type',     '', ...
                'options',  {{}}, ...
                'minimum',  -inf, ...
                'maximum',  inf, ...
                'tooltip',  '', ...
                'group',    'General');

            for i = 1 : 2 : length(varargin)
                field = varargin{i};
                if ~any(strcmp(field, ExpGuiParam.FIELDS))
                    EventStation.anonymousError('"%s" is not a valid field of a parameter spec!', field)
                end
                spec.(field) = varargin{i+1};
            end

            % An explicit set of options implies the type
            if ~isempty(spec.options) && isempty(spec.type)
                spec.type = ExpGuiParam.TYPE_OPTIONS;
            end
        end

        function specs = fromReflection(exp)
            % SPECS = FROMREFLECTION(EXP) builds the default parameter list
            % for an Experiment, by looking at its public properties.
            %
            % Constant, hidden, private and blacklisted properties are
            % skipped. The type of each remaining property is inferred from
            % its current value, so a property which happens to be empty is
            % offered as free text. The Experiment's own setter remains the
            % authority on what is actually a valid value.

            specs = [];
            if ~isa(exp, 'Experiment'); return; end

            propertyNames = exp.getAllNonConstProperties();
            specList = {};

            for i = 1 : length(propertyNames)
                name = propertyNames{i};
                if any(strcmp(name, ExpGuiParam.BLACKLIST)); continue; end

                % Skip anything we cannot read or cannot render
                try
                    value = exp.(name);
                catch
                    continue
                end
                if isa(value, 'ExpParameter'); continue; end
                if isobject(value); continue; end

                if any(strcmp(name, ExpGuiParam.READONLY_LIST))
                    type = ExpGuiParam.TYPE_READONLY;
                else
                    type = ExpGuiParam.inferType(value);
                end

                specList{end+1} = ExpGuiParam.make(name, ...
                    'type',    type, ...
                    'group',   ExpGuiParam.groupOf(name), ...
                    'options', ExpGuiParam.optionsOf(name), ...
                    'tooltip', ExpGuiParam.helpOf(exp, name)); %#ok<AGROW>
            end

            if ~isempty(specList)
                specs = [specList{:}];
            end
        end

        function type = inferType(value)
            % Infer how a value should be edited, from what it currently is
            if islogical(value)
                type = ExpGuiParam.TYPE_LOGICAL;
            elseif ischar(value)
                type = ExpGuiParam.TYPE_STRING;
            elseif isnumeric(value) && isscalar(value)
                type = ExpGuiParam.TYPE_DOUBLE;
            elseif isnumeric(value)
                % Covers empty numerics too: an empty vector is still a
                % vector, and the user needs to be able to fill it in.
                type = ExpGuiParam.TYPE_VECTOR;
            elseif iscell(value)
                % Cell arrays of char (e.g. MWChannel) are edited as text
                type = ExpGuiParam.TYPE_STRING;
            else
                type = ExpGuiParam.TYPE_READONLY;
            end
        end

        function group = groupOf(name)
            % Which section of the parameter table this property belongs to
            table = ExpGuiParam.GROUP_OF_BASE_PROPERTY;
            idx = strcmp(name, table(:, 1));
            if any(idx)
                group = table{idx, 2};
            else
                group = 'Experiment';
            end
        end

        function options = optionsOf(name)
            % The closed set of values for a property, or {} if it is free
            table = ExpGuiParam.OPTIONS_OF_BASE_PROPERTY;
            idx = strcmp(name, table(:, 1));
            if any(idx)
                options = table{idx, 2};
            else
                options = {};
            end
        end

        function str = helpOf(exp, name)
            % Best-effort tooltip: the comment the author wrote next to the
            % property declaration. Returns '' when there is nothing to say.
            str = '';
            try
                mc = metaclass(exp);
                idx = strcmp({mc.PropertyList.Name}, name);
                if any(idx)
                    str = mc.PropertyList(idx).Description;
                end
            catch
                % Tooltips are a nicety - never let one break the GUI
            end
        end

        function label = prettify(name)
            % 'referenceDetectionDuration' -> 'Reference Detection Duration'
            label = regexprep(name, '([a-z0-9])([A-Z])', '$1 $2');
            label = [upper(label(1)), label(2:end)];
        end
    end

    %% Converting between values and the strings shown in the table
    methods (Static)
        function str = valueToString(value)
            % Render a property value as a single line of text
            if ischar(value)
                str = value;
            elseif islogical(value) && isscalar(value)
                str = BooleanHelper.boolToString(value);
            elseif isempty(value)
                str = '';
            elseif isnumeric(value) && isscalar(value)
                str = StringHelper.formatNumber(value, ExpGuiParam.DECIMAL_DIGITS);
            elseif isnumeric(value)
                str = ExpGuiParam.vectorToString(value);
            elseif iscell(value)
                parts = cellfun(@ExpGuiParam.valueToString, value, 'UniformOutput', false);
                str = strjoin(parts, ', ');
            else
                str = sprintf('<%s>', class(value));
            end
        end

        function str = vectorToString(vec)
            % Prefer the compact colon form, when the vector is regular.
            % A 100-point frequency sweep is unreadable written out in full,
            % and unusable as something to edit.
            vec = vec(:).';
            if length(vec) > 2
                steps = diff(vec);
                if all(abs(steps - steps(1)) <= 1e-12 * max(abs(vec)))
                    str = sprintf('%s : %s : %s', ...
                        StringHelper.formatNumber(vec(1), ExpGuiParam.DECIMAL_DIGITS), ...
                        StringHelper.formatNumber(steps(1), ExpGuiParam.DECIMAL_DIGITS), ...
                        StringHelper.formatNumber(vec(end), ExpGuiParam.DECIMAL_DIGITS));
                    return
                end
            end
            parts = arrayfun(@(x) StringHelper.formatNumber(x, ExpGuiParam.DECIMAL_DIGITS), vec, 'UniformOutput', false);
            str = sprintf('[%s]', strjoin(parts, ' '));
        end

        function [value, isOk] = stringToValue(str, type)
            % Parse what the user typed, according to the expected type.
            % Never uses eval: the vector forms are parsed explicitly.
            isOk = true;
            str = strtrim(str);

            switch type
                case {ExpGuiParam.TYPE_STRING, ExpGuiParam.TYPE_OPTIONS}
                    value = str;

                case ExpGuiParam.TYPE_LOGICAL
                    value = [];
                    switch lower(str)
                        case {'1', 'true', 'yes', 'on'};    value = true;
                        case {'0', 'false', 'no', 'off'};   value = false;
                        otherwise;                          isOk = false;
                    end

                case ExpGuiParam.TYPE_DOUBLE
                    if isempty(str)
                        value = [];
                    else
                        value = str2double(str);
                        if isnan(value) && ~strcmpi(str, 'nan')
                            isOk = false;
                        end
                    end

                case ExpGuiParam.TYPE_VECTOR
                    [value, isOk] = ExpGuiParam.parseVector(str);

                otherwise
                    value = [];
                    isOk = false;
            end
        end

        function [vec, isOk] = parseVector(str)
            % Accepts '', '[1 2 3]', '1, 2, 3', '1 : 0.5 : 10'
            isOk = true;
            vec = [];

            str = strtrim(strrep(strrep(str, '[', ''), ']', ''));
            if isempty(str); return; end

            if any(str == ':')
                parts = strtrim(strsplit(str, ':'));
                numbers = str2double(parts);
                if any(isnan(numbers)); isOk = false; return; end
                switch length(numbers)
                    case 2;     vec = numbers(1) : numbers(2);
                    case 3;     vec = numbers(1) : numbers(2) : numbers(3);
                    otherwise;  isOk = false; return
                end
            else
                parts = strtrim(strsplit(str, {',', ' ', ';'}));
                parts = parts(~cellfun(@isempty, parts));
                numbers = str2double(parts);
                if any(isnan(numbers)); isOk = false; return; end
                vec = numbers;
            end
        end
    end
end
