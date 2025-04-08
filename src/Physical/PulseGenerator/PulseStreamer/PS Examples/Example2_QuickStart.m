%% Example 2: Creating and streaming a sequence
% This example shows a typical workflow on how to create sequences and 
% stream them with the Pulse Streamer.
% You can see generated signals with an oscilloscope connected to digital
% channels 0,1,2 and analog channel 0. Please use 50 Ohm termination 
% to avoid overshoot and ringing.

clear all;

% Add API functions to MATLAB path
addpath('PulseStreamer');

% Hostname or IP address of the pulse streamer
ipAddress = 'pulsestreamer';

% Connect to Pulse Streamer
ps=PulseStreamer(ipAddress);

% Make sure that Pulse Streamer is in the default state
ps.reset(); 

%% Define signal patterns
% Pattern must be a cell array in which first column holds durations and
% second column holds output values

% Laser control pattern
pattLaser = {20000, true; 50000, false; 10000, true; 10000, false};

% Trigger signal pattern
pattTrigger = {250000, true; 50000, false};

% Voltage pattern 
% This pattern will be used for analog signal generation so the values are
% real numbers
pattVolt = {50000, 0.1; 50000, 0.2; 50000, 0.3; 50000, 0.4; 50000, 0.5; 0, 0}; 

%% Build sequence
% Here the earlier defined patterns are assigned to Pulse Streamer outputs
% and stacked into a sequence.

% Give names to channels
TRIGGER = 0;
LASER_532 = 1;
LASER_1064 = 2;
CONTROL_VOLTAGE = 0; % Analog

% Create sequence builder object
builder = PSSequenceBuilder(ps);

% Assign patterns to channels. The same pattern can be assigned to any 
% number of channels. 
builder.setDigital(LASER_532, pattLaser);
builder.setDigital(LASER_1064, pattLaser);
builder.setDigital(TRIGGER, pattTrigger);
builder.setAnalog(CONTROL_VOLTAGE, pattVolt);

% Build the sequence. The result is an object of class PSSequence
sequence = builder.buildSequence();

%% Sequence class supports a number of useful operations.
% Sequences can be repeated and concatenated in arbitrary order as well as
% visualized.

% Print sequence duration
fprintf('Sequence duration before repetition: %d [ns]\n', sequence.getDuration())

% Repeat sequence twice by duplicating sequence data in memory
sequence = sequence.repeat(2); 

% Print sequence duration
fprintf('Sequence duration after repetition: %d [ns]\n', sequence.getDuration())

% Visualize sequence
sequence.plot();

%% Send prepared sequence to the Pulse Streamer

nRuns = -1; % number of times to stream the sequence. -1: means repeat indefinitely
finalState = OutputState(0,0,0); % final state after the sequence streaming is completed

% In the default state, the Pulse Streamer will start generating signals 
% immediately after calling the "stream()" method.
ps.stream(sequence, nRuns, finalState);

