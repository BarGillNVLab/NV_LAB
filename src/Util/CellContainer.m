classdef CellContainer < handle
    %CELLCONTAINER class to wrap a cell array, so that it inherit from handle
    %   used a lot by classes that need to store a cell array in a
    %   singleton and dont want to create a whole singleton object for that
    
    properties
        cells
        % cell array
    end
    
    methods
        function obj = CellContainer
            obj@handle;
            obj.cells = {};
        end
    end
    
end

