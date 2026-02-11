classdef ElliptecController < handle
    %ELLIPTECCONTROLLER Summary of this class goes here
    
    properties
        port
        device
        deviceID = '' % Optional , Unique Char ID for the device on Bus ('0','1'...)
        ownsPort = false % Track the instance that created the port
        encoderMax = 143280; %full rotation in encoder units (0-143280)
    end
    
    methods

        function obj = ElliptecController(portName,deviceID,existingSerial)
            if nargin < 2
                deviceID = '';
            end
            if nargin < 3
                existingSerial = [];
            end
            obj.port = portName;
            obj.deviceID = deviceID;
            
            if isempty(existingSerial)
                obj.device = serialport(portName,9600);
                configureTerminator(obj.device,"CR"); % CR = Carriage Return ('\r')
                flush(obj.device); %Clears Buffers
                obj.ownsPort = true;
            else
                obj.device = existingSerial;
                obj.ownsPort = false;
            end
            pause(0.2);
        end
        
        function delete(obj)
            if  obj.ownsPort && ~isempty(obj.device)
                clear obj.device; %cleanup serial object
            end
        end


        function send(obj,cmd)
            fullCmd = [obj.deviceID cmd]; %adds deviceID prefix
            writeline(obj.device,fullCmd); % Sends command with terminator \r
            pause(0.05); % lets the device process
        end

        function resp = read(obj)
            resp = readline(obj.device); %Reads one line of response
        end

        function home(obj)
            obj.send('ho0'); % hw = home the motor
            pause(5); % ewair for home to finish (no response)
        end

        function moveToAngle(obj, angle_deg)
            %Convert desired angle to encoder unit
            enc = round((mod((angle_deg),360) / (360)) * obj.encoderMax);
            enc = mod(enc, obj.encoderMax);
            hexStr = upper(dec2hex(typecast(int32(enc),'uint32'),8));
            obj.send(['ma' hexStr]);
        end

        function moveBy(obj, angle_deg)
            %Convert desired angle to encoder unit
            enc = round((mod((angle_deg),360) / (360)) * obj.encoderMax);
            enc = mod(enc, obj.encoderMax);
            hexStr = upper(dec2hex(typecast(int32(enc),'uint32'),8));
            obj.send(['mr' hexStr]);
        end

        function angle_deg = getAngle(obj)
            flush(obj.device);
            obj.send('gp') % get position
            try
                resp = obj.read(); %Read Response
                if isstring(resp), resp = char(resp); end
                if startsWith(resp(2:end),'P')
                    hexstr = resp(4:end);
                    raw = uint32(hex2dec(hexstr));
                    if bitget(raw,32)
                        raw = typecast(uint32(raw),'int32');
                    end
                    pos = double(raw);
                    angle_deg = mod(pos/obj.encoderMax * 360,360);
                else

                    error('Unexpected Response: %s', resp);
                end
            catch e
                warning(e.identifier,"Failed to read position: %s", e.message);
                angle_deg = NaN;
            end
        end

        function resp = sendRead(obj,cmd)            
            writeline(obj.device,cmd); % Sends command with terminator \r
            pause(0.05); % lets the device process 
            resp = readline(obj.device); %Reads one line of response
            disp(resp)
        end
    end
end

