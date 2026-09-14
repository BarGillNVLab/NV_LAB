classdef ViewExperimentResult < ViewVBox & EventListener
    %VIEWEXPERIMENTRESULT Live results of the selected experiment, in the main window
    %   A second view of the same measurement the plot window shows, so the
    %   result is visible without another window in front of the controls.
    %
    %   It draws itself from the Experiment's own data parameters rather
    %   than calling plotResults. Experiment.gAxes is a single handle that
    %   ViewExperimentPlot claims through addGraphicAxes, so asking the
    %   Experiment to plot here would take the axes away from that window
    %   and leave it dead. Reading mCurrentXAxisParam and signalParam
    %   instead means both views can be open at once, neither owning the
    %   other.
    %
    %   See also VIEWEXPERIMENTPLOT, VIEWEXPERIMENTCOLUMN

    properties (Access = private)
        vAxes
        lblStatus
        expName = ''
    end

    methods
        function obj = ViewExperimentResult(parent, controller)
            obj@ViewVBox(parent, controller, 4, 3);
            obj@EventListener({});      % re-targeted in showExperiment

            obj.vAxes = axes('Parent', uicontainer('Parent', obj.component), ...
                'NextPlot', 'replacechildren', 'FontSize', 8, ...
                'UserData', 'experimentResult');

            hBottom = uix.HBox('Parent', obj.component, 'Spacing', 4);
            obj.lblStatus = uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', hBottom, ...
                'String', 'No experiment loaded.');
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', hBottom, ...
                'String', 'To figure', ...
                'TooltipString', 'Copy this plot into its own figure', ...
                'Callback', @obj.toFigureCallback);
            hBottom.Widths = [-1, 70];

            obj.component.Heights = [-1, 20];

            obj.width = 400;
            obj.height = 220;
        end

        function showExperiment(obj, expName)
            if ~isempty(obj.expName)
                obj.stopListeningTo(obj.expName);
            end
            obj.expName = expName;
            if ~isempty(expName)
                obj.startListeningTo(expName);
            end
            obj.refresh();
        end

        function refresh(obj)
            if ~isvalid(obj); return; end

            exp = obj.experimentOrEmpty();
            if isempty(exp)
                obj.clearAxes('No experiment loaded.');
                return
            end

            [x, y, err, xLabel, yLabel] = obj.readData(exp);
            if isempty(y) || all(isnan(y(:)))
                obj.clearAxes(sprintf('%s: nothing measured yet.', obj.expName));
                return
            end

            try
                obj.draw(x, y, err, xLabel, yLabel);
            catch drawErr
                obj.clearAxes(sprintf('Cannot plot: %s', drawErr.message));
                return
            end

            obj.lblStatus.String = sprintf('%s - %d of %d averages', ...
                obj.expName, exp.currIter, exp.averages);
        end
    end

    %% Reading and drawing
    methods (Access = private)
        function [x, y, err, xLabel, yLabel] = readData(obj, exp)
            x = []; y = []; err = [];
            xLabel = ''; yLabel = '';

            try
                xParam = exp.mCurrentXAxisParam;
                yParam = exp.signalParam;
                if isa(xParam, 'ExpParameter')
                    x = xParam.value;
                    xLabel = xParam.label;
                end
                if isa(yParam, 'ExpParameter')
                    y = yParam.value;
                    err = yParam.sterr;
                    yLabel = yParam.label;
                end
            catch
                % An experiment part-way through construction may not have
                % its parameters yet; nothing to draw is not an error
            end

            % A single average leaves y as a row or column; make both vectors
            y = y(:)';
            err = err(:)';
            x = x(:)';
            if isempty(x) || numel(x) ~= numel(y)
                x = 1 : numel(y);
                if isempty(xLabel); xLabel = 'Point'; end
            end
            if numel(err) ~= numel(y); err = []; end
        end

        function draw(obj, x, y, err, xLabel, yLabel)
            ax = obj.vAxes;
            cla(ax, 'reset');
            if isempty(err)
                plot(ax, x, y, 'o-', 'MarkerSize', 3, 'LineWidth', 1);
            else
                errorbar(ax, x, y, err, 'o-', 'MarkerSize', 3, 'LineWidth', 1);
            end
            grid(ax, 'on');
            xlabel(ax, xLabel, 'Interpreter', 'none');
            ylabel(ax, yLabel, 'Interpreter', 'none');
            if numel(x) > 1 && x(end) ~= x(1)
                xlim(ax, sort([x(1) x(end)]));
            end
        end

        function toFigureCallback(obj, ~, ~)
            if ~isvalid(obj.vAxes); return; end
            try
                isVisible = true;
                AxesHelper.copyToNewFigure(obj.vAxes, isVisible);
                title(strrep(obj.expName, '_', ' '));
            catch err
                EventStation.anonymousWarning('Could not copy the plot: %s', err.message);
            end
        end

        function clearAxes(obj, message)
            if isvalid(obj.vAxes); cla(obj.vAxes, 'reset'); end
            if isvalid(obj.lblStatus); obj.lblStatus.String = message; end
        end

        function exp = experimentOrEmpty(obj)
            exp = [];
            if isempty(obj.expName); return; end
            candidate = getObjByName(obj.expName);
            if ~isempty(candidate) && isvalid(candidate) && isa(candidate, 'Experiment')
                exp = candidate;
            end
        end
    end

    %% overridden from EventListener
    methods
        function onEvent(obj, event)
            if ~isvalid(obj); return; end
            if isfield(event.extraInfo, Experiment.EVENT_DATA_UPDATED) ...
                    || isfield(event.extraInfo, Experiment.EVENT_PARAM_ITERATION_DONE) ...
                    || isfield(event.extraInfo, Experiment.EVENT_EXP_PAUSED)
                obj.refresh();
            end
        end
    end
end
