%% Start working
path = 'G:\My Drive\NV Lab\Setup 7\calibration\20250223 - with swithes\';
jsonLocation = [path, 'expProperties.json'];

main;
h = Helmholtz;
h.load([path, 'helmholtzState.mat']);
h.control('auto');

%% ESR zero field
h.control('off');
a = AWGExpESR;
a.frequency = 2870 + (-20:2:20);
a.repeats = 10;
a.averages = 10;
a.amplitude = -10;
a.isTracking = 0;
a.nChannels = 2;
a.detectionDuration = 100; a.referenceDetectionDuration = a.detectionDuration;
a.AWGorSRSswitch = 0;
a.run;

%% ESR with field
h.control('auto');
a = AWGExpESR;
a.frequency = 2766 + (-30:2:30);
% a.frequency = 2790 + (-30:1:30);
% a.frequency = 2700:3:2870;
a.averages = 1;
a.repeats = 10;
a.amplitude = -30;
a.isTracking = 0;
a.nChannels = 2;
a.detectionDuration = 100; a.referenceDetectionDuration = a.detectionDuration;
a.AWGorSRSswitch = 0;
a.run;
f0 = ESRfit(a, 0, 0, 1);

%% Alignment
m = AWGExpHelmholtzAlignment;
m.frequency = 2766 + (-20:1:20);
% m.frequency = 2810:2:2870;
m.averages = 1;
m.repeats = 10;
m.amplitude = -25;
m.isTracking = 0;
m.nChannels = 2;
m.detectionDuration = 100; m.referenceDetectionDuration = m.detectionDuration;
m.AWGorSRSswitch = 0;

m.widthPlot = 1;
m.scan_axis = 'Bphi';
m.scan_values = 46:1:50;

m.runScan;

%% Rabi
% AWG.sendCommand('awgcontrol:run:immediate');
b = AWGExpRabiCont;
% b = AWGExpRabi;
% b.isTracking = 0; b.nChannels = 2; b.GIMeas = 0; b.AWGorSRSswitch = 0; b.lastDelay = 1;
% b.referenceDetectionDuration = 0.5;
% b.detectionDuration = 0.5;
% b.timeDelay = 25e-6;
% b.frequency = 2762.9;

b.loadJsonParams('all', jsonLocation);

b.detectionDuration = 1;
b.referenceDetectionDuration = b.detectionDuration;

b.repeats = 1000;
b.averages = 1;
b.amplitude = -22;

b.tau = 0.005 : 0.01 : 0.3;

b.recordVoltageSpan = 1;

b.laserInitializationDuration = 15;

b.voltageOffset = [];
b.inputConfig = 'diff';
b.balancedSequence = 0;
spcm = getObjByName(Spcm.NAME);
spcm.balancedMeas = 0;
digi = getObjByName(Digitizer.NAME);
digi.maxVoltage = [0.1 0.1 0.1 10];
b.smallDelay = 0.5;
b.constantTime = 1;

% b.voltageOffset = [];
% b.inputConfig = 'norm';
% b.balancedSequence = 1;
% spcm = getObjByName(Spcm.NAME);
% spcm.diffrentialInput = 0;
% spcm.balancedMeas = 0;
% digi = getObjByName(Digitizer.NAME);
% digi.maxVoltage = [0.1 0.1 2 10];

b.run;
[pulses, f, T, coeff, ~, ~] = rabiFit(b, 0, 0, 1);

% pulses = round(pulses, 3);
% paramsStruct = struct('halfPiTime', pulses(1), 'piTime', pulses(2), 'threeHalvesPiTime', pulses(3));
% JsonInfoReader.setParams(paramsStruct, jsonLocation);

%% single drive
x0 = 0.016;
fRabi = 10;

s1 = AWGsensingSingleDriveCont;

s1.loadJsonParams('all', jsonLocation);

s1.repeats = 1000;
s1.averages = 1;
s1.amplitude = -22;
s1.rabiFreq1 = fRabi;
s1.signalRatio = -10;

s1.tau = x0 + (0 : 1/fRabi : 1.5);

s1.recordVoltageSpan = 1;

s1.laserInitializationDuration = 15;

s1.voltageOffset = [];
s1.inputConfig = 'norm';
s1.balancedSequence = 1;
spcm = getObjByName(Spcm.NAME);
spcm.diffrentialInput = 0;
spcm.balancedMeas = 1;
digi = getObjByName(Digitizer.NAME);
digi.maxVoltage = [0.1 0.1 2 10];
s1.smallDelay = 1;


% s1.voltageOffset = [];
% s1.inputConfig = 'norm';
% s1.balancedSequence = 1;
% spcm = getObjByName(Spcm.NAME);
% spcm.diffrentialInput = 0;
% spcm.balancedMeas = 0;
% digi = getObjByName(Digitizer.NAME);
% digi.maxVoltage = [0.1 0.1 2 10];

s1.run;
[pulses, f, T, coeff, ~, ~] = rabiFit(s1, 0, 0, 1);

% pulses = round(pulses, 3);
% paramsStruct = struct('halfPiTime', pulses(1), 'piTime', pulses(2), 'threeHalvesPiTime', pulses(3));
% JsonInfoReader.setParams(paramsStruct, jsonLocation);

%% Ico type one
w = AWGExpTypeOneBase;
w.isTracking = 0; w.nChannels = 2; w.GIMeas = 0; w.AWGorSRSswitch = 0; w.lastDelay = 1;
w.repeats = 3000;
w.averages = 3;
w.referenceDetectionDuration = 0.5;
w.detectionDuration = 0.5;
w.timeDelay = 20e-6;
w.frequency = 2756;
normalize = 0.1;
obj.segmentDurs = obj.segmentDurs * normalize/0.2;
dr.mormSegmentDuration=normalize;
w.EchoLike = 0;
w.amplitude = -3 + [0 0];
w.nRepetitions = 1:1:120;
w.RabiFreq = 14.0030;
w.RabiX0 = 0;

w.run;



%% Ico type droid
dr = AWGExpDroid;
dr.isTracking = 0; dr.nChannels = 2; dr.GIMeas = 0; dr.AWGorSRSswitch = 0; dr.lastDelay = 1;
dr.repeats = 3000;
dr.averages = 3;
dr.referenceDetectionDuration = 0.5;
dr.detectionDuration = 0.5;
dr.timeDelay = 20e-6;
dr.frequency = 2756;
normalize = 10;
dr.segmentDurs = dr.segmentDurs * normalize/0.02;
dr.mormSegmentDuration=normalize;
dr.EchoLike = 0;
dr.amplitude = -3 + [0 0];
dr.nRepetitions = 1:3:50;
dr.RabiFreq = 14.0;
dr.RabiX0 = 0;

dr.run;
%%
t = AWGExpT1;
t.isTracking = 0; t.nChannels = 2; t.GIMeas = 0; t.AWGorSRSswitch = 0; t.lastDelay = 1;
t.repeats = 500;
t.averages = 3;
t.tau = (1:3:70).^2;
t.referenceDetectionDuration = 0.5;
t.detectionDuration = 0.5;
t.timeDelay = 20e-6;
t.frequency = 2756;

t.amplitude = -3 + [0 0];
t.run;
