classdef HandleWrapper < handle
    %HANDLEWRAPPER Creates handles for required objects
    
    properties
        wrapped
    end
    
    methods
        function obj = HandleWrapper(referenced)
            obj@handle;
            obj.wrapped = referenced;
        end
    end
    
end

