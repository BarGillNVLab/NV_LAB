classdef AomDummy < LaserPartAbstract
    %AOMDUMMY dummy aom in which everything works
    
    properties
        canSetValue = true;
        canSetEnabled = true;
    end
    
    properties (Access = private)
        valuePrivate = 0;
        enabledPrivate = false;
    end
    
    methods
        % constructor
        function obj = AomDummy(name)
            obj@LaserPartAbstract(name);
        end
    end
    
    methods (Access = protected)
        function setEnabledRealWorld(obj, tf)
            obj.enabledPrivate = tf;
        end
        
        function setValueRealWorld(obj, val)
            obj.valuePrivate = val;
        end
        
        function val = getValueRealWorld(obj)
            % Gets the voltage value from physical laser part
            val = obj.valuePrivate;
        end
        
        function tf = getEnabledRealWorld(obj)
            % Returns whether the physical laser part is on (true) or off (false)
            tf = obj.enabledPrivate;
        end
    end
        
end