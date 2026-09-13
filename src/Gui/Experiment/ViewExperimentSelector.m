classdef ViewExperimentSelector < ViewVBox
    %VIEWEXPERIMENTSELECTOR Choose which Experiment to work with
    %   A filter-as-you-type list of every Experiment found on disk, with
    %   the ones used day to day pinned at the top.
    %
    %   Selecting a row does nothing but highlight it. The Experiment object
    %   is only constructed when the user presses Load, because constructing
    %   one is not free: it runs Setup.init, replaces any existing Experiment
    %   of the same name and resets that Experiment's parameters.

    properties (Constant)
        % Pinned to the top of the list. These are Experiment NAME values,
        % not class names. Anything here which does not exist on this setup
        % is quietly skipped.
        FAVOURITES = {'ESR', 'Rabi', 'Echo', 'T1', 'Ramsey', 'DEER'}

        PREFIX_FAVOURITE = '* '     % marks a pinned entry in the list
    end

    properties (Access = private)
        edtFilter
        lbxExperiments
        btnLoad

        allNames = {}       % every Experiment name found, sorted, favourites first
        shownNames = {}     % those currently passing the filter

        chosenCallback      % function handle, called with the chosen name
    end

    methods
        function obj = ViewExperimentSelector(parent, controller, chosenCallback)
            padding = 5;
            spacing = 5;
            obj@ViewVBox(parent, controller, padding, spacing);
            obj.chosenCallback = chosenCallback;

            obj.edtFilter = uicontrol(obj.PROP_EDIT_SMALL{:}, ...
                'Parent', obj.component, ...
                'String', '', ...
                'TooltipString', 'Type to filter the list', ...
                'Callback', @obj.filterCallback);
            % Filter as the user types, rather than only on Enter
            try
                addlistener(obj.edtFilter, 'String', 'PostSet', @(~,~) obj.filterCallback());
            catch
                % Not every release lets us listen on String. Enter still works.
            end

            obj.lbxExperiments = uicontrol(...
                'Parent', obj.component, ...
                'Style', 'listbox', ...
                'FontSize', 9, ...
                'String', {}, ...
                'Callback', @obj.listboxCallback);

            obj.btnLoad = uicontrol(obj.PROP_BUTTON{:}, ...
                'Parent', obj.component, ...
                'String', 'Load Experiment', ...
                'Enable', 'off', ...
                'Callback', @obj.loadCallback);

            obj.component.Heights = [25, -1, 30];

            obj.refreshList();

            obj.height = 170;
            obj.width = 400;
        end

        function preselect(obj, name)
            % Highlight an experiment without constructing it. Loading is
            % left to the user, because constructing an Experiment resets
            % its parameters.
            if isempty(name); return; end
            idx = find(strcmp(obj.shownNames, name), 1);
            if isempty(idx); return; end
            obj.lbxExperiments.Value = idx;
            obj.btnLoad.Enable = 'on';
        end

        function refreshList(obj)
            % Rescan for experiments and rebuild the list
            try
                names = Experiment.getExperimentNames();
            catch err
                EventStation.anonymousWarning('Could not list experiments: %s', err.message);
                names = {};
            end

            % Drop entries whose NAME could not be read
            names = names(~cellfun(@isempty, names));
            names = unique(names);

            isFavourite = ismember(names, obj.FAVOURITES);
            obj.allNames = [ ...
                sort(names(isFavourite)), ...
                sort(names(~isFavourite))];

            obj.applyFilter();
        end
    end

    %% Callbacks
    methods (Access = private)
        function filterCallback(obj, ~, ~)
            obj.applyFilter();
        end

        function listboxCallback(obj, ~, ~)
            hasSelection = ~isempty(obj.shownNames) && obj.lbxExperiments.Value >= 1;
            obj.btnLoad.Enable = BooleanHelper.boolToOnOff(hasSelection);

            % Double click loads, same as pressing the button
            if hasSelection && strcmp(get(ancestor(obj.lbxExperiments, 'figure'), 'SelectionType'), 'open')
                obj.loadCallback();
            end
        end

        function loadCallback(obj, ~, ~)
            if isempty(obj.shownNames); return; end
            index = obj.lbxExperiments.Value;
            if index < 1 || index > length(obj.shownNames); return; end

            name = obj.shownNames{index};

            oldPointer = [];
            fig = ancestor(obj.component, 'figure');
            if ~isempty(fig)
                oldPointer = fig.Pointer;
                fig.Pointer = 'watch';
                drawnow limitrate
            end

            try
                % Constructs the Experiment if it does not exist yet
                getExpByName(name);
            catch err
                if ~isempty(fig) && isvalid(fig); fig.Pointer = oldPointer; end
                EventStation.anonymousWarning('Could not load "%s": %s', name, err.message);
                return
            end

            if ~isempty(fig) && isvalid(fig); fig.Pointer = oldPointer; end

            if ~isempty(obj.chosenCallback)
                obj.chosenCallback(name);
            end
        end

        function applyFilter(obj)
            % Keep only names containing the filter text, case-insensitively
            filterText = strtrim(obj.edtFilter.String);
            if isempty(filterText)
                obj.shownNames = obj.allNames;
            else
                matches = contains(obj.allNames, filterText, 'IgnoreCase', true);
                obj.shownNames = obj.allNames(matches);
            end

            % Mark the pinned ones, so it is obvious why they are on top
            display = obj.shownNames;
            for i = 1 : length(display)
                if ismember(display{i}, obj.FAVOURITES)
                    display{i} = [obj.PREFIX_FAVOURITE, display{i}];
                end
            end

            obj.lbxExperiments.String = display;
            obj.lbxExperiments.Value = min(max(1, obj.lbxExperiments.Value), max(1, length(display)));

            hasAny = ~isempty(display);
            obj.btnLoad.Enable = BooleanHelper.boolToOnOff(hasAny);
        end
    end

end
