classdef PSTriggerStart < uint8
    % PSTriggerStart defines how to start sequence streaming.
    %
    % The output sequence of the Pulse Streamer can be started
    % immediately, with software or different edges in the 
    % hardware trigger mode.
    
    enumeration
        Immediate           (0) % Trigger immediately after sequence is uploaded.
        Software            (1) % Trigger by calling "startNow()" method.
        HardwareRising      (2) % External trigger on rising edge.
        HardwareFalling     (3) % External trigger on falling edge.
        HardwareBoth        (4) % External trigger on rising and falling edges.
    end
end

