classdef (Sealed) AgilentAWGclass <  handle
    properties (Constant)
        frequency = 1000;       % in MHz
        AWminLength = 32;       % minimal waveform length
        AWstep = 1;             % minimal waveform step size
        %sequenceMinTime = 0.1  % Minimal duration supporting short segments (pg. 231, 2nd line from end of page)
        %loopMinLength = 32     % Minimal number of steps required for loops
        %trigMinLength = 32;    % Minimal number of steps required for triggering
        %loopMinTime = 0.5;     % Minimal time for a loop. Not sure if needed
        minSegmentNum = 1       % Minimal number of required segments
        blocksize = 1e3;        % Number of blocks per segment will be: ceil(2*numSamplesSeg#Ch#/blocksize)
        %Vpp=0.5;               % maximal voltage output: convert scale of [0,1] to [0,1]*Vpp V;
        Vmin = -5;              % V limit of device        
        Vmax = 5;               % V limit of device
        VmaxAbsSoftLim = 0.5    %V limmit due to system requerments (SRS,...). For both channels together.
        trigSource = 'EXT';     %'INT' for internal trigger. 'EXT' for external trig. Use internal fto test the AWG.
    end
    properties (Dependent)
        minWaveformDuration
    end
    properties
        runMode
        waveforms = {{},{}}; %segmentLibrary{channel}, where channel is 1 or 2. Each segment must by of length 1(DC), of length >=16 and devides by 4.
        sequence
    end
    properties (Access = private)
        InstrObj
        viRscName %= 'USB0::0x0957::0x5707::MY53800253::0::INSTR';% This may have to be changed for different computers.
               
        currentChannel=[];
        
        waveformChange = 0;
        UploadTimeOut=20;
    end
    
    
    methods (Access = private)
        function obj = AgilentAWGclass(viRscName)
             obj.viRscName =  viRscName; %'USB0::0x0957::0x5707::MY53802481::0::INSTR';% This may have to be changed for different computers.             
        end
    end
    methods (Static)
        function obj = getInstance(viRscName)
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = AgilentAWGclass(viRscName);
            end
            obj = localObj;
            obj.Initialize
        end
    end
    
    methods
        function x = get.minWaveformDuration(obj)
            %minimal AWG duration, in \mus
            x = obj.AWminLength/obj.frequency;
        end
        function set.runMode(obj,newVal)
            switch lower(newVal)
                case 'triglastpulse'
                    obj.runMode = 'trigLastPulse';
                otherwise
                    error('Unknown option')
            end
        end
        
        function Initialize(obj)
            try
                if isempty(obj.InstrObj)
                    obj.InstrObj = visa('agilent', obj.viRscName);
                end
                if isempty(obj.InstrObj)
                    error('failed to open: %s.', obj.viRscName);
                end
                try
                    fclose(obj.InstrObj);% close the AWG connection - if it was not closed before.
                catch err
                    err2warning(err)
                end
                set(obj.InstrObj, 'OutputBufferSize', obj.blocksize + 64);
                set(obj.InstrObj, 'InputBufferSize', 256);
                set(obj.InstrObj, 'TimeOut', obj.UploadTimeOut);%
                
                set(obj.InstrObj,'OutputBufferSize',99999999999999999999999999999999999999999999);
                
                fopen(obj.InstrObj);
                idn = query(obj.InstrObj, '*IDN?');
                if ~contains(idn, '33622A')
                    error('Instrument not supported');
                else
                    fprintf('Instrument IDN: %s\n', idn);
                end
                obj.deviceError();               
                obj.Reset;
                fclose(obj.InstrObj);
                
            catch ex %not sure if this is needed here
                if ~isempty(obj.InstrObj) && strcmp(obj.InstrObj.Status, 'open')
                    flushinput(obj.InstrObj);
                    flushoutput(obj.InstrObj);
                    fclose(obj.InstrObj);
                end
                rethrow(ex)
            end
        end
        
        
        function index = AddWaveformByDuration(obj,newWaveformCh1,newWaveformCh2,duration)
            % Adds a new waveform to channel 1 and 2, with each point
            % caried out for a duration given by "duration" - in \mus
            %%% test input
            if length(newWaveformCh1) ~= length(newWaveformCh2) || length(newWaveformCh1) ~= length(duration)
                error('Inputs must have the same length')
            end
            % change from duration to points
            points = round(duration*obj.frequency);
            timeChange = sum(abs(points/obj.frequency - duration));
            if timeChange > 1e-4
                warning('Change in time due to round ups detected when converting waveform duration to # of points. total change of %f',timeChange)
            end
            % rewrite waveform as points for the awg, (with each point of
            % period 1/obj.frequency)
            waveformCh1 = zeros(1,sum(points));
            waveformCh2 = waveformCh1;
            startIndex = 1;
            for k = 1:length(points)
                endIndex = startIndex + points(k) - 1; 
                waveformCh1(startIndex:endIndex) = newWaveformCh1(k);
                waveformCh2(startIndex:endIndex) = newWaveformCh2(k);
                startIndex = endIndex+1;
            end
            index = AddWaveformByPoints(obj,waveformCh1,waveformCh2);
        end
        function index = AddWaveformByPoints(obj,newWaveformCh1,newWaveformCh2)
            % Stores a new waveform at the end of obj.waveforms. Use LoadWaveforms to load to AWG.
            %
            % Each waveform, waveformsCh1 and newWaveformCh2, is given by a chain of amplitudes in the range
            % of 0 to 1.
            % returns the index of the new waveform
            
            % if newWaveformCh1 || newWaveformCh2 are empty - zeroes will be used
            % with the same length as for the other channel
            
            %             if isrow(newWaveform) == 0
            %                 newWaveform = newWaveforms';
            %             end
            if (isempty(newWaveformCh1) && ~isempty(newWaveformCh2)) ... % just for convinience
                    || (~isempty(newWaveformCh1) && isempty(newWaveformCh2))
                if isempty(newWaveformCh1)
                    newWaveformCh1 = zeros(1,length(newWaveformCh2));
                else
                    newWaveformCh2 = zeros(1,length(newWaveformCh1));
                end
            end         
            waveformTemp = obj.waveforms;            
            waveformTemp{1}{end+1} = newWaveformCh1;
            waveformTemp{2}{end+1} = newWaveformCh2;
            obj.waveforms = waveformTemp;
            index = length(obj.waveforms{1});
        end
        function index = AddSequence(obj,newWaveformNum,newRepeats,newTrigger)
            % Add a new sequence to obj.sequence
            saveSequence = obj.sequence;
            newSequence = obj.sequence;            
            newSequence.waveforms{end+1} = newWaveformNum;
            newSequence.repeats{end+1} = newRepeats; 
            newSequence.trigger{end+1} = newTrigger;
            try % try adding this to the sequence
                obj.sequence = newSequence;            
            catch err
                obj.sequence = saveSequence;                
                error('sequence was not changes: %s',err.message)
            end
            index = length(newSequence.waveforms);            
        end
        function Load(obj)
            % Load stored waveforms and sequences to memory.
            for channel = 1:2
                obj.StopAWG(channel)
                obj.SendCmd('SOURce%d:DATA:VOLatile:CLEar',channel); % clear device memory
                %loads stored waveforms to AWG
                for k =1:length(obj.waveforms{channel})
                    obj.WriteWaveformToAWG(obj.waveforms{channel}{k},k,channel)
                end
                % Uploads sequence of waveforms. Same waveform number is
                % uploaded to both channels (for simplicity). This can be
                % changed to save memory
                for k = 1:length(obj.sequence.waveforms)
                    obj.WriteSequenceToAWG(obj.sequence.waveforms{k},obj.sequence.repeats{k},obj.sequence.trigger{k},k,channel);
                end
            end
        end 
        function UploadLoadAndSave(obj)
            % uploads and saves the waveforms and sequences
            %Stores in library \experiment
            
            
        end
        function LoadSequenceAndRun(obj,sequenceName)
            %Lowdes sequence from AWG memory to volatile memory
            
        end
        
        function DeleteSequences
        end
%         function LoadWaveforms(obj)
%             %loads stored waveforms to AWG
%             for channel = 1:2
%                 obj.SendCmd('SOURce%d:DATA:VOLatile:CLEar',channel); % clear device memory
%                 for k =1:length(obj.waveforms{channel})
%                     obj.writeWaveformToAWG(obj.waveforms{channel}{k},k,channel)             
%                 end
%             end
%             %obj.deviceError();
%             obj.waveformChange = 0;
%         end
%         
%         function LoadSequence(obj,waveformNum,reps,trig)
%             %%% Uploads sequence of waveforms.
%             %%% This is based on the waveforms that were preloaded to the
%             %%% AWG memory, as given by a obj.waveforms.
%             % waveformNum is a vector of waveform numbers, as previously entered.
%             % reps - number of repeats for each waveformNum entery, ranging
%             % from 1 to alot...
%             % trig - trig mode. 0 (false) or 1 (true) for each waveform entry
%             % store in obj.sequence (and test the input)
%             
%             obj.ClearSequence; %clear prev. sequence from memory.
%             s.waveforms = waveformNum;
%             s.repeats = reps;
%             s.trigger = trig;
%             obj.sequence = s;
%             
%             try
%                 for channel = 1:2
%                     command = ['arbseq' num2str(channel)];
%                     for k=1:length(obj.sequence.repeats)
%                         if (trig(k)==0)
%                             trigmode='repeat';
%                         elseif (trig(k)==1 && reps(k)==1)
%                             trigmode='onceWaitTrig';
%                         else %(trig(k)==1 && reps(k)~=1)
%                             %trigmode='repeatTilTrig' % this may cause sinchronization problems.
%                             obj.clearSequenceTable(channel);
%                             error('last sequence is a loop. This is not supported (trig problem')
%                         end
%                         command = [command ',arbseg' num2str(waveformNum(k)) ',' num2str(reps(k)) ',' trigmode ',maintain,10'];
%                     end
%                     
%                     arbBytes=num2str(length(command));
%                     command = ['Source' num2str(channel) ':DATA:SEQ #' num2str(length(arbBytes)) arbBytes command];
%                     
%                     fwrite(obj.InstrObj, command); %combine header and datapoints then send to instrument
%                     obj.SendCmd('*WAI');   %Make sure no other commands are exectued until arb is done downloadin
%                     obj.deviceError();
%                 end
%             catch err
%                 s.waveforms = [];
%                 s.repeats = [];
%                 s.trigger = [];
%                 obj.sequence = s;
%                 rethrow(err)
%             end
%             %
%         end
        
        function err=deviceError(obj)
            %%% Read device error. See page 249 in manual.
            err=NaN;
            while err~=0
                errstr=query(obj.InstrObj, ':SYST:ERR?');
                err=str2double(errstr(1:3)); %after letter 3 there is a string that gives a value NAN
                if err %<0
                    try
                        obj.Reset();
                    catch err2
                        warning(err2.message)
                    end
                    error('Device Status proble: %s\n', errstr);
                    %elseif err>0
                    %    warning('Device Status proble: %s\n', errstr);
                end
            end
        end
        %         function defineVpp(obj,waveforms,channel) % ????????????????????????????
        %             maxlocal=max(waveforms{1});
        %             minlocal=min(waveforms{1});
        %
        %             for k=1:length(waveforms)
        %                 if max(waveforms{k})>maxlocal
        %                     maxlocal=max(waveforms{k});
        %                 end
        %                 if min(waveforms{k})<minlocal
        %                     minlocal=min(waveforms{k});
        %                 end
        %
        %             end
        %             if channel==1
        %                 obj.Vppbyseg1=(maxlocal-minlocal)*obj.Vpp;
        %             elseif channel==2
        %                 obj.Vppbyseg2=(maxlocal-minlocal)*obj.Vpp;
        %             else error('Channel must be 1 or 2!');
        %             end
        %         end
        
        function Run(obj,sequenceNum) %!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!            
            % run device (both channels), using the preloaded sequence sequenceNum, as given in obj.sequence.waveforms{sequenceNum} 
            if obj.waveformChange == 1
                error('waveforms were changed but not loaded')
            end
            channel=1:2;
            for k=1:length(channel)
                chan=channel(k);
                % sind maximal and minimal voltage, to ve used with HIGH
                % and LOW Volt.
                maxV= obj.Vmin;
                minV = obj.Vmax;
                for l = obj.sequence.waveforms{sequenceNum}                   
                    m = max(obj.waveforms{chan}{l});
                    if m > maxV
                        maxV = m;
                    end
                    m = min(obj.waveforms{chan}{l});
                    if m < minV
                        minV = m;
                    end
                end
                if minV<obj.Vmin
                    error('Input Voltage lower then the minimal allowed was entered')
                end
                if maxV>obj.Vmax
                    error('Input Voltage larger then the maximal allowed was entered')
                end
                if abs(maxV - minV) < 1e-10
                    if maxV+0.05 >= obj.Vmax
                        minV = minV-0.05;
                    else
                        maxV = maxV+0.05;
                    end
                end
                
                switch obj.runMode
                    % maximal and minimal voltage points
                    
                    case 'trigLastPulse'
                        obj.SendCmd('TRIG%d:SOUR %s',chan,obj.trigSource);
                        command = ['SOURce' num2str(chan) ':FUNCtion:ARBitrary arbseq' num2str(sequenceNum)];
                        obj.SendCmd(command); % set current arb waveform to defined arb testrise
                        command = ['SOURce' num2str(chan) ':FUNCtion:ARB:SRATe ' num2str(obj.frequency*1e6)]; %create sample rate command, transfer from MHz to Hz
                        obj.SendCmd(command);
                        command=['SOURce' num2str(chan) ':FUNCtion ARB'];
                        obj.SendCmd(command);  % turn on arb function
                        
                        
                        %command = ['SOURce' num2str(chan) ':VOLT ' '0.5']; %create amplitude command
                        command = ['SOURce' num2str(chan) ':VOLT:HIGH ' num2str(maxV)]; %create amplitude command
                        obj.SendCmd(command);
                        %command=['SOURce' num2str(chan) ':VOLT:OFFSET ' '0'];
                        command = ['SOURce' num2str(chan) ':VOLT:LOW ' num2str(minV)]; %create amplitude command
                        obj.SendCmd(command);  % set offset to 0 V
                        command=['OUTPUT' num2str(chan) ' ON'];
                        obj.SendCmd(command);  %Enable Output for channel
                        %                     case 'single' % not sure this is working....
                        %                         obj.SendCmd('TRIG%d:SOUR %s',chan,obj.trigSource);
                        %                         command = ['SOURce' num2str(chan) ':FUNCtion:ARBitrary arbseq' num2str(chan)];
                        %                         obj.SendCmd(command); % set current arb waveform to defined arb testrise
                        %                         command = ['SOURce' num2str(chan) ':FUNCtion:ARB:SRATe ' num2str(obj.frequencyPrivate)]; %create sample rate command
                        %                         obj.SendCmd(command);
                        %                         command=['SOURce' num2str(chan) ':FUNCtion ARB'];
                        %                         obj.SendCmd(command);  % turn on arb function
                        %
                        %
                        %                         command = ['SOURce' num2str(chan) ':VOLT ' num2str(Vppbyseg)]; %create amplitude command
                        %                         obj.SendCmd(command);
                        %                         command=['SOURce' num2str(chan) ':VOLT:OFFSET ' num2str(Voffset)];
                        %                         obj.SendCmd(command);  % set offset to 0 V
                        %                         command=['OUTPUT' num2str(chan) ' ON'];
                        %                         obj.SendCmd(command);  %Enable Output for channel
                        %                     case 'trig'
                        %                         %InstCh = query(obj.InstrObj, 'INST?');
                        %                         %fprintf('Device connected to channel %s\n', InstCh);
                        %                         %Define sequence
                        %
                        %                         obj.SendCmd('INIT:CONT ON'); %Continuous mode
                        %                         %%%
                        %                         obj.SendCmd('TRIG:SOUR:ADV %s',obj.trigSource); %Activates external trigger !!!!!!!!!!!!!!!!!!! EXT
                        %                         obj.SendCmd('SEQ:ADV:SOUR %s',obj.trigSource); % !!!!!!!!!!!EXT
                        %                         if strcmp(obj.trigSource,'INT')
                        %                             obj.SendCmd('TRIG:TIM 1e6'); %Sets internal trigger timer frequency (Hz)
                        %                         end
                        %
                        %                         %%%
                        %                         %obj.SendCmd('TRIG:SOUR:ADV STEP'); % Each seq will go on and on till  a new trig arrives.
                        %                         obj.SendCmd('SEQ:ADV STEP'); %each event will go on in a loop till the next trigger
                        %                         obj.SendCmd(':FUNC:MODE SEQ');%This is used to set the instr to seq mode
                        %                         obj.SendCmd(':FREQ:RAST %d', obj.frequencyPrivate);
                        %                         %SendCmd(':FREQ:RAST MAX');
                        %                         %SendCmd(['VOLT:AMPL ',num2str(obj.Vpp)]);%!!!!!!!!!!!!!!! change to 1 V, and shifs by 0.5 V
                        %                         obj.SendCmd('VOLT %d',obj.Vpp);
                        %                         obj.SendCmd('VOLT:OFFS %d',obj.Voffset);
                        %                         obj.SendCmd('OUTP:FILT ALL');
                        %                         obj.deviceError();
                        %                         obj.SendCmd(':OUTP ON');
                        %                     case 'mix'
                        %                         obj.SendCmd('INIT:CONT ON'); %Continuous mode
                        %                         obj.SendCmd('TRIG:SOUR:ADV %s',obj.trigSource);
                        %                         obj.SendCmd('SEQ:ADV:SOUR %s',obj.trigSource);
                        %                         if strcmp(obj.trigSource,'INT')
                        %                             obj.SendCmd('TRIG:TIM 1e6'); %Sets internal trigger timer frequency (Hz)
                        %                         end
                        %                         obj.SendCmd('SEQ:ADV MIX'); %each event will go on in a loop till the next trigger
                        %                         obj.SendCmd(':FUNC:MODE SEQ');%This is used to set the instr to seq mode
                        %                         obj.SendCmd(':FREQ:RAST %d', obj.frequencyPrivate);
                        %                         obj.SendCmd('VOLT %d',obj.Vpp);%
                        %                         obj.SendCmd('VOLT:OFFS %d',obj.Voffset);%
                        %                         obj.SendCmd('OUTP:FILT ALL');
                        %                         obj.deviceError();
                        %                         obj.SendCmd(':OUTP ON');
                    otherwise
                        error('Unknown run mode!')
                end                
            end
            obj.deviceError;
            obj.DeviceReady;
        end
        
        function StopAWG(obj,chn)
            if nargin<2
                chn=1:2;
            end
            for channel=chn
                %                 obj.setAWGchannel(channel);
                command=['OUTPUT' num2str(channel) ' OFF'];
                obj.SendCmd(command);  %Disable Output for channel
                %obj.SendCmd(':OUTP Off');
            end
        end
        %         function stopAndReset(obj)
        %             for channel=1:2
        %                 obj.stopAWG(channel);
        %                 obj.clearSegments(channel);
        %                 obj.clearSequenceTable(channel);
        %             end
        %             flushinput(obj.InstrObj);
        %             flushoutput(obj.InstrObj);
        %             obj.currentChannel=[];
        %         end
        function Connect(obj)
            fopen(obj.InstrObj);           
        end
        function DeviceReady(obj)
            %tests if theall pending requensts were executed
            OK = query(obj.InstrObj, '*OPC?');        
            if strcmp(OK,'1')% should return 1 once all is complete
                error('How did we get here? %s',OK)
            end
        end       
        function CloseConnection(obj)
            try
                obj.StopAWG();
                obj.ClearMemory;                
                flushinput(obj.InstrObj);
                flushoutput(obj.InstrObj);
            catch err
                warning(err.message)
            end
            fclose(obj.InstrObj);
            disp('AWG connection closed');
        end
        
        function Reset(obj)
            obj.ClearMemory;
            obj.SendCmd('OUTPUT1 OFF')
            obj.SendCmd('OUTPUT2 OFF')
            %obj.ClearSequence;
            flushinput(obj.InstrObj);
            flushoutput(obj.InstrObj);
            obj.SendCmd('*CLS');
            obj.SendCmd('*RST');
            obj.currentChannel=[];
        end
        
        function ClearMemory(obj)            
            % clear AWG memory            
            channel=1:2;
            for k=1:length(channel)
                obj.StopAWG(channel)
                obj.SendCmd('SOURce%d:DATA:VOLatile:CLEar',channel(k));
            end
            % clear matlab stored waveforms
            obj.waveforms={{},{}};         
            % clear matlab stored sequences
            s.waveforms = {};
            s.repeats = {};
            s.trigger = {};
            obj.sequence = s;
        end
%         
%         function ClearWaveforms(obj)
%             channel=1:2;
%             for k=1:length(channel)                              
%                 obj.SendCmd('OUTPUT%d OFF',channel(k)); % closes the output - to prevent the AWG from producing defult waveform.               
%                 obj.SendCmd('SOURce%d:DATA:VOLatile:CLEar',channel(k));                
%             end
%             obj.waveforms={{},{}};
%             obj.ClearSequence % to prevent a refference to a non existing waveform
%         end
    end
    
    methods (Access = protected)
        function WriteSequenceToAWG(obj,waveformNumbers,repeats,trigger,traceNum, channel)
            % Uploads a sequence of waveforms (vectors), with a given
            % number of repeats for each one and a trigger mode (0 or 1).
            % This will be stored as "arbseq#' where # is the traceNum
            try
                if length(waveformNumbers) ~= length(repeats) || length(waveformNumbers) ~= length(trigger)
                    error('Input must be of same length')
                end
                command = ['arbseq' num2str(traceNum)];
                
                for k=1:length(repeats)
                    if (trigger(k)==0)
                        trigmode='repeat';
                    elseif (trigger(k)==1 && repeats(k)==1)
                        trigmode='onceWaitTrig';
                    else %(trig(k)==1 && reps(k)~=1)
                        %trigmode='repeatTilTrig' % this may cause sinchronization problems.
                        error('last sequence is a loop. This is not supported (trig problem')
                    end
                    command = [command ',arbseg' num2str(waveformNumbers(k)) ',' num2str(repeats(k)) ',' trigmode ',maintain,10'];
                end
                
                arbBytes=num2str(length(command));
                command = ['Source' num2str(channel) ':DATA:SEQ #' num2str(length(arbBytes)) arbBytes command];
                
                fwrite(obj.InstrObj, command); %combine header and datapoints then send to instrument
                obj.SendCmd('*WAI');   %Make sure no other commands are exectued until arb is done downloadin
                obj.deviceError();
            catch err
                obj.ClearMemory;
                rethrow(err)
            end
        end

        
        function WriteWaveformToAWG(obj,waveform,tracenum,channel)
            %loads a single waveform (a vector of numbers) to trace number 'traceNumber' of the AWG.
            %Segment is in bytesarray, as given by the 'arbitraryWaveform'
            waveform = single(waveform);
            binaryWaveform = typecast(waveform, 'uint8');
            obj.SendCmd('FORM:BORD SWAP')  %configure the box to correctly accept the binary arb points
            arbBytes=num2str(length(waveform) * 4); %# of bytes
            header= ['SOURce' num2str(channel) ':DATA:ARBitrary arbseg' num2str(tracenum) ', #' num2str(length(arbBytes)) arbBytes]; %create header
            fwrite(obj.InstrObj, [header binaryWaveform], 'uint8'); %combine header and datapoints then send to instrument
            obj.SendCmd('*WAI');   %Make sure no other commands are exectued until arb is done downloadin
            %             command = ['SOURce' num2str(channel) ':FUNCtion:ARBitrary arbseg' num2str(tracenum)];
            %             fprintf(obj.InstrObj,command); % set current arb waveform to defined arb testrise
            %               command = ['MMEM:STOR:DATA' num2str(channel) ' "INT:\arbseg' num2str(tracenum) '.arb"'];
            %               obj.SendCmd(command);
            
            query(obj.InstrObj, '*OPC?');
            obj.deviceError();
        end
        
%         function binaryWaveform = convertWaveform(obj,waveform)
%             %%% converts a waveform to a binary form.
%             %%% number of points must devise by 4 and >=16.
%             numPoints=length(waveform);
%             if numPoints<obj.AWminLength || mod(numPoints,obj.AWstep)~=0
%                 error('number of waveform points must be 16 or larger, and devide by 4')
%             end
%             % Convert data to 14 bit
%             waveform = uint16(((2^13-1)*waveform)+2^13); % 14 bit data
%             % Convert data to bytearray [low byte 0, high byte 0, low byte 1, ...]
%             binaryWaveform = zeros(2* numPoints,1, 'uint8');
%             % Low byte
%             binaryWaveform(1:2:2*numPoints) = uint8(bitand(waveform, uint16(hex2dec('00FF'))));
%             % High byte
%             binaryWaveform(2:2:2*numPoints) = uint8(bitshift(bitand(waveform, uint16(hex2dec('FF00'))), -8));
%         end
        %         function getError(obj)
        %             query(obj.InstrObj, 'SYST:ERR?');
        %         end
        
        function verifyOperationComplete(obj)
            while ~strcmp(obj.InstrObj.TransferStatus,'idle')
                pause(0.02);
            end
        end
        
        function SendCmd(obj,varargin)
            if length(varargin) > 1
                scpi_str = sprintf(varargin{1}, varargin{2:end});%may be a problem here
            else
                scpi_str = varargin{1};
            end
            fprintf(obj.InstrObj, scpi_str);
            obj.verifyOperationComplete();
            query(obj.InstrObj, '*OPC?');
        end
%         function queryAWG(~,text)% first input in obj....
%             eval(sprintf('query(obj.InstrObj, ''%s'')',text));
%         end
        function [steps, timeChange]=durationToSteps(obj,duration)
            f=obj.frequency;
            steps=round(duration*f);
            if steps<0
                error('Negative steps')
            end
            timeChange=steps/f-duration;
            if abs(timeChange)<1e-10
                timeChange=0;
            end
        end
        
    end
    
    methods %test length and time
        %         function [n,k]=minimalRequredLoopSteps(obj,loopLength)
        %             n=1:100;
        %             k=(n*loopLength-obj.AWminLengthPrivate)/obj.AWstepPrivate;
        %             validIndex=(rem(k,1)==0).*(k>=0);% nonZero k and integer k only
        %             validIndex=validIndex.*(obj.AWminLengthPrivate+k*obj.AWstepPrivate>=obj.loopMinLength);% valid number of steps to allow loops
        %             validIndex=validIndex.*(obj.AWminLengthPrivate+k*obj.AWstepPrivate>=obj.trigMinLength);% valid number of steps to allow triggering of the loops
        %             minimalIndex=find(validIndex,1,'first');
        %             if isempty(minimalIndex)
        %                 error('did not find a valid loop time')
        %             end
        %             k=k(minimalIndex); %minimal value of k
        %             n=n(minimalIndex);
        %             %n=(obj.AWminLengthPrivate+k*obj.AWstepPrivate)/loopLength;
        %
        %         end
        %         function minSegmentLength=findMinSegmentLength(obj,segmentLength)
        %             % find the minimal required segment length such that
        %             % minSegmentLength=AWminLength+k*AWstep and minSegmentLength>=segmentLength
        %             k=ceil((segmentLength-obj.AWminLengthPrivate)/obj.AWstepPrivate); %minimal number of allowed AWG steps
        %             if k<0
        %                 k=0;
        %             end
        %             minSegmentLength=obj.AWminLengthPrivate+k*obj.AWstepPrivate;
        %         end
        %         function minSegmentTime=findMinSegmentTime(obj,segmentTime)
        %             % same as minSegmentLength, but in units of time. Input and
        %             % autput in \mus!
        %             f=obj.frequency;
        %             segmentLength=segmentTime*f;
        %             minSegmentLength=obj.findMinSegmentLength(segmentLength);
        %             minSegmentTime=minSegmentLength/f;
        %         end
        function set.waveforms(obj,newWaveform)
            % Insert new waveforms to both channels. This is made to allow
            % a single time tagging / triggerieng for bth channels. If
            % input is empty for one of the channels - zeros will be added
            % otomatically. 
            % waveforms will be added to
            % obj.wavefoems{channel){end+1}
            % waveform names are stored in AWG memory as arbseg# where # is
            % as given in the waveforms{1/2}{#}
            minV = obj.Vmax*[1,1]; %saves the minimal voltage of the new waveforms, for each of the channels;
            maxV = obj.Vmin*[1,1]; %saves the maximal voltage of the new waveforms, for each of the channels;
            normV = [0, 0]; %saves the maximal magnitude of noth channels together;
            
            if ~isa(newWaveform,'cell') || length(newWaveform)~=2
                error('Input waveforms must be a cell of length 2');
            end
            if length(newWaveform{1})~=length(newWaveform{2})
                error('Input to both channels must be of the same length')
            end
            if ~isa(newWaveform{1},'cell') || ~isa(newWaveform{2},'cell')
                error('waveform must be a cell of waveforms for each channel')
            end
            for k = 1:length(newWaveform{1})
                if length(newWaveform{1}{k}) ~=length(newWaveform{2}{k})
                   error('Input waveforms must be of the same length'); 
                end
                for l = 1:2
                    if ~isnumeric(newWaveform{l}{k})
                        error('input must be numeric')
                    end
                    if rem((length(newWaveform{l}{k})-obj.AWminLength)/obj.AWstep,1)
                        error('Problem in number of steps in segment %u. Must be %u+integer*%u',k,obj.AWminLength,obj.AWstep)
                    end
                    if min(newWaveform{l}{k}) < minV
                        minV = min(newWaveform{l}{k});
                    end
                    if max(newWaveform{l}{k}) > maxV
                        maxV = max(newWaveform{l}{k});
                    end
                end
                tempNorm = max((newWaveform{1}{k}.^2 + newWaveform{2}{k}.^2).^0.5);
                if max(tempNorm) > normV
                    normV = tempNorm;
                end
            end
                        %%% test V does not exeed maximal limits
            if maxV > obj.Vmax
                error('Waveform maximal voltage exceeds maximal alloved value (%f V)',obj.Vmax);
            end
            if minV < obj.Vmin
                error('Waveform minimal voltage is lower then the minimal alloved value (%f V)',obj.Vmin);
            end
            if normV > obj.VmaxAbsSoftLim
                error('Waveform maximal total voltage exceeds maximal alloved value (%f V). This may harm other devices',obj.VmaxAbsSoftLim);
            end
            %%%%
            obj.waveforms = newWaveform;
        end
        function set.sequence(obj,newSequence)            
            % inserts values to sequence property. Composed of a cell
            % (stores different sequences), with each one having 3 vector fields:
            % waveform numbers - "waveforms", repeats and trigger
            % sequence names are stored in AWG memory as arbseq# where # is
            % as given in the sequence{#}
            try               
                if ~isfield(newSequence,'waveforms') ||...
                        ~isfield(newSequence,'repeats')...
                        || ~isfield(newSequence,'trigger')
                    error('sequence must include waveforms, repeats and triggers')
                end
                if length(newSequence.waveforms)~= length(newSequence.repeats)... % test equal length
                        || length(newSequence.waveforms) ~= length(newSequence.trigger)
                    error('Input fields must have the same length')
                end
                if ~isa(newSequence.waveforms,'cell') || ...
                        ~isa(newSequence.repeats,'cell') || ~isa(newSequence.trigger,'cell')
                    error('input fields must be of class ''cell''')
                end
                for k = 1:length(newSequence.waveforms) % sest that each element in the cell has the currect structure                    
                    % test input is empty or numeric
                    if (~isempty(newSequence.waveforms{k}) && ~isnumeric(newSequence.waveforms{k})) || ...
                            (~isempty(newSequence.repeats{k}) && ~isnumeric(newSequence.repeats{k}))
                        error('input must be numeric')
                    end                   
                    % test input is empty or numeric or logical
                    if ~isempty(newSequence.trigger{k}) && ~isnumeric(newSequence.trigger{k}) && ~islogical(newSequence.trigger{k})
                        error('input must be numeric or logical')
                    end
                    %
                    if length(newSequence.waveforms{k})~= length(newSequence.repeats{k})... % test equal length
                            || length(newSequence.waveforms{k}) ~= length(newSequence.trigger{k})
                        error('Input fields must have the same length')
                    end                   
                    %
                    if sum(newSequence.repeats{k} <0) || sum(newSequence.repeats{k} > 1e4)
                        error('repeats must be between 0 and 1e7')
                    end
                    if ~ isempty(newSequence.trigger{k}) % test that the sequence points to existing waveforms
                        if min(newSequence.waveforms{k}) < 1 || max(newSequence.waveforms{k}) > length(obj.waveforms{1})
                            error('refference to a non existing waveform')
                        end
                    end
                end
                obj.sequence.waveforms = newSequence.waveforms;
                obj.sequence.repeats = newSequence.repeats;
                obj.sequence.trigger = newSequence.trigger;
            catch err
                obj.sequence.waveforms = {};
                obj.sequence.repeats = {};
                obj.sequence.trigger = {};
                rethrow(err);
            end
        end
    end
    
end