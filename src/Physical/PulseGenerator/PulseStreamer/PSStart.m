classdef PSStart < uint8
    % PSStart enumeration
    % The output sequence of the Pulse Streamer can be started either
    % immediately, with a software trigger (obj.startNow) or with an
    % external hardware trigger.
    enumeration
        Immediate (0)
        Software (1)
        Hardware (2)
    end
end