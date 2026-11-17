classdef ViewKinesisStages < ViewVBox
    %VIEWKINESISSTAGES Thorlabs Kinesis stage controls + focus search for mainExp
    %   Stages come from setupInfo.json "kinesisStages". Building this view
    %   connects to them read-only; nothing moves until a button is pressed.
    %
    %   Focus: steps the chosen stage to maximise SPCM counts (FocusFinder),
    %   stopping at the kcps limit, past the peak, on saturation, or at the
    %   maximum travel.
    %
    %   See also KINESISSTAGEPANEL, KINESISSTAGE, FOCUSFINDER

    properties (Constant)
        HEADER_HEIGHT = 22
        ROW = 24
        WIDTH = 300
    end

    properties (SetAccess = private)
        panel   % KinesisStagePanel
    end

    properties (Access = private)
        popStage
        edtStep
        edtLimit
        edtTravel
        edtInt
        lblStatus
        finder = []
    end

    methods
        function obj = ViewKinesisStages(parent, controller)
            obj@ViewVBox(parent, controller, 0, 2);
            box = obj.component;
            stages = KinesisStage.getStages();
            obj.panel = KinesisStagePanel(box, stages);

            % Focus search
            uicontrol(obj.PROP_LIGHT_LABEL{:}, 'Parent', box, 'String', 'Find focus (max SPCM counts)');
            names = cellfun(@(s) s.name, stages, 'UniformOutput', false);
            if isempty(names); names = {'(none)'}; end
            zIndex = find(strcmpi(names, 'Z'), 1);
            if isempty(zIndex); zIndex = 1; end
            r1 = uix.HBox('Parent', box, 'Spacing', 3);
            obj.popStage = uicontrol(obj.PROP_POPUP{:}, 'Parent', r1, 'String', names, ...
                'Value', zIndex, ...
                'TooltipString', 'Stage to move for focus (default Z)');
            obj.edtStep = obj.labelled(r1, 'step um', '1', 'Step size [um]');
            obj.edtLimit = obj.labelled(r1, 'max kcps', '10', 'Hard limit: stop as soon as counts reach this');
            r1.Widths = [55, 40, -1, 50, -1];
            r2 = uix.HBox('Parent', box, 'Spacing', 3);
            obj.edtTravel = obj.labelled(r2, 'travel um', '50', 'Never move further than this from the start');
            obj.edtInt = obj.labelled(r2, 'int ms', '100', 'SPCM integration per point [ms]');
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', r2, 'String', 'Find', ...
                'Callback', @(~, ~) obj.findFocus(stages));
            uicontrol(obj.PROP_BUTTON_SMALL{:}, 'Parent', r2, 'String', 'Stop', ...
                'ForegroundColor', [0.8 0 0], 'Callback', @(~, ~) obj.stopFocus());
            r2.Widths = [50, -1, 36, -1, 38, 38];
            obj.lblStatus = uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', box, 'String', '');

            heights = [obj.panel.height, obj.HEADER_HEIGHT, obj.ROW, obj.ROW, obj.ROW];
            obj.setHeights(heights);
            obj.height = sum(heights) + 2 * numel(heights);
            obj.width = obj.WIDTH;
        end
    end

    methods (Access = private)
        function edt = labelled(obj, row, label, value, tooltip)
            uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', row, 'String', label, 'TooltipString', tooltip);
            edt = uicontrol(obj.PROP_EDIT{:}, 'Parent', row, 'String', value, 'TooltipString', tooltip);
        end

        function findFocus(obj, stages)
            if isempty(stages); return; end
            if ~isempty(obj.finder) && obj.finder.isRunning; return; end
            f = FocusFinder(stages{obj.popStage.Value});
            f.stepUm = str2double(obj.edtStep.String);
            f.limitKcps = str2double(obj.edtLimit.String);
            f.maxTravelUm = str2double(obj.edtTravel.String);
            f.integrationS = str2double(obj.edtInt.String) / 1000;
            f.onPoint = @(f) obj.showPoint(f);
            obj.finder = f;
            try
                r = f.run();
                obj.lblStatus.String = sprintf('%s: %.2f kcps at %.4f mm (moved %+.1f um)', ...
                    r.reason, r.bestKcps, r.finalPosition, 1000 * (r.finalPosition - r.startPosition));
                assignin('base', 'focusResult', r);
            catch err
                obj.lblStatus.String = err.message;
            end
        end

        function stopFocus(obj)
            if ~isempty(obj.finder); obj.finder.stop(); end
        end

        function showPoint(obj, f)
            h = f.history(end, :);
            obj.lblStatus.String = sprintf('%.4f mm: %.2f kcps (%d points)', h(1), h(2), size(f.history, 1));
        end
    end
end
