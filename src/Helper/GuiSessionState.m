classdef GuiSessionState
    %GUISESSIONSTATE Remembers what the experiment column was doing
    %   Saved when the window closes, restored when it opens: which mode was
    %   showing, which experiment was selected, the parameter values that had
    %   been edited, and the sequence that was being built.
    %
    %   Deliberately NOT restored silently:
    %
    %     - The experiment is pre-selected in the list, not constructed.
    %       Constructing an Experiment runs Setup.init and resets that
    %       experiment's parameters, which is too much to do to someone
    %       during startup.
    %     - Its remembered parameters are applied when that experiment is
    %       loaded, and the panel says so. Quietly restoring last week's
    %       frequency vector and letting somebody press Start is exactly the
    %       kind of surprise a lab does not need.
    %
    %   The sequence being built is restored outright - nothing can act on
    %   it without the user pressing a button.
    %
    %   Delete the file to start fresh; a missing or unreadable file is not
    %   an error.
    %
    %   See also VIEWEXPERIMENTCOLUMN, USERSEQUENCESPEC

    properties (Constant)
        FILE_NAME = 'guiSession.json'
    end

    methods (Static)
        function fullPath = filePath()
            fullPath = fullfile(UserSequenceSpec.defaultFolder(), GuiSessionState.FILE_NAME);
        end

        function save(state)
            % STATE is a struct; anything jsonencode can handle
            try
                folder = fileparts(GuiSessionState.filePath());
                if ~PathHelper.isFolderExists(folder); mkdir(folder); end

                fid = fopen(GuiSessionState.filePath(), 'w');
                if fid == -1; return; end
                closeFile = onCleanup(@() fclose(fid)); %#ok<NASGU>
                fwrite(fid, jsonencode(state, 'PrettyPrint', true), 'char');
            catch
                % Losing the session state is never worth an error on exit
            end
        end

        function state = load()
            % Returns an empty struct when there is nothing usable to read
            state = struct();
            try
                fullPath = GuiSessionState.filePath();
                if ~PathHelper.isFileExists(fullPath); return; end
                state = jsondecode(fileread(fullPath));
            catch
                state = struct();
            end
        end

        function params = captureParameters(exp)
            % The editable parameter values of an experiment, as a struct.
            % Only the plainly representable ones - a value that cannot
            % survive JSON is better dropped than restored wrongly.
            params = struct();
            if isempty(exp) || ~isvalid(exp) || ~isa(exp, 'Experiment'); return; end

            try
                specs = exp.guiParameterSpec();
            catch
                return
            end

            for i = 1 : numel(specs)
                name = specs(i).name;
                try
                    value = exp.(name);
                catch
                    continue
                end
                if ischar(value) || islogical(value) || (isnumeric(value) && numel(value) <= 10000)
                    params.(name) = value;
                end
            end
        end

        function [applied, skipped] = applyParameters(exp, params)
            % Push remembered values back onto an experiment. Each is set
            % individually, so one rejected value does not stop the rest.
            applied = {};
            skipped = {};
            if isempty(exp) || ~isvalid(exp) || ~isstruct(params); return; end

            names = fieldnames(params);
            for i = 1 : numel(names)
                name = names{i};
                if ~isprop(exp, name)
                    skipped{end+1} = name; %#ok<AGROW>
                    continue
                end
                try
                    exp.(name) = params.(name);
                    applied{end+1} = name; %#ok<AGROW>
                catch
                    skipped{end+1} = name; %#ok<AGROW>
                end
            end
        end
    end
end
