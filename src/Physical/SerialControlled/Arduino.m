classdef Arduino < BaseObject & SerialControlled
    
    properties (Access = private)
        delayTime = 0.3;
    end
    
    properties (Constant)
        NAME = 'Arduino'
        
        PORT = 'COM19'
    end
    
    methods
        function obj = Arduino
            % Default constructor
            obj@SerialControlled(Arduino.PORT);
            obj@BaseObject(Arduino.NAME);
            BaseObject.addObject(obj);
            
            obj.baudRate = 9600;
            obj.connect;
        end
        
        function connect(obj)
            obj.open;
            pause(obj.delayTime);
            obj.keepConnected = true;
        end
        
        function disconnect(obj)
            obj.close;
        end
        
        function initializeXOR(obj)
            % Sends initialization flag
            query(obj, 'init');
        end
        
        function highXOR(obj)
            % Sends high XOR flag
            query(obj, 'high');
        end
        
        function debugX(obj)
            % Turn on debug mode on axis X
            query(obj, 'debugX');
        end
        
        function debugY(obj)
            % Turn on debug mode on axis Y
            query(obj, 'debugY');
        end
        
        function debugZ(obj)
            % Turn on debug mode on axis Z
            query(obj, 'debugZ');
        end
        
        function debugTime(obj)
            % Turn on debug time mode
            query(obj, 'debugTime');
        end
        
        function debugTimeOFF(obj)
            % Turn off debug time mode
            query(obj, 'debugTimeOff');
        end
        
        function output = getState(obj)
            % Get current debug state
            output = query(obj, 'getState');
        end
        
        function debugOff(obj)
            % Turn debug mode off
            query(obj, 'debugOff');
        end
    end
end