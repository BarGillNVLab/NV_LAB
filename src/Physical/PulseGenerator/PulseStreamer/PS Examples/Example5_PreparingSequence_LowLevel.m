%% Example 5: Creating a sequence using low-level functions
% This example reveals more details on internal working of Pulse Streamer's 
% API for MATLAB. 
% You can see generated signals with an oscilloscope connected to digital
% channels 0,1,2 and analog channel 0. Please use 50 Ohm termination 
% to avoid overshoot and ringing.

clear all;
% Add API functions to MATLAB path
addpath('PulseStreamer');

%
% Typical workflow with new API is to define your desired signals patterns
% one-by-one for each channel and use "PSSequenceBuilder" to set the channel
% at which the patterns shall be streamed.
% "PSSequenceBuilder" takes care of the pattern timing alignment and
% ensures that each pattern is resampled to the common timebase, i.e.
% common "ticks" for each pattern.
%
% Ultimately the "PSSequenceBuilder.buildSequence()" must be called in 
% order to produce the sequence. The returned value will be of class
% "PSSequence".
%
% PSSequence object is then acceptable by the "PulseStreamer.stream()"
% method and also supports a number of other useful methods, like 
% concatenating, repeating, or displaying sequence data.  
%
% The RAW values of a "PSSequence" object can be accessed via class
% read-only properties such as:
%  PSSequence.ticks - Durations of each state/level
%  PSSequence.digi  - Digital channels data
%  PSSequence.ao0   - Analog channel 0
%  PSSequence.ao1   - Analog channel 1

% A PSSequence object can be created manually, without using 
% PSSequenceBuilder class. For that a correctly shaped array must be
% prepared and provided on creation of the PSSequence object as shown
% below.

ticks = [1000, 2000, 1000, 3000]; % Durations for each level [ns]
digi =  [   0,    1,    3,    1]; % integer number as bit mask. Each bit coresponds to digital output  
ao0  =  [   0,  0.6,  0.3,  0.1]; % Analog out 0 [Volts]
ao1  =  [   0, -0.3, -0.2, -0.1]; % Analog out 1 [Volts]

RLE = [ticks(:), digi(:), ao0(:), ao1(:)]; % This is in fact Run-Length Encoded data of the sequence

% Create PSSequence object using its constructor
sequence = PSSequence(RLE); 

% Feel free to confirm that the data in the "sequence" is the same as we
% provided. Uncomment the following lines to test.
%  all(sequence.ticks(:) == ticks(:))
%  all(sequence.digi(:) == digi(:))
%  all(sequence.ao0(:) == ao0(:))
%  all(sequence.ao1(:) == ao1(:))

% Visualize sequence data in a plot
plot(sequence); % the same as "sequence.plot();" 


%% Stream the sequence
% DHCP is activated in factory settings
% IP address of the pulse streamer (default hostname is PulseStreamer)
ipAddress = 'pulsestreamer';

% Connect to the pulse streamer
ps = PulseStreamer(ipAddress);

nRuns = 10000; % Repeat sequence 10000 times

% Upload and stream the sequence
finalState = sequence.getLastState(); % final state is the last state in the sequence
ps.stream(sequence, nRuns, finalState);
% final state will be OutputState(1, 0.1, -0.1), last state of the sequence

% If finalState parameter is excluded from the "stream" method call, then 
% the default OutputState(0,0,0) will be used instead.
ps.stream(sequence, nRuns); % final state will be all zeros


