% This script demonstrates changes needed for making code written for old 
% API v0.9 work with new API v1.0.
clear
addpath('PulseStreamer');

ipAddress = 'PulseStreamer';

% connect to the pulse streamer
ps = PulseStreamer(ipAddress);

%% basic settings
outputZero = OutputState(0,0,0);
% initialOutputState = outputZero;   %OLD
finalOutputState = outputZero;
% underflowOutputState = outputZero; %OLD

% MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW %
%OLD: start = PSStart.Immediate;
start = PSTriggerStart.Immediate;
ps.setTrigger(start, PSTriggerMode.Single);

% settings for sequence generation
numberOfSequences = 10;
pulsesPerSequence = 100;
nRuns = 100;

disp(['Test performance for ' num2str(numberOfSequences * pulsesPerSequence * nRuns) ' of pulses in total.']);

fprintf('\n')

%% Generate sequences
%
% MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW %
%
% The way how sequences are generated has changed in the v1.0. P and PH
% classes are deprecated. For easier migration we provide modified 
% versions of P and PH classes and a function that converts P and PH
% objects to a PSSequence object. Further use of P and PH classes is 
% discouraged as they will be removed in the future. 

disp(['Generating ' num2str(numberOfSequences) ' sequences with ' num2str(pulsesPerSequence) ' PHs each, that means in total ' num2str(numberOfSequences * pulsesPerSequence) ' PHs.']);
tic 
% we first create "numberOfSequences" different sequence groups (S1, S2, ...)"
sequences = cell(1,numberOfSequences);        
for iSeq=1:numberOfSequences
    sequences{iSeq} = [];        
    for iPulse = 1:pulsesPerSequence
        % the content of the PHs is more or less arbitary
        sequences{iSeq} = sequences{iSeq} + PH(1000, mod(iPulse * iSeq, 256), 0, 0);
    end
end
toc

fprintf('\n')
% case one - output one sequences after another and loop this "nRuns" times
% (S1, S2, ...) * nRuns
disp(['a) Output one sequences after another and loop this ' num2str(nRuns) ' times.']);
disp(['Total number of pulses: ' num2str(numberOfSequences * pulsesPerSequence * nRuns)]);
disp(['The number of times all sequences are repeated are passed to the "stream" method, which is the most efficient way for repeating the whole sequence.']);
tic
runs = nRuns;
pSeq = [];
for iSeq=1:numberOfSequences
    pSeq = pSeq + sequences{iSeq};
end

% MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW %
% OLD: 
%   ps.stream(pSeq, runs, initialOutputState, finalOutputState, underflowOutputState, start);
% NEW:
% method "stream" has new signature: stream(sequence, nRuns, finalState)
% where "sequence" MUST BE an object of class "PSSequence".
%
% You can convert an array of P/PH objects created above into 
% PSSequence object using the following compatibility function.

pSeqNew = convert_PPH_to_PSSequence(pSeq); % This is REQUIRED! % MIGRATION: CONVERSION FUNCTION

ps.stream(pSeqNew, runs, finalOutputState); %NEW
toc

%%
% case two - output each sequence "nRuns" times. Then continue with the
% next sequence for "nRuns" times and so on...
% (S1*nRuns, S2*nRuns, ...)
fprintf('\n')
disp(['b) Output each sequence ' num2str(nRuns) ' times and continue with the next sequence the same way.']);
disp(['Total number of pulses: ' num2str(numberOfSequences * pulsesPerSequence * nRuns)]);
disp(['The repetition is build up with "*" which is slower compared to the method of a).'])
disp(['The advantage is that not only the whole sequence in total can be repeated, but also sub-sequences as shown here.']);
tic
pSeq = [];
for iSeq=1:numberOfSequences
    pSeq = pSeq + sequences{iSeq} * nRuns;
end
%
runs = 1;

% MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW % MIGRATION: NEW %
% OLD: 
%   ps.stream(pSeq, runs, initialOutputState, finalOutputState, underflowOutputState, start);
% NEW:
% method "stream" has new signature: stream(sequence, nRuns, finalState)
% where "sequence" MUST BE an object of class "PSSequence".
%
% You can convert an array of P/PH objects created above into 
% PSSequence object using the following compatibility function.

pSeqNew = convert_PPH_to_PSSequence(pSeq); % This is REQUIRED! % MIGRATION: CONVERSION FUNCTION

ps.stream(pSeqNew, runs, finalOutputState); %NEW
toc

