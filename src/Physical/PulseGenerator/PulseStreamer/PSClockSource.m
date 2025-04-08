classdef PSClockSource < uint8
    % PSClockSource enumeration.
    % Defines the source of the Pulse Streamer clock signal
    enumeration
        Internal    (0)   % Internal clock generator
        Ext125MHz   (1)   % External clock source of 125 MHz
        Ext10MHz    (2)   % External reference clock 10 MHz
    end
end

