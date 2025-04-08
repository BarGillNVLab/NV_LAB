classdef FrequencyGeneratorTektronixAWG < FrequencyGenerator
        %FREQUENCYGENERATOR Tektronix AWG class


    properties (Constant, Hidden)
        TYPE = 'TektronixAWG';
        MODE_FG = 'FGEN';               % function generator mode
        MODE_AWG = 'AWG';               % AWG mode
        
        NEEDED_FIELDS = {'address', 'serialNumber', 'minFrequency', 'maxFrequency', 'minAmplitude', 'maxAmplitude', ...
                         'trigger1Channel', 'trigger1ChannelName',  'onDelay1', 'offDelay1'};
        OPTIONAL_FIELDS = {'trigger2Channel', 'trigger2ChannelName',  'onDelay2', 'offDelay2'};
        MAX_SAMPLE_RATE = 16e3;         % MHz
        MIN_SAMPLE_RATE = 8e3;          % MHz. recommended, not physical
        MAX_VPP = 0.50;                 % The constant Vpp we work with
        TRIG_SOURCE = 'EXT';            % 'INT' for internal trigger. 'EXT' for external trig. Use internal for testing.
        TIME_CONVERT = 1e6;
        MAX_REAPETS = 10e5;
        MIN_WAVEFORM_LENGTH = 2400;     % minimum samples for waveform
        VISA_BRAND = 'ni';              % VISA brand
        BUFFER = 5e7;                   % buffer length
        TRIG_DURATION = 0.1;
        COMM_DELAY = 0.005;             % double. (Default value) time (in seconds) between consecutive commands
        RUN_MODE_CONT = 'continuous';
        RUM_MODE_TRIG = 'triggered';
        RUN_MODE_TCON = 'tcontinuous';
    end
       
    properties (Access = private)
        address
        v                       % visa object
        mode                    % AWG / FGEN (function generator)
    end
    
    properties
        MaxNormPowerAllowed
        Vpp
        workChannels
        
        SampleRate              % in MHz
        waveforms               % segmentLibrary{channel}, where channel is 1 or 2. Each segment must by of length 1(DC), of length >=16 and devides by 4.
        sequences
    end
    
    properties (Dependent)
        minWaveformDuration     % in mus
    end
        
    
    methods (Access = private)
        function obj = FrequencyGeneratorTektronixAWG(name, address, frequencyLimits, amplitudeLimits, triggersNames, channels, delays)
            % All models are the same in regards to controlling them, but
            % the limitations on the amplitude and on the allowed frequencies may vary.
            obj@FrequencyGenerator(name, frequencyLimits, amplitudeLimits);
            obj.address = address;
            obj.connect;
            if strcmp(obj.queryValue('mode'), obj.MODE_AWG)
                obj.mode = obj.MODE_AWG;
            else
                obj.mode = obj.MODE_FG;
            end
            obj.RegisterPgChannels(triggersNames, channels, delays);
            obj.Reset;
            obj.initialize;
        end
        
        
    end
    
%%  General functions     
    methods
        function connect(obj)
            if isempty(obj.v) || ~isvalid(obj.v)
                obj.v = visa(obj.VISA_BRAND, obj.address, 'InputBufferSize', obj.BUFFER, 'OutputBufferSize', obj.BUFFER);
            end
            if strcmp(obj.v.Status, 'closed')
                fopen(obj.v);
            end
        end

        function disconnect(obj)
            if strcmp(obj.v.Status, 'open')
                obj.setValue('enableOutput', '0', 1);
                obj.setValue('enableOutput', '0', 2);
                fclose(obj.v);
            end
        end

        function delete(obj)
            obj.disconnect;
            delete(obj.v)
        end
        
        function sendCommand(obj, command, precision)
%             Actually sends command to hardware
            obj.connect() % Only happens if it is closed
            if nargin < 3
                try
                    fwrite(obj.v, command);
                catch err
                    obj.disconnect();
                    obj.connect();
                    obj.sendError(err);
                end
            else
                if strcmp(precision, 'single')
                    if length(command)>10000
                        wq = 0;
                    end
                    fwrite(obj.v, command, precision);
                else
                    error('can not send command: "precision" does not right')
                end
            end
            obj.commDelay();
            obj.verifyOperationComplete();
        end
        
        function value = readOutput(obj, what)
            % Get value returned from object
            value = fscanf(obj.v, '%s');
            switch what
                case {'frequency', 'freq', 'f'}
                    value = num2str(str2double(value)/1e6);  % convert Hz to MHz
                case {'enableoutput', 'output', 'enabled', 'enable'}
                    value = num2str(strcmp(value,'1;FGEN'));
            end
        end

        function setTimeOut (obj, TimeOut)
            if (TimeOut < 30) || (TimeOut > 1000)
                warning('timeout is not changed, it must be more than 30 and less than 1000')
            else
                obj.v.timeout = TimeOut;
            end
        end

        function setAmplitude (obj, Power)
            % The actual amplitude is const, and we just change the 'MaxNormPowerAllowed'
            % just for back support:
            if nargin == 1
                obj.MaxNormPowerAllowed = 1;
            else
                if max(Power) > obj.maxAmpl
                    error('max value for power is %d dBm, the current is %d.', obj.maxAmpl, max(Power))
                end
                Power_Volt  = obj.dBmToVpp(Power);
                obj.MaxNormPowerAllowed = Power_Volt/obj.MAX_VPP;
            end
            for i = 1:length(Power)
                AmpCmd = sprintf('SOURCE%d:VOLTAGE:AMPLITUDE %d', i, obj.MAX_VPP);
                obj.sendCommand(AmpCmd);
            end
        end
        
        function set.SampleRate(obj, newSampleRate)
            if (newSampleRate < obj.MIN_SAMPLE_RATE) || (newSampleRate > obj.MAX_SAMPLE_RATE)
                error('Sample rate must be between %d and %d Ms, the current is %d', obj.MIN_SAMPLE_RATE, obj.MAX_SAMPLE_RATE, newSampleRate);
            end
            obj.SampleRate = newSampleRate;
            RateCommand = sprintf('clock:srate %f', obj.SampleRate*obj.TIME_CONVERT);
            obj.sendCommand(RateCommand);
        end
        
        function set.workChannels(obj, n)
            obj.workChannels = n;
            if ismember(1, n)
                obj.sendCommand('output1:state on');
            else
                obj.sendCommand('output1:state off');
            end
            if ismember(2, n)
                obj.sendCommand('output2:state on');
            else
                obj.sendCommand('output2:state off');
            end
        end
        
        function t = get.minWaveformDuration(obj)
            minTime = 1/obj.SampleRate * obj.MIN_WAVEFORM_LENGTH;
            t = ceil(minTime * obj.SampleRate) / obj.SampleRate;
        end
    end

%% Adding waveforms and sequences:
    methods

        function index = AddWaveformByPoints(obj, newWaveform, initPadding, finalPadding, indexPlot)
            % Stores a new waveform at the end of obj.waveforms. Use LoadWaveforms to load to AWG.
            % The waveform is given by an array of amplitudes in the range of -1 to 1.
            % The optional padding parameters if for zero points around the waveform. The value is in number op points.
            % this function returns the index of the new waveform.
            if ~exist('initPadding', 'var')
                initPadding = 0;
            end
            if ~exist('finalPadding', 'var')
                finalPadding = 0;
            end
            if ~exist('indexPlot', 'var')
                indexPlot = 1;
            end
            if length(newWaveform) + initPadding + finalPadding < obj.MIN_WAVEFORM_LENGTH
                error('The minimum length of waveform is %d, the current is %d', obj.MIN_WAVEFORM_LENGTH, length(newWaveform) + initPadding + finalPadding)
            end
            if max(abs(newWaveform)) > 1
                error('Amplitude waveform must be between -1 to 1');
            end
            s = obj.waveforms;
            s{end+1} = [zeros(1,initPadding), newWaveform, zeros(1,finalPadding)];
            obj.waveforms = s;
            index = length(obj.waveforms);
            if indexPlot
                fprintf('%d ', index);
            end
        end
        
        function [index,wf,t] = AddWaveformByFunction(obj,f, duration, shift, toRound, toReverse)
            % Adding waveform of f(t-shift), for t=[0,duration].
            % t in mus!!
            % the parameter 'toRound' is 1 if you want round the 'duration' to divided by the sample time
            % this function return the waveform and time vectors for debuging. 
            if ~exist('toRound', 'var')
                toRound = 0;
            end
            if ~exist('toReverse', 'var')
                toReverse = 0;
            end
            t_sample = 1/obj.SampleRate; %sign(duration) is for t left to zero, without using shift
            if toRound
                duration = round(duration/t_sample)*t_sample;
            end
            if sign(duration) == 1
                t = 0 : t_sample : duration-t_sample;
            else
                t = 0-t_sample : -t_sample : duration;
            end
            % tests:
            MAX_ERROR = 1e-9;
            if mod(duration,t_sample) > MAX_ERROR && t_sample - mod(duration,t_sample) > MAX_ERROR 
                error('The parameter ''duration'' not divided by the AWG sample time. Fix it or change the parameter ''toRound'' to ''True''')
            end
            if length(t) < obj.MIN_WAVEFORM_LENGTH
                error('Tha minimum waveform length the AWG can get is %d samples, The current is %d.', obj.MIN_WAVEFORM_LENGTH, length(t))
            end
            
            % creating the waveform:
            wf = f(t-shift);
            if toReverse
                wf = flip(wf);
            end
            index = AddWaveformByPoints(obj,wf);
        end

        function [index,WF,t] = AddWaveformByDuration(obj,newWaveformI,newWaveformQ,f,duration,t0)
            % Adds a new waveform with each point caried out for a duration given by "duration" - in \mus
            % newWaveformI/Q must be between -1:1. "f"- in \MHz

            if isempty(newWaveformI) && ~isempty(newWaveformQ)
                newWaveformI = zeros(size(newWaveformQ));
            elseif ~isempty(newWaveformI) && isempty(newWaveformQ)
                newWaveformQ = zeros(size(newWaveformI));
            end
            if sum(size(newWaveformI) ~= [length(f),length(duration)]) || sum(size(newWaveformQ) ~= [length(f),length(duration)])
                error('Inputs must have the right size')
            end
            
            % change from duration to points
            points = round(duration*obj.SampleRate);
            timeChange = abs(sum((points)/obj.SampleRate - duration));
            if timeChange > 1e-6
                warning('Change in time due to round ups detected when converting waveform duration to # of points. total change of %f',timeChange)
            end
            
            % rewrite waveform as points for the AWG, (with each point of period 1/obj.SampleRate)
            t = (0 : 1/(sum(points)) : 1-1/(sum(points))).*sum(duration) + t0;
            if length(t) < obj.MIN_WAVEFORM_LENGTH
                error('Tha minimum point at waveform the AWG can get is %d , The current is %d. (At maximum sumple rate is consider toal waveform duration of 0.15us)',obj.MIN_WAVEFORM_LENGTH,length(t))
            end
            waveformI = zeros(length(f),length(points));
            waveformQ = waveformI;
            startIndex = 1;
            for k = 1:length(points)
                endIndex = startIndex + points(k) - 1;
                for j=1:length(f)
                    waveformI(j,startIndex:endIndex) = newWaveformI(j,k);
                    waveformQ(j,startIndex:endIndex) = newWaveformQ(j,k);
                end
                startIndex = endIndex+1;
            end
            for j=1:length(f)
                waveformI(j,:) = waveformI(j,:) .* sin(2*pi*f(j)*(t));
                waveformQ(j,:) = waveformQ(j,:) .* cos(2*pi*f(j)*(t));
            end
            waveformI = sum(waveformI,1);
            waveformQ = sum(waveformQ,1);
            WF = waveformI + waveformQ;
            index = AddWaveformByPoints(obj,WF);
        end

        function [index,WF,t] = AddWaveformByDurationPhaseModulationSpinLock(obj,newWaveformI,newWaveformQ,FuncI,FuncQ,f,duration,t0,alpha,RF,spinLock)
            % Adds a new waveform, with each point caried out for a duration given by "duration" - in \mus
            % newWaveformI/Q must be between -1:1. "f"- in \MHz
            % 'spinLock' gets 1 for spin lock and 0 for spin unLock
            
            if isempty(newWaveformI) && ~isempty(newWaveformQ)
                newWaveformI = zeros(size(newWaveformQ));
            elseif ~isempty(newWaveformI) && isempty(newWaveformQ)
                newWaveformQ = zeros(size(newWaveformI));
            end
            if sum(size(newWaveformI) ~= [length(f),length(duration)]) || sum(size(newWaveformQ) ~= [length(f),length(duration)])
                error('Inputs must have the right size')
            end
            
            % change from duration to points
            points = round(duration*obj.SampleRate);
            timeChange = abs(sum((points)/obj.SampleRate - duration));
            if timeChange > 1e-6
                warning('Change in time due to round ups detected when converting waveform duration to # of points. total change of %f',timeChange)
            end
            
            % rewrite waveform as points for the AWG, (with each point of period 1/obj.SampleRate)
            t = (0 : 1/(sum(points)) : 1-1/(sum(points))).*sum(duration) +t0;
            if length(t) < obj.MIN_WAVEFORM_LENGTH
                error('Tha minimum point at waveform the AWG can get is %d , The current is %d. (At maximum sumple rate is consider toal waveform duration of 0.15us)',obj.MIN_WAVEFORM_LENGTH,length(t))
            end
            waveformI = zeros(length(f),sum(points));
            waveformQ = waveformI;
            waveformIFunc = waveformI;
            waveformQFunc = waveformI;
            startIndex = 1;
            for k = 1:length(points)
                endIndex = startIndex + points(k) - 1;
                for j=1:length(f)
                    waveformI(j,startIndex:endIndex) = newWaveformI(j,k);
                    waveformQ(j,startIndex:endIndex) = newWaveformQ(j,k);
                    waveformIFunc(j,startIndex:endIndex) = FuncI(j,k);
                    waveformQFunc(j,startIndex:endIndex) = FuncQ(j,k);
                end
                startIndex = endIndex+1;
            end
            for j=1:length(f)
                if spinLock
                    waveformI(j,:) = (waveformI(j,:) + waveformIFunc(j,:) .* sin(alpha*sin(2*pi*RF*t))) .* sin(2*pi*f(j)*(t));
                    waveformQ(j,:) = (waveformQ(j,:) + waveformQFunc(j,:) .* cos(alpha*sin(2*pi*RF*t))) .* cos(2*pi*f(j)*(t));
                else % spin nuLock
                    waveformI(j,:) = (waveformI(j,:) + waveformIFunc(j,:) .* cos(alpha*sin(2*pi*RF*t))) .* sin(2*pi*f(j)*(t));
                    waveformQ(j,:) = (waveformQ(j,:) + waveformQFunc(j,:) .* sin(alpha*sin(2*pi*RF*t))) .* cos(2*pi*f(j)*(t));
                end
            end
            waveformI = sum(waveformI,1);
            waveformQ = sum(waveformQ,1);
            WF = waveformI + waveformQ;
            index = AddWaveformByPoints(obj,WF);
        end

        function [index, time, total_WF] = AddSequence(obj, WaveformsIndeces, Repeats, Triggers, WaveformDrawing)
            % Add a new sequence to obj.sequences:
            % WaveformsIndeces - vector of the waveforms indexes.
            % Repeats - vector of number of reapets for any waveform.
            % Triggers - vector of boolean values for all waveform if waiting to trigger
            % WaveformDrawing - boolean. If to draw the full sequence points.
            
            if nargin < 5 
                WaveformDrawing = 0;
            end
            
            s = obj.sequences;
            s.waveforms{end+1} = WaveformsIndeces;
            s.repeats{end+1}   = Repeats;
            s.trigger{end+1}   = Triggers;
            obj.sequences = s;
            index = length(obj.sequences.waveforms);
            
            % drawing the wavefotm
            time = 0;
            total_WF = 0;
            if WaveformDrawing(1) ~= 0
                % ploting waveform:
                total_WF = [];
                for q = 1:length(WaveformsIndeces)
                    total_WF = [total_WF, repmat(obj.waveforms{WaveformsIndeces(q)},1, Repeats(q))];
                end
                time = 0 : 1/obj.SampleRate : (length(total_WF)-1)/obj.SampleRate;
                figure;
                hold on; plot(time,total_WF);
                
                % optional ploting of constant cosine, to control the phase:
                if length(WaveformDrawing) > 1
                    w = WaveformDrawing(1);
                    A = WaveformDrawing(2);
                    if length(WaveformDrawing) == 3
                        t0 = WaveformDrawing(3);
                    else
                        t0 = 0;
                    end
                    time = 0 : 1/(10*obj.SampleRate) : (length(total_WF)-1)/obj.SampleRate;
                    f = @(t) A*cos(w*(t-t0));
                    plot(time, f(time), 'red');
                end
            end
        end
        
        function waveform = getWaveform(obj, index)
            if nargin == 1
                waveform = obj.waveforms;
            else
                waveform = obj.waveforms{index};
            end
        end

        function sequence = getSequence(obj, index)
            if nargin == 1
                sequence = obj.sequences;
            else
                S.waveforms = obj.sequences.waveforms{index};
                S.repeats   = obj.sequences.repeats{index};
                S.trigger   = obj.sequences.trigger{index};
                sequence = S;
            end
        end
        
        
        function LoadWaveform(obj)
            % Load stored waveforms to memory.
            fprintf('Loading %d waveforms to the AWG...', length(obj.waveforms));
            obj.deleteWaveforms;
            for k = 1:length(obj.waveforms)
                currentWaveform = obj.waveforms{k};
                if ~(max(abs(currentWaveform)) <= 1)
                     error('The max value allowed to insert to the AWG is +-1, the current is : %g' ,max(abs(currentWaveform)))
                end
                try
                    obj.WriteWaveformToAWG(currentWaveform,k)
                catch err
                    fprintf('Caught error trying to write waveform %d\n', k);
                    rethrow(err)
                end
            end
            fprintf(' Done!\n');
        end

        function LoadSequence(obj)
            % Load stored sequences to memory.
            fprintf('Loading %d sequences to the AWG...', length(obj.sequences.waveforms));
            obj.deleteSequences;
            for k = 1:length(obj.sequences.waveforms)
                obj.WriteSequenceToAWG(obj.sequences.waveforms{k}, obj.sequences.repeats{k}, obj.sequences.trigger{k}, k);
            end
            fprintf(' Done!\n');
        end
        
        function set.waveforms(obj, newWaveform)
            % waveforms will be added to obj.wavefoems{end+1}
            % waveform names are stored in AWG memory as arbseg# where # is as given in the waveforms{#}
            if ~isa(newWaveform,'cell')
                error('Input waveforms must be a cell array');
            end
            for k = 1:length(newWaveform)
                WF = newWaveform{k};
                if ~isnumeric(WF)
                    error('input must be numeric')
                end
                if length(WF) < obj.MIN_WAVEFORM_LENGTH
                    error('Tha minimum waveform length the AWG can get is %d samples, The current is %d.', obj.MIN_WAVEFORM_LENGTH, length(t))
                end
                if max(abs(WF)) > 1
                    error('Waveform''s maximum allowed total value is 1. the current maximum total value : %g', max(abs(WF)))
                end
            end
            obj.waveforms = newWaveform;
        end
        
        function set.sequences(obj,newSequence)
            % inserts values to sequence property. Composed of a cell
            % (stores different sequences), with each one having 3 vector fields:
            % waveform numbers - "waveforms", repeats and trigger
            % sequence names are stored in AWG memory as arbseq# where # is
            % as given in the sequence{#}
            if ~isfield(newSequence,'waveforms') ||...
                    ~isfield(newSequence,'repeats')...
                    || ~isfield(newSequence,'trigger')
                error('sequence must include waveforms, repeats and triggers')
            end
            if range([length(newSequence.waveforms), length(newSequence.repeats), length(newSequence.trigger)]) > 0
                error('Input fields must have the same length')
            end
            if ~isa(newSequence.waveforms,'cell') || ...
                    ~isa(newSequence.repeats,'cell') || ~isa(newSequence.trigger,'cell')
                error('input fields must be cell arrays')
            end
            for k = 1:length(newSequence.waveforms) % test that each element in the cell has the currect structure
                % test if input is empty or numeric
                if (~isempty(newSequence.waveforms{k}) && ~isnumeric(newSequence.waveforms{k})) || ...
                        (~isempty(newSequence.repeats{k}) && ~isnumeric(newSequence.repeats{k}))
                    error('input must be numeric')
                end
                % test if input is empty or numeric or logical
                if ~isempty(newSequence.trigger{k}) && ~isnumeric(newSequence.trigger{k}) && ~islogical(newSequence.trigger{k})
                    error('input must be numeric or logical')
                end
                % test equal length
                if range([length(newSequence.waveforms{k}), length(newSequence.repeats{k}), length(newSequence.trigger{k})]) > 0
                    error('Input fields must have the same length')
                end
                % test number of repeats
                if sum(newSequence.repeats{k} < 0) || sum(newSequence.repeats{k} > obj.MAX_REAPETS)
                    error('repeats must be between 0 and %d', obj.MAX_REAPETS)
                end
            end
            obj.sequences.waveforms = newSequence.waveforms;
            obj.sequences.repeats   = newSequence.repeats;
            obj.sequences.trigger   = newSequence.trigger;
        end
        
    end
    
%% User control functions
    methods
        
        function Run(obj)
            obj.deviceReady();
            pause(0.3);
            obj.sendCommand('awgcontrol:run:immediate');
            obj.deviceReady();
            pause(0.5);
            obj.waitForRunning();
        end
        
        function setRunMode(obj, mode, channels)
            % set the run mode of the channels
            % channels: 1, 2, or [1 2]
            if ~exist('channels', 'var')
                channels = 1;
            end
            if ~srtcmpi(mode, obj.RUN_MODE_CONT) && ~srtcmpi(mode, obj.RUM_MODE_TRIG) && ~srtcmpi(mode, obj.RUN_MODE_TCON)
                error('AWG run mode can be just "%s", "%s", or "%s"', obj.RUN_MODE_CONT, obj.RUM_MODE_TRIG, obj.RUN_MODE_TCON);
            end
            for i = 1:length(channels)
                runModeCommand = sprintf('SOURce%d:RMODe %s', channels(i), mode);
                obj.sendCommand(runModeCommand);
            end
        end
        
        function assignSequence(obj, sequenceNum, channel)
            % assign sequenct to a channel
            if nargin < 3
                channel = 1;
            end
            assign_command = sprintf('source%d:casset:sequence "%s", 1',channel, num2str(sequenceNum)); % assign sequence to track 1
            obj.sendCommand(assign_command);
        end
        
        function assignWaveform(obj, waveformNum, channel)
            % assign waveform to a channel
            if nargin < 3
                channel = 1;
            end
            assign_command = sprintf('source%d:casset:waveform "%s"',channel, num2str(waveformNum)); % assign waveform to track 1
            obj.sendCommand(assign_command);
        end
        
        function ChangeSampleRate(obj, Durations)
            % change the sample rate of the AWG to the highest number that divide (1/f) by all the times in the durations vector
            MAX_ERROR = 1e-10;
            f = obj.MAX_SAMPLE_RATE;
            while sum(mod(Durations,1/f)) > MAX_ERROR
                f = f - 1e-6;
                if f < obj.MIN_SAMPLE_RATE
                    error('AWG sample rate not found');
                end
            end
            obj.SampleRate = round(f,6);
        end
        
        function maxfreq = CheckMinTimeFotReapets(obj,f)
            if length(f) == 6
                syms m1 m2 m3 m4 m5 m6
                eqns = [f(1)/m1-f(2)/m2,f(2)/m2-f(3)/m3,f(3)/m3-f(4)/m4,f(4)/m4-f(5)/m5,f(5)/m5-f(6)/m6,f(6)/m6-f(1)/m1];
                vars = [m1,m2,m3,m4,m5,m6];
                sol = solve(eqns,vars);
                y = [(sol.m1) (sol.m2) (sol.m3) (sol.m4) (sol.m5) (sol.m6)] ;
                [~,D] = numden(y);
                multiple = single(max(D));
                y = multiple*single(y);
                if y(1)/f(1) ~= y(2)/f(2) &&  y(3)/f(3) ~= y(4)/f(4) && y(1)/f(1) ~= y(4)/f(4) && y(5)/f(5) ~= y(6)/f(6) && y(1)/f(1) ~= y(6)/f(6)
                    error('can not find corporate pereiod time')
                end
                commonFrequnecy = f(1)/y(1);
            elseif length(f) == 2
                syms m1 m2
                eqns = f(1)/m1-f(2)/m2;
                vars=[m1,m2];
                sol = solve(eqns,vars);
                y = [(sol.m1) (sol.m2)] ;
                [~,D] = numden(y);
                multiple = single(max(D));
                y = multiple*single(y);
                if y(1)/f(1) ~= y(2)/f(2)
                    error('can not find corporate pereiod time')
                end
                commonFrequnecy = f(1)/y(1);
            elseif length(f) == 1
                commonFrequnecy = f;
            else
                error('there is no option to check period for %g frequencies. just for : 1 , 2 or 6 per waveform', length(f))
            end
            maxfreq = gcd(commonFrequnecy*obj.TIME_CONVERT, obj.SampleRate*obj.TIME_CONVERT) / obj.TIME_CONVERT;
        end
        
        function Reset(obj)
            obj.sendCommand('*RST');
            obj.setTimeOut(100);
            obj.SampleRate = obj.MAX_SAMPLE_RATE;
            obj.workChannels = 1;
            obj.ResetStoredData;
        end
        
        function ResetStoredData(obj)
            obj.waveforms = {};
            s.waveforms = {};
            s.repeats = {};
            s.trigger = {};
            obj.sequences = s;
        end
        
    end

%% Function generator mode functions
    methods
        function command = createCommand(obj, what, value, channel)
            space = repmat(' ',1,~strcmp(value,'?'));   % '?' shold be without space and value with space
            chan =  num2str(channel);
            switch lower(what)
                case {'enableoutput', 'output', 'enabled', 'enable'}
                    switch value
                        case {'1', 'ON'}
                            obj.setValue('mode', 'FGEN');
                            command = ['OUTP', chan, ' ON; AWGC:RUN'];
                        case {'0', 'OFF'}
                            command = ['AWGC:STOP; OUTP', chan, ' OFF'];
                        case '?'
                            command = ['OUTP', chan, '?; INST:MODE?'];
                        otherwise
                            error('no type of OUTPUT syntax "%s"',value)
                    end
                case {'frequency', 'freq'}
                    if ~strcmp(value, '?')
                        value = value*1e6; % convert MHz to Hz
                    end
                    command = ['FGEN:CHAN', chan, ':FREQ' ,    space , num2str(value)];
                case {'amplitude', 'ampl', 'amp'}
                    command = ['FGEN:CHAN', chan, ':AMPL:POW', space , num2str(value)];
                case {'phase'}
                    command = ['FGEN:CHAN', chan, ':PHAS',     space , num2str(value)];
                case {'mode'}
                    if sum(strncmp(value, {obj.MODE_FG, obj.MODE_AWG, '?'},10))
                        command = ['INST:MODE', space, value];
                        if ~strcmp(value, '?')
                            obj.mode = value;
                        end
                    else
                        error('no type of mode %s', value)
                    end
                otherwise
                    error('Unknown command type %s', what)
            end
        end
    end
    
%% AWG programming:
    methods (Access = private)
        
        function deleteWaveforms(obj)
            command = 'wlist:waveform:delete ALL';
            obj.sendCommand(command); 
        end
        
        function deleteSequences(obj)
            command = 'slist:sequence:delete ALL';
            obj.sendCommand(command); 
        end
       
        function WriteWaveformToAWG(obj, waveform, waveformName)
            % loads a single waveform (a vector of numbers) to trace number 'traceNumber' of the AWG.
            % Segment is in bytesarray, as given by the 'arbitraryWaveform'.
            
            if max(abs(waveform)) > 1
                error('The maximal total value for waveform must be less than 1')
            end
            if length(waveform) < obj.MIN_WAVEFORM_LENGTH
                error('Tha minimum point at waveform the AWG can get is %d , The current is %d. (At maximal sumple rate is consider toal waveform duration of 0.15us)',obj.MIN_WAVEFORM_LENGTH,length(waveform))
            end                
            
            Waveform_Name_1 = sprintf('%g',waveformName);                   % Waveform name
            Waveform_Data_1 = single(waveform);                             % Waveform data
            wfm_bytes = length(Waveform_Data_1) * 4;                        % waveform size, a single point is 4 bytes
            
            % Generate commands:
            delete_waveform = sprintf('wlist:waveform:delete "%s"', Waveform_Name_1);               %delete any previous instances of the waveform we're sending
            wfm_header      = sprintf('#%d%d',length(num2str(wfm_bytes)), wfm_bytes);               %generate an IEEE 488.2 binblock header
            create_waveform = sprintf('wlist:waveform:data "%s",%s', Waveform_Name_1, wfm_header);  %generate first part of the command to send the waveform data
            new_waveform    = sprintf('wlist:waveform:new "%s", %d', Waveform_Name_1, length(Waveform_Data_1));
            
            % Send commands:
            obj.sendCommand(delete_waveform);           % send delete waveform command
            obj.sendCommand(new_waveform);              % send new waveform command
            obj.v.EOIMode = 'off';                      % turn off automatic assertion of EOI at end of writes so we can send single command with multiple writes
            obj.sendCommand(create_waveform);           % send header of create waveform command
            obj.v.EOIMode = 'on';                       % turn EOI mode back on
            obj.sendCommand(Waveform_Data_1,'single');  % send data for the create waveform command
            obj.sendCommand('*WAI');
        end        

        function WriteSequenceToAWG(obj, WaveformsIndeces, Repeats, Triggers, traceNum)
            % Uploads a sequence of waveforms (vectors), with a given number of repeats for each one and a trigger mode (0 or 1).
            % This will be stored as "arbseq#' where # is the traceNum
            
            if range([length(WaveformsIndeces), length(Repeats), length(Triggers)]) > 0
                error('All of the vectors must be in the same length')
            end
            
            seq_name = sprintf('%g',traceNum);
            steps = length(WaveformsIndeces);
            
            delete = sprintf('slist:seq:delete "%s"', seq_name);
            obj.sendCommand(delete);
            create_seq = sprintf('slist:seq:new "%s", %d, 1', seq_name, steps); %2 steps, 1 track
            obj.sendCommand(create_seq);
            
            for r = 1:steps
                if (Triggers(r) == 1) && (Repeats(r) ~= 1)
                    error('last sequence is a loop. This is not supported (trig problem)')
                end
                
                % Generate commands:
                currentWavform = sprintf('%d',WaveformsIndeces(r));
                assign_step    = sprintf('slist:seq:step%d:tasset1:wav "%s", "%s"',r, seq_name, currentWavform);
                repeart_count  = sprintf('slist:seq:step%d:rcount "%s", %d',r ,seq_name, Repeats(r));
                if Triggers(r) == 0
                    define_Trigger = sprintf('slist:seq:step%d:winput "%s", off',r, seq_name);
                else
                    define_Trigger = sprintf('slist:seq:step%d:winput "%s", atrigger',r, seq_name);
                end
                
                % Send commands:
                obj.sendCommand(assign_step);
                obj.sendCommand(repeart_count);
                obj.sendCommand(define_Trigger);
            end
            last2first = sprintf('slist:seq:step%d:goto "%s", first',r, seq_name);
            obj.sendCommand(last2first);
            obj.sendCommand('*WAI');    %Make sure no other commands are exectued until arb is done downloadin
        end
        
        function waitForRunning(obj)
            timer = tic;
            while ~query(obj.v,'AWGControl:RSTate?')
                obj.commDelay();
                if toc(timer) > obj.COMM_DELAY * 10
                    error('AWG time out - device does not enter into RUN mode');
                end
            end
        end
        
        function deviceReady(obj)
            % tests if the the previous overlapping command was executed
            timer = tic;
            while ~contains(query(obj.v, '*OPC?'), '1')
                obj.commDelay();
                if toc(timer) > obj.COMM_DELAY * 10
                    error('AWG time out - overlapping commands has not completed');
                end
            end
        end
        
        function verifyOperationComplete(obj)
            while ~strcmp(obj.v.TransferStatus,'idle')
                obj.commDelay();
            end
        end
        
        function commDelay(obj)
            % Communication Delay
            delay = tic;
            while toc(delay) < obj.COMM_DELAY
            end
        end
    end
    
%%
    methods (Static)
        
        function RegisterPgChannels(names, channels, delays)
            PG = getObjByName(PulseGenerator.NAME);
                if isempty(PG); throwBaseObjException(PulseGenerator.NAME); end
            for i = 1:length(names)
                channel = Channel.Digital(names{i}, channels(i), delays(2*i-1), delays(2*i));
                PG.registerChannel(channel);
            end
        end
        
        function obj = getInstance(struct)
            missingField = FactoryHelper.usualChecks(struct, ...
                FrequencyGeneratorTektronixAWG.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Trying to create a Tektronix AWG, encountered missing field - "%s". Aborting',...
                    missingField);
            end
            struct = FactoryHelper.supplementStruct(struct, FrequencyGeneratorTektronixAWG.OPTIONAL_FIELDS);
            
            name = [FrequencyGeneratorTektronixAWG.TYPE, '-', struct.serialNumber];
            frequencyLimits = [struct.minFrequency, struct.maxFrequency];
            amplitudeLimits = [struct.minAmplitude, struct.maxAmplitude];
            if ~isempty(struct.trigger2ChannelName)
                triggersNames = {struct.trigger1ChannelName, struct.trigger2ChannelName};
                channels = [struct.trigger1Channel, struct.trigger2Channel];
                delays = [struct.onDelay1, struct.offDelay1, struct.onDelay2, struct.offDelay2];
            else
                triggersNames = {struct.trigger1ChannelName};
                channels = struct.trigger1Channel;
                delays = [struct.onDelay1, struct.offDelay1];
            end
            
            obj = FrequencyGeneratorTektronixAWG(name, struct.address, frequencyLimits, amplitudeLimits, triggersNames, channels, delays);
            addBaseObject(obj);
        end
        
        function Vpp = dBmToVpp(P_dBm)
            P_Watt = 1e-3*(10.^(P_dBm/10));
            Vpp = 2*sqrt(P_Watt*50*2);
        end

    end
end