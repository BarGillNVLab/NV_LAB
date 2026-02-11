% goal: reduce console time to get max or in power (optical attenuator)
mgr = ElliptecManager()

% how to add each mirror
mgr.addDevice('COM6','1')
mgr.addDevice('COM6','2')

% get current angle
mgr.getAngle('COM6','1') % infront of GT
mgr.getAngle('COM6','2') % infront of PBS


% % set max power
% mgr.moveToAngle('COM6','1',85) % GT
% pause(0.5)
% mgr.moveToAngle('COM6','2',63) % PBS
% pause(0.5)


% set min power
mgr.moveToAngle('COM6','1',20) % GT
pause(0.5)
mgr.moveToAngle('COM6','2',18) % PBS
pause(0.5)

% get current angle
GT_ang = mgr.getAngle('COM6','1');
disp(sprintf("Lambda/2 infornt of GT: %.2f degrees",GT_ang));

PBS_ang = mgr.getAngle('COM6','2');
disp(sprintf("Lambda/2 infornt of PBS: %.2f degrees",PBS_ang));