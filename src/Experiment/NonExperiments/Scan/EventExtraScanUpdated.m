classdef EventExtraScanUpdated < handle
    %EVENTEXTRASCANUPDATED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        scan        % matrix of double. Scan results
        scanExtraInfo % lifetime & G2 data, if available
        phAxes      % a vector or a cell of 2 vectors
        axesString  % vector of chars. Axes labels (for example 'zx' or 'y')
        stageName   % "string" (vector of chars). Name of scanning stage
        botLabel    % the label to show below
        leftLabel   % the label to show on the left
    end
        
    methods
        function obj = EventExtraScanUpdated(scan, phAxes, axesString, stageName, botLabel, leftLabel, scanExtraInfo)
            obj@handle;
            obj.scan = scan;
            obj.phAxes = phAxes;
            obj.axesString = axesString;
            obj.stageName = stageName;
            obj.botLabel = botLabel;
            obj.leftLabel = leftLabel;
            if exist('scanExtraInfo', 'var')
                obj.scanExtraInfo = scanExtraInfo;
            end
        end
        
        function phAxis = getFirstAxis(obj)
            if iscell(obj.phAxes)
                phAxis = obj.phAxes{1};
            else
                phAxis = obj.phAxes;
            end
        end
        
        function phAxis = getSecondAxis(obj)
            if ~iscell(obj.phAxes) || obj.dimNumber ~= 2
%                 EventStation.anonymousWarning('asking for second axis when no such exist! answer will be a 0x0 vector')
                phAxis = [];
            else
                phAxis = obj.phAxes{2};
            end
            
        end
        
        function num = dimNumber(obj)
            % Dimensions of scan
            num = length(obj.axesString);
        end
    end
    
end