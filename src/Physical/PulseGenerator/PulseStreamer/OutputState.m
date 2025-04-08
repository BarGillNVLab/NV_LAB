classdef OutputState
    % OutputState class combines three values (8 digital, 1 analog, 1 analog) 
    % which define the output on all ports 

    properties (Hidden, Constant)
       ticks = 0;  % always zero for this class
    end
    
    properties (SetAccess=private)
        digi  % binary encoded state of the digital outputs
        ao0   % output value of the first analog ao0 channel (range: +/-1V -0x7fff to 0x7fff)
        ao1   % output value of the first analog ao1 channel (range: +/-1V -0x7fff to 0x7fff) 
    end
    
    methods
        function obj = OutputState(digi, ao0, ao1)
            assert((0 <= digi) && (digi < 256))
            assert((-1 <= ao0) && (ao0 <= 1))
            assert((-1 <= ao1) && (ao1 <= 1))
            obj.digi = digi;
            obj.ao0 = ao0;
            obj.ao1 = ao1;
        end
    end
    
    methods (Static)
        function out = Zero()
            % Same as OutputState(0,0,0)
            out = OutputState(0,0,0);
        end
    end
end

