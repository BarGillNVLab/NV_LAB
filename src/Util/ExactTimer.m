classdef ExactTimer < handle
    %EXACTTIMER Customized timer, which gives 0 at first call
    
    properties (Access = private)
        mTimer = []     % Timer object. Initialized as empty, meaning that 
                        % timing has not started
    end
    
    methods
        function obj = ExactTimer()
            obj@handle;
        end
        
        function t = toc(obj)
            % By using this function we get time 0 for the first time the
            % timer is run (At the beginning of an experiment, for
            % example), and not the few msec it gives otherwise
            if isempty(obj.mTimer)
                t = 0;
                obj.mTimer = tic;
            else
                t = toc(obj.mTimer);
            end
        end
        
        function reset(obj)
            obj.mTimer = [];
        end
    end
    
end

