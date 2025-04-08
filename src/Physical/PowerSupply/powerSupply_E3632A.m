classdef powerSupply_E3632A < powerSupply

    properties (Constant)
        BAUD_RATE = 9600;
    end

    methods
        
        function obj = powerSupply_E3632A(name, address)
            obj@powerSupply(name, address);
            obj.channels = [];
            obj.ranges = ["P15V", "P30V"];
            obj.minCurrent = [0, 0];
            obj.maxCurrent = [7, 4];
            obj.minVoltage = [0, 0];
            obj.maxVoltage = [15, 30];
            
            obj.mode = "current";
            obj.updateParameters;
        end
        
        function initilize(obj, address)
            obj.id = serialport(address, obj.BAUD_RATE);
        end
        
        function connect(obj)
        end
        
        function closeConnection(obj)    
            obj.id = '';
        end
        
        function reset(obj)
            obj.sendCommand('*RST');
            obj.updateParameters;
        end
        
        function setCurrent(obj, I, channel)
            obj.checkCurrentLim(I, channel);
            if strcmp(obj.mode, 'current')
                obj.sendCommand(sprintf('APPL MAX, %s', num2str(I)));
            end
            obj.current = I;
        end
        
        function I = getCurrent(obj, channel)
            % for some reason the command 'Measure' does non worked
            I = 0;
            % I = str2double(obj.sendCommand('MEAS:CURR?'));
        end

        function setVoltage(obj, V, channel)
            if ~exist('channel', 'var'); channel = []; end;
            obj.checkVoltageLim(V, channel);
            if strcmp(obj.mode, 'voltage')
                obj.sendCommand(sprintf('APPL %s, MAX', num2str(V)));
            end
            obj.voltage = V;
        end
        
        function V = getVoltage(obj, channel)
            % for some reason the command 'Measure' does non worked
            V = 0;
            % V = str2double(obj.sendCommand('MEAS:VOLT?'));
        end
        
        function setMode(obj, mode, channel)
            % This power supply doesn't have 'mode' current/voltage.
            % In a given resistent the lowest one is the mode and the highest is the limit.
            % Here we stored internal 'mode' value and assiged the other parameter to maximum.
            if ~exist('channel', 'var'); channel = []; end
            obj.checkMode(mode);
            obj.mode = mode;
            if strcmp(mode, 'current')
                obj.setCurrent(obj.current, channel);
            else
                obj.setVoltage(obj.voltage, channel);
            end
        end
        
        function m = getMode(obj, channel)
            m = obj.mode;
        end
        
        function setRange(obj, range, channel)
            if ~exist('channel', 'var'); channel = []; end
            obj.checkRange(range, channel);
            obj.sendCommand(sprintf('VOLT:RANG %s', num2str(range)));
            obj.range(1) = range;
        end
        
        function r = getRange(obj, channel)
            r = obj.sendCommand('VOLT:RANG?');
        end
        
        function output(obj, state, channel)
            if ~exist('channel', 'var'); channel = []; end
            obj.checkOutput(state);
            obj.sendCommand(sprintf('OUTP %s', obj.booltoOnOff(state)));
        end
        
        function o = getOutput(obj, channel)
            % output state in this power supply is same for all channels
            o = obj.sendCommand('OUTP?');
        end
        
        function relay(obj, state)
            obj.checkOutput(state);
            obj.sendCommand(sprintf('OUTP %s', upper(state)));
        end
        
        function answer = sendCommand(obj, what)
            try
                writeline(obj.id, what);
            catch
                % For some reason, the connection sometimes closes; we open it and try again
                obj.id = serialport(address);
                writeline(obj.id, what);
                pause(0.5);
            end
            if contains(what, '?')
                answer = readline(obj.id);
            end
            if ~contains(what, 'ERR')
%                 obj.checkError;
            end
        end
        
        function checkError(obj)
            err = obj.sendCommand('SYST:ERR?');
            if length(err) ~= 15 || ~strcmp(err(1:13),'+0,"No error"')
                try
                    obj.close
                catch
                    err = [err, '\nDevice connection could not be closed!'];
                end
                error('Error in E3632A power supplier:\n%s', err)
            end
        end
        
    end
    
    
    methods (Static)
        function powerSupplyObj = create(powerSupplyName, powerSupplyStruct)
            address = powerSupplyStruct.address;
            powerSupplyObj = powerSupply_E3632A(powerSupplyName, address);
        end
    end


    
end