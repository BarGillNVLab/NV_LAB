classdef (Sealed) ExpParamLogical < ExpParameter
    %EXPPARAMLOGICAL 
    
    properties (SetAccess = protected)
        type = ExpParameter.TYPE_LOGICAL;
    end
   
    methods
        function obj = ExpParamLogical(name, value, expName, desc)
            if ~exist('value', 'var'); value = []; end
            if ~exist('expName', 'var'); expName = ''; end
            if ~exist('desc', 'var'); desc = ''; end
            obj@ExpParameter(name, value, [], [], expName, desc);
        end
        
    end
    
    methods (Static)
        function isOK = validateValue(value)
            % Check if a new value is valid, according to obj.type
            isOK = ValidationHelper.isTrueOrFalse(value);
        end
    end
    
end

