classdef powerSupply_E3631A < powerSupply
    
    methods
        
        function obj = powerSupply_E3631A(name, address)
            obj@powerSupply(name, address);
            obj.channels = ["P6V"; "P25V"; "N25V"];
            obj.ranges = [];
            obj.minCurrent = [0; 0; 0];
            obj.maxCurrent = [5; 1; 1];
            obj.minVoltage = [0; 0; -25];
            obj.maxVoltage = [6; 25; 0];
            
            obj.mode = ["current"; "current"; "current"];
            obj.updateParameters;
        end
        
        function initilize(obj, address)
            obj.id = visadev(address);
        end
        
        function connect(obj)
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
            obj.checkChannel(channel);
            o = obj.sendCommand('OUTP?');
        end
        
        function answer = sendCommand(obj, what)
            try
                writeline(obj.id, what);
                if contains(what, '?')
                    answer = readline(obj.id);
                else
                    answer = '';
                end
            catch
                warning('Error in sending command. Retrying...');
                writeline(obj.id, what);
                pause(0.5);
                if contains(what, '?')
                    answer = readline(obj.id);
                else
                    answer = '';
                end
            end
        end
        
        function checkError(obj)
            err = obj.sendCommand('SYST:ERR?');
            if length(err) ~= 15 || ~strcmp(err(1:13),'+0,"No error"')
                error('Error in E3631A power supply:\n%s', err);
            end
        end
        
    end
    
    methods (Static)
        function powerSupplyObj = create(powerSupplyName, powerSupplyStruct)
            address = powerSupplyStruct.address;
            powerSupplyObj = powerSupply_E3631A(powerSupplyName, address);
        end
    end
end
