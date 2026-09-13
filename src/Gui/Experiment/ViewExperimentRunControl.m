classdef ViewExperimentRunControl < ViewVBox & EventListener
    %VIEWEXPERIMENTRUNCONTROL Start, pause, restart and halt the selected Experiment
    %   Mirrors the controls of ViewExperimentPlot, minus the results plot:
    %   Experiment.run opens its own plot window anyway, and that window
    %   stays the place where results are drawn and analysed.

    properties (Access = private)
        btnStartStop
        btnRestart
        btnEmergencyStop
        btnOpenPlot
        cbxAutosave
        progressbarAverages
        progressbarParameters

        expName = ''
    end

    methods
        function obj = ViewExperimentRunControl(parent, controller)
            padding = 5;
            spacing = 4;
            obj@ViewVBox(parent, controller, padding, spacing);
            obj@EventListener({});      % re-targeted in showExperiment

            box = obj.component;    % for brevity

            obj.progressbarAverages = progressbar(box, 0, 'Averages Progress Bar');
            obj.progressbarParameters = progressbar(box, 0, 'Parameters Progress Bar');
            axes();  % So as not to accidentally overwrite on these axes

            hboxTop = uix.HBox('Parent', box, 'Spacing', 5);
            obj.btnStartStop = ButtonStartStop(hboxTop, 'Start', 'Pause');
                obj.btnStartStop.startCallback = @obj.btnStartCallback;
                obj.btnStartStop.stopCallback  = @obj.btnStopCallback;
            obj.btnRestart = uicontrol(obj.PROP_BUTTON{:}, ...
                'Parent', hboxTop, ...
                'String', 'Restart', ...
                'Callback', @obj.btnRestartCallback);
            hboxTop.Widths = [-1, 80];

            hboxBottom = uix.HBox('Parent', box, 'Spacing', 5);
            obj.cbxAutosave = uicontrol(obj.PROP_CHECKBOX{:}, ...
                'Parent', hboxBottom, ...
                'String', 'Autosave', ...
                'TooltipString', 'Autosave results when the run completes', ...
                'Callback', @obj.cbxAutosaveCallback);
            obj.btnOpenPlot = uicontrol(obj.PROP_BUTTON_SMALL{:}, ...
                'Parent', hboxBottom, ...
                'String', 'Open Plot', ...
                'TooltipString', 'Open the results window for this experiment', ...
                'Callback', @obj.btnOpenPlotCallback);
            hboxBottom.Widths = [-1, 90];

            obj.btnEmergencyStop = uicontrol(obj.PROP_BUTTON_BIG_RED{:}, ...
                'Parent', box, ...
                'String', 'Halt Experiment', ...
                'Callback', @obj.btnEmergencyStopCallback);

            box.Heights = [30, 30, 32, 24, 36];

            obj.setEnable(false);

            obj.height = 190;
            obj.width = 400;
        end

        function showExperiment(obj, expName)
            if ~isempty(obj.expName)
                obj.stopListeningTo(obj.expName);
            end
            obj.expName = expName;
            if ~isempty(expName)
                obj.startListeningTo(expName);
            end
            try
                obj.refresh();
                obj.update();
            catch err
                % Never let a display problem propagate back into the
                % selector's callback and abort loading the experiment.
                EventStation.anonymousWarning('Could not show run controls for %s: %s', ...
                    expName, err.message);
            end
        end

        function refresh(obj)
            % Enable and label the buttons to match the Experiment's state
            if ~isvalid(obj); return; end
            exp = obj.experimentOrEmpty();
            if isempty(exp)
                obj.setEnable(false);
                return
            end
            obj.setEnable(true);

            inTheMiddleOfRun = exp.currParamIter > 0 || exp.currIter > 0;

            if ~exp.restartFlag && inTheMiddleOfRun
                obj.btnStartStop.startString = 'Resume';
            else
                obj.btnStartStop.startString = 'Start';
            end
            if exp.stopFlag
                obj.btnStartStop.stopString = 'Pause';
            else
                obj.btnStartStop.stopString = 'Pausing...';
            end
            obj.btnStartStop.isRunning = exp.isRunning;

            bEnable = exp.isRunning || (exp.currParamIter > 0 && exp.currParamIter < exp.getTotalNumberOfParams);
            obj.btnEmergencyStop.Enable = BooleanHelper.boolToOnOff(bEnable);
            if exp.isRunning || exp.currParamIter == 0
                obj.btnEmergencyStop.String = 'Halt Experiment';
            else
                obj.btnEmergencyStop.String = 'Clear Last Average';
            end

            obj.btnRestart.Enable = BooleanHelper.boolToOnOff(~exp.isRunning && inTheMiddleOfRun);
            obj.cbxAutosave.Value = logical(exp.shouldAutosave);
        end

        function update(obj)
            % Refresh the two progress bars
            if ~isvalid(obj); return; end
            exp = obj.experimentOrEmpty();
            if isempty(exp)
                progressbar(obj.progressbarAverages, 0, 'No experiment loaded');
                progressbar(obj.progressbarParameters, 0, '');
                return
            end

            nDone = exp.currIter;
            frac = obj.safeFraction(nDone, exp.averages);
            progressbar(obj.progressbarAverages, frac, ...
                sprintf('%d of %d averages (%.2f%%) done', nDone, exp.averages, frac*100));

            nParamsDone = exp.currParamIter;
            total = exp.getTotalNumberOfParams;
            fracParams = obj.safeFraction(nParamsDone, total);
            progressbar(obj.progressbarParameters, fracParams, ...
                sprintf('%d of %d %s (%.0f%%) done', nParamsDone, total, ...
                    obj.parameterNameOf(exp), fracParams*100));
        end
    end

    %% Callbacks
    methods (Access = private)
        function btnStartCallback(obj, ~, ~)
            exp = obj.experimentOrEmpty();
            if isempty(exp); return; end

            % One Experiment at a time: the run loop, the pulse generator and
            % the SPCM are all shared, single instances.
            currentName = Experiment.current();
            if ~isempty(currentName) && ~strcmp(currentName, obj.expName)
                other = getObjByName(currentName);
                if ~isempty(other) && isvalid(other) && other.isRunning
                    if ~QuestionUserYesNo('Another experiment is running', sprintf( ...
                            '"%s" is running. Pause it and start "%s" instead?', ...
                            currentName, obj.expName))
                        return
                    end
                    other.pause();
                end
            end

            try
                exp.run();
            catch err
                EventStation.anonymousWarning('%s could not run: %s', obj.expName, err.message);
            end
            obj.refresh();
        end

        function btnStopCallback(obj, ~, ~)
            exp = obj.experimentOrEmpty();
            if isempty(exp); return; end
            exp.pause();
            obj.refresh();
            drawnow
        end

        function btnRestartCallback(obj, ~, ~)
            exp = obj.experimentOrEmpty();
            if isempty(exp); return; end
            if QuestionUserYesNo('Restart Experiment', 'Do you want to restart the Experiment?')
                exp.restart();
                obj.refresh();
            end
        end

        function btnEmergencyStopCallback(obj, ~, ~)
            exp = obj.experimentOrEmpty();
            if isempty(exp); return; end
            if exp.isRunning
                exp.emergencyStop();
            elseif exp.currParamIter > 0
                exp.clearUncompleteRun();
            end
            obj.refresh();
        end

        function btnOpenPlotCallback(obj, ~, ~)
            if isempty(obj.expName); return; end
            GuiControllerExperiment(obj.expName).start;
        end

        function cbxAutosaveCallback(obj, ~, ~)
            exp = obj.experimentOrEmpty();
            if isempty(exp); return; end
            exp.shouldAutosave = logical(obj.cbxAutosave.Value);
        end

        function setEnable(obj, tf)
            onOff = BooleanHelper.boolToOnOff(tf);
            obj.btnStartStop.Enable = onOff;
            obj.btnRestart.Enable = onOff;
            obj.btnEmergencyStop.Enable = onOff;
            obj.btnOpenPlot.Enable = onOff;
            obj.cbxAutosave.Enable = onOff;
        end

        function name = parameterNameOf(obj, exp) %#ok<INUSL>
            % parameterName is declared with restricted access, so a class
            % the access list does not name would throw here. The label on a
            % progress bar is not worth losing the window over.
            try
                name = exp.parameterName;
            catch
                name = 'parameters';
            end
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

    methods (Static, Access = private)
        function frac = safeFraction(done, total)
            % Progress bars are drawn before an Experiment knows how many
            % parameters it has, so guard the division.
            if isempty(total) || ~isfinite(total) || total <= 0
                frac = 0;
            else
                frac = min(1, max(0, done / total));
            end
        end
    end

    %% overridden from EventListener
    methods
        function onEvent(obj, event)
            if ~isvalid(obj); return; end
            if isfield(event.extraInfo, Experiment.EVENT_DATA_UPDATED) ...
                    || isfield(event.extraInfo, Experiment.EVENT_EXP_RESUMED) ...
                    || isfield(event.extraInfo, Experiment.EVENT_EXP_PAUSED)
                obj.refresh();
                obj.update();
            elseif isfield(event.extraInfo, Experiment.EVENT_PARAM_ITERATION_DONE)
                obj.refresh();
                obj.update();
            end
        end
    end

end
