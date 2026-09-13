classdef ViewExperimentSequence < ViewVBox
    %VIEWEXPERIMENTSEQUENCE Live plot of the selected Experiment's sequence
    %   Redrawn whenever a parameter changes, so the effect of an edit is
    %   visible immediately.
    %
    %   The live path never touches hardware: it asks the Experiment for its
    %   Sequence through Experiment.buildSequence and plots that object
    %   directly. Experiments which have not adopted buildSequence get a
    %   button instead, because the only way to see their sequence is
    %   Experiment.plotSequence, which runs prepare() and therefore
    %   configures the pulse generator, frequency generator and SPCM.

    properties (Access = private)
        vAxes
        lblStatus
        btnPreview

        expName = ''
    end

    methods
        function obj = ViewExperimentSequence(parent, controller)
            padding = 5;
            spacing = 3;
            obj@ViewVBox(parent, controller, padding, spacing);

            obj.vAxes = axes('Parent', uicontainer('Parent', obj.component), ...
                'NextPlot', 'replacechildren', ...
                'FontSize', 7, ...
                'UserData', 'sequence');

            hboxBottom = uix.HBox('Parent', obj.component, 'Spacing', 5);
            obj.lblStatus = uicontrol(obj.PROP_TEXT_NO_BG{:}, ...
                'Parent', hboxBottom, ...
                'String', 'No experiment loaded.');
            obj.btnPreview = uicontrol(obj.PROP_BUTTON_SMALL{:}, ...
                'Parent', hboxBottom, ...
                'String', 'Preview', ...
                'TooltipString', 'Build the sequence on the hardware and plot it', ...
                'Visible', 'off', ...
                'Callback', @obj.btnPreviewCallback);
            hboxBottom.Widths = [-1, 80];

            obj.component.Heights = [-1, 22];

            obj.height = 220;
            obj.width = 400;
        end

        function showExperiment(obj, expName)
            obj.expName = expName;
            obj.refreshPreview();
        end

        function refreshPreview(obj)
            % Redraw the sequence, without touching hardware.
            exp = obj.experimentOrEmpty();
            if isempty(exp)
                obj.clearAxes('No experiment loaded.');
                obj.btnPreview.Visible = 'off';
                return
            end

            if ~exp.hasSequencePreview()
                % No hardware-free path into this Experiment's sequence
                obj.clearAxes(sprintf('%s has no live preview.', obj.expName));
                obj.btnPreview.Visible = 'on';
                return
            end
            obj.btnPreview.Visible = 'off';

            % Never let a half-finished set of parameters (an empty vector, a
            % pi time not filled in yet) throw out of a GUI callback. The
            % message goes on the axes instead.
            try
                S = exp.buildSequence();
            catch err
                obj.clearAxes(sprintf('Cannot build sequence: %s', err.message));
                return
            end

            if isempty(S) || ~isa(S, 'Sequence') || S.duration == 0
                obj.clearAxes('Sequence is empty.');
                return
            end

            try
                cla(obj.vAxes);
                S.plotSequence(obj.vAxes);
                obj.lblStatus.String = sprintf('Duration: %s us (per repeat)', ...
                    StringHelper.formatNumber(S.duration, 3));
            catch err
                obj.clearAxes(sprintf('Cannot plot sequence: %s', err.message));
            end
        end
    end

    %% Callbacks
    methods (Access = private)
        function btnPreviewCallback(obj, ~, ~)
            exp = obj.experimentOrEmpty();
            if isempty(exp); return; end

            if exp.isRunning
                EventStation.anonymousWarning('%s is running. Pause it before previewing the sequence.', obj.expName);
                return
            end

            % This one really does drive the instruments, so ask first
            if ~QuestionUserYesNo('Preview sequence', sprintf( ...
                    ['%s cannot build its sequence without hardware.\n\n', ...
                    'Previewing it will configure the pulse generator, frequency\n', ...
                    'generator and SPCM. Continue?'], obj.expName))
                return
            end

            try
                cla(obj.vAxes);
                exp.plotSequence(obj.vAxes);
                obj.lblStatus.String = 'Previewed using hardware.';
            catch err
                obj.clearAxes(sprintf('Preview failed: %s', err.message));
            end
        end

        function clearAxes(obj, message)
            if ~isvalid(obj.vAxes); return; end
            cla(obj.vAxes);
            obj.lblStatus.String = message;
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

end
