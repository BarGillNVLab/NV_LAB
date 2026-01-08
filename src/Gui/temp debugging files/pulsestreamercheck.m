import PulseStreamer.PulseStreamer
% Create Pulse Streamer object
ps = PulseStreamer('132.64.56.157');

% Set software trigger mode
% disp(ps.getTriggerStart());
PSTriggerStart.Software;

% Define time durations in nanoseconds
t1 = 10e6;       % 10 microseconds = 10,000 ns
t2 = 15e6;       % 15 milliseconds = 15,000,000 ns

% Create pulse sequence
seq = ps.createSequence();

% Step 1: Channel 1 ON
pattern1 = {t1,1; t2, 0; t1, 1;t2,1};
seq.setDigital(1, pattern1);

% Step 2: Channels 1,2,5 ON
pattern2 = {t1,0; t2, 1; t1, 0;t2,0};
seq.setDigital(2, pattern2);

% Step 3: Channel 1 ON
pattern3 = {t1,0; t2, 1; t1, 0;t2,1};
seq.setDigital(5, pattern3);


% Load sequence
ps.stream(seq, 50);  % 1 repeat

disp(ps.isStreaming());

% Start with software trigger
ps.startNow();

disp(ps.isStreaming());
