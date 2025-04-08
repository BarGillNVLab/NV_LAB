classdef P < PH   
    % P class (P means Pulse) combines a duration (ticks) and an output
    % state. 
    % 
    % THIS CLASS IS DEPRECATED!
    % Further use of P and PH classes is
    % discouraged as they will be removed in the future.
    %
    % INSTEAD, USE: "PSSequenceBuilder" to create sequences.
    %
    % For compatibility with your existing code, we provide conversion 
    % function "convert_PPH_to_PSSequence.m". 
    % Use it to convert an array of P/PH objects to PSSequence object.
    % For example see: "Example2_QuickStart_migration.m"
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
                        
            assert(all(ismember(digchan,0:7)));
            mask = uint8(sum(pow2(unique(digchan))));
            
            obj = obj@PH(ticks, mask, analog0, analog1);
        end
    end
end