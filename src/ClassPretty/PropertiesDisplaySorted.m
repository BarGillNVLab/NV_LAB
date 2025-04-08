classdef PropertiesDisplaySorted < handle & matlab.mixin.CustomDisplay
    %DISPLAYPROPERTIESSORTED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function obj = PropertiesDisplaySorted
            obj@handle;
            obj@matlab.mixin.CustomDisplay;
        end
        
        function stringCell = getAllConstProperties(obj)
            mc = metaclass(obj);
            allProps = mc.PropertyList;
            stringCell = sort({allProps(and(not([allProps.Hidden]) ,[allProps.Constant])).Name});
        end
        
        function stringCell = getAllPropertiesThisClassDefined(obj)
            mc = metaclass(obj);
            allProps = mc.PropertyList;
            stringCell = {};
            for prop = allProps'
                if eq(prop.DefiningClass,mc) && ~prop.Constant
                    stringCell{end + 1} = prop.Name;
                end
            end
        end
        
        function stringCell = getAllPropertiesInherited(obj)
            mc = metaclass(obj);
            allProps = mc.PropertyList;
            stringCell = {};
            for prop = allProps'
                if ~eq(prop.DefiningClass,mc) && ~prop.Constant
                    stringCell{end + 1} = prop.Name;
                end
            end
        end
        
        function stringCell = getAllNonConstProperties(obj)
            % This function does not return properties which
            % are private (that is, their getAccess == private)
            % If such functionality is needed, it should be probably be
            % implemented as a different function
            mc = metaclass(obj);
            allProps = mc.PropertyList;
            
            stringCell = sort({allProps(and(and(not([allProps.Hidden]) ,not([allProps.Constant])), ...
                not(strcmp({allProps.GetAccess},'private')))).Name});
        end
    end
    
    % from matlab.mixin.CustomDisplay
    % https://www.mathworks.com/help/matlab/matlab_oop/use-cases.html
    methods (Access = protected)
        function propgrp = getPropertyGroups(obj)
            % show only the NON-CONST properties
            propgrp = matlab.mixin.util.PropertyGroup(obj.getAllNonConstProperties);
        end
    end
end

