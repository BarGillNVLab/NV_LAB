classdef GuiControllerMainExp < GuiController
    %GUICONTROLLERMAINEXP Gui Controller for the main window with experiments
    %   Same as GuiControllerImage, but the main view also carries the
    %   experiment column on the right.

    properties
        dummyMode
        mainView        % ViewMainExperiment, kept so the session can be saved
    end

    methods
        function obj = GuiControllerMainExp(dummyMode)
            if ~exist('dummyMode', 'var')
                dummyMode = 0;
            end
            shouldConfirmOnExit = true;
            openOnlyOne = true;
            windowName = 'NV Lab - Image & Experiment';
            obj = obj@GuiController(windowName, shouldConfirmOnExit, openOnlyOne);
            obj.dummyMode = dummyMode;
        end

        function view = getMainView(obj, figureWindowParent)
            % This function should get the main View of this GUI.
            % It can call any view constructor with the params:
            % parent=figureWindowParent, controller=obj
            view = ViewMainExperiment(figureWindowParent, obj, obj.dummyMode);
            obj.mainView = view;
        end

        function onStarted(obj)
            obj.windowMinHeight = 1;
            obj.windowMinWidth = 1;
        end

        function onClose(obj)
            % Callback. Things to run when need to close the GUI.
            obj.saveSession();

            imageScanResult = getObjByName(ImageScanResult.NAME);
            if ~isempty(imageScanResult)
                imageScanResult.checkGraphicAxes;       % Tell it that vAxes are no longer available (without being EventSender)
            else
                % Could not find ImageScanResult, so nothing needs updating.
            end
        end

        function saveSession(obj)
            % Remember what the experiment column was doing, for next time.
            % Never let this stop the window from closing.
            try
                if isempty(obj.mainView) || ~isvalid(obj.mainView); return; end
                column = obj.mainView.viewExperiment;
                if isempty(column) || ~isvalid(column); return; end
                GuiSessionState.save(column.captureState());
            catch
                % A lost session file is not worth a failed close
            end
        end

        function tf = onAboutToclose(obj)
            % Closing this window does not have to stop the experiment. The
            % run loop and the results plot live in their own window, so the
            % measurement can carry on perfectly well without this one.
            tf = true;
            expName = Experiment.current();
            if isempty(expName); return; end

            exp = getObjByName(expName);
            if isempty(exp) || ~isvalid(exp) || ~exp.isRunning; return; end

            answer = QuestionUser('Experiment is running', sprintf( ...
                ['"%s" is still running.\n\n', ...
                'Keep it running and switch to its plot window, ', ...
                'stop it and close, or stay here?'], expName), ...
                {'Keep running', 'Stop and close', 'Cancel'});

            switch answer
                case 1      % Keep running
                    if ~obj.showExperimentWindow(expName)
                        % Rather than leave a running experiment with no way
                        % to watch or stop it, stay where we are.
                        tf = false;
                        return
                    end
                case 2      % Stop and close
                    exp.emergencyStop();
                otherwise   % Cancel, or the dialog was dismissed
                    tf = false;
                    return
            end

            % The question above has already been asked and answered, so do
            % not follow it with the generic "are you sure?" as well.
            obj.confirmOnClose = false;
        end

        function isOk = showExperimentWindow(obj, expName) %#ok<INUSL>
            % Bring up the experiment's own plot window. It is a separate
            % GuiController with openOnlyOne set, so this raises the existing
            % window if there is one, and creates it if it was closed.
            isOk = true;
            try
                GuiControllerExperiment(expName).start;
            catch err
                isOk = false;
                EventStation.anonymousWarning( ...
                    'Could not open the plot window for %s, so this window stays open: %s', ...
                    expName, err.message);
            end
        end
    end

end
