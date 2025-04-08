classdef (Sealed) PulseBlasterNewClass < PulseGenerator
    
    properties (Constant, Hidden)
        MAX_REPEATS = 1e6;       	% int. Maximum value for obj.repeats
        MAX_PULSES = Inf; %% ??;          % int. Maximum number of pulses in acceptable sequences
        MAX_DURATION = 1e5;         % double. Maximum duration of pulse.
        
        AVAILABLE_ADDRESSES = 0:7;	% List of all available physical addresses.
                                    % Should be either vector of doubles or cell of char arrays
        NEEDED_FIELDS = {'libPathName'}
    end
    
    properties (Constant, Access = private) 
        frequencyPrivate = 500; %in MHz ( == 500e6 Hz)
    end
    
    methods (Access = private)
        function obj = PulseBlasterNewClass()
            obj@PulseGenerator;
            % Private default constructor.
        end
    end
    methods (Access = public)
        
        function Initialize(obj, path)
            if ~libisloaded('mypbesr')
                disp('Matlab: Load spinapi.dll')
                
                % Added by Sungkun
                % spinapi.h C:\Program Files\SpinCore\SpinAPI\dll
                % spinapi.dll C:\Program Files\SpinCore\SpinAPI\dll
                dllPath = [PathHelper.appendBackslashIfNeeded(path), 'spinapi64.dll'];
                hPath = [PathHelper.appendBackslashIfNeeded(path), 'spinapi.h'];
                funclist = loadlibrary(dllPath, hPath, 'alias','mypbesr');
            end
            obj.initSequence;
        end
    end

    methods
        function setChannelNameAndValue(obj,names,values)
            if size(names)~=size(values)
                error('inputs must be of the same size')
            end
            if ~isa(names,'cell')
                error('Input ''name'' must be of class ''cell''')
            end
            if ~isnumeric(values)
                error('Input ''values'' must be a numeric input')
            end
            if length(unique(names)) ~= length(names)
                error('input ''names'' has repeats in it. A single name must be given to each channel')
            end
            if length(unique(values)) ~= length(values)
                error('input ''values'' has repeats in it. A single name must be given to each channel')
            end
            values = round(values);
            obj.channelValuesPrivate = values;
            obj.channelNamesPrivate = names;
        end
    end
    
    methods
        
        function on(obj, channelNames)
            % Turns on channels named (channelNames)
            % Returns error if not all were turned on
            obj.getReady;
            
            if isempty(channelNames)
                inputChannels = 0;
                obj.sendWarning('Warning! No channel was turned on or off!');
            else
                inputChannels = obj.channelName2Address(channelNames); % converts from a cell of names to channel numbers, if needed
                minChan = min(obj.AVAILABLE_ADDRESSES); % Probably 0, but just in case
                maxChan = max(obj.AVAILABLE_ADDRESSES);
                if sum(rem(inputChannels,1)) || min(inputChannels) < minChan || max(inputChannels)> maxChan
                    error('Input must be valid channels! Ignoring.')
                end
                inputChannels = sum(2.^inputChannels);
            end
            % Channles should be on either if they were on until now, or if we asked to turn them on now.
            channels = bitor(obj.onChannelsBinary, inputChannels);
            
            obj.chooseOnChannels(channels)
        end
        
        function off(obj, channelNames)
            obj.getReady;
            
            if ~exist('channelNames', 'var') || isempty(channelNames)
                % We want everything off
                channels = 0;
            else
                inputChannels = obj.channelName2Address(channelNames); % converts from a cell of names to channel numbers, if needed
                minChan = min(obj.AVAILABLE_ADDRESSES); % Probably 0, but just in case
                maxChan = max(obj.AVAILABLE_ADDRESSES);
                if sum(rem(inputChannels,1)) || min(inputChannels) < minChan || max(inputChannels)> maxChan
                    error('Input must be valid channels! Ignoring.')
                end
                % We want on only channels which were on before AND NOT
                % channels which are turned off.
                channels = bitget(obj.onChannelsBinary,1:8); 
                channels(inputChannels+1) = false;  % Channels are internally labeled 0:7, but the matlab vector is 1:8
                channels = binaryVectorToDecimal(channels, 'LSBFirst');
            end
            
            obj.chooseOnChannels(channels);
        end
        
        function run(obj)
            uploadSequence(obj)
            % function RunPBSequence
            obj.getReady;
            obj.PBesrStop();
            obj.PBesrStart(); %start pulsing. it will start pulse sequence which were progammed/loaded to PBESR card before.
        end
        
        function [PB] = sendToHardware(obj)%,events,duration,channels,repeats)
            %duration: event duration, in ns;
            %channels: a vector of the channel numbers
            %events: a (logical) matrix of length(channels) * length(duration).
            % The input can also be a cell with N inputs, each one
            % containing the PB to be turned on (empty for non)
            
            %% input (pulseSequence)- a multiline sequence
            ClockTime = 1/obj.frequencyPrivate*1e3;% in ns
            MinDelay = ClockTime*(2^8);% MinDelay in ns
            ShortDelay = ClockTime*5;    % [ns]
            maxRep = 1048576;% Maximal number of LONG_DELAY repetitions
            
            LONG_DELAY = {'LONG_DELAY'};
            CONTINUE = {'CONTINUE'};
            LOOP = {'LOOP'};
            END_LOOP = {'END_LOOP'};
            
            %             if isa(events,'cell')
            %                 temp = zeros(obj.maxPBchannel,length(events));
            %                 for k = 1:length(events)
            %                     temp(events{k}+1,k) = 1;
            %                 end
            %                 events = temp;
            %             end
            %if isempty(channels)
            %    channels = zeros(1,size(events,1));
            %else
            %    channels = obj.ChannelValuesFromNames(channels); %converts from a cell of names to channel numbers, if needed
            %end
            %             if ~isnumeric(channels)
            %                 error('Input must be of a numeric class')
            %             end
            %if ~isnumeric(repeats)
            %    error('Input must be of a numeric class')
            %end
            %if ~ise(dueration,'double')
            %    error('Input must be of class double')
            %end
            
            %if size(events,2)~= size(duration,2)
            %    error('Imbalance in input events and duration length')
            %end
            %if size(events,1)~= size(channels,2)
            %    error('Imbalance in input events and channels length')
            %end
            
            %PBevents=sum(diag(2.^(0:size(events,1)-1))*(events~=0),1); % convert events to logics
            
            % Converting sequence to machine-readable format
            seq = BooleanHelper.ifTrueElse(obj.delayFixed, obj.delayFixedSequence, obj.sequence);
            pulses = seq.getPulses();
            len = length(pulses);
            pulsesBinary = zeros(len, 1);
            duration = zeros(len,1);
            for k = 1:len
                channelNames = pulses(k).getOnChannels;
                channels = obj.channelName2Address(channelNames); % converts from a cell of names to channel numbers
                pulsesBinary(k) = sum(2.^channels);
                duration(k) = pulses(k).duration;
            end
            
            duration = duration * 1e3; %convert duration in ns to \mus
            PB = [pulsesBinary, duration]; 
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %% This was taken as is...
            
            % STEP 6: Decide if each event is of the type "CONTINUE" or "LONG DELAY"
            %   CMD = [Output Values, Instruction, Instruction Data, Delay (Duration)]
            
            
            c=0;% c is the counter for the CMDs given to the pulseblaster
            for pb = 1:size(PB,1)
                Output    = PB(pb,1);
                CurrDelay = PB(pb,2);
                
                % if the PB event is a LONG_DELAY (according to SpinCore documentation,
                % this instruction requires 3 or more loops)
                if CurrDelay > (3*MinDelay + ShortDelay)
                    Inst = LONG_DELAY;
                    c = c + 1;
                    
                    % get the integer number of  MinDelays
                    Inst_Data = floor(CurrDelay/MinDelay);
                    CurrDelay = mod(CurrDelay, MinDelay);
                    
                    % if the leftover time is five clock cycles or less
                    % (i.e., requires short codes), remove one loop iteration from the
                    % LONG_DELAY instruction
                    if CurrDelay <= ShortDelay
                        Inst_Data = Inst_Data - 1;
                        CurrDelay = CurrDelay + MinDelay;
                    end
                    
                    CMD(c,:) = [Output, Inst, Inst_Data, MinDelay]; %#ok<AGROW>
                end
                
                % if the PB event is just a series of CONTINUEs or if there is leftover
                % time after the LONG_DELAY instruction (the 0.5 is for round errors)
                ncont = 0;
                if CurrDelay > (3*MinDelay + 0.5)          % need 4 CONTINUE instructions
                    ncont = 4;
                elseif CurrDelay > (2*MinDelay + 0.5)      % need 3 CONTINUE instructions
                    ncont = 3;
                elseif CurrDelay > (MinDelay + 0.5)      % need 2 CONTINUE instructions
                    ncont = 2;
                elseif CurrDelay > (ShortDelay + 0.5)      % need 1 CONTINUE instruction
                    ncont = 1;
                else                                       % would need shortcodes
                    disp('SHORT CODES NOT IMPLEMENTED. SORRY, BUB.');
                end
                
                while (ncont ~= 0)
                    Inst = CONTINUE;
                    Inst_Data = 0;
                    c = c + 1;
                    
                    % if ncont is one, just use current CurrDelay
                    if ncont == 1
                        TempDelay = CurrDelay;
                    else
                        % divide by ncont and round up to nearest clockcycle
                        TempDelay = floor( floor(CurrDelay/(ClockTime)) / ncont )*(ClockTime);
                    end
                    %     diary on
                    %       fprintf ('ncont %d:  TempDelay = %f, CurrDelay = %f (ClockTime = %f\n', ncont, TempDelay, CurrDelay, ClockTime*1e9);
                    %     diary off
                    CMD(c,:) = [Output,Inst,Inst_Data,TempDelay];
                    
                    CurrDelay = CurrDelay - TempDelay;
                    ncont = ncont - 1;
                end
            end
            
            % STEP 7:
            
            
            CMD = obj.ValidateCMD(CMD,ClockTime);
            %S=obj.CMD2PBI(CMD);
            NCMD = size(CMD,1);
            
            
            
            % this next block of code takes the basic pulse sequence and repeats it for
            % SEQ.samples using the LOOP command of the PB code.
            a=1;
            if strcmp(CMD(1,2),CONTINUE)
                % fixed this error, jhodges, 9 Oct 2008
                %%% Old Code
                %%%AuxCMD(a,:) = CMD{1,:};
                %%%AuxCMD(a,1) = LOOP;
                
                % if first command in sequence is a contiune, change it to a LOOP
                AuxCMD(a,:) = [CMD{1,1},LOOP,obj.repeats,CMD{1,4},CMD{1,5}];
            elseif strcmp(CMD(1,2),LONG_DELAY)
                AuxCMD(a,:) = [CMD{1,1},LOOP,obj.repeats,MinDelay,CMD{1,5}];
                a = a +1;
                %aux= CMD{1,3};
                
                % jhdoges,jmaze 17 Nov 2008
                % now, we need to account for 1 of the loops of the LONG_DELAY going to
                % the LOOP command.  If there are at least two loops left, issue a
                % long_delay command with the remaining loops, otherwise, just do a
                % continue for the LONG_DELAY command length
                if CMD{1,3}-1 > 1
                    AuxCMD(a,:) = [CMD{1,1},LONG_DELAY,CMD{1,3}-1,CMD{1,4},CMD{1,5}];
                else
                    AuxCMD(a,:) = [CMD{1,1},CONTINUE,0,CMD{1,4},CMD{1,5}];
                end
                
            end
            for c=2:NCMD-1
                a = a + 1;
                AuxCMD(a,:) = CMD(c,:);
            end
            a = a + 1;
            if strcmp(CMD(NCMD,2),CONTINUE)
                AuxCMD(a,:) = CMD(NCMD,:);
                AuxCMD(a,2) = END_LOOP;
                %     AuxCMD(a,3) = {1};  % ADDED BY LINH
            elseif strcmp(CMD(NCMD,2),LONG_DELAY)
                AuxCMD(a,:) = [CMD{NCMD,1},LONG_DELAY,CMD{NCMD,3}-1,CMD{NCMD,4},CMD{NCMD,5}];
                a = a + 1;
                AuxCMD(a,:) = [CMD(NCMD,1),END_LOOP,0,MinDelay,CMD{NCMD,5}];
                %      AuxCMD(a,:) = [CMD(NCMD,1),END_LOOP,1,MinDelay,CMD{NCMD,5}]; % ADDED BY LINH
            end
            CMD = AuxCMD;
            Ncmd= a;
            
            % Changed from TXT file and PB.EXE code to pure matlab functions
            % JMazejhodges July 11, 2008
            % fid = fopen('pb_seq.txt','wt');
            % for cmd = 1:Ncmd
            %     fprintf(fid,'flags:%.0f\tinst:%.0f\tinst_data:%.0f\tdelay:%.0f\n',...
            %         Six + CMD{cmd,1},ValueCte(CMD{cmd,2}),CMD{cmd,3},CMD{cmd,4});
            % end
            % fclose(fid);
            %s = obj.CMD2PBI(CMD);
            
            if (~obj.PBisReady())
                obj.PBesrInit(); %initialize PBesr
            end
            % sets the clock frequency. for PBESR-PRO-400, it's 400MHz
            % for PBESR-PRO-333, it's 333.3MHz
            obj.PBesrSetClock();
            %PBesrSetClock(300);
            obj.PBesrStop();
            
            obj.PBesrStartProgramming(); % enter the programming mode
            
            % Loop over all commands
            for cmd = 1:Ncmd
                %flag = Six + CMD{cmd,1};  % Adding the Six option no longer necessary
                flag = CMD{cmd,1};
                flag_option = CMD{cmd,5};
                inst = char(CMD{cmd,2});
                inst_arg = CMD{cmd,3};
                leng = CMD{cmd,4};
                % give the instruction to the PB
                PBstatus = obj.PBesrInstruction(flag, flag_option, inst, inst_arg, leng);
                %     if PBstatus < 0,
                %     tic
                %         warning('[%d] Invalid PulseBlaster Instruction (Line %d)\nCMD = [%d]\t[%s]\t[%d]\t[%g]\t[%s]',PBstatus, cmd,flag,inst,inst_arg,length,flag_option);
                %     end
                %     toc
                %     pause(0.002); % for some reason this makes loop work--wtf
            end
            
            % Last command is to stop the outputs
            flag = 0; % set all lines low
            obj.PBesrInstruction(flag, flag_option, 'CONTINUE', 0, 100);
            obj.PBesrInstruction(flag, flag_option, 'STOP', 0, 100);
            
            obj.PBesrStopProgramming(); % exit the programming mode
            
            %PBesrStart(); %start pulsing. it will start pulse sequence which were progammed/loaded to PBESR card before.
            
            % PBesrClose(); %close PBesr
            %set status to 0, implement in the future
            %status = s;
            
            
        end
        
        %         function AddChannel(obj,channelNumber,channelName)
        %             %Adds another channel to PB, given a channel number and name.
        %             %If a name isnt given, the channel will be named after the
        %             %channel number.
        %             if nargin<3
        %                 channelName=num2str(channelNumber);
        %             end
        %             if length(channelNumber)~=1 || length(channelName)~=1
        %                 error('input a single number-name pair at a time')
        %             end
        %
        %             if ~ismember(channelNumber,obj.channelPrivate) && ~ismember(channelName,obj.namePrivate); % add a new name- number pair
        %                 obj.channelPrivate=[obj.channelPrivate, channelNumber];
        %                 obj.namePrivate=[obj.namePrivate,channelName];
        %             elseif (obj.channelPrivate==channelNumber) == strcmp(obj.namePrivate,channelName) %name-number pair already in the list
        %             else
        %                 error('Channel Name (%s) or number (%f) already exist, and not as a pair.',channelName,channelNumber);
        %             end
        %         end
    end
    
    methods (Access = private)
        % Internal workings
                   
        function chooseOnChannels(obj, channels)
            % Turn (or keep) on only the channels referred to by channels.
            % 
            % input:
            % - channels:   binary representation of the channels which are
            %               on. For example, 11 (= 1 + 2 + 8) means that
            %               only channels 0, 1 and 3 are on.
            
            obj.PBesrStartProgramming(); % enter the programming mode
                label = obj.PBesrInstruction(channels, 'ON', 'CONTINUE', 0, 100);
                obj.PBesrInstruction(channels, 'ON', 'BRANCH', label, 100);
            obj.PBesrStopProgramming(); % exit the programming mode
            
            obj.PBesrStop();
            obj.PBesrStart();
            
            % Store the new state internally
            obj.onChannelsBinary = channels;
        end
        
        function getReady(obj)
            if (~obj.PBisReady())
                obj.PBesrInit(); % initialize PBesr
                obj.PBesrSetClock();
            end
        end
    end
    
    methods %!%(Access = private)
        
        
        function [j]= Index(obj,channel)
            %recives either channel's name or number
            %returnes the channels location in channelPrivate
            if iscell(channel)
                I=find(strcmp(channel,obj.NamePrivate));
                j=obj.channelPrivate(I);
            elseif isnumeric(channel)
                I=find(obj.channelPrivate==cannel);
                j=obj.channelPrivate(I);
            else
                error('couldnt find the PB channel');
            end
            
        end
        
        % function Status(obj,status)
        % if status==0;
        
        % elseif status==1;
        
        %  elseif status==2;
        
        %   else error('Not an option');
        
        %    end
        
        % end
        
    end
    
    methods %!%(Access = private)
        %functions copied from PBFunctionpool,basics.
        
        function status = PBesrStopProgramming(obj)
            %Send a software trigger to the board. This will start execution of a pulse
            % program. It will also trigger a program which is currently paused due to
            % a WAIT instruction. Triggering can also be accomplished through hardware,
            % please see your board's manual for details on how to accomplish this.
            % \return A negative number is returned on failure, and spinerr is set to a
            % description of the error. 0 is returned on success.
            status = calllib('mypbesr','pb_stop_programming');
        end
        
        function status = PBesrStop(obj)
            %Stops the output of board and resets the PulseBlaster Core. Analog output will
            % return to ground, and TTL outputs will either remain in the same state they were
            % in when the reset command was received or return to ground. This also resets the
            % PulseBlaster Core so that the board can be run again using pb_start() or a hardware
            % trigger.  Note: Either pb_reset() or pb_stop() must be called before pb_start() if
            % the pulse program is to be run from the beginning (as opposed to continuing from a
            % WAIT state).
            % \return A negative number is returned on failure, and spinerr is set to a
            % description of the error. 0 is returned on success.
            status = calllib('mypbesr','pb_stop');
        end
        
        function status = PBesrStartProgramming(obj)
            
            PULSE_PROGRAM  = 0;
            FREQ_REGS      = 1;
            
            PHASE_REGS     = 2;
            TX_PHASE_REGS  = 2;
            PHASE_REGS_1   = 2;
            
            RX_PHASE_REGS  = 3;
            PHASE_REGS_0   = 3;
            
            status = calllib('mypbesr','pb_start_programming',PULSE_PROGRAM);
        end
        
        
        function status = PBesrStart(obj)
            % ed on failure, and spinerr is set to a
            % description of the error. 0 is returned on success.
            status = calllib('mypbesr','pb_start');
        end
        function PBesrSetClock(obj)
            %End communication with the board. This is generally called as the last line in a program.
            % Once this is called, no further communication can take place with the board
            % unless the board is reinitialized with pb_init(). However, any pulse program that
            % is loaded and running at the time of calling this function will continue to
            % run indefinitely.
            %
            % \return A negative number is returned on failure, and spinerr is set to a
            % description of the error. 0 is returned on success.
            %calllib('mypbesr','pb_set_clock',obj.frequencyPrivate*1e-6);%in MHz
            calllib('mypbesr','pb_set_clock',obj.frequencyPrivate);%in MHz
        end
        
        function inst_num = PBesrInstruction(obj,flag, flag_option, inst, inst_arg, length)
            %added by Sungkun
            %input arguments
            %flag : flag of set of channels to be on
            %flag_option : options to be associated with flag. string type.
            %inst : specific instruction including loop, branch, etc.. string type.
            %inst_arg : instruction specific arguments. usually integer.
            %length : length of pulse in nanosecond.
            
            %output argument : number of instruction.
            
            
            %flag_option map. string-to-bits
            ALL_FLAGS_ON	= hex2dec('1FFFFF');
            ONE_PERIOD		= hex2dec('200000');
            TWO_PERIOD		= hex2dec('400000');
            THREE_PERIOD	= hex2dec('600000');
            FOUR_PERIOD		= hex2dec('800000');
            FIVE_PERIOD		= hex2dec('A00000');
            SIX_PERIOD      = hex2dec('C00000');
            ON				= hex2dec('E00000');
            
            %instruction map. string-to-bits
            CONTINUE = 0;
            STOP = 1;
            LOOP = 2;
            END_LOOP = 3;
            JSR = 4;
            RTS = 5;
            BRANCH = 6;
            LONG_DELAY = 7;
            WAIT = 8;
            
            switch flag_option
                case 'ON'
                    flag = bitor(flag, ON);
                case 'ONE_PERIOD'
                    flag = bitor(flag, ONE_PERIOD);
                case 'TWO_PERIOD'
                    flag = bitor(flag, TWO_PERIOD);
                case 'THREE_PERIOD'
                    flag = bitor(flag, THREE_PERIOD);
                case 'FOUR_PERIOD'
                    flag = bitor(flag, FOUR_PERIOD);
                case 'FIVE_PERIOD'
                    flag = bitor(flag, FIVE_PERIOD);
                case 'SIX_PERIOD'
                    flag = bitor(flag, SIX_PERIOD);
                case 'ALL_FLAGS_ON'
                    flag = ALL_FLAGS_ON;
                otherwise
            end
            
            switch inst
                case 'CONTINUE'
                    inst = CONTINUE;
                case 'STOP'
                    inst = STOP;
                case 'LOOP'
                    inst = LOOP;
                case 'END_LOOP'
                    inst = END_LOOP;
                case 'JSR'
                    inst = JSR;
                case 'RTS'
                    inst = RTS;
                case 'BRANCH'
                    inst = BRANCH;
                case 'LONG_DELAY'
                    inst = LONG_DELAY;
                case 'WAIT'
                    inst = WAIT;
                otherwise
            end
            
            inst_num = calllib('mypbesr','pb_inst_pbonly',flag, inst, inst_arg, length);
        end
        
        function status = PBesrGetError(obj)
            %Get the firmware version on the board. This is not supported on all boards.
            %return Returns the firmware id as described above. A 0 is returned if the
            %firmware id feature is not available on this version of the board.
            status = calllib('mypbesr','pb_get_error');
        end
        
        function status = PBesrClose(obj)
            status = calllib('mypbesr','pb_close');
        end
        
        %         function LoadPBESR(obj)
        %
        %             if ~libisloaded('mypbesr')
        %                 disp('Matlab: Load spinapi.dll')
        %                 % Added by Sungkun
        %                 % spinapi.h C:\Program Files\SpinCore\SpinAPI\dll
        %                 % spinapi.dll C:\Program Files\SpinCore\SpinAPI\dll
        %                 funclist = loadlibrary('C:\SpinCore\SpinAPI\dll\spinapi64.dll','C:\SpinCore\SpinAPI\dll\spinapi.h','alias','mypbesr');
        %             end
        %             disp('Matlab: spinapi.dll loaded')
        %
        %             % disp('Initializing the board... ')
        %             % if PBesrInit() ~= 0; %initialize PBesr
        %             % error('Error: %s\n', PBesrGetError());
        %             % end
        %             %
        %             % % sets the clock frequency. for PBESR-PRO-400, it's 400MHz
        %             % % for PBESR-PRO-333, it's 333.3MHz
        %             % PBesrSetClock(400);
        %         end
        function status = PBesrInit(obj)
            status = calllib('mypbesr', 'pb_init');
        end
        
        function [ValidCMD] = ValidateCMD(obj, CMD, ClockTime)
            % checks the CMD structure for erroneously short instruction delays due to
            % rounding errors in building the pulse sequence via matlab
            
            a = 1;
            for k = 1:size(CMD, 1)
                
                % 1 ns is the minimum delay until next instruction
                if CMD{k,4} > 1
                    
                    Delay = CMD{k,4};
                    ClockPeriods = round(Delay/(ClockTime));
                    
                    ValidCMD{a,1} = CMD{k,1};
                    ValidCMD{a,2} = CMD{k,2};
                    ValidCMD{a,3} = CMD{k,3};
                    
                    switch ClockPeriods
                        
                        case 1
                            ValidCMD{a,4} = 5*ClockTime;
                            ValidCMD{a,5} = 'ONE_PERIOD';
                            
                        case 2
                            ValidCMD{a,4} = 5*ClockTime;
                            ValidCMD{a,5} = 'TWO_PERIOD';
                            
                        case 3
                            ValidCMD{a,4} = 5*ClockTime;
                            ValidCMD{a,5} = 'THREE_PERIOD';
                            
                        case 4
                            ValidCMD{a,4} = 5*ClockTime;
                            ValidCMD{a,5} = 'FOUR_PERIOD';
                            
                        case 5
                            ValidCMD{a,4} = 5*ClockTime;
                            ValidCMD{a,5} = 'FIVE_PERIOD';
                            
                        case 6
                            ValidCMD{a,4} = ClockPeriods*ClockTime;
                            ValidCMD{a,5} = 'SIX_PERIOD';
                            
                        otherwise
                            ValidCMD{a,4} = ClockPeriods*ClockTime;
                            ValidCMD{a,5} = 'ON';
                            
                    end
                    
                    % Due to a peculiarity in the PB to CMD logic, we can end up
                    % having LONG_DELAY types with only 1 multiplier.  These should be
                    % made into continue delays
                    if strcmp(CMD{k,2}, 'LONG_DELAY') && (CMD{k,3} == 1)
                        ValidCMD{a,1} = CMD{k,1};
                        ValidCMD{a,2} = 'CONTINUE';
                        ValidCMD{a,3} = 0;
                        ValidCMD{a,4} = CMD{k,4};
                        ValidCMD{a,5} = 'ON';
                    end
                    
                    a = a+1;
                    
                end
            end
        end
        function [PBready] = PBisReady(obj)
            stat = obj.PBesrReadStatus();
            % the check for stat<100 is supposed to capture an uninitialized board.
            % This is not fool-proof, and should be fixed somehow
            if (stat>0) && (stat<100)
                PBready=1;
            else
                PBready=0;
            end
        end
        
        function status = PBesrReadStatus(obj)
            status = calllib('mypbesr','pb_read_status');
        end
        
        function s = CMD2PBI(obj, CMD)
            % converts a CMD structure to pulse blaster interpreter code for debugging
            s = '';
            for k = 1:size(CMD,1)
                flags = dec2hex(CMD{k,1}, 6);
                delay = CMD{k,4};
                inst = CMD{k,2};
                inst_opt = CMD{k,3};
                flag_opt = CMD{k,5};
                
                if strcmp(flag_opt, 'ON')
                    ON = hex2dec('E00000');
                    flags = bitor(ON, CMD{k,1});
                    flags = dec2hex(flags);
                end
                
                s = [s,sprintf('0x%s,\t%0.3fns,\t%s,\t%d\n', flags, delay, inst, inst_opt)];
            end
        end
        
    end
    
    methods
        function CallPBON(obj, OutPuts)
            %This Function receives a Binary number
            
            %Outputs file
            WriteOutPuts(OutPuts);
            
            %Executable file
            path = '';
            file = 'PB_ON.exe';
            
            status = dos([path file]);
        end
    end
    
    %% Get instance constructor
    methods (Static, Access = public)
        function obj = GetInstance(struct)
            % Returns a singelton instance.
            obj = getObjByName(PulseGenerator.NAME);
            if isempty(obj)
                % None exists, so we create a new one
                missingField = FactoryHelper.usualChecks(struct, PulseBlasterNewClass.NEEDED_FIELDS);
                if ~isnan(missingField)
                    error('Error while creating a PulseBlaster object: missing field "%s"!', missingField);
                end
                
                obj = PulseBlasterNewClass();
                path = struct.libPathName;
                Initialize(obj, path)
                
                addBaseObject(obj)
            end
        end
    end
end
