classdef EventExtraImageUpdated < handle
    %EVENTEXTRASCANUPDATED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        image        % matrix of double. Scan results
        phAxes      % a vector or a cell of 2 vectors
        botLabel    % the label to show below
        leftLabel   % the label to show on the left
    end
        
    methods
        function obj = EventExtraImageUpdated(image, phAxes, botLabel, leftLabel)
            obj@handle;
            obj.image = image;
            obj.phAxes = phAxes;
            obj.botLabel = botLabel;
            obj.leftLabel = leftLabel;
        end
        
        function phAxis = getFirstAxis(obj)
            if iscell(obj.phAxes)
                phAxis = obj.phAxes{1};
            else
                phAxis = obj.phAxes;
            end
        end
        
        function phAxis = getSecondAxis(obj)
            phAxis = obj.phAxes{2};
        end
        
    end
    
end