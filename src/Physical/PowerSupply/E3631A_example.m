% Example: step the current through the wire with the E3631A on COM5.
% Only one MATLAB object can hold COM5 at a time. To watch it in the GUI
% while this runs, call E3631A_gui(ps) on this same object.

ps = E3631A('COM5', 'P6V');     % P6V: 0-5 A, up to 6 V compliance
% ps.vLimit = 2;                % optional: lower the compliance voltage

currents = 0:0.1:0.5;           % [A]
ps.setCurrent(currents(1));
ps.on;
for I = currents
    ps.setCurrent(I);
    pause(1);                   % let it settle / do your measurement here
    fprintf('set %.3f A  ->  meas %.4f A, %.4f V\n', I, ps.current, ps.voltage);
end
ps.setCurrent(0);
ps.off;
clear ps                        % frees COM5 and returns the front panel to local
