classdef ViewExperimentColumn < ViewVBox
    %VIEWEXPERIMENTCOLUMN The experiment column of the main window
    %   A mode switch at the top chooses what the column shows:
    %
    %     Experiment       - choose an experiment, edit its parameters, look
    %                        at its pulse sequence, run it.
    %     Sequence builder - build a pulse sequence by hand, preview it live,
    %                        run it, save it, or export it as an Exp*.m class.
    %     Helper functions - browse and run anything in helperFunctions\.
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
        HEIGHT_SEQUENCE = 220
        HEIGHT_RUN = 190

        MODE_EXPERIMENT = 1
        MODE_BUILDER = 2
        MODE_HELPERS = 3
        MODE_NAMES = {'Experiment', 'Sequence builder', 'Helper functions'}
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
        viewRun
        viewBuilder
        viewHelpers

        panelParams         % ViewExpandablePanel, so we can retitle it

        % Remembered from the previous session. The experiment is only
        % pre-selected, and its parameters are applied when the user
        % actually loads it - see GuiSessionState for why.
        rememberedExpName = ''
        rememberedParams = struct()
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

            panelSequence = ViewExpandablePanel(cardExperiment, controller, 'Sequence');
            obj.viewSequence = ViewExperimentSequence(panelSequence, controller);

            panelRun = ViewExpandablePanel(cardExperiment, controller, 'Run');
            obj.viewRun = ViewExperimentRunControl(panelRun, controller);

            cardExperiment.setHeights([ ...
                obj.HEIGHT_SELECTOR, obj.HEIGHT_PARAMS, obj.HEIGHT_SEQUENCE, obj.HEIGHT_RUN]);

            %%% Card 2 - sequence builder
            cardBuilder = ViewVBox(cardParent, controller, 0, spacing);
            panelBuilder = ViewExpandablePanel(cardBuilder, controller, 'Sequence builder');
            obj.viewBuilder = ViewSequenceBuilder(panelBuilder, controller);
            cardBuilder.setHeights(-1);

            %%% Card 3 - helper functions
            cardHelpers = ViewVBox(cardParent, controller, 0, spacing);
            panelHelpers = ViewExpandablePanel(cardHelpers, controller, 'Helper functions');
            obj.viewHelpers = ViewHelperFunctions(panelHelpers, controller);
            cardHelpers.setHeights(-1);

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
                state.builderSpec = obj.viewBuilder.currentSpec().toStruct();
            catch
                % A half-built sequence is not worth failing the save over
            end
        end
    end

    methods (Access = private)
        function restoreState(obj)
            state = GuiSessionState.load();
            if isempty(fieldnames(state)); return; end

            if isfield(state, 'builderSpec')
                try
                    obj.viewBuilder.setSpec(UserSequenceSpec.fromStruct(state.builderSpec));
                catch
                    % Keep the example sequence if the saved one is unusable
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
            obj.viewRun.showExperiment(expName);

            % So that a helper argument named exp resolves to this one
            obj.viewHelpers.showExperiment(expName);

            obj.applyRememberedParameters(expName);
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
