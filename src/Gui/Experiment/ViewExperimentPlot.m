classdef ViewExperimentPlot < ViewVBox & EventListener
    %VIEWEXPERIMENTPLOT GUI showing results and progress of an Experiment
    
    properties (Access = private)
        expName
        
        vAxes
        cbxAutosave
        progressbarAverages
        progressbarParameters
        btnStartStop
        btnRestart
        btnOpenInFig
        radioNormalDisplay
        radioAlterDisplay
        btnEmergencyStop
    end
    
    methods
        
        function obj = ViewExperimentPlot(expName, parent, controller)
            padding = 15;
            spacing = 15;
            obj@ViewVBox(parent, controller, padding, spacing);
            obj@EventListener({expName, SaveLoadCatExp.NAME});
            obj.expName = expName;
            exp = getExpByName(expName);
            
            fig = obj.component;    % for brevity
            obj.vAxes = axes('Parent', uicontainer('Parent', fig), ...
                'NextPlot', 'replacechildren', ...
                'OuterPosition', [-0.05 0 1.13 1], ...
                'UserData', 'experiment');     % To be plotted on by the Experiment
            obj.progressbarAverages = progressbar(fig, 0, 'Averages Progress Bar');
            axes();  % So as not to accidently overwrite on these axes
            
            hboxControls = uix.HBox('Parent', fig, ...
                'Spacing', 10, 'Padding', 1);
            obj.btnStartStop = ButtonStartStop(hboxControls, 'Start', 'Pause');
                obj.btnStartStop.startCallback = @obj.btnStartCallback;
                obj.btnStartStop.stopCallback  = @obj.btnStopCallback;
            obj.btnRestart = uicontrol(obj.PROP_BUTTON_BIG_BLUE{:}, ...
                'Parent', hboxControls, ...
                'String', 'Restart', ...
                'Callback', @obj.btnRestartCallback);
            bgDisplayType = uibuttongroup(...
                'Parent', hboxControls, ...
                'Title', 'Display Mode', ...
                'SelectionChangedFcn',@obj.callbackRadioSelection);
            rbHeight = 15; % "rb" stands for "radio button"
            rbWidth = 150;
            padding = 10;
            
            obj.radioNormalDisplay = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgDisplayType, ...
                'String', exp.displayType1, ...
                'Position', [padding, 2*padding+rbHeight, rbWidth, rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'UserData', false ... usually, == normal
                );
            obj.radioAlterDisplay = uicontrol(obj.PROP_RADIO{:}, 'Parent', bgDisplayType, ...
                'String', exp.displayType2, ...
                'Position', [padding, padding, rbWidth, rbHeight], ...  % [fromLeft, fromBottom, width, height]
                'UserData', true ... usually, == referenced
                );
            obj.btnOpenInFig = uicontrol(obj.PROP_BUTTON{:}, ...
                'Parent', hboxControls, ...
                'String', '<html><center>Open In<br />Figure</center></html>', ...
                'Callback', @obj.btnOpenInFigureCallback);
            
                        % Autosave toggle. Wrapped in a VBox so the checkbox is
            % vertically centred rather than stretched by the HBox.
            vboxAutosave = uix.VBox('Parent', hboxControls, 'Padding', 0);
                uix.Empty('Parent', vboxAutosave);
                obj.cbxAutosave = uicontrol(...
                    'Parent', vboxAutosave, ...
                    'Style', 'checkbox', ...
                    'String', 'Autosave', ...
                    'TooltipString', 'Autosave results when the run completes', ...
                    'Value', logical(exp.shouldAutosave), ...
                    'Callback', @obj.cbxAutosaveCallback);
                uix.Empty('Parent', vboxAutosave);
            vboxAutosave.Heights = [-1, 20, -1];
            
            hboxControls.Widths = [-1, 100, 150, 70, 80];
            obj.progressbarParameters = progressbar(fig, 0, 'Parameters Progress Bar');
            obj.btnEmergencyStop = uicontrol(obj.PROP_BUTTON_BIG_RED{:}, ...
                'Parent', fig, ...
                'String', 'Halt Experiment', ...
                'Callback', @obj.btnEmergencyStopCallback);
                
            fig.Heights = [-1, 40, 80, 40, 40];
            
            obj.height = 500;
            obj.width = 700;
            
            exp.addGraphicAxes(obj.vAxes); % So that experiment could plot on it
            exp.plotResults;
            obj.refresh;
        end
        
        %%% Callbacks %%%
        function btnOpenInFigureCallback(obj, ~, ~)
            exp = getObjByName(obj.expName);
            if isempty(exp)
                EventStation.anonymousWarning('%s Experiment does not exist!')
                return
            end
            isVisible = true;
            AxesHelper.copyToNewFigure(exp.gAxes, isVisible);
            expNameFixed = strrep(obj.expName, '_', ' ');
            title(expNameFixed);
        end
        
        function btnStopCallback(obj, ~, ~)
            exp = getExpByName(obj.expName);
            if isempty(exp)
                EventStation.anonymousWarning('%s Experiment does not exist!')
                return
            end
            exp.pause;
            obj.refresh;
            drawnow
        end
        
        function btnStartCallback(obj, ~, ~)
            exp = getExpByName(obj.expName);
            exp.run;
            obj.refresh;
        end
        
        function btnRestartCallback(obj, ~, ~)
            strQuestion = sprintf('Do you want to restart the Experiment?');
            strTitle = 'Restart Experiment';
            if QuestionUserYesNo(strTitle, strQuestion)
                exp = getExpByName(obj.expName);
                exp.restart();
                obj.refresh;
            end
        end
        
        function callbackRadioSelection(obj, ~, event)
            exp = getExpByName(obj.expName);
            exp.isPlotAlternate = event.NewValue.UserData;
            exp.plotResultsWhenSwitchingViews;
            drawnow
        end

        function cbxAutosaveCallback(obj, ~, ~)
            exp = getExpByName(obj.expName);
            if isempty(exp)
                EventStation.anonymousWarning('%s Experiment does not exist!', obj.expName)
                return
            end
            exp.shouldAutosave = logical(obj.cbxAutosave.Value);
        end

        function btnEmergencyStopCallback(obj, ~, ~)
            exp = getObjByName(obj.expName);
            if isempty(exp)
                EventStation.anonymousWarning('%s Experiment does not exist!')
                return
            end
            if exp.isRunning
                exp.emergencyStop;
            elseif exp.currParamIter > 0
                exp.clearUncompleteRun;
            end
        end
        
        %%% Updating display %%%
        function update(obj)
            exp = getObjByName(obj.expName);
            
            % Refresh Progress bars
            nDone = exp.currIter;  % The number of the current iteration is also the number of iterations done
            frac = nDone / exp.averages;
            string = sprintf('%d of %d averages (%.2f%%) done', nDone, exp.averages, frac*100);
            progressbar(obj.progressbarAverages, frac, string);
            updateParameterProgressbar(obj);
        end
        
        function updateParameterProgressbar(obj)
            exp = getObjByName(obj.expName);
            
            nDone = exp.currParamIter;
            frac = nDone / exp.getTotalNumberOfParams;
            string = sprintf('%d of %d %s (%.0f%%) done', nDone, exp.getTotalNumberOfParams, exp.parameterName , frac*100);
            progressbar(obj.progressbarParameters, frac, string);
        end
        
        function refresh(obj)
            % Start/Stop status
            if isvalid(obj)
                exp = getExpByName(obj.expName);
                inTheMiddleOfRun = exp.currParamIter > 0 || exp.currIter > 0;
                
                % Take care of Start/Stop button
                if ~exp.restartFlag && inTheMiddleOfRun
                    obj.btnStartStop.startString = 'Resume';
                else
                    obj.btnStartStop.startString = 'Start';
                end
                if exp.stopFlag
                    obj.btnStartStop.stopString = 'Pausing...';
                else
                    obj.btnStartStop.stopString = 'Pause';
                end
                
                % Take care of Emergency Stop button
                bEnable = exp.isRunning || (exp.currParamIter > 0 && exp.currParamIter < exp.getTotalNumberOfParams);
                obj.btnEmergencyStop.Enable = BooleanHelper.boolToOnOff(bEnable);
                if exp.isRunning || exp.currParamIter == 0
                    obj.btnEmergencyStop.String = 'Halt Experiment';
                else
                    obj.btnEmergencyStop.String = 'Clear Last Average';
                end
                
                % Take care of Restart button
                obj.btnStartStop.isRunning = exp.isRunning;
                obj.btnRestart.Enable = BooleanHelper.boolToOnOff(~exp.isRunning && inTheMiddleOfRun);
                
                % Autosave checkbox: stays live during the run, so the user
                % can decide mid-experiment whether the result gets saved.
                obj.cbxAutosave.Value = logical(exp.shouldAutosave);
                % Display type
                if exp.isPlotAlternateAvailable
                    obj.radioAlterDisplay.Enable = 'on';
                else
                    obj.radioAlterDisplay.Enable = 'off';
                end
            end
        end
        
    end
    
    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if isfield(event.extraInfo, Experiment.EVENT_DATA_UPDATED) ...
                    || isfield(event.extraInfo, Experiment.EVENT_EXP_RESUMED) ...
                    || isfield(event.extraInfo, Experiment.EVENT_EXP_PAUSED)
                obj.refresh;
                obj.update;
            elseif isfield(event.extraInfo, Experiment.EVENT_PARAM_ITERATION_DONE)
                obj.refresh;
                obj.updateParameterProgressbar;
            end
        end
    end
end