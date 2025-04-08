%% This example shows how to migrate the API v0.9 to v1.0
% Since version 0.9 the API of the Pulse streamer has significant changes
% and improvements. New functionality was also added to the firmware.
% 
% This example shows the old code in comments and tells how it shall be 
% modified in order to work with the new API.

clear
fprintf('Example to show the main functionallity of the PulseStreamer\n\n');
% experiment settings 
% the durations/names are just examples
SHUTTER = 0;
LASER = 1;
CAMERA = 2;
FIXED_FREQUENCY = 7;

preopenTimeShutter = 1000; %ns
laserPulseDuration = 2000; %ns
delayBeforeCameraTrigger = 1000; % ns
cameraExposureTime = 3000; % ns
totalCycleDuration = 10 * 1000; % ns

%% Connect to Pulse Streamer
% This part remains valid for API v1.0

fprintf('Connect to the Pulse Streamer\n\n');
% set path to matlab library
addpath('PulseStreamer');
% DHCP is activated in factory settings of the Pulse Streamer. The hostname
% of the Pulse Streamer is Pulse Streamer
ipAddress = 'PulseStreamer';
% connect to the pulse streamer
ps = PulseStreamer(ipAddress);

%% Generate sequence
%
% MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW %
%
% The way how sequences are generated has changed in the v1.0. P and PH
% classes are deprecated. For easier migration we provide modified 
% versions of P and PH classes and a function that converts P and PH
% objects to a PSSequence object. Further use of P and PH classes is 
% discouraged as they will be removed in the future. 


fprintf('A typical sequence is generated on channel 0:2\n\n');
%%% successive programming of the output channels
% this sections shows how to program a sequence with pulses defined one
% after the next one
% The class P is the class to define pulses

sequenceExperiment = [];
sequenceExperiment = sequenceExperiment + P(preopenTimeShutter, SHUTTER);
sequenceExperiment = sequenceExperiment + P(laserPulseDuration, [LASER, SHUTTER]);
sequenceExperiment = sequenceExperiment + P(delayBeforeCameraTrigger, []);
sequenceExperiment = sequenceExperiment + P(cameraExposureTime, CAMERA);
durationWithoutPadding = P.duration(sequenceExperiment);
fprintf('Duration without padding:   %d ns\n', durationWithoutPadding);
sequenceExperiment = sequenceExperiment + P(totalCycleDuration - durationWithoutPadding, []);
durationWithPadding = P.duration(sequenceExperiment);
fprintf('Duration with padding:     %d ns\n', durationWithPadding);

fprintf('\nAn aligned but independent fixed frequency is applied on channel 7.\n\n');
%%% independent programming of the output channels
% Sometimes it is more conveniant to program the channels independently.
% For example, we want to have a fixed frequency applied on channel FIXED_FREQUENCY
period = 1000; % 100 kHz
sequenceFrequency = P(period / 2, FIXED_FREQUENCY) + P(period / 2, []);
% This sequence must be repeated for the whole cycle duration of the
% sequence defined above
sequenceFrequency = sequenceFrequency * (totalCycleDuration / period);
% now union these two independent sequences
sequence = P.union(sequenceExperiment, sequenceFrequency);
% Here the sequences have the very same length. If this is not the case
% shorter sequences are padded with the very last pulse programmed


%% Streaming the sequence
% The API v1.0 has a number of modifications in the stream method and the way
% Pulse Streamer is triggered. 
%
% MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW %
%
%OLD:
% runs = -1; %0 or -1 means that the sequence is repeated until the power is turned off
%NEW: 
% runs>=0 means sequence is uploaded to memory and streamed 0 or more times
runs = -1;  % -1 means that the sequence is repeated until the power is turned off

outputZero = OutputState(0,0,0);

%
% MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW % 
%
% The sequence should start immediately after the upload (no hardware or software trigger)
% OLD:
%   start = PSStart.Immediate;
% NEW:
% Start trigger shall be set by using method "setTrigger(start, mode)"
start = PSTriggerStart.Immediate; % start immediately after sequence upload
mode = PSTriggerMode.Single; % automatic rearm off. To get old behavior, auto rearm must be disabled.
ps.setTrigger(start, mode); % send trigger settings to the Pulse Streamer

fprintf('Send the generated sequences to the Pulse Streamer and start the output.\n\n');

%
% MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW %
%
% send the data to the Pulse Streamer and start the sequence
% OLD:
%  ps.stream(sequence, runs, outputZero, outputZero, outputZero, start);
% NEW:
% method "stream" has new signature: stream(sequence, nRuns, finalState)
% where "sequence" MUST BE an object of class "PSSequence".
%
% You can convert an array of P/PH objects created above into 
% PSSequence object using the following compatibility function.
sequence = convert_PPH_to_PSSequence(sequence); % This is REQUIRED! % MIGRATION: CONVERSION FUNCTION

ps.stream(sequence, runs, outputZero);
fprintf('Output is active.\n');
