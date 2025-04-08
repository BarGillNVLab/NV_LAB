classdef PSSerial < uint8
    % PSSerial enumeration
    % defines the type of serial number to request from the Pulse Streamer
    
    enumeration
        Serial  (0) % Serial number of the device
        MAC     (1) % MAC address of the ethernet interface
    end
end

