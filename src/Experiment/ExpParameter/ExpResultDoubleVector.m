classdef (Sealed) ExpResultDoubleVector < ExpParameter
    %EXPRESULTDOUBLEVECTOR 
    
    properties (SetAccess = protected)
        type = ExpParameter.TYPE_RESULT
    end
    
    methods
        function obj = ExpResultDoubleVector(name, value, sterr, units, expName, desc)
            if ~exist('value', 'var'); value = []; end
            if ~exist('sterr', 'var'); sterr = []; end
            if ~exist('units', 'var'); units = ''; end
            if ~exist('expName', 'var'); expName = ''; end
            if ~exist('desc', 'var'); desc = ''; end
            obj@ExpParameter(name, value, sterr, units, expName, desc);
        end
    end
    
    methods (Static)
        function isOK = validateValue(value)
            % Check if a new value is valid, according to obj.type
            isOK = isnumeric(value) && ~isscalar(value);
        end
    end
    
end

