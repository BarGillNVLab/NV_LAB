classdef Digitizer < EventSender
   
    properties (Constant)
        UNIT_CONV = 1e6;
        VOLTAGE_CONV = 1e3;
        MAX_SAMPLE_RATE = 100;
        AVALIABLE_SAMPLE_RATES = [100, 50, 25, 10, 5, 2, 1, 0.5, 0.2, 0.1, 0.05, 0.02, 0.01, 0.005, 0.002, 0.001];
        TIME_OUT = 1e7;       % us
        MAX_SAMPLES_PER_POINT = 1000;   % the maximum samples we want for single data point
        SEGMENT_SIZE_INTEGER_MULTIPLE = 32;
    end
    
    properties 
        handle
        externalRefClock = 0
        sampleRate
        maxVoltage          % Array. 0.5 for +-0.5 volta etc.
        voltageOffset       % Array
        channelDelay        % Array. negative mean to acquire before the trigger!
        inputImpedance

        acqInfo
        channelInfo
        trigInfo
        segmentBodySize
        negativeDelaySize
        positiveDelaySize
        segmentPreTrigSize
        segmentPostTrigSize
    end
    
    properties(Constant = true)
        NAME = 'gageDigitizer';
    end
    
    methods
        function obj = Digitizer()
            obj@EventSender(Digitizer.NAME);
            if isempty(getObjByName(Digitizer.NAME))
                addBaseObject(obj);  % so it can be reached by getObjByName()
            end
            obj.connect;
            obj.reset;
        end
        
        function connect(obj)
            systems = CsMl_Initialize;
            CsMl_ErrorHandler(systems);
            
            [ret, obj.handle] = CsMl_GetSystem;
            CsMl_ErrorHandler(ret);
            sysinfo = obj.queryCommand('CsMl_GetSystemInfo');
            sn = obj.queryCommand('CsMl_GetSerialNumber');
            fprintf('Connected to digitizer board name: %s, serial number: %s\n', sysinfo.BoardName, sn);
        end
        
        function disConnect(obj)
            CsMl_FreeSystem(obj.handle);
        end
        
        function sendCommand(obj, command, struct)
            [ret, ~] = CsMl_GetSystemInfo(obj.handle);
            if ret ~= 1
                obj.connect;
            end
            if exist('struct', 'var')
                vararg = {command, obj.handle, struct};
            else
                vararg = {command, obj.handle};
            end
            ret = feval(vararg{:});
%             if ret ~= 1
%                 obj.disConnect;
%                 obj.connect;
%                 ret = feval(vararg{:});
%             end
            obj.checkError(ret);
        end
        
        function answer = queryCommand(obj, command, struct)
            [ret, ~] = CsMl_GetSystemInfo(obj.handle);
            if ret ~= 1
                obj.connect;
            end
            if exist('struct', 'var')
                vararg = {command, obj.handle, struct};
            else
                vararg = {command, obj.handle};
            end
            [ret, answer] = feval(vararg{:});
%             if ret ~= 1
%                 obj.disConnect;
%                 obj.connect;
%                 [ret, answer] = feval(vararg{:});
%             end
            obj.checkError(ret);
        end
        
        function checkError(obj, ret)
            errorTxt = CsMl_ErrorHandler(ret, 0, obj.handle);
            if ~isempty(errorTxt)
                obj.sendError(errorTxt);
            end
        end
        
        function writeToBoard(obj)
            obj.sendCommand('CsMl_ConfigureAcquisition', obj.acqInfo);
            obj.sendCommand('CsMl_ConfigureChannel', obj.channelInfo);
            obj.sendCommand('CsMl_ConfigureTrigger', obj.trigInfo);
            try
                obj.sendCommand('CsMl_Commit');
            catch
                SegmentSize = obj.acqInfo.SegmentSize;
                Depth = obj.acqInfo.Depth;
                N = 32*3;
                obj.acqInfo.SegmentSize = N;
                obj.acqInfo.Depth = N;
                obj.sendCommand('CsMl_ConfigureAcquisition', obj.acqInfo);
                obj.sendCommand('CsMl_Commit');
                pause(1);
                
                obj.acqInfo.SegmentSize = SegmentSize;
                obj.acqInfo.Depth = Depth;
                obj.sendCommand('CsMl_ConfigureAcquisition', obj.acqInfo);
                obj.sendCommand('CsMl_Commit');
            end
        end

        function configure = readFromBoard(obj, chan)
            if ~exist('chan', 'var')
                chan = 1;
            end
            acqInfoState = obj.queryCommand('CsMl_QueryAcquisition');
            channelInfoState = obj.queryCommand('CsMl_QueryChannel', chan);
            trigInfoState = obj.queryCommand('CsMl_QueryTrigger', 1);
            configure = struct;
            configure.acqInfo = acqInfoState;
            configure.channelInfo = channelInfoState;
            configure.trigInfo = trigInfoState;
        end
        
        function waitForDeviceReady(obj)
            status = CsMl_QueryStatus(obj.handle);
            tic
            while status ~= 0
                if toc > (obj.TIME_OUT / obj.UNIT_CONV)
                    error('Time out when waiting to read from the digitizer')
                end
                status = CsMl_QueryStatus(obj.handle);
            end
        end
    end
        
    methods
        function reset(obj)
            obj.setupInit;
        end
        
        function prepareAcquisition(obj, chan, nSegments, segmentDuration, triggered, sampleRate)
            if ~exist('triggered', 'var')
                triggered = 1;
            end
            
            if exist('sampleRate', 'var')
                if ~any(sampleRate == obj.AVALIABLE_SAMPLE_RATES)    
                    error('Digitizer sample rate not avavliable!')
                end
                obj.sampleRate = sampleRate;
            else
                obj.sampleRate = obj.MAX_SAMPLE_RATE;
            end
            obj.segmentBodySize = segmentDuration * obj.sampleRate;
            if mod(obj.segmentBodySize, 1)
                obj.segmentBodySize = fix(obj.segmentBodySize);
                warning('Digitizer segment duration changed to be sample rate complete period: %d us insteed of %d us', obj.segmentBodySize / obj.sampleRate, segmentDuration)
            end
            
            obj.negativeDelaySize = max((obj.channelDelay(chan) < 0) .* (-obj.channelDelay(chan))) * obj.sampleRate;
            obj.positiveDelaySize = max((obj.channelDelay(chan) > 0) .* ( obj.channelDelay(chan))) * obj.sampleRate;
            if mod(obj.negativeDelaySize, 1)
                obj.negativeDelaySize = fix(obj.negativeDelaySize);
                warning('Digitizer channel delay changed to be sample rate complete period: %d us insteed of %d us ', obj.negativeDelaySize / obj.sampleRate, max((obj.channelDelay(chan) < 0) .* (-obj.channelDelay(chan))))
            end
            if mod(obj.positiveDelaySize, 1)
                obj.positiveDelaySize = fix(obj.positiveDelaySize);
                warning('Digitizer channel delay changed to be sample rate complete period: %d us insteed of %d us', obj.positiveDelaySize / obj.sampleRate, max((obj.channelDelay(chan) > 0) .* ( obj.channelDelay(chan))))
            end
            
            obj.segmentPreTrigSize = obj.SEGMENT_SIZE_INTEGER_MULTIPLE * ceil(obj.negativeDelaySize / obj.SEGMENT_SIZE_INTEGER_MULTIPLE);
            obj.segmentPostTrigSize = obj.SEGMENT_SIZE_INTEGER_MULTIPLE * ceil((obj.segmentBodySize + obj.positiveDelaySize) / obj.SEGMENT_SIZE_INTEGER_MULTIPLE);
            
            mode = 'Single';
            if any(chan==3)
                mode = 'Dual';
            end
            if any(any(chan==[2 4]'))
                mode = 'Quad';
            end
            
            obj.acqInfo.SampleRate = obj.sampleRate * obj.UNIT_CONV;
            obj.acqInfo.ExtClock = obj.externalRefClock;
            obj.acqInfo.Mode = CsMl_Translate(mode, 'Mode');
            obj.acqInfo.SegmentCount = nSegments;
            obj.acqInfo.Depth = obj.segmentPostTrigSize;
            obj.acqInfo.SegmentSize = obj.segmentPreTrigSize + obj.segmentPostTrigSize;
            obj.acqInfo.TriggerTimeout = obj.TIME_OUT;
            obj.acqInfo.TriggerHoldoff = obj.acqInfo.SegmentSize - obj.acqInfo.Depth;
%             obj.acqInfo.TriggerHoldoff = obj.segmentPreTrigSize;
            obj.acqInfo.TriggerDelay = 0;
            obj.acqInfo.TimeStampConfig = 0;
            
            for i = 1:length(chan)
                obj.channelInfo(i).Channel = chan(i);
                obj.channelInfo(i).Coupling = CsMl_Translate('DC', 'Coupling');
                obj.channelInfo(i).DiffInput = 'norm';
                obj.channelInfo(i).InputRange = obj.maxVoltage(chan(i)) * obj.VOLTAGE_CONV * 2;
                obj.channelInfo(i).Impedance = obj.inputImpedance(chan(i));
                obj.channelInfo(i).DcOffset = obj.voltageOffset(chan(i)) * obj.VOLTAGE_CONV;
                obj.channelInfo(i).DirectAdc = 0;
                obj.channelInfo(i).Filter = 0;
            end
            
            obj.trigInfo.Trigger = 1;
            obj.trigInfo.Slope = CsMl_Translate('Positive', 'Slope');
            obj.trigInfo.Level = 30;
            obj.trigInfo.Source = CsMl_Translate(BooleanHelper.ifTrueElse(triggered, 'External', 'Disable'), 'Source');
            obj.trigInfo.ExtCoupling = CsMl_Translate('DC', 'ExtCoupling');
            obj.trigInfo.ExtRange = 10000;
            
            obj.writeToBoard;
        end
        
        function startExperiment(obj)
            obj.stopAcquisition;
            obj.sendCommand('CsMl_Capture');
        end
        
        function voltage = readExperimentData(obj, chan, getRawData, throwZeros)
            % read and get the data that acquired in the last task.
            % chan: Channel to read. Can be a vector.
            % getRawData: boolean. If to get all the acquired points without averaging.
            % throwZero: boolean. If to throw all the missed points of the acquisition task. Repalace the zeros by NaN.
            % return 'voltage': A matrix of size [length(chan) * nSegments]. When 'rawData' is on the size is [length(chan) * nSegments * segmentSize].
            if ~exist('getRawData', 'var')
                getRawData = 0;
            end
            if ~exist('throwZeros', 'var')
                throwZeros = 1;
            end
            status = CsMl_QueryStatus(obj.handle);
            while status ~= 0
                if toc > (obj.TIME_OUT / obj.UNIT_CONV)
                    error('Time out when waiting to read from the digitizer')
                end
                status = CsMl_QueryStatus(obj.handle);
                if (status == 1) && (obj.trigInfo.Source == 0)
                    obj.forceAcquisition;
                    status = CsMl_QueryStatus(obj.handle);
                end
                if status == 2
                    obj.stopAcquisition;
                    status = CsMl_QueryStatus(obj.handle);
                end
            end
            
            % changing the system info in order to get all the data in single read
            sysinfo = obj.queryCommand('CsMl_GetSystemInfo');
            acqInfoBackup = obj.acqInfo;
            SegmentSizeWithTail =  obj.acqInfo.SegmentSize + (64 / obj.acqInfo.Mode / sysinfo.SampleSize);
            obj.acqInfo.SegmentSize = SegmentSizeWithTail * obj.acqInfo.SegmentCount;
            obj.acqInfo.Depth = obj.acqInfo.SegmentSize;
            obj.acqInfo.SegmentCount = 1;
            obj.acqInfo.TriggerHoldoff = 0;
            obj.writeToBoard;
            obj.acqInfo = acqInfoBackup;
            
            voltage = zeros(length(chan), obj.acqInfo.SegmentCount, obj.segmentBodySize);
            for i = 1:length(chan)
                transfer.Channel = chan(i);
                transfer.start = 0;
                transfer.Mode = 0;
                transfer.Segment = 1;
                transfer.Length = (obj.acqInfo.SegmentSize + (64 / obj.acqInfo.Mode / sysinfo.SampleSize)) * obj.acqInfo.SegmentCount;
                v = obj.queryCommand('CsMl_Transfer', transfer);
                v = reshape(v, SegmentSizeWithTail, obj.acqInfo.SegmentCount)';
                delaySize = round(obj.channelDelay(chan(i)) * obj.acqInfo.SampleRate / obj.UNIT_CONV);
                v = v(:, (obj.segmentPreTrigSize + delaySize + (1:obj.segmentBodySize)));
                voltage(i, :, :) = v;
            end
            obj.writeToBoard;
            if throwZeros
                for s = 1:obj.acqInfo.SegmentCount
                    v = squeeze(voltage(:, s, :));
                    if size(v,2)==1; v=v'; end
                    [~, ind] = ind2sub(size(v), find(v==0));
                    v(:, ind) = NaN;
                    voltage(:, s, :) = v;
                end
            end
            if ~getRawData
                voltage = mean(voltage, 3, "omitnan");
            end
        end
        
        function forceAcquisition(obj)
            obj.sendCommand('CsMl_ForceCapture');
        end
        
        function stopAcquisition(obj)
            status = CsMl_QueryStatus(obj.handle);
            if status ~= 0
                obj.sendCommand('CsMl_AbortCapture');
            end
        end
        
    end
    
    methods
        function [ret] = setupInit(obj)
            % Set the acquisition, channel and trigger parameters for the system and
            % calls ConfigureAcquisition, ConfigureChannel and ConfigureTrigger.
            
            obj.acqInfo.SampleRate = 10000000;
            obj.acqInfo.ExtClock = 0;
            obj.acqInfo.Mode = CsMl_Translate('Quad', 'Mode');
            obj.acqInfo.SegmentCount = 5;
            obj.acqInfo.Depth = 8160;
            obj.acqInfo.SegmentSize = 8160;
            obj.acqInfo.TriggerTimeout = 10000000;
            obj.acqInfo.TriggerHoldoff = 0;
            obj.acqInfo.TriggerDelay = 0;
            obj.acqInfo.TimeStampConfig = 0;
            
            obj.channelInfo = struct;
            obj.channelInfo.Channel = 1;
            obj.channelInfo.Coupling = CsMl_Translate('DC', 'Coupling');
            obj.channelInfo.DiffInput = 0;
            obj.channelInfo.InputRange = 2000;
            obj.channelInfo.Impedance = 50;
            obj.channelInfo.DcOffset = 0;
            obj.channelInfo.DirectAdc = 0;
            obj.channelInfo.Filter = 0;
            
            obj.trigInfo.Trigger = 1;
            obj.trigInfo.Slope = CsMl_Translate('Positive', 'Slope');
            obj.trigInfo.Level = 0;
            obj.trigInfo.Source = 1;
            obj.trigInfo.ExtCoupling = CsMl_Translate('DC', 'ExtCoupling');
            obj.trigInfo.ExtRange = 2000;
            
            obj.writeToBoard;
            
            ret = 1;
        end
    end
end