classdef Scope_MSO_X_3000 < Scope
    
    properties (Constant, Hidden)
        VISA_BRAND = 'ni';              % VISA brand
        BUFFER = 5e6;                   % buffer length
        REAL_TIME_MODE = 'rtime';
        SEGMENTED_MODE = 'segmented';
        TRIGGER_SOURCES = {'channel', 'digital', 'external', 'line', 'wgen'};
        TRIGGER_COUPLING_MODES = {'DC', 'AC', 'LFR'};
        MAX_SEGMENTS = 1000;
        COMM_DELAY = 0.1;
    end
    
    properties
        nPoints     % number of points to aquire
    end
    
    methods
        
        function obj = Scope_MSO_X_3000(name, address)
            obj@Scope(name, address);
            obj.nChannels = 4;
            obj.nPoints = 100;
        end
        
        function initilize(obj)
            obj.connect;
        end
        
        function connect(obj)
            if isempty(obj.v) || ~isvalid(obj.v)
                obj.v = visa(obj.VISA_BRAND, obj.address, 'InputBufferSize', obj.BUFFER, 'OutputBufferSize', obj.BUFFER);
            end
            if strcmp(obj.v.Status, 'closed')
                fopen(obj.v);
            end
        end
        
        function closeConnection(obj)    
            fclose(obj.v);
        end
        
        function reset(obj)
            obj.sendCommand('*RST');
        end
        
        function run(obj)
            obj.sendCommand(':run');
        end
        
        
        function answer = sendCommand(obj, what)
            try
                fprintf(obj.id, what);
            catch
                % For some reason, the connection sometimes closes; we open it and try again
                fopen(obj.id);
                fprintf(obj.id, what);
                pause(0.5);
            end
            if contains(what, '?')
                answer = fscanf(obj.id);
            end
        end
        
        function setNumSegments(obj, nSegments)
            if nSegments > obj.MAX_SEGMENTS
                error('Maximum sements in this scope is %d', obj.MAX_SEGMENTS)
            end
            command = sprintf(':acquire:segmented:count %d', nSegments);
            sendCommand(obj, command);
        end
        
        function aquasitionMode(obj, mode)
            if ~any(strcmpi(mode, {obj.SEGMENTED_MODE, obj.REAL_TIME_MODE}))
                error('no type of mode %s', mode);
            end
            command = sprintf(':acquire:mode %s', mode);
            sendCommand(obj, command);
        end
        
        function triggerSource(obj, source)
            if ~(contains(source, obj.TRIGGER_SOURCES))
                error('trigger source not avaliable')
            end
            command = sprintf(':trigger:edge:source %s', source);
            sendCommand(obj, command);
        end
        
        function triggerCoupling(obj, mode)
            if ~any(strcmpi(mode, obj.TRIGGER_COUPLING_MODES))
                error('trigger coupling mode not exist')
            end
            command = sprintf(':trigger:edge:coupling %s', mode);
            sendCommand(obj, command);
        end
        
        function commDelay(obj)
            % Communication Delay
            delay = tic;
            while toc(delay) < obj.COMM_DELAY
            end
        end
        
        function deviceReady(obj)
            % tests if the the previous overlapping command was executed
            timer = tic;
            while ~contains(query(obj.v, '*OPC?'), '1')
                obj.commDelay();
                if toc(timer) > obj.COMM_DELAY * 10
                    error('Scope time out - overlapping commands has not completed');
                end
            end
        end
        
        function timeScale(obj, scale)
            % scale: time/div in second
            command = sprintf('timebase:scale %d', scale);
            obj.sendCommand(command);
        end
        
        function acquisitionTime(obj, time)
            obj.timeScale(time/10);
        end
        
        function timeDelay(obj, time)
            command = sprintf('timebase:delay %d', time);
            obj.sendCommand(command);
        end
        
        function bitsInBus(obj, bus, bits, display)
            command = sprintf('bus%d:bits (@1:15), OFF', bus);
            obj.sendCommand(command);
            bitsStr = num2str(bits(1));
            for i = 2:length(bits); bitsStr = [bitsStr, ',', num2str(bits(i))]; end
            command = sprintf('bus%d:bits (@%s), %s', bus, bitsStr, display);
            obj.sendCommand(command);
        end
        
        function displayChannel(obj, type, number, mode)
            % type: 'channel', 'digital', 'bus' or 'pod'(group of digital channels 1: 0-7, 2: 8-15
            % mode: 'on' or 'off'
            command = sprintf(':%s%d:display %s', type, number, mode);
            obj.sendCommand(command);
        end
        
        function axesProp = getAxesProperties(obj)
            axesProp = struct;
            axesProp.xOrigin = str2double(obj.sendCommand(':waveform:xorigin?'));
            axesProp.xReference = str2double(obj.sendCommand(':waveform:xreference?'));
            axesProp.xIncrement = str2double(obj.sendCommand(':waveform:xincrement?'));
        end
    end
    
    methods
        function dataDef(obj, source, points)
            obj.sendCommand(':waveform:format word');
            command = sprintf(':waveform:source %s', source);
            obj.sendCommand(command);
            command = sprintf(':waveform:points %s', points);
            obj.sendCommand(command);
        end
        
        function data = readData(obj, nReads)
%             data = struct('time', [], 'digitalData', zeros(nReads, obj.nPoints));
            data = struct('time', [], 'digitalData', zeros(nReads, 95));
            
            % digital data:
            tic
            for i = 1:100
                fwrite(v, sprintf(':acquire:segmented:index %d', i));
%                 rawData = obj.sendCommand(':waveform:data?');
                fwrite(v, 'waveform:data?'); rawData = fscanf(v);
                hexData = strsplit(rawData, ',');
                data.digitalData(i, :) = hex2dec(hexData(2:end));
            end
            toc
            % time vector:
            axesData = obj.axesProp;
            data.time = ((1:obj.nPoints - axesData.xReference) * axesData.xIncrement) + axesData.xOrigin;
        end
        
        function prepareExpMode(obj, nReads)
            obj.aquasitionMode(obj.SEGMENTED_MODE);
            obj.setNumSegments(nReads);
            obj.triggerSource('external');
            obj.triggerCoupling('AC');
            obj.bitsInBus(1, 0:15, 'ON');
            obj.dataDef(obj, 'bus1', obj.nPoints);
            for i = 1:obj.nChannels
                obj.displayChannel('channel', i, 'off');
            end
            obj.displayChannel('pod', 1, 'off');
            obj.displayChannel('pod', 2, 'off');
            obj.displayChannel('bus', 2, 'off');
            obj.displayChannel('bus', 1, 'on');
        end
        
        function setDetectionTime(obj,detectionsTime)
            maxDetecionTime = max(detectionsTime);
            obj.acquisitionTime(maxDetecionTime);
            obj.timeDelay(maxDetecionTime/2);
        end
        
    end
    
    
    methods (Static)
        function scopeObj = create(scopeName, scopeStruct)
            address = scopeStruct.address;
            scopeObj = scope_MSO_X_3000(scopeName, address);
        end
    end


    
end