function fig = KinesisStage_gui(stages)
% Control window for the Kinesis stages.
%   KinesisStage_gui                 % stages from setupInfo.json "kinesisStages"
%   KinesisStage_gui({z, x})         % stages you created yourself
% Opening it never moves anything.

if nargin < 1; stages = KinesisStage.getStages(); end
fig = figure('Name', 'Kinesis stages', 'NumberTitle', 'off', 'MenuBar', 'none', ...
    'ToolBar', 'none', 'HandleVisibility', 'off');
box = uix.VBox('Parent', fig, 'Padding', 6);
panel = KinesisStagePanel(box, stages);
fig.Position(3:4) = [330, panel.height + 14];
end
