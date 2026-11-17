function fig = E3631A_gui(ps)
% Small control panel for the E3631A current source.
%   E3631A_gui            % connects to COM5, channel P6V
%   E3631A_gui(ps)        % reuses an existing E3631A object (e.g. from your script)
% Measured V/I refresh every 2 s, paused while the SPCM counter or an
% experiment runs (each refresh is a serial round trip on MATLAB's main thread).

if nargin < 1; ps = E3631A('COM5'); end

fig = uifigure('Name', sprintf('E3631A - %s', ps.channel), 'Position', [100 100 300 250]);
g = uigridlayout(fig, [6 2], 'RowHeight', repmat({'fit'}, 1, 6));

uilabel(g, 'Text', 'Set current [A]');
setField = uieditfield(g, 'numeric', 'Limits', [0 ps.MAX_I.(ps.channel)], ...
    'ValueDisplayFormat', '%.4f', 'Value', ps.setpoint, 'ValueChangedFcn', @(s, ~) apply(s.Value));

uilabel(g, 'Text', 'Compliance V');
uieditfield(g, 'numeric', 'Value', ps.vLimit, 'ValueDisplayFormat', '%.3f', ...
    'ValueChangedFcn', @(s, ~) setVLimit(s));

uilabel(g, 'Text', 'Output');
outSwitch = uiswitch(g, 'Value', onOff(ps.isOn), 'ValueChangedFcn', @(s, ~) toggle(s.Value));

uilabel(g, 'Text', 'Measured I [A]');
iLabel = uilabel(g, 'FontWeight', 'bold', 'FontSize', 16);
uilabel(g, 'Text', 'Measured V [V]');
vLabel = uilabel(g, 'FontWeight', 'bold', 'FontSize', 16);
status = uilabel(g, 'Text', '', 'FontColor', [0.7 0 0]);
status.Layout.Column = [1 2];

t = timer('ExecutionMode', 'fixedSpacing', 'Period', 2, 'TimerFcn', @(~, ~) refresh);
fig.CloseRequestFcn = @(~, ~) closeGui;
start(t);

    function apply(I)
        guard(@() ps.setCurrent(I));
    end
    function setVLimit(s)
        try
            ps.vLimit = s.Value;
            ps.setCurrent(setField.Value);   % re-send so the new compliance takes effect
            status.Text = '';
        catch err
            status.Text = err.message;
            s.Value = ps.vLimit;
        end
    end
    function toggle(v)
        if v == "On"; guard(@ps.on); else; guard(@ps.off); end
    end
    function refresh
        if ps.isBusy || ~isvalid(fig); return; end
        try
            if ViewLaser.timingSensitiveRunIsOn(); return; end
        catch       % standalone use without the lab code on the path
        end
        try
            iLabel.Text = sprintf('%.4f', ps.current);
            vLabel.Text = sprintf('%.4f', ps.voltage);
            outSwitch.Value = onOff(ps.isOn);   % follows changes made from a script
        catch err
            status.Text = err.message;
        end
    end
    function guard(fn)
        try
            fn();
            status.Text = '';
        catch err
            status.Text = err.message;
        end
    end
    function closeGui
        stop(t); delete(t); delete(fig);
    end
end

function s = onOff(tf)
if tf; s = 'On'; else; s = 'Off'; end
end
