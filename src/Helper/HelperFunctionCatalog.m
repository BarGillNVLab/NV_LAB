classdef HelperFunctionCatalog
    %HELPERFUNCTIONCATALOG Discovers and runs the functions in helperFunctions\
    %   Finds every .m file under the helperFunctions tree, works out its
    %   signature, and knows how to turn the strings a user typed in the GUI
    %   into real arguments.
    %
    %   Nothing here uses eval on user input. A typed value is either a
    %   number, a vector, a logical, a quoted string, the current Experiment,
    %   or the name of a variable in the base workspace - and nothing else.
    %
    %   See also VIEWHELPERFUNCTIONS

    properties (Constant)
        % Placeholder meaning "pass the Experiment currently selected in the GUI"
        TOKEN_EXPERIMENT = '<current experiment>'

        % Argument names we can fill in on the user's behalf. Matched
        % case-insensitively against the declared argument name.
        % The experiment token is repeated literally rather than referring to
        % TOKEN_EXPERIMENT: MATLAB does not allow a property default to
        % reference another property of the same class.
        DEFAULT_BY_ARGUMENT = { ...
            'exp',          '<current experiment>'
            'experiment',   '<current experiment>'
            'toplot',       'true'
            'tosave',       'false'
            'plotfit',      'true'
            ... % An empty char, not a blank cell: a blank here would leave a
            ... % gap before toPlot, and MATLAB cannot skip an argument.
            ... % It is only read when toSave is true, which the GUI checks for.
            'path',         ''''''
            'save_path',    ''''''
            }
    end

    methods (Static)
        function folder = root()
            folder = PathHelper.getSourceSubfolder('helperFunctions');
        end

        function entries = discover()
            % ENTRIES = DISCOVER() returns a struct array describing every
            % .m file under helperFunctions\, sorted by name.
            %
            % Fields: name, file, group, isScript, inputs, outputs, summary

            entries = HelperFunctionCatalog.emptyEntry();
            root = HelperFunctionCatalog.root();
            if ~PathHelper.isFolderExists(root)
                EventStation.anonymousWarning('Could not find the helperFunctions folder at "%s".', root);
                return
            end

            found = dir(fullfile(root, '**', '*.m'));
            list = cell(1, numel(found));
            n = 0;
            for i = 1 : numel(found)
                if found(i).isdir; continue; end
                fullPath = fullfile(found(i).folder, found(i).name);
                try
                    entry = HelperFunctionCatalog.describe(fullPath, root);
                catch
                    continue    % An unreadable file should not break the list
                end
                n = n + 1;
                list{n} = entry;
            end
            list = list(1:n);
            if isempty(list); return; end

            entries = [list{:}];
            [~, order] = sort(lower({entries.name}));
            entries = entries(order);
        end

        function entry = describe(fullPath, root)
            % Parse one .m file: its signature, and its H1 summary line
            if ~exist('root', 'var'); root = HelperFunctionCatalog.root(); end

            [folder, name] = fileparts(fullPath);
            entry = struct('name', name, 'file', fullPath, 'group', '', ...
                'isScript', false, 'inputs', {{}}, 'outputs', {{}}, 'summary', '');

            % Folder relative to the helperFunctions root, for display.
            % root() ends with a separator but fileparts() never does, so the
            % two must be normalised before they can be compared.
            rootNoSlash = regexprep(root, '[\\/]+$', '');
            group = strrep(folder, rootNoSlash, '');
            group = regexprep(group, '^[\\/]+', '');
            if isempty(group); group = '.'; end
            entry.group = group;

            [declaration, summary] = HelperFunctionCatalog.readDeclaration(fullPath);
            entry.summary = summary;

            if isempty(declaration)
                % No function line - this is a script
                entry.isScript = true;
                return
            end

            [entry.outputs, entry.inputs] = HelperFunctionCatalog.parseDeclaration(declaration);
        end

        function [declaration, summary] = readDeclaration(fullPath)
            % Returns the (joined) function line, and the first comment line
            % that follows it. Either may be ''.
            declaration = '';
            summary = '';

            text = fileread(fullPath);
            lines = regexp(text, '\r\n|\n|\r', 'split');

            i = 1;
            while i <= numel(lines)
                stripped = strtrim(lines{i});
                if isempty(stripped) || stripped(1) == '%'
                    if isempty(summary) && ~isempty(stripped) && stripped(1) == '%'
                        summary = HelperFunctionCatalog.stripComment(stripped);  % script's H1
                    end
                    i = i + 1;
                    continue
                end
                if strncmp(stripped, 'function', 8)
                    % Join continuation lines
                    declaration = stripped;
                    while endsWith(strtrim(declaration), '...') && i < numel(lines)
                        i = i + 1;
                        declaration = [strtrim(declaration(1:end-3)), ' ', strtrim(lines{i})]; %#ok<AGROW>
                    end
                    summary = '';   % prefer the comment that follows the function line
                    for j = i+1 : numel(lines)
                        nextLine = strtrim(lines{j});
                        if isempty(nextLine); continue; end
                        if nextLine(1) == '%'
                            summary = HelperFunctionCatalog.stripComment(nextLine);
                        end
                        break
                    end
                end
                return  % first non-comment line decides it, either way
            end
        end

        function [outputs, inputs] = parseDeclaration(declaration)
            % 'function [a, b] = name(x, y)' -> outputs {a,b}, inputs {x,y}
            outputs = {};
            inputs = {};

            body = strtrim(regexprep(declaration, '^function\s*', ''));

            % Outputs, if there is an '=' before the argument list
            eqIdx = strfind(body, '=');
            parenIdx = strfind(body, '(');
            if ~isempty(eqIdx) && (isempty(parenIdx) || eqIdx(1) < parenIdx(1))
                lhs = strtrim(body(1 : eqIdx(1)-1));
                lhs = strrep(strrep(lhs, '[', ''), ']', '');
                outputs = HelperFunctionCatalog.splitNames(lhs);
                body = strtrim(body(eqIdx(1)+1 : end));
            end

            % Inputs
            openIdx = strfind(body, '(');
            closeIdx = strfind(body, ')');
            if ~isempty(openIdx) && ~isempty(closeIdx) && closeIdx(end) > openIdx(1)
                argText = body(openIdx(1)+1 : closeIdx(end)-1);
                inputs = HelperFunctionCatalog.splitNames(argText);
            end
        end

        function str = stripComment(line)
            % '%% Alignment' -> 'Alignment'
            str = strtrim(regexprep(line, '^%+', ''));
        end

        function names = splitNames(text)
            parts = strsplit(text, ',');
            parts = cellfun(@strtrim, parts, 'UniformOutput', false);
            names = parts(~cellfun(@isempty, parts));
        end

        function value = defaultFor(argumentName)
            % The string the GUI should pre-fill for a given argument name
            table = HelperFunctionCatalog.DEFAULT_BY_ARGUMENT;
            idx = strcmpi(argumentName, table(:, 1));
            if any(idx)
                value = table{idx, 2};
            else
                value = '';
            end
        end
    end

    %% Turning typed text into arguments
    methods (Static)
        function [args, isOk, message] = resolveArguments(rawValues, exp)
            % ARGS = RESOLVEARGUMENTS(RAWVALUES, EXP) converts the cell of
            % strings typed in the GUI into a cell of MATLAB values.
            %
            % Trailing blanks are dropped, so a function keeps its own
            % defaults for arguments the user did not fill in. A blank in
            % the middle is an error - MATLAB has no way to skip an
            % argument and still supply a later one.
            args = {};
            isOk = true;
            message = '';

            % Find the last argument the user actually supplied
            filled = ~cellfun(@(s) isempty(strtrim(s)), rawValues);
            last = find(filled, 1, 'last');
            if isempty(last); return; end

            if any(~filled(1:last))
                gaps = find(~filled(1:last));
                isOk = false;
                message = sprintf(['Argument %d is empty but argument %d is not. ', ...
                    'MATLAB cannot skip an argument - fill it in, or clear the later ones.'], ...
                    gaps(1), last);
                return
            end

            args = cell(1, last);
            for i = 1 : last
                [args{i}, ok, why] = HelperFunctionCatalog.parseValue(rawValues{i}, exp);
                if ~ok
                    isOk = false;
                    message = sprintf('Argument %d: %s', i, why);
                    return
                end
            end
        end

        function [value, isOk, message] = parseValue(str, exp)
            % Interpret one typed argument. Never uses eval.
            value = [];
            isOk = true;
            message = '';
            str = strtrim(str);

            % 1. The current experiment
            if strcmp(str, HelperFunctionCatalog.TOKEN_EXPERIMENT)
                if isempty(exp) || ~isvalid(exp)
                    isOk = false;
                    message = 'no experiment is loaded, so there is nothing to pass.';
                    return
                end
                value = exp;
                return
            end

            % 2. A quoted string
            if length(str) >= 2 && str(1) == '''' && str(end) == ''''
                value = strrep(str(2:end-1), '''''', '''');
                return
            end

            % 3. true / false
            switch lower(str)
                case {'true'};  value = true;  return
                case {'false'}; value = false; return
            end

            % 4. A number or a vector
            [vec, parsedOk] = ExpGuiParam.parseVector(str);
            if parsedOk && ~isempty(vec)
                value = vec;
                return
            end

            % 5. A variable in the base workspace
            if isvarname(str)
                if evalin('base', sprintf('exist(''%s'', ''var'')', str))
                    value = evalin('base', str);
                    return
                end
                isOk = false;
                message = sprintf('''%s'' is not a number, and there is no variable by that name in the workspace.', str);
                return
            end

            isOk = false;
            message = sprintf(['could not make sense of "%s". Use a number, a vector ', ...
                '(1:2:9 or [1 2 3]), true/false, a ''quoted string'', or the name of a ', ...
                'workspace variable.'], str);
        end
    end

    %% Running
    methods (Static)
        function ensureOnPath(entry)
            % A helper in a subfolder is only callable once its folder is on
            % the path. The helperFunctions tree is not added by Setup.init.
            folder = fileparts(entry.file);
            onPath = strsplit(path, pathsep);
            if ~any(strcmpi(folder, onPath))
                addpath(folder);
            end
        end

        function [outputs, names, errorMessage] = run(entry, args)
            % Calls the helper. Returns its outputs, their declared names,
            % and '' or the error message.
            outputs = {};
            names = {};
            errorMessage = '';

            HelperFunctionCatalog.ensureOnPath(entry);

            if entry.isScript
                try
                    evalin('base', entry.name);
                catch err
                    errorMessage = err.message;
                end
                return
            end

            % Ask only for outputs the function actually declares
            nOut = numel(entry.outputs);
            try
                declared = nargout(entry.name);
                if declared >= 0
                    nOut = min(nOut, declared);
                end
            catch
                % Introspection failed; trust the parsed declaration
            end

            try
                if nOut <= 0
                    fh = str2func(entry.name);
                    fh(args{:});
                else
                    outputs = cell(1, nOut);
                    fh = str2func(entry.name);
                    [outputs{1:nOut}] = fh(args{:});
                    names = entry.outputs(1:nOut);
                end
            catch err
                outputs = {};
                names = {};
                errorMessage = err.message;
            end
        end

        function str = summarize(names, values)
            % One line per output, values rendered compactly
            if isempty(names)
                str = 'Done. (no outputs)';
                return
            end
            parts = cell(1, numel(names));
            for i = 1 : numel(names)
                parts{i} = sprintf('%s = %s', names{i}, ...
                    HelperFunctionCatalog.describeValue(values{i}));
            end
            str = strjoin(parts, sprintf('\n'));
        end

        function str = describeValue(value)
            % A short, readable rendering of any output value
            if ischar(value)
                str = value;
            elseif islogical(value) && isscalar(value)
                str = BooleanHelper.boolToString(value);
            elseif isnumeric(value) && isscalar(value)
                str = StringHelper.formatNumber(value, ExpGuiParam.DECIMAL_DIGITS);
            elseif isnumeric(value) && numel(value) <= 8
                str = ExpGuiParam.valueToString(value);
            elseif isnumeric(value)
                str = sprintf('<%s %s>  [%s ... %s]', ...
                    HelperFunctionCatalog.sizeString(value), class(value), ...
                    StringHelper.formatNumber(value(1), 3), ...
                    StringHelper.formatNumber(value(end), 3));
            elseif isstruct(value)
                str = sprintf('<struct with fields: %s>', strjoin(fieldnames(value)', ', '));
            else
                str = sprintf('<%s %s>', HelperFunctionCatalog.sizeString(value), class(value));
            end
        end

        function str = sizeString(value)
            str = strjoin(arrayfun(@(d) sprintf('%d', d), size(value), 'UniformOutput', false), 'x');
        end
    end

    methods (Static, Access = private)
        function entry = emptyEntry()
            entry = struct('name', {}, 'file', {}, 'group', {}, ...
                'isScript', {}, 'inputs', {}, 'outputs', {}, 'summary', {});
        end
    end
end
