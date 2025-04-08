%% Alignment
m = AWGExpHelmholtzAlignment;
m.averages = 3;
m.repeats = 10;
m.amplitude = -10;
m.isTracking = 0;
m.nChannels = 2;
m.detectionDuration = 100; m.referenceDetectionDuration = m.detectionDuration;
m.AWGorSRSswitch = 0;

m.mirrorSweepAround = [];%2870;
% m.frequency = 2766 + (-40:2:40);
m.frequency = 2840 + (-40:2:40);
% m.scan_axis = 'Bphi';
m.scan_axis = 'Btheta';
m.scan_values = 44:1:48;
m.widthPlot = 1;
m.runScan;

%% ESR to get an accurate resonance
a = AWGExpESR;
a.frequency = 2766 + (-40:2:40);
% a.frequency = 2810 + (-20:2:20);
% a.frequency = 2700:3:2870;
a.averages = 3;
a.repeats = 10;
a.amplitude = -10;
a.isTracking = 0;
a.nChannels = 2;
a.detectionDuration = 100; a.referenceDetectionDuration = a.detectionDuration;
a.AWGorSRSswitch = 0;
a.mirrorSweepAround = [];
a.run;
f0 = ESRfit(a, 0, 0, 1);
