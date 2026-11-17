classdef ViewExperimentColumn < ViewVBox
    %VIEWEXPERIMENTCOLUMN The experiment column of the main window
    %   A mode switch at the top chooses what the column shows:
    %
    %     Experiment       - choose an experiment, edit its parameters, look
    %                        at its pulse sequence, run it.
    %     Sequence builder - build a pulse sequence by hand, preview it live,
    %                        run it, save it, or export it as an Exp*.m class.
    %     Helper functions - browse and run anything in helperFunctions\.
    %     Scan loop        - nested loops over stages, current, MW and
    %                        experiment parameters, with steps at each point.
    %
    %   The two modes are cards in a uix.CardPanel, so switching is instant
    %   and neither side loses its state.
    %
    %   This class owns the "currently selected experiment" and is the only
    %   place that knows it: the panels below do not talk to each other,
    %   they report up to here and are told what to show. The helper panel
    %   is told too, so that an argument called exp can be filled in with
    %   whichever experiment is selected.

    properties (Constant)
        HEIGHT_MODE = 26
        HEIGHT_SELECTOR = 170
        HEIGHT_PARAMS = 260
        HEIGHT_SEQUENCE = 250       % the tabbed sequence/results panel
        HEIGHT_RUN = 190

        MODE_EXPERIMENT = 1
        MODE_HELPERS = 3
        MODE_NAMES = {'Experiment', 'Sequence builder', 'Helper functions', 'Scan loop'}
    end

    properties (SetAccess = private)
        expName = ''        % char array. Name of the selected Experiment, or '' for none
    end

    properties (Access = private)
        popMode
        cards

        viewSelector
        viewParams
        viewSequence
        viewResult
        viewRun
        viewHelpers

        panelParams         % ViewExpandablePanel, so we can retitle it

        % Remembered from the previous session. The experiment is only
        % pre-selected, and its parameters are applied when the user
        % actually loads it - see GuiSessionState for why.
        rememberedExpName = ''
        rememberedParams = struct()

        % The sequence being edited. Held here rather than in the builder
        % window so that closing that window does not discard the work.
        builderSpec = []
    end

    methods
        function obj = ViewExperimentColumn(parent, controller)
            padding = 2;
            spacing = 3;
            obj@ViewVBox(parent, controller, padding, spacing);

            obj.popMode = uicontrol(obj.PROP_POPUP{:}, ...
                'Parent', obj.component, ...
                'String', obj.MODE_NAMES, ...
                'Value', obj.MODE_EXPERIMENT, ...
                'TooltipString', 'Switch between running experiments, building a sequence, and running helper functions', ...
                'Callback', @obj.modeCallback);

            obj.cards = uix.CardPanel('Parent', obj.component, 'Padding', 0);
            % The card panel is not a GuiComponent, but every View only ever
            % reaches for parent.component - the same trick GuiController
            % uses to parent the main view onto the figure.
            cardParent.component = obj.cards;

            %%% Card 1 - experiments
            cardExperiment = ViewVBox(cardParent, controller, 0, spacing);

            panelSelector = ViewExpandablePanel(cardExperiment, controller, 'Experiment');
            obj.viewSelector = ViewExperimentSelector(panelSelector, controller, @obj.onExperimentChosen);

            obj.panelParams = ViewExpandablePanel(cardExperiment, controller, 'Parameters');
            obj.viewParams = ViewExperimentParams(obj.panelParams, controller, @obj.onParameterChanged);

            % Sequence preview and results share one panel as tabs: the
            % column is already full height, so a fifth panel would be
            % clipped rather than shown.
            panelSequence = ViewExpandablePanel(cardExperiment, controller, 'Sequence & results');
            tabs = uix.TabPanel('Parent', panelSequence.component, 'Padding', 2, 'FontSize', 8);
            tabParent.component = tabs;
            obj.viewSequence = ViewExperimentSequence(tabParent, controller);
            obj.viewResult = ViewExperimentResult(tabParent, controller);
            tabs.TabTitles = {'Sequence', 'Results'};
            tabs.Selection = 1;

            panelRun = ViewExpandablePanel(cardExperiment, controller, 'Run');
            obj.viewRun = ViewExperimentRunControl(panelRun, controller);

            cardExperiment.setHeights([ ...
                obj.HEIGHT_SELECTOR, obj.HEIGHT_PARAMS, obj.HEIGHT_SEQUENCE, obj.HEIGHT_RUN]);

            %%% Card 2 - sequence builder launcher
            % The builder itself lives in its own resizable window: three
            % tables and a channel-lane preview do not fit in this column.
            cardBuilder = ViewVBox(cardParent, controller, 0, spacing);
            panelBuilder = ViewExpandablePanel(cardBuilder, controller, 'Sequence builder');
            launcher = ViewVBox(panelBuilder, controller, 8, 6);
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', launcher.component, ...
                'Max', 2, 'Min', 0, ...
                'String', ['Build a sequence by hand: pulses as time slices, ', ...
                    'durations written over named variables, and any number of ', ...
                    'those variables swept over an explicit table of points.']);
            uicontrol(obj.PROP_BUTTON{:}, 'Parent', launcher.component, ...
                'String', 'Open sequence builder', ...
                'Callback', @obj.openBuilderCallback);
            uix.Empty('Parent', launcher.component);
            launcher.setHeights([70, 36, -1]);
            cardBuilder.setHeights(-1);

            %%% Card 3 - helper functions
            cardHelpers = ViewVBox(cardParent, controller, 0, spacing);
            panelHelpers = ViewExpandablePanel(cardHelpers, controller, 'Helper functions');
            obj.viewHelpers = ViewHelperFunctions(panelHelpers, controller);
            cardHelpers.setHeights(-1);

            %%% Card 4 - scan loop over stages / current / MW / experiment parameters
            cardLoop = ViewVBox(cardParent, controller, 0, spacing);
            uicontrol(obj.PROP_BUTTON{:}, 'Parent', cardLoop.component, ...
                'String', 'Current x X scan with ESR...', ...
                'TooltipString', 'Wire current x X positions, Z retract between points, an ESR at each', ...
                'Callback', @(~, ~) scanCurrentX_ESR());
            panelLoop = ViewExpandablePanel(cardLoop, controller, 'Scan loop (general)');
            ViewScanLoop(panelLoop, controller);
            cardLoop.setHeights([34, -1]);

            obj.cards.Selection = obj.MODE_EXPERIMENT;
            obj.restoreState();

            obj.component.Heights = [obj.HEIGHT_MODE, -1];

            obj.width = 420;
            obj.height = obj.HEIGHT_MODE + obj.HEIGHT_SELECTOR + obj.HEIGHT_PARAMS + ...
                obj.HEIGHT_SEQUENCE + obj.HEIGHT_RUN;
        end
    end

    methods
        function state = captureState(obj)
            % What the next session should come back to
            state = struct();
            state.mode = obj.popMode.Value;
            state.expName = obj.expName;
            state.expParams = GuiSessionState.captureParameters(getObjByName(obj.expName));
            try
                if ~isempty(obj.builderSpec) && isvalid(obj.builderSpec)
                    state.builderSpec = obj.builderSpec.toStruct();
                end
            catch
                % A half-built sequence is not worth failing the save over
            end
        end
    end

    methods (Static)
        function name = workspaceNameFor(expName)
            % 'ESR' -> 'esr', 'ESR_CS' -> 'esr_cs', and anything that is not
            % a usable identifier is made into one.
            name = lower(expName);
            if ~isvarname(name)
                name = matlab.lang.makeValidName(name);
            end
        end
    end

    methods (Access = private)
        function restoreState(obj)
            state = GuiSessionState.load();
            if isempty(fieldnames(state)); return; end

            if isfield(state, 'builderSpec')
                try
                    obj.builderSpec = UserSequenceSpec.fromStruct(state.builderSpec);
                catch
                    % Start from the example sequence if the saved one is unusable
                    obj.builderSpec = [];
                end
            end

            if isfield(state, 'expName') && ~isempty(state.expName)
                obj.rememberedExpName = char(state.expName);
                obj.viewSelector.preselect(obj.rememberedExpName);
            end
            if isfield(state, 'expParams') && isstruct(state.expParams)
                obj.rememberedParams = state.expParams;
            end

            if isfield(state, 'mode')
                mode = min(max(1, state.mode), numel(obj.MODE_NAMES));
                obj.popMode.Value = mode;
                obj.cards.Selection = mode;
            end
        end

        function openBuilderCallback(obj, ~, ~)
            controller = GuiControllerSequenceBuilder(obj.builderSpec);
            controller.start;
            % Keep hold of whatever it is editing, so the session state and
            % the next open both pick up from here
            if ~isempty(controller.spec)
                obj.builderSpec = controller.spec;
            end
        end

        function modeCallback(obj, ~, ~)
            obj.cards.Selection = obj.popMode.Value;
        end

        function onExperimentChosen(obj, expName)
            % The user picked an experiment in the selector. Point every
            % other panel at it.
            obj.expName = expName;
            obj.panelParams.component.Title = sprintf('Parameters - %s', expName);

            obj.viewParams.showExperiment(expName);
            obj.viewSequence.showExperiment(expName);
            obj.viewResult.showExperiment(expName);
            obj.viewRun.showExperiment(expName);

            % So that a helper argument named exp resolves to this one
            obj.viewHelpers.showExperiment(expName);

            obj.applyRememberedParameters(expName);
            obj.publishToWorkspace(expName);
        end

        function publishToWorkspace(obj, expName)
            % Put the experiment in the base workspace, the way it would be
            % if it had been constructed at the prompt.
            %
            % Experiment is a handle class, so this is the same object the
            % GUI is showing - not a copy. Changing esr.averages at the
            % prompt shows up in the parameter table, and an edit in the
            % table is visible from the prompt.
            exp = getObjByName(expName);
            if isempty(exp) || ~isvalid(exp); return; end

            variableName = ViewExperimentColumn.workspaceNameFor(expName);
            try
                assignin('base', variableName, exp);
            catch err
                EventStation.anonymousWarning('Could not put %s in the workspace: %s', ...
                    expName, err.message);
                return
            end

            % Said out loud, because a variable appearing unannounced is
            % worse than no variable at all
            fprintf('%s is in the workspace as "%s" (the same object the GUI shows).\n', ...
                expName, variableName);
            obj.viewParams.showNotice(sprintf('In the workspace as "%s".', variableName));
        end

        function applyRememberedParameters(obj, expName)
            % Put last session's values back, but only for the experiment
            % they belong to, only once, and only with it said out loud.
            if isempty(obj.rememberedExpName) || ~strcmp(expName, obj.rememberedExpName)
                return
            end
            if isempty(fieldnames(obj.rememberedParams)); return; end

            exp = getObjByName(expName);
            [applied, skipped] = GuiSessionState.applyParameters(exp, obj.rememberedParams);

            obj.rememberedParams = struct();    % once only
            obj.rememberedExpName = '';

            if isempty(applied); return; end
            obj.viewParams.refreshValues();
            message = sprintf('Restored %d parameter(s) from your last session.', numel(applied));
            if ~isempty(skipped)
                message = sprintf('%s %d could not be applied.', message, numel(skipped));
            end
            obj.viewParams.showNotice(message);
        end

        function onParameterChanged(obj)
            % A parameter was edited. The sequence may well look different
            % now, so redraw it - this does not touch hardware.
            obj.viewSequence.refreshPreview();
            obj.viewRun.refresh();
        end
    end

end
