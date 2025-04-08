classdef PSTriggerMode < uint8
    % PSTriggerMode defines how trigger is rearmed.
    % 
    % When TriggerMode == Single then sequence is streamed only once and
    % the trigger is not rearmed automatically. 
    % Trigger can be rearmed by uploading the sequence again or by calling
    % "PulseStreamer.rearm()" method.
    
    enumeration
        Normal  (0)  % Trigger is rearmed automatically.
        Single  (1)  % Trigger once only and do no not rearm automatically. Rearm via the rearm() method.
    end
end

