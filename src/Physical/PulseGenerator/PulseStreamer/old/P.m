classdef P < PH   
    % P class (P means Pulse) combines a duration (ticks) and an output state.
    % the JSON string sent to the pulse streamer is calculated as soon as
    % a pulse is generated
    %
    % usage:
    % PH(100,[0,1],0,1)
    % defines a pulse of length 100ns
    % digital channels 0 and 1 are high (3 V)
    % analog channel 0: 0 V
    % analog channel 1: 1 V
    methods
        function obj = P(ticks, digchan, analog0, analog1)            
            if nargin < 2
                error('P must have at least the ticks ans digchan parameter');
            end
            if nargin < 3
                analog0 = 0;
            end
            if nargin < 4
                analog1 = 0;
            end
            mask = uint8(0);
            for c = digchan
                assert((0 <= c) && (c < 8))
                mask = bitset(mask, c+1);
            end
            obj = obj@PH(ticks, mask, analog0, analog1);
        end
    end
end