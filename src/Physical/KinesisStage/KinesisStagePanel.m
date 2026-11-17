classdef KinesisStagePanel < handle
    % Controls for a set of KinesisStage axes, drawn into any uix container.
    % Used by the mainExp column (ViewKinesisStages) and by KinesisStage_gui.
    %
    % Per axis: live position, "Go to" an absolute target, step -/+ and Stop.
    % GUI moves do not block, so Stop always works. A move longer than
    % CONFIRM_ABOVE_MM asks first - this setup is sensitive to big jumps.
    % There is deliberately no Home button; call stage.home() from code.

    properties (Constant)
        ROW_HEIGHT = 24
        ROWS_PER_STAGE = 2
        REFRESH_S = 0.25    % tick; the stages are actually read this often only while one moves
        IDLE_S = 1          % read interval when nothing is moving - keeps MATLAB's main thread free
        CONFIRM_ABOVE_MM = 0.5
        DEFAULT_STEP_UM = 10    % the step box is in um, like the focus search; positions are in mm
    end

    properties (SetAccess = private)
        height
        stages      % cell of KinesisStage
    end

    properties (Access = private)
        lblPos = {}
        edtTarget = {}
        edtStep = {}
        refreshTimer
        lastRead            % tic of the last stage read
        anyMoving = false   % a stage was moving at the last read, or a move was just sent
    end

    methods
        function obj = KinesisStagePanel(parentBox, stages)
            obj.stages = stages;
            box = uix.VBox('Parent', parentBox, 'Spacing', 2);
            heights = [];
            for i = 1:numel(stages)
                s = stages{i};
                r1 = uix.HBox('Parent', box, 'Spacing', 3);
                uicontrol(GuiComponent.PROP_LABEL{:}, 'Parent', r1, 'String', s.name, ...
                    'TooltipString', sprintf('SN %s, limits %g..%g mm', s.serialNumber, s.minPosition, s.maxPosition));
                obj.lblPos{i} = uicontrol(GuiComponent.PROP_TEXT_BIG{:}, 'Parent', r1, 'String', '');
                uicontrol(GuiComponent.PROP_TEXT_UNITS{:}, 'Parent', r1, 'String', 'mm');
                uicontrol(GuiComponent.PROP_BUTTON_SMALL{:}, 'Parent', r1, 'String', 'Stop', ...
                    'ForegroundColor', [0.8 0 0], 'Callback', @(~, ~) obj.safe(@() s.stop));
                r1.Widths = [60, -1, 30, 50];

                r2 = uix.HBox('Parent', box, 'Spacing', 3);
                obj.edtTarget{i} = uicontrol(GuiComponent.PROP_EDIT{:}, 'Parent', r2, ...
                    'String', sprintf('%.4f', s.position), 'TooltipString', 'Absolute target [mm]');
                uicontrol(GuiComponent.PROP_TEXT_NO_BG{:}, 'Parent', r2, 'String', 'mm');
                uicontrol(GuiComponent.PROP_BUTTON_SMALL{:}, 'Parent', r2, 'String', 'Go to', ...
                    'Callback', @(~, ~) obj.goTo(i));
                uicontrol(GuiComponent.PROP_BUTTON_SMALL{:}, 'Parent', r2, 'String', '-', ...
                    'Callback', @(~, ~) obj.step(i, -1));
                obj.edtStep{i} = uicontrol(GuiComponent.PROP_EDIT{:}, 'Parent', r2, ...
                    'String', num2str(obj.DEFAULT_STEP_UM), 'TooltipString', 'Step [um]');
                uicontrol(GuiComponent.PROP_BUTTON_SMALL{:}, 'Parent', r2, 'String', '+', ...
                    'Callback', @(~, ~) obj.step(i, +1));
                uicontrol(GuiComponent.PROP_TEXT_NO_BG{:}, 'Parent', r2, 'String', 'um');
                r2.Widths = [-1, 20, 40, 22, 45, 22, 18];
                heights = [heights, obj.ROW_HEIGHT, obj.ROW_HEIGHT]; %#ok<AGROW>
            end
            if isempty(stages)
                uicontrol(GuiComponent.PROP_TEXT_NO_BG{:}, 'Parent', box, 'String', ...
                    'No Kinesis stages connected (see "kinesisStages" in setupInfo.json).');
                heights = obj.ROW_HEIGHT;
            end
            box.Heights = heights;
            obj.height = sum(heights) + 2 * numel(heights);

            obj.refresh(true);
            if ~isempty(stages)
                obj.refreshTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', obj.REFRESH_S, ...
                    'TimerFcn', @(~, ~) obj.refresh, 'ErrorFcn', @(~, ~) []);
                start(obj.refreshTimer);
            end
            box.DeleteFcn = @(~, ~) obj.delete;
        end

        function refresh(obj, force)
            % Cheap when idle: the timer ticks every REFRESH_S, but the
            % stages are only read every IDLE_S unless one is moving.
            if nargin < 2; force = false; end
            if ~force && ~obj.anyMoving && ~isempty(obj.lastRead) && toc(obj.lastRead) < obj.IDLE_S
                return
            end
            obj.lastRead = tic;
            moving = false;
            for i = 1:numel(obj.stages)
                if ~isvalid(obj.lblPos{i}); return; end
                try
                    s = obj.stages{i};
                    obj.lblPos{i}.String = sprintf('%.4f', s.position);
                    if s.isMoving
                        moving = true;
                        obj.lblPos{i}.ForegroundColor = [0.85 0.4 0];
                    else
                        obj.lblPos{i}.ForegroundColor = [0 0 0];
                    end
                catch
                    obj.lblPos{i}.String = 'error';
                end
            end
            obj.anyMoving = moving;
        end

        function delete(obj)
            if ~isempty(obj.refreshTimer) && isvalid(obj.refreshTimer)
                stop(obj.refreshTimer);
                delete(obj.refreshTimer);
            end
        end
    end

    methods (Access = private)
        function goTo(obj, i)
            target = str2double(obj.edtTarget{i}.String);
            obj.move(i, target);
        end

        function step(obj, i, direction)
            d = str2double(obj.edtStep{i}.String);   % um
            if isnan(d) || d <= 0
                errordlg('Step must be a positive number of um', 'Kinesis stage'); return
            end
            obj.move(i, obj.stages{i}.position + direction * d / 1000);
        end

        function move(obj, i, target)
            s = obj.stages{i};
            if isnan(target)
                errordlg('Target must be a number of mm', 'Kinesis stage'); return
            end
            distance = abs(target - s.position);
            if distance > obj.CONFIRM_ABOVE_MM
                q = sprintf('Move %s by %.4f mm (%.4f -> %.4f mm)?', s.name, distance, s.position, target);
                if ~strcmp(questdlg(q, 'Large move', 'Move', 'Cancel', 'Cancel'), 'Move'); return; end
            end
            obj.safe(@() s.moveTo(target, false));
            obj.edtTarget{i}.String = sprintf('%.4f', target);
            obj.anyMoving = true;   % follow the move at the fast rate
        end

        function safe(~, fn)
            try
                fn();
            catch err
                errordlg(err.message, 'Kinesis stage');
            end
        end
    end
end
