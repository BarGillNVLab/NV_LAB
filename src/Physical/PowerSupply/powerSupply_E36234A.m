classdef powerSupply_E36234A < powerSupply
    
    properties
        digitalState
    end

    methods
        
        function obj = powerSupply_E36234A(name, address)
            obj@powerSupply(name, address);
            obj.channels = ["CH1"; "CH2"];
            obj.ranges = [];
            obj.minCurrent = [0; 0];
            obj.maxCurrent = [10; 10];
            obj.minVoltage = [0; 0];
            obj.maxVoltage = [60; 60];
            
            obj.mode = ["current"; "current"];
            obj.digitalState = [0 0 0];
            obj.updateParameters;
        end
        
        function initilize(obj, address)
            obj.id = visadev(address);
        end
        
        function closeConnection(obj)    
            clear obj.id;
        end
        
        function reset(obj)
            obj.sendCommand('*RST');
            obj.updateParameters;
        end
        
        function setCurrent(obj, I, channel)
            obj.checkChannel(channel);
            obj.checkCurrentLim(I, channel);
            i = obj.chan2ind(channel);
            if strcmp(obj.mode(i), 'current')
                obj.sendCommand(sprintf('APPL %s, MAX, %s', channel, num2str(I)));
            end
            obj.current(i) = I;
            obj.sendCommand(sprintf('INST %s', channel));
        end
        
        function I = getCurrent(obj, channel)
            obj.checkChannel(channel);
            I = str2double(obj.sendCommand(sprintf('MEAS:CURR? %s', channel)));
        end

        function setVoltage(obj, V, channel)
            obj.checkChannel(channel);
            obj.checkVoltageLim(V, channel);
            i = obj.chan2ind(channel);
            if strcmp(obj.mode(i), 'voltage')
                obj.sendCommand(sprintf('APPL %s, %s, MAX', channel, num2str(V)));
            end
            obj.voltage(i) = V;
            obj.sendCommand(sprintf('INST %s', channel));
        end
        
        function V = getVoltage(obj, channel)
            obj.checkChannel(channel);
            V = str2double(obj.sendCommand(sprintf('MEAS:VOLT? %s', channel)));
        end
        
        function setMode(obj, mode, channel)
            % This power supply doesn't have 'mode' current/voltage.
            % In a given resistent the lowest one is the mode and the highest is the limit.
            % Here we stored internal 'mode' value and assiged the other parameter to maximum.
            obj.checkChannel(channel);
            obj.checkMode(mode);
            i = obj.chan2ind(channel);
            obj.mode(i) = mode;
            if strcmp(mode, 'current')
                obj.setCurrent(obj.current(i), channel);
            else
                obj.setVoltage(obj.voltage(i), channel);
            end
            obj.sendCommand(sprintf('INST %s', channel));
        end
        
        function m = getMode(obj, channel)
            obj.checkChannel(channel);
            i = obj.chan2ind(channel);
            m = obj.mode(i);
        end
        
        function setRange(obj, range, channel)
        end

        function connect(obj)
        end
        
        function r = getRange(obj, channel)
            r = '';
        end
        
        function output(obj, state, channel)
            obj.checkChannel(channel);
            obj.checkOutput(state);
            obj.sendCommand(sprintf('INST %s', channel));
            obj.sendCommand(sprintf('OUTP %s', obj.booltoOnOff(state)))
        end
        
        function o = getOutput(obj, channel)
            % output state in this power supply is same for all channels
            obj.checkChannel(channel);
            o = obj.sendCommand('OUTP?');
        end
        
        function answer = sendCommand(obj, what)
            writeline(obj.id, what);
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
                error('Error in E36234A power supplier:\n%s', err)
            end
        end
        
    end
    
    
    methods (Static)
        function powerSupplyObj = create(powerSupplyName, powerSupplyStruct)
            address = powerSupplyStruct.address;
            powerSupplyObj = powerSupply_E36234A(powerSupplyName, address);
        end
    end


    
end