classdef PSTriggerEdge < uint8
    % PSTriggerEdge enumeration
    % The output sequence of the Pulse Streamer can be started with
    % different edges in the hardware trigger mode.
    enumeration
        Rising (0)
        Falling (1)
        Both (2)
    end
end

