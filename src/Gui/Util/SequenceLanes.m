classdef SequenceLanes
    %SEQUENCELANES Draws a Sequence as one lane per channel
    %   A readable alternative to Sequence.plotSequence, which stacks every
    %   channel on one set of axes and writes each nickname rotated 270
    %   degrees at the centre of its pulse. For a sequence that opens with
    %   several short or zero-length delays - as Rabi does - those labels
    %   land on top of one another and the plot becomes a vertical smear.
    %
    %   Here each channel gets its own lane, blocks are filled rectangles,
    %   and nicknames are written horizontally along the top with any label
    %   skipped that would collide with the one before it.
    %
    %   Shared by the main window's sequence tab and the sequence builder, so
    %   the two show the same picture. The builder additionally makes the
    %   blocks draggable, which is why the block handles are returned.
    %
    %   See also VIEWEXPERIMENTSEQUENCE, VIEWSEQUENCEBUILDER, SEQUENCE

    properties (Constant)
        LANE_FILL = [0.94 0.94 0.94]
        LANE_EDGE = [0.85 0.85 0.85]
        BLOCK_FILL = [0.20 0.45 0.75]
        LABEL_COLOUR = [0.25 0.25 0.25]

        LANE_THICKNESS = 0.62   % of the 1.0 available per lane
        LABELS_ACROSS = 28      % roughly how many nicknames fit side by side
    end

    methods (Static)
        function blocks = draw(ax, S)
            % BLOCKS = DRAW(AX, S) draws sequence S into axes AX.
            %
            % BLOCKS is a struct array with one entry per drawn rectangle:
            %   patch      - the graphics handle
            %   startTime  - when it begins, in microseconds
            %   endTime    - when it ends
            % Callers that want the blocks to be interactive attach their own
            % callbacks to these handles.
            blocks = struct('patch', {}, 'startTime', {}, 'endTime', {});

            cla(ax, 'reset');
            hold(ax, 'on');

            channelsStruct = S.perChannelEdgeTimes();
            names = {channelsStruct.name};
            keep = ~cellfun(@isempty, names);   % the last entry marks empty pulses
            channelsStruct = channelsStruct(keep);
            names = names(keep);
            nLanes = numel(names);

            if nLanes == 0
                hold(ax, 'off');
                return
            end

            total = S.duration;
            thickness = SequenceLanes.LANE_THICKNESS;

            for i = 1 : nLanes
                y = nLanes - i;     % first channel at the top

                % Lane background. The vertex order walks x and y in step, so
                % the second corner has to stay on the baseline - pairing it
                % with the top edge draws a diagonal across the lane instead.
                patch(ax, [0 total total 0], [y y y+thickness y+thickness], ...
                    SequenceLanes.LANE_FILL, 'EdgeColor', SequenceLanes.LANE_EDGE);

                for j = 1 : channelsStruct(i).numOfPulses
                    t0 = channelsStruct(i).pulsesStartTime(j);
                    t1 = channelsStruct(i).pulsesEndTime(j);
                    if t1 <= t0; continue; end
                    h = patch(ax, [t0 t1 t1 t0], [y y y+thickness y+thickness], ...
                        SequenceLanes.BLOCK_FILL, ...
                        'EdgeColor', SequenceLanes.BLOCK_FILL * 0.6);
                    blocks(end+1) = struct('patch', h, 'startTime', t0, 'endTime', t1); %#ok<AGROW>
                end
            end

            SequenceLanes.drawLabels(ax, S, nLanes, total);

            set(ax, 'YTick', (0 : nLanes-1) + thickness/2, ...
                'YTickLabel', fliplr(names), ...
                'TickLabelInterpreter', 'none', ...
                'FontSize', 8, 'Box', 'on', 'Layer', 'top', 'TickDir', 'out');
            xlim(ax, [0 max(total, eps)]);
            ylim(ax, [-0.1 nLanes + 0.75]);
            xlabel(ax, 't [\mus]');
            hold(ax, 'off');
        end
    end

    methods (Static, Access = private)
        function drawLabels(ax, S, nLanes, total)
            % Nicknames across the top, dropping any that would collide.
            % Interpreter 'none' because a nickname like 'pi_half' is a name,
            % not TeX - left to itself MATLAB renders it with a subscript.
            edges = S.edgeTimes();
            pulses = S.getPulses();
            lastDrawn = -inf;
            minGap = total / SequenceLanes.LABELS_ACROSS;

            for j = 1 : numel(pulses)
                label = pulses(j).nickname;
                if isempty(label); continue; end
                if j + 1 > numel(edges); break; end

                centre = (edges(j) + edges(j+1)) / 2;
                if centre - lastDrawn < minGap; continue; end

                text(ax, centre, nLanes + 0.15, label, ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                    'FontSize', 7, 'Color', SequenceLanes.LABEL_COLOUR, ...
                    'Interpreter', 'none');
                lastDrawn = centre;
            end
        end
    end
end
