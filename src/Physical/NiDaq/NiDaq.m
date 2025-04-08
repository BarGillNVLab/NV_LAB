classdef NiDaq < EventSender
    %NiDaq Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        dummyMode;  	% logical. if set to true nothing will actually be passed
        dummyChannel    % vector of doubles. Saves value of write channels, for dummy mode
        
        channelArray
        % 2D array.         (todo: Better make it an array of Channels)
        % 1st column - channels ('dev/...')
        % 2nd column - channel names ('laser green')
        % 3rd column - channel minimum value. by default it is 0.
        % 4th column - channel maximum value. by default it is 1.
        
        deviceName  % string. is used by the library functions
        analogInputMaxVoltage    %max  10 volts
        analogInputMinVoltage    %min -10 volts
    end
    
    properties (Constant, Hidden)
       IDX_CHANNEL = 1;
       IDX_CHANNEL_NAME = 2;
       IDX_CHANNEL_MIN = 3;
       IDX_CHANNEL_MAX = 4;
       
       MAX_VOLTAGE = 10;
       MIN_VOLTAGE = -10;
       DEFAULT_MIN_VOLTAGE = 0;
       DEFAULT_MAX_VOLTAGE = 1;
       
       CHANNEL_100MHZ = '100MHz';
       CHANNEL_100kHZ = '100kHz';
    end
    properties (Constant)
        NAME = 'NiDaq';
        UNITS = ' V'; % The space is for the GUI.
        
        EVENT_NIDAQ_RESET = 'Ni_Daq_reset';
    end
    
    %% Initializtion %%
    
    methods (Access = protected)
        function obj = NiDaq(deviceName, dummyMode)
            obj@EventSender(NiDaq.NAME);
            obj.init(deviceName, dummyMode)
        end
        
        function init(obj, deviceName, dummyModeBoolean)
            % Internal channels that are being used by someone
            obj.registerChannel('100MHzTimebase', obj.CHANNEL_100MHZ)
            obj.registerChannel('100kHzTimebase', obj.CHANNEL_100kHZ)
            
            obj.dummyMode = dummyModeBoolean;
            obj.deviceName = deviceName;
            if ~dummyModeBoolean
                LoadNIDAQmx;
            end
        end
    end
  
    methods (Static)
        function create(niDaqStruct)
            % This method is used to load the NiDAQ as new
            %
            % niDaqStruct HAS TO HAVE a property named "deviceName" (as a
            % string), or an error will be thrown.
            %
            % niDaqStruct can have a 'dummy' logical property called
            % "dummy". If set to true, no actual physics will be involved.
            % Good for testing purposes.
            % The default value (if it doesn't exist in struct) is false.
            %
            missingField = FactoryHelper.usualChecks(niDaqStruct, {'deviceName'});
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Can''t find the reserved word "%s" in the NiDaq struct', ...
                    missingField);
            end
            if isfield(niDaqStruct, 'dummy')
                dummy = niDaqStruct.dummy;
            else
                dummy = false;
            end
            
            
            obj = getObjByName(NiDaq.NAME);
            if ~isempty(obj)
                % Initialize object if it exists
                init(obj, niDaqStruct.deviceName, dummy);
            else
                % Create it otherwise
                obj = NiDaq(niDaqStruct.deviceName, dummy);
                addBaseObject(obj); % so it can be reached by getObjByName()
            end
            
%             pg = getObjByName('pulseGenerator');
%             if isa(pg, 'PulseStreamerNewClass')
%                 logicFamily = daq.ni.NIDAQmx.DAQmx_Val_3point3V;
%             else
%                 logicFamily = daq.ni.NIDAQmx.DAQmx_Val_5V;
%             end
%             status = DAQmxSetDigitalLogicFamilyPowerUpState(obj.deviceName, logicFamily);
%             obj.checkError(status);
        end
    end
    
    methods
    
%         function setDigitalLogicFamily(obj)
%             % Define the logiv family (TTL or LVTTL) due to the pulse
%             % generator type
%             PG = getObjByName('pulseBlaster');
%             if isa(PG, 'PulseBlasterNewClass')
%                 logicFamily = daq.ni.NIDAQmx.DAQmx_Val_5V;
%             else
%                 logicFamily = daq.ni.NIDAQmx.DAQmx_Val_3point3V;
%             end
%             status = DAQmxSetDigitalLogicFamilyPowerUpState(obj.deviceName, logicFamily);
%             obj.checkError(status);    
%         end
    
        function registerChannel(obj, newChannel, newChannelName, minValueOptional, maxValueOptional)
            % We accept also empty values for minValueOptional &
            % maxValueOptional, which allows us to tell the function to
            % use default values for any of the optional variables
            if exist('minValueOptional', 'var') && ~isempty(minValueOptional)
                minValue = minValueOptional;
            else
                minValue = obj.DEFAULT_MIN_VOLTAGE;
            end
            if exist('maxValueOptional', 'var') && ~isempty(maxValueOptional)
                maxValue = maxValueOptional;
            else
                maxValue = obj.DEFAULT_MAX_VOLTAGE;
            end
            
            if ~isempty(obj.channelArray)
                % We want to make sure we are not overwriting an existing
                % channel
                takenIndices = obj.channelArray(1:end, NiDaq.IDX_CHANNEL);
                channelAlreadyInIndexes = find(strcmp(takenIndices, newChannel));
                if ~isempty(channelAlreadyInIndexes)
                    channelIndex = channelAlreadyInIndexes(1);
                    channelCapturedName = obj.getChannelNameFromIndex(channelIndex);
                    if ~strcmp(newChannelName, channelCapturedName)
                        % Maybe we are just trying to register again the
                        % same channel, and that is just fine. Otherwise,
                        errorTemplate = 'Can''t assign channel "%s" to "%s", as it has already been taken by "%s"!';
                        errorMsg = sprintf(errorTemplate, newChannel, newChannelName, channelCapturedName);
                        obj.sendError(errorMsg);
                    else
                        return  % This channel is already registered
                    end
                end
            end
            
            obj.channelArray{end + 1, NiDaq.IDX_CHANNEL} = newChannel;
            obj.channelArray{end, NiDaq.IDX_CHANNEL_NAME} = newChannelName;
            obj.channelArray{end, NiDaq.IDX_CHANNEL_MIN} = minValue;
            obj.channelArray{end, NiDaq.IDX_CHANNEL_MAX} = maxValue;
            
%             if strcmp(newChannelName, 'spcm_pg')
%                 pg = getObjByName('pulseGenerator');
%                 if isa(pg, 'PulseStreamerNewClass')
%                     state = daq.ni.NIDAQmx.DAQmx_Val_Low;
%                 else
%                     state = daq.ni.NIDAQmx.DAQmx_Val_High;
%                 end
%                 status = DAQmxSetDigitalPowerUpStates(obj.deviceName, newChannel, state);
%                 obj.checkError(status);
%             end
            
            if obj.dummyMode    % If we are in dummy mode, we want to have default value for value;
                obj.dummyChannel(length(obj.channelArray)) = -1;
            end
        end % func registerChannel
    end
    
    methods (Access = protected)
        function index = getIndexFromChannelOrName(obj, channelOrChannelName)
            if channelOrChannelName(1) == '_'
                % This is a virtual channel. We need to get the index of
                % the real channel (for example, 'ao3' and not '_ao3_vs_aognd')
                channelOrChannelName = regexp(channelOrChannelName, 'ao\d', 'match', 'once');
            end
            
            channelNamesIndexes = find(contains(obj.channelArray(1:end, NiDaq.IDX_CHANNEL_NAME), channelOrChannelName));
            if ~isempty(channelNamesIndexes)
                index = channelNamesIndexes(1);
                return;
            end
            
            channelIndexes = find(contains(obj.channelArray(1:end, NiDaq.IDX_CHANNEL), channelOrChannelName));
            if ~isempty(channelIndexes)
                index = channelIndexes(1);
                return;
            end
            
            EventStation.anonymousError(...
                '%s couldn''t find either channel or channel name "%s". Have you registered this channel?', ...
                obj.name, channelOrChannelName);
        end
        
        function channelName = getChannelNameFromIndex(obj, index)
            channelName = obj.channelArray{index, NiDaq.IDX_CHANNEL_NAME};
        end
        
        function channel = getChannelFromIndex(obj, index)
            channel = obj.channelArray{index, NiDaq.IDX_CHANNEL};
        end
        
        function min = getChannelMinimumFromIndex(obj, index)
            min = obj.channelArray{index, NiDaq.IDX_CHANNEL_MIN};
            if ~isnumeric(min)
                min = str2double(min);
            end
            if isnan(min)
                min = obj.DEFAULT_MIN_VOLTAGE;
            end
        end
        
        function max = getChannelMaximumFromIndex(obj, index)
            max = obj.channelArray{index, NiDaq.IDX_CHANNEL_MAX};
            if ~isnumeric(max)
                max = str2double(max);
            end
            if isnan(max)
                max = obj.DEFAULT_MAX_VOLTAGE;
            end
        end
    end
    
    %%% end (Initializtion block)   
    
    %% Read & write
    methods
        function task = prepareVoltageInputTask(obj, channel, terminalConfig)
            % We might want to read continuously, so we need a seperate
            % function for creating the channel
            % channel - channel ID (e.g. 'ai3')
            
            task = obj.createTask();
            if obj.dummyMode
                return
            end
            
            channelIndex = obj.getIndexFromChannelOrName(channel);
            physicalChannel = sprintf('/%s/%s', obj.deviceName, channel);
            minVal = obj.getChannelMinimumFromIndex(channelIndex);
            maxVal = obj.getChannelMaximumFromIndex(channelIndex);
            
            % NiDaq constants
            if ~exist('terminalConfig', 'var')
                terminalConfig =  daq.ni.NIDAQmx.DAQmx_Val_RSE;
            end
            daqUnits =        daq.ni.NIDAQmx.DAQmx_Val_Volts;
            
            nameToAssignToChannel = '';
            customScaleName = '';
            status = DAQmxCreateAIVoltageChan(task, physicalChannel, nameToAssignToChannel, terminalConfig, minVal, maxVal, daqUnits, customScaleName);
            obj.checkError(status);
        end
        
        function voltageInt = readVoltage(obj, channelOrChannelName, numSampsPerChan, timeout)
            if obj.dummyMode; voltageInt = 0; return; end
            
            % Reads the voltage at the given channel
            channelIndex = obj.getIndexFromChannelOrName(channelOrChannelName);
            channel = obj.getChannelFromIndex(channelIndex);
            
            if obj.dummyMode
                val = obj.dummyChannel(channelIndex);
                if val == -1 % read channel
                    voltageInt = 0.5;
                else    % write channel -- we have value to return
                    voltageInt = val;
                end
                return
            end
            
            % Terminal configuration - DAQ constant
            if ~contains(channel, 'ao')
                terminalConfig =  daq.ni.NIDAQmx.DAQmx_Val_RSE;
            else
                % Virtual channel - reading from output channel
                channel = regexprep(channel, 'ao(\d+)', '_ao$1_vs_aognd');
                terminalConfig = daq.ni.NIDAQmx.DAQmx_Val_Diff;
            end
            
            % Create channel            
            task = obj.prepareVoltageInputTask(channel, terminalConfig);
            
            % Setting defaults
            if ~exist('numSampsPerChan', 'var')
                numSampsPerChan = 1;
            end
            if ~exist('timeout', 'var')
                timeout = 1;
            end
            
            % Read from channel
            obj.startTask(task);
            voltageInt = obj.readVoltageInternal(task, numSampsPerChan, timeout);
            obj.endTask(task);
        end
        
        function task = prepareVoltageOutputTask(obj, channel)
            % We might want to read continuously, so we need a seperate
            % function for creating the channel
            % channel - channel ID (e.g. 'ao2')
            
            channelIndex = obj.getIndexFromChannelOrName(channel);

            if obj.dummyMode
                % When using dummy NiDaq, we use the "task" variable to
                % send the channel number to the daq
                task = channelIndex;
                return
            end
            
            % NiDaq constants
            task = obj.createTask();
            units = daq.ni.NIDAQmx.DAQmx_Val_Volts;
            
            physicalChannel = sprintf('/%s/%s', obj.deviceName, channel);
            minVal = obj.getChannelMinimumFromIndex(channelIndex);
            maxVal = obj.getChannelMaximumFromIndex(channelIndex);

            status = DAQmxCreateAOVoltageChan(task, physicalChannel, minVal, maxVal, units);
            obj.checkError(status);
        end
        
        function writeVoltage(obj, channelOrChannelName, newVoltage)
            % Writes the given voltage at the given channel
            channelIndex = obj.getIndexFromChannelOrName(channelOrChannelName);
            channel = obj.getChannelFromIndex(channelIndex);

            % Create channel
            task = obj.prepareVoltageOutputTask(channel);

            % Write to channel
            obj.startTask(task);
            obj.writeVoltageOnce(newVoltage, task)
            obj.endTask(task);
        end
        
        function writeVoltageOnce(obj, voltage, task)
            if obj.dummyMode
                % When using dummy NiDaq, we use the "task" variable to
                % send the channel number to the daq
                channelIndex = task;
                obj.dummyChannel(channelIndex) = voltage;
                return
            end
            
            numSampsPerChan = 1;
            autoStart = 1;
            timeout = 10;
            dataLayout =  daq.ni.NIDAQmx.DAQmx_Val_GroupByScanNumber;
            sampsPerChanWritten = 0;    % dummy variable (that is, has no meaning)
            status = DAQmxWriteAnalogF64(task, numSampsPerChan, autoStart, timeout, dataLayout, voltage, sampsPerChanWritten);
            obj.checkError(status);
        end
        
        function digitalInt = readDigital(obj, channelOrChannelName)
            % Read the current digital status of the given channel
            channelIndex = obj.getIndexFromChannelOrName(channelOrChannelName);
            channel = obj.getChannelFromIndex(channelIndex);
            
            if obj.dummyMode
                digitalInt = true;
                return
            end
            
            % NiDaq constants
            lineGrouping    = daq.ni.NIDAQmx.DAQmx_Val_ChanForAllLines;
            fillMode        = daq.ni.NIDAQmx.DAQmx_Val_GroupByChannel;
            
            task = obj.createTask();
            
            strLines = sprintf('/%s/%s', obj.deviceName, channel);
            strNameToAssignToLines = '';
            status = DAQmxCreateDIChan(task, strLines, strNameToAssignToLines, lineGrouping);
            obj.checkError(status);
            
            obj.startTask(task);
            
            numSampsPerChan = 1;
            timeout = 1;
            readArray = zeros(1, 1);
            arraySizeInSamps = 1;
            sampsPerChanRead = 0;   % dummy variable
            [status, digitalInt] = DAQmxReadDigitalU32(task, numSampsPerChan, timeout, fillMode, readArray, arraySizeInSamps, sampsPerChanRead);
            
            obj.checkError(status);
            
            obj.endTask(task);
            
        end
        
        function task = prepareDigitalOutputTask(obj, channel)
            % We might want to read continuously, so we need a seperate
            % function for creating the channel
            % channel - channel ID (e.g. 'PFI5')

            if obj.dummyMode
                % When using dummy NiDaq, we use the "task" variable to
                % send the channel number to the daq
                channelIndex = obj.getIndexFromChannelOrName(channel);
                task = channelIndex;
                return;
            end

            task = obj.createTask();
            
            strLines = sprintf('/%s/%s', obj.deviceName, channel);
            strNameToAssignToLines = '';
            lineGrouping = daq.ni.NIDAQmx.DAQmx_Val_ChanForAllLines;
            
            status = DAQmxCreateDOChan(task, strLines, strNameToAssignToLines, lineGrouping);
            obj.checkError(status);
        end
        
        function writeDigital(obj, channelOrChannelName, newLogicalValue)
            % Writes the given digital status at the given channel
            
            if obj.dummyMode
                % Do nothing
                return
            end
            
            channelIndex = obj.getIndexFromChannelOrName(channelOrChannelName);
            channel = obj.getChannelFromIndex(channelIndex);
            task = obj.prepareDigitalOutputTask(channel);
            line = str2double(channel(end));    % channel is of the form 'portM/lineN', where M and N are integers
            
            obj.startTask(task);
            obj.writeDigitalOnce(task, newLogicalValue, line);
            obj.endTask(task);
        end
        
        function writeDigitalOnce(obj, task, value, line)
            if obj.dummyMode
                % When using dummy NiDaq, we use the "task" variable to
                % send the channel number to the daq
                channelIndex = task;
                obj.dummyChannel(channelIndex) = value;
                return
            end
            
            numSampsPerChan = 1;
            bAutoStart = 1;
            timeout = 10;
            bDataLayout = daq.ni.NIDAQmx.DAQmx_Val_GroupByChannel;
            writeArray = value*2^line;
            sampsPerChanWritten = 1;
            status = DAQmxWriteDigitalU32(task, numSampsPerChan, bAutoStart, timeout, bDataLayout, writeArray, sampsPerChanWritten);
            obj.checkError(status);
        end
        
        
        function task = CreateDAQEdgeCountingMeas(obj, nCounts, countChannelName, edgesChannelName, ctrNumberOpt)
            % Creates an edge counting measurement task.
            % (countChannelName, edgesChannelName) use cases:
            % For counting photons by stage: (SPCM, Stage)
            % For counting time by stage: (NiDaq.CHANNEL_100MHZ, Stage)
            % For counting photons by time: (SPCM, NiDaq.CHANNEL_100kHZ)
            % For counting photons by gating Pulse: (SPCM, PulseGenerator)
            % ctrNumber can be 0 or 1. If not specified, then it is 0.
            
            % Getting input variables for DAQ functions
            if ~exist('ctrNumberOpt', 'var')
                ctrNumberOpt = 0;
            end
            device = sprintf('/%s/Ctr%d', obj.deviceName, ctrNumberOpt);
            edgesChannel = obj.getChannelFromIndex(obj.getIndexFromChannelOrName(edgesChannelName));
            edgesChannelFullName = sprintf('/%s/%s', obj.deviceName, edgesChannel);
            countChannel = obj.getChannelFromIndex(obj.getIndexFromChannelOrName(countChannelName));
            countChannelFullName = sprintf('/%s/%s', obj.deviceName, countChannel);
            
            edgeRising = daq.ni.NIDAQmx.DAQmx_Val_Rising;
            sampleMode = daq.ni.NIDAQmx.DAQmx_Val_ContSamps;    % Continuous
            countDirection = daq.ni.NIDAQmx.DAQmx_Val_CountUp;  % Up
            
            switch edgesChannelName
                case obj.CHANNEL_100kHZ
                    sampleRate = 100e3;
                otherwise
                    sampleRate = 1e6;
            end
            
            % Creating task
            task = obj.createTask();

            status = DAQmxCreateCICountEdgesChan(task, device, '', edgeRising, 0, countDirection);
            obj.checkError(status);
            
            status = DAQmxCfgSampClkTiming(task, edgesChannelFullName, sampleRate, edgeRising, sampleMode, nCounts);
            obj.checkError(status);
            
            status = DAQmxSet(task, 'CI.CountEdgesTerm', device, countChannelFullName);
            obj.checkError(status);
        end
        
        function task = CreateDAQPulseWidthMeas(obj, nCounts, countChannelName, pulseWidthChannelName, ctrNumberOpt)
            % Creates a pulse width measurement task
            % (countChannelName, pulseWidthChannelName) use cases:
            % For counting photons by stage: (SPCM, Stages)
            % For counting time by stage: (NiDaq.CHANNEL_100MHZ, Stage)
            % For counting photons by time: (SPCM, NiDaq.CHANNEL_100kHZ)
            % For counting photons by gating Pulse: (SPCM, PulseGenerator)
            % ctrNumber can be 0 or 1. If not specified, then it is 0.
            
            % Due to a bug in the NiDaq (specifically, with series X), we
            % actually need to implement this as edge counting with a pause
            % trigger:
            
            % Getting input variables for DAQ functions
            if ~exist('ctrNumberOpt', 'var')
                ctrNumberOpt = 0;
            end
            device = sprintf('/%s/Ctr%d', obj.deviceName, ctrNumberOpt);
            edgesChannel = obj.getChannelFromIndex(obj.getIndexFromChannelOrName(pulseWidthChannelName));
            edgesChannelFullName = sprintf('/%s/%s', obj.deviceName, edgesChannel);
            countChannel = obj.getChannelFromIndex(obj.getIndexFromChannelOrName(countChannelName));
            countChannelFullName = sprintf('/%s/%s', obj.deviceName, countChannel);
            
            edgeRising = daq.ni.NIDAQmx.DAQmx_Val_Rising;
            edgeFalling = daq.ni.NIDAQmx.DAQmx_Val_Falling;
            sampleMode = daq.ni.NIDAQmx.DAQmx_Val_ContSamps;         % Continuous
            countDirection = daq.ni.NIDAQmx.DAQmx_Val_CountUp;       % Up
            pauseTriggerType = daq.ni.NIDAQmx.DAQmx_Val_DigLvl;      % Digital
            pauseTriggerDigitalLevel = daq.ni.NIDAQmx.DAQmx_Val_Low; % Low
            
            sampleRate = 1e6;
            
            
            % Creating task
            task = obj.createTask();
            
            status = DAQmxCreateCICountEdgesChan(task, device, '', edgeRising, 0, countDirection);
            obj.checkError(status);
            
            status = DAQmxCfgSampClkTiming(task, edgesChannelFullName, sampleRate, edgeFalling , sampleMode, nCounts);
            obj.checkError(status);
            
            status = DAQmxSet(task, 'CI.CountEdgesTerm', device, countChannelFullName);
            obj.checkError(status);
            
            status = DAQmxSet(task, 'PauseTrigType', device, pauseTriggerType);
            obj.checkError(status);
            
            status = DAQmxSet(task, 'DigLvlPauseTrigSrc', device, edgesChannelFullName);
            obj.checkError(status);
            
            status = DAQmxSet(task, 'DigLvlPauseTrigWhen', device, pauseTriggerDigitalLevel);
            obj.checkError(status);
            
%             logicFamily = daq.ni.NIDAQmx.DAQmx_Val_3point3V;
%             status = daq.ni.NIDAQmx.DAQmxSetDILogicFamily(task,device,logicFamily)
%             status = DAQmxSet(task, 'DILogicFamily', device, logicFamily);
%             obj.checkError(status);
        end
        
        function [task, counterOutputChannelName] = CreateDAQgatedClock(obj, edgesChannelName, ctrNumberOpt)
            % creating internal gated clock with frequency 1.25MHz, 
            % working just when 'edgesChannelName' is 1.
            
            % Getting input variables for DAQ functions
            if ~exist('ctrNumberOpt', 'var')
                ctrNumberOpt = 0;
            end
            switch ctrNumberOpt
                case 0
                    counterOutputChannel = 'PFI8';
                case 1
                    counterOutputChannel = 'PFI3';
                case 2
                    counterOutputChannel = 'PFI0';
                case 3
                    counterOutputChannel = 'PFI5';
            end
            counter = sprintf('/%s/Ctr%d', obj.deviceName, ctrNumberOpt);
            edgesChannel = obj.getChannelFromIndex(obj.getIndexFromChannelOrName(edgesChannelName));
            edgesChannelFullName = sprintf('/%s/%s', obj.deviceName, edgesChannel);
            countBaseChannel = obj.getChannelFromIndex(obj.getIndexFromChannelOrName(obj.CHANNEL_100MHZ));
            countBaseChannelFullName = sprintf('/%s/%s', obj.deviceName, countBaseChannel);
            counterOutputChannelName = 'gatedClock';
            obj.registerChannel(counterOutputChannel, counterOutputChannelName);
            
            idleState = daq.ni.NIDAQmx.DAQmx_Val_Low;                   % The resting state of the counter output
            sampleMode = daq.ni.NIDAQmx.DAQmx_Val_ContSamps;            % coutinious
            counterBufferSize = 1e6;
            pauseTriggerType = daq.ni.NIDAQmx.DAQmx_Val_DigLvl;         % Digital
            pauseTriggerDigitalLevel = daq.ni.NIDAQmx.DAQmx_Val_Low;    % Low
            
            % Creating task
            task = obj.createTask();

            % creates the gated 1MHz clock:
            status = DAQmxCreateCOPulseChanTicks(task, counter, '', countBaseChannelFullName, idleState, 2, 98, 2);
            obj.checkError(status);
            
            status = DAQmxCfgImplicitTiming(task, sampleMode, counterBufferSize);
            obj.checkError(status);
            
            status = DAQmxSet(task, 'PauseTrigType', counter, pauseTriggerType);
            obj.checkError(status);
            
            status = DAQmxSet(task, 'DigLvlPauseTrigSrc', counter, edgesChannelFullName);
            obj.checkError(status);
            
            status = DAQmxSet(task, 'DigLvlPauseTrigWhen', counter, pauseTriggerDigitalLevel);
            obj.checkError(status);
        end
        
        function task = CreateDAQclockedVoltageMeas(obj, nPulses, measureChannelName, clockChannel, samplesPerPulse)
            % Creates clocked measurement task.
            % (measuredChannelName, gateChannelName)
            % pulses must be bigger then 1 us. Otherwise it might loose the aquisition pulse.

            if ~exist('samplesPerPulse', 'var')
                samplesPerPulse = 1000;
            end
            
            clockChannelName = obj.getChannelFromIndex(obj.getIndexFromChannelOrName(clockChannel));
            clockChannelFullName = sprintf('/%s/%s', obj.deviceName, clockChannelName);
            measureChannel = obj.getChannelFromIndex(obj.getIndexFromChannelOrName(measureChannelName));
            measureChannelFullName = sprintf('/%s/%s', obj.deviceName, measureChannel);

            sampleMode = daq.ni.NIDAQmx.DAQmx_Val_ContSamps;            % coutinious
            terminalConfig = daq.ni.NIDAQmx.DAQmx_Val_Diff;             % The input terminal configuration - differential mode
            units = daq.ni.NIDAQmx.DAQmx_Val_Volts;
            activeEdge = daq.ni.NIDAQmx.DAQmx_Val_Rising;
            maxSampleRate = 1.25e6;                                        % choose due to the analog sample rate
            bufferSize = nPulses * samplesPerPulse * 1.1;             % probably should be big enough. If necessary it can be bigger
            
            % Creating task
            task = obj.createTask();

            % creates the voltage sampling part:
            status = DAQmxCreateAIVoltageChan(task, measureChannelFullName, '', terminalConfig, ...
                                              obj.analogInputMinVoltage, obj.analogInputMaxVoltage, units, '');
            obj.checkError(status);
            
            status = DAQmxCfgSampClkTiming(task, clockChannelFullName, maxSampleRate, activeEdge, sampleMode, bufferSize);
            obj.checkError(status);
        end

        function task = CreateDAQcoutiniousVoltageMeas(obj, measureChannelName, sampleRate)
            % Creates coutinious aquisition task.
            if ~exist('sampleRate', 'var')
                sampleRate = 100e3;
            end
            
            % Getting input variables for DAQ functions
            measureChannel = obj.getChannelFromIndex(obj.getIndexFromChannelOrName(measureChannelName));
            measureChannelFullName = sprintf('/%s/%s', obj.deviceName, measureChannel);
            sampleMode = daq.ni.NIDAQmx.DAQmx_Val_ContSamps;            % coutinious
            terminalConfig = daq.ni.NIDAQmx.DAQmx_Val_Diff;             % The input terminal configuration - differential mode
            units = daq.ni.NIDAQmx.DAQmx_Val_Volts;
            activeEdge = daq.ni.NIDAQmx.DAQmx_Val_Rising;
            bufferSize = 1e5;
            
            % Creating task
            task = obj.createTask();

            status = DAQmxCreateAIVoltageChan(task, measureChannelFullName, '', terminalConfig, ...
                                              obj.analogInputMinVoltage, obj.analogInputMaxVoltage, units, '');
            obj.checkError(status);
            
            status = DAQmxCfgSampClkTiming(task, '', sampleRate, activeEdge, sampleMode, bufferSize);
            obj.checkError(status);
        end

        function task = CreateDAQnSamplesVoltageMeas(obj, measureChannelName, sampleRate, nCounts)
            % Creates n samples aquisition task.
            
            % Getting input variables for DAQ functions
            measureChannel = obj.getChannelFromIndex(obj.getIndexFromChannelOrName(measureChannelName));
            measureChannelFullName = sprintf('/%s/%s', obj.deviceName, measureChannel);
            sampleMode = daq.ni.NIDAQmx.DAQmx_Val_FiniteSamps;         % coutinious
%             terminalConfig = daq.ni.NIDAQmx.DAQmx_Val_RSE;             % The input terminal configuration - differential mode
            terminalConfig = daq.ni.NIDAQmx.DAQmx_Val_Diff;             % The input terminal configuration - differential mode
            units = daq.ni.NIDAQmx.DAQmx_Val_Volts;
            activeEdge = daq.ni.NIDAQmx.DAQmx_Val_Rising;
            
            % Creating task
            task = obj.createTask();

            status = DAQmxCreateAIVoltageChan(task, measureChannelFullName, '', terminalConfig, ...
                                              obj.analogInputMinVoltage, obj.analogInputMaxVoltage, units, '');
            obj.checkError(status);
            
            status = DAQmxCfgSampClkTiming(task, '', sampleRate, activeEdge, sampleMode, nCounts);
            obj.checkError(status);
        end
        
        function task = CreateDAQEdgeVoltageMeas(obj, nCounts, measureChannelName, edgesChannelName)
            % Getting input variables for DAQ functions
            edgesChannel = obj.getChannelFromIndex(obj.getIndexFromChannelOrName(edgesChannelName));
            edgesChannelFullName = sprintf('/%s/%s', obj.deviceName, edgesChannel);
            measureChannel = obj.getChannelFromIndex(obj.getIndexFromChannelOrName(measureChannelName));
            measureChannelFullName = sprintf('/%s/%s', obj.deviceName, measureChannel);
            sampleMode = daq.ni.NIDAQmx.DAQmx_Val_FiniteSamps;          % finite
            terminalConfig = daq.ni.NIDAQmx.DAQmx_Val_Diff;             % The input terminal configuration - differential mode
            units = daq.ni.NIDAQmx.DAQmx_Val_Volts;
            activeEdge = daq.ni.NIDAQmx.DAQmx_Val_Rising;
            sampleRate = 1.25e6;
            
            % Creating task
            task = obj.createTask();

            status = DAQmxCreateAIVoltageChan(task, measureChannelFullName, '', terminalConfig, ...
                                              obj.analogInputMinVoltage, obj.analogInputMaxVoltage, units, '');
            obj.checkError(status);
            
            status = DAQmxCfgSampClkTiming(task, edgesChannelFullName, sampleRate, activeEdge, sampleMode, nCounts);
            obj.checkError(status);
        end
        
        function task = CreateDAQCountingMeas(obj, countChannelName, ctrNumberOpt)
            % Creates a simple counting measurement task.
            % just count the number of pulses.
            % used for calibration to check if there is miss pulses.
            if ~exist('ctrNumberOpt', 'var')
                ctrNumberOpt = 2;
            end
            device = sprintf('/%s/Ctr%d', obj.deviceName, ctrNumberOpt);
            countChannel = obj.getChannelFromIndex(obj.getIndexFromChannelOrName(countChannelName));
            countChannelFullName = sprintf('/%s/%s', obj.deviceName, countChannel);
            
            edgeRising = daq.ni.NIDAQmx.DAQmx_Val_Rising;
            sampleMode = daq.ni.NIDAQmx.DAQmx_Val_ContSamps;    % Continuous
            countDirection = daq.ni.NIDAQmx.DAQmx_Val_CountUp;  % Up
            maxSampleRate = 1e7;
            buffer = 1e7;
            
            % Creating task
            task = obj.createTask();
            status = DAQmxCreateCICountEdgesChan(task, device, '', edgeRising, 0, countDirection);
            obj.checkError(status);
            
            status = DAQmxCfgSampClkTiming(task, countChannelFullName, maxSampleRate, edgeRising, sampleMode, buffer);
            obj.checkError(status);
        end
        
        function CreateDAQTimedPulseChannelOutput(obj, frequency, dutyCycle, nPulses)
            % Creates pulse series, defined by frequency, duty cycle and
            % total number of number of pulses.
            % Probably unneeded, in afterthought, but should be harmless.
            
            if ~exist('ctrNumberOpt', 'var')
                ctrNumberOpt = 0;
            end
            device = sprintf('/%s/Ctr%d', obj.deviceName, ctrNumberOpt);
            
            % DAQ constants
            daqUnits = daq.ni.NIDAQmx.DAQmx_Val_Hz;             % Volts
            idleState = daq.ni.NIDAQmx.DAQmx_Val_Low;           % Low
            sampleMode = daq.ni.NIDAQmx.DAQmx_Val_ContSamps;    % Continuous
            
            task = obj.createTask;
            
            initialDelay = 0.0;
            status = DAQmxCreateCOPulseChanFreq(task, device, '', daqUnits, idleState, initialDelay, frequency, dutyCycle);
            obj.checkError(status);
            
            status = DAQmxCfgImplicitTiming(task, sampleMode, nPulses);
            obj.checkError(status);
            
            obj.endTask(task);
        end
        
        
        function availSamps = availableSamples(obj, task)
            availSamps = uint32(0);
            [status, availSamps] = daq.ni.NIDAQmx.DAQmxGetReadAvailSampPerChan(task, availSamps);
            obj.checkError(status)
        end
        
        function [readArray, nRead] = ReadDAQCounter(obj, task, nCounts, timeout)
            numSampsPerChan = nCounts;
            readArray = zeros(1, nCounts);
            arraySizeInSamps = nCounts;
            sampsPerChanRead = int32(0);
            
            
            [status, readArray, nRead] = DAQmxReadCounterU32(task, numSampsPerChan, ...
                timeout, readArray, arraySizeInSamps, sampsPerChanRead);
            obj.checkError(status);
        end

        function readValue = ReadDAQCounterScalar(obj, task, timeout)
            [status, readValue] = DAQmxReadCounterScalarU32(task, timeout);
            readValue = double(readValue);
            obj.checkError(status);
        end
        
        
        function readArray = readDAQVoltage(obj, task, nCounts, timeout)
            numSampsPerChan = daq.ni.NIDAQmx.DAQmx_Val_Auto;
            readArray = zeros(1, nCounts);
            arraySizeInSamps = nCounts;
            fillMode = daq.ni.NIDAQmx.DAQmx_Val_GroupByChannel;
            sampsPerChanRead = int32(0);
            [status, readArray] = DAQmxReadAnalogF64(task, numSampsPerChan, ...
                timeout, fillMode, readArray, arraySizeInSamps, sampsPerChanRead);
            obj.checkError(status);
        end
        
    end
    %%% End (Reading & writing)
    
    %% Task handling
    methods
        function startTask(obj, task)
            if obj.dummyMode; return; end
            
            status = DAQmxStartTask(task);
            obj.checkError(status)
        end
        
        function tf = isTaskComplete(obj, task)
            if obj.dummyMode; return; end
            
            [status, tf] = DAQmxGetTaskComplete(task);
            obj.checkError(status)
        end
        
        function stopTask(obj, task)
            if obj.dummyMode; return; end
            
            status = DAQmxStopTask(task);
            obj.checkError(status)
        end
        
        function endTask(obj, task)
            if obj.dummyMode; return; end
            
            obj.stopTask(task);
            obj.clearTask(task)
        end
        
    end
    
    methods (Access = protected)
        function checkError(obj, status)
            % Checks for DAQ errors according to the status and sends an error event.
            if status ~= 0
                bufferSize = uint32(500);
                errorString = char(ones(1,bufferSize));
                [statusInternal, errorString]=daq.ni.NIDAQmx.DAQmxGetErrorString(status, errorString, bufferSize);
                obj.reset;
                if statusInternal ~= 0 || isempty(errorString)
                    obj.sendError(['NIDAQ Error ' num2str(status)])
                else
                    obj.sendError(['NIDAQ Error ' num2str(status) ': ' errorString]);
                end
            end
%             lh = addlistener(s,'ErrorOccurred' @(src,event), disp(getReport(event.Error)));
        end
        
        function reset(obj)
            DAQmxResetDevice(obj.deviceName);
            fprintf('DAQ Card Ready! (reset)\n');
            obj.sendEvent(struct(NiDaq.EVENT_NIDAQ_RESET, true));
        end
        
        function task = createTask(obj)
            [status, ~, task] = DAQmxCreateTask([]);
            obj.checkError(status);
        end
        
        function clearTask(obj, task)
            status = DAQmxClearTask(task);
            obj.checkError(status)
        end
        
        function voltageInt = readVoltageInternal(obj, task, numSampsPerChan, timeout)
            % Required constants
            fillmode = daq.ni.NIDAQmx.DAQmx_Val_GroupByScanNumber;
            readArray = zeros(1, numSampsPerChan);
            sampsPerChanRead = 0;   % dummy variable
            
            % Actual reading
            [status, voltageInt]= DAQmxReadAnalogF64(task, numSampsPerChan, timeout, fillmode, readArray, numSampsPerChan, sampsPerChanRead);
            obj.checkError(status);
        end 
    end
    
    methods (Static)
        function d = countDiff(counts)
            % Treats overflow in edge counting
            maxCounts = 2^32;   % (i.e., 2^32 +1 => -2^32)
            
            d = diff(counts);
            d(d<0) = d(d<0) + maxCounts;
        end
    end

end