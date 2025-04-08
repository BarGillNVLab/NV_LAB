%% Callback function for example 3.

function Example3_VariousCallbackMethod(pulseStreamer)
    % this is the test callback function for testPulseStreamer - case 4
    disp('hasFinishedCallback - Pulse Streamer finished.');
    
    % You have access to the calling Pulse Streamer object.
    % Here we just print the state 
    pulseStreamer.status();
end

