classdef FrequencyGeneratorSGT100A < FrequencyGenerator
    %FREQUENCYGENERATORWINDFREAK Windfreak frequency generator class
    % includes, for now, synthHD & synthNV
    
    properties (Constant, Hidden)
        TYPE = 'SGT100A';
        
        NEEDED_FIELDS = {'address', 'serialNumber', 'minFrequency', 'maxFrequency', 'minAmplitude', 'maxAmplitude', 'MW', 'AWG'}
        OPTIONAL_FIELDS = {'keepOn', 'mode'};
    end

%     properties (Constant, Hidden)
%         TYPE = 'srs';
% %         NAME = 'srsFrequencyGenerator';
% 
%         NEEDED_FIELDS = {'address', 'port', 'serialNumber', 'minFrequency', 'maxFrequency', 'minAmplitude', 'maxAmplitude'}
%         OPTIONAL_FIELDS = {'keepOn'};
%     end
       
    properties %(Access = private)
        visa;       % visa object
        IQ = struct('output', false, 'segment_names', [], 'list_name', '', 'internal_path', '/var/user/', 'switchWF', true, 'duration', 0.1, 'repeats', -1, 'trigger_next', 1, 'trigger_output', 2);
        awg
        switchMW
                
    end
    
    methods (Access = private)
        function obj = FrequencyGeneratorSGT100A(name, address, port, frequencyLimits, amplitudeLimits, keepOn, MW, AWG)
            % All models are the same in regards to controlling them, but
            % the limitations on the amplitude and on the allowed frequencies may vary.
            obj@FrequencyGenerator(name, frequencyLimits, amplitudeLimits, keepOn);
            [~, obj.visa] = rs_connect('visa', 'ni', address);
            
            obj.initialize;
            obj.switchMW.channel = MW.switchChannel;
            obj.switchMW.channelName = MW.switchChannelName;
            obj.awg = AWG;
        end
    end

    methods
        function connect(obj)
            if ~isa(obj.visa, 'visa')
                [status, obj.visa] = rs_connect( 'visa', 'ni', obj.address ); % connects and closes the connection.
            else % the object exists but the instrument is disconnected, so we just need to connect to it %% might not be needed, the rs_command and rs_query open and close the connection
%                 fopen(obj.visa);
            end
        end

        function disconnect(obj)
            if strcmp(obj.visa.Status, 'open')
                fclose(obj.visa);
            end
        end

        function reset(obj)
            obj.sendCommand('*RST');
        end

        function delete(obj)
            obj.disconnect;
            delete(obj.visa);
        end

        function sendCommand(obj, command)
            % Actually sends command to hardware
            [Status] = rs_send_command(obj.visa, command);
        end

        function value = readOutput(obj, command)
            % Get value returned from object
            [Status, value] = rs_send_query(obj.visa, command);
            % value = fscanf(obj.t, '%s');
            % switch what
            %     case {'frequency', 'freq', 'f'}
            %         value = num2str(str2double(value)/1e6);  % convert Hz to MHz
            % end
        end

        function value = queryValue(obj, what, channel)
            if ~exist('channel', 'var') || isempty(channel)
                channel = 1:obj.numChannels;
            end
            value = [];
            for i = 1:length(channel)
                command = obj.createCommand(what, '?', channel(i));
                value = [value, str2double(readOutput(obj, command))];
%                 value = [value, str2double(obj.readOutput(what))]; %#ok<AGROW>
            end
%             command = createCommand(what, '?', channel);
%             value = readOutput(obj, command);
        end

%         function set.IQ.output(obj, newState)
%             checkBoolean(obj, newState);
%             sendCommand(obj, [':SOUR:BB:ARB:STAT ', num2str(newState)]); % in actually we're turning on/off the ARB
%             obj.IQ.output = newState;
%         end

        function checkBoolean(obj, newVal)
            if ~isscalar(newVal)
                obj.sendError('Parameter must be scalar!')
            end
            if ~ValidationHelper.isTrueOrFalse(newVal)
                errMsg = sprintf(...
                    'Parameter must be true or false!');
                obj.sendError(errMsg);
            end
        end
    end
    
%%
    methods (Static)
        function obj = getInstance(struct)
            missingField = FactoryHelper.usualChecks(struct, ...
                FrequencyGeneratorSRS.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Trying to create an SRS frequency generator, encountered missing field - "%s". Aborting',...
                    missingField);
            end
            struct = FactoryHelper.supplementStruct(struct, FrequencyGeneratorSRS.OPTIONAL_FIELDS);
            
            name = [FrequencyGeneratorSGT100A.TYPE, '-', struct.serialNumber];
            address = ['TCPIP0::', struct.address, '::hislip0,4880::INSTR'];
            frequencyLimits = [struct.minFrequency, struct.maxFrequency];
            amplitudeLimits = [struct.minAmplitude, struct.maxAmplitude];
            keepOn = struct.keepOn;
            MW = struct.MW;
            AWG = struct.AWG;
            obj = FrequencyGeneratorSGT100A(name, address, struct.port, frequencyLimits, amplitudeLimits, keepOn, MW, AWG);

            addBaseObject(obj);
        end
        
        function command = createCommand(what, value, channel) %#ok<INUSD>
           switch lower(what)
               case {'enableoutput', 'output', 'enabled', 'enable'}
                   name = 'OUTP:STAT ';
               case {'frequency', 'freq'}
                   name = 'FREQ ';
                   if ~strcmp(value, '?')
                       value = value*1e6; % convert MHz to Hz
                   end
               case {'amplitude', 'ampl', 'amp'}
                   name = 'POW ';
               case {'phase'}
                   name = 'PHAS ';   % phase is in deg
               otherwise
                   error('Unknown command type %s', what)
           end
           
           if isnumeric(value)
               value = num2str(value);
           end
           if value == '?'
               name = name(1:end-1);
           end
           command = [name, value];
        end

        function loadAWGInternal(obj, waveforms, waveformNames)
            % what we need to do:
            % 1. create I, Q from waveform
            % 2. load all waveforms to instrument
            % 3. create multi segment list
            % 4. append all sequences
            % 5. apply settings
            
           

            % set defaults for non mandatory fields (and clockrate)
            defult = {'clock', 300e6, 'duration', 0.1e-6, 'StartPlayback', 0, 'KeepLocalFile', 0, 'path', '/hdd/', 'filename','untitled.wv', 'comment', '', 'copyright', '', 'no_scaling', 0};
            IQinfo.clock = obj.clock;
            IQinfo.duration = obj.sampleRate; %length(waveforms)/sampleRate; % needs to be in us
            % startPlayback = obj.startPlayback;
            % KeepLocalFile = obj.KeepLocalFile;
            IQinfo.path = obj.wavformPath;
            % IQinfo.filename = [waveformNames, '.wv'];
            IQinfo.comment = obj.comment;
            IQinfo.copyright = obj.copyright;
            IQinfo.no_scaling = obj.no_scaling;
            % populate parameters with user input (if there's no user input use defaults)
            % IQinfo = varargin2param(defult, varargin);

            % waveform down conversion
            for i = 1:length(waveforms)
                [time, I, Q] = generateIQFromWaveform(waveforms(i));
                [I, Q] = obj.underSampling(time, [I, Q], obj.clock);
                IQinfo.I_data = I;
                IQinfo.Q_data = Q;
                IQinfo.filename = [waveformNames(i), '.wv'];

                [Status] = rs_generate_wave( obj.visa, IQinfo, IQinfo.StartPlayback, IQinfo.KeepLocalFile );
            end


            
            %  % find the SGT100 from the list of available FGs
            % fgCell = FrequencyGenerator.getFG();
            % fg_names = cellfun(@(c) c.name, fgCell, 'UniformOutput', false);
            % % sgt_idx = find(contains(fg_names, 'SGT'));
            % % sgt100 = fgCell{sgt_idx};
            % sgt100 = fgCell{contains(fg_names, 'SGT')};
            % 
            % fg = getObjByName(obj.freqGenName);
            % 
            % if isempty(IQinfo.filename)  % temp patch
            %     IQinfo.filename = 'untitled.wv';
            % end
            % 
            % IQinfo.duration = IQinfo.duration*1e-6; %convert to us
            % 
            % if length(I_vec) == 1
            %     I_vec = I_vec*ones(1,(1+IQinfo.clock.*IQinfo.duration));
            % end
            % if length(Q_vec) == 1
            %     Q_vec = Q_vec*ones(1, (1+IQinfo.clock.*IQinfo.duration));
            % end
            % 
            % IQinfo.I_data = I_vec;
            % IQinfo.Q_data = Q_vec;
            % 
            % [Status] = rs_generate_wave( sgt100.visa, IQinfo, IQinfo.StartPlayback, IQinfo.KeepLocalFile )
            
            
            
            DELAY_TIME = 0.2;

            % make sure that pulse modulation is turned on
            % sendCommand(obj, ':PULM:STAT ON')
            sendCommand(obj, ':PULM:STAT OFF')
            pause(DELAY_TIME)
            % sendCommand(obj, ':BB:ARB:WSEG:NEXT:SOUR NEXT')
            pause(DELAY_TIME)

            % make sure the correct channel is configured for triggering
            trigger_command = [':CONNector:USER', num2str(obj.IQ.trigger_output), ':OMODe TRIG'];
            % trigger_command = [':CONNector:USER', num2str(obj.IQ.trigger_output), ':OMODe NEXT'];
            % trigger_command = [':CONNector:USER', num2str(obj.IQ.trigger_output), ':OMODe PEMSource'];
            sendCommand(obj, trigger_command)
            pause(DELAY_TIME)
            % make sure trigger mode is armed_auto
%             sendCommand(obj, ':BB:ARB:TRIG:SEQ AAUT')
            sendCommand(obj, ':BB:ARB:TRIG:SEQ RETR')
            pause(DELAY_TIME)
            if obj.IQ.trigger_next
                trigger_command = [':CONNector:USER', num2str(obj.IQ.trigger_next), ':OMODe NEXT'];
                % trigger_command = [':CONNector:USER', num2str(obj.IQ.trigger_next), ':OMODe TRIG'];
                sendCommand(obj, trigger_command)
                pause(DELAY_TIME)
                % if we're working with two trigger channels, make sure trigger mode is auto
%                 sendCommand(obj, 'BB:ARB:TRIG:SEQ AUTO')  % NEEDS TO BE TESTED
            end

            % arm the instrument
%             sendCommand(obj, ':BB:ARB:TRIG:ARM:EXEC')
            pause(DELAY_TIME)

            % choose list file-name
            if ~exist(obj.IQ.list_name)
                obj.IQ.list_name = 'untitled_list';
            end
%             sendCommand(obj, [':BB:ARB:WSEG:CONF:OFIL ', char(39), obj.IQ.list_name, char(39)]) % char(39) is the special character single apostrophe (')
            sendCommand(obj, [':BB:ARB:WSEG:CONF:SEL ', char(39), obj.IQ.list_name, char(39)])
            pause(DELAY_TIME)
            sendCommand(obj, [':BB:ARB:WSEG:CONF:OFIL ', char(39), obj.IQ.list_name, char(39)])
            pause(DELAY_TIME)

            % create new play list
            sendCommand(obj, ['BB:ARB:WSEG:SEQ:SEL ', char(39), obj.IQ.internal_path, obj.IQ.list_name, char(39)])
            pause(DELAY_TIME)
            
            % load the new list to append segments
            state = 'ON';
            for i=1:length(obj.IQ.segment_names)
%                 segment_name = ['untitled', num2str(i), '.wv']
                waveformNames = [waveformNames, '.wv'];
                if obj.IQ.repeats(i) == -1
                    obj.IQ.repeats(i) = 1;
                end
                sendCommand(obj, [':BB:ARB:WSEG:CONF:SEGM:APP ', char(39), convertStringsToChars(obj.IQ.segment_names(i)), char(39)]);
                pause(DELAY_TIME)
                sendCommand(obj, [':BB:ARB:WSEG:SEQuence:APP ', state,',', num2str(i-1),',', num2str(obj.IQ.repeats(i)),',', 'NEXT'])
                pause(DELAY_TIME)
                sendCommand(obj, [':BB:ARB:WSEG:CONF:BLANk:APP ',  '',num2str(300e6)])
            end

            % creat list with the chosen filename
%             full_filename
            sendCommand(obj, [':BB:ARB:WSEG:CRE ', char(39), obj.IQ.internal_path, obj.IQ.list_name, '.inf_mswv', char(39)])
            pause(DELAY_TIME)

            % make sure trigger source is external
            sendCommand(obj, ':BB:ARB:TRIG:SOUR EXT')
            pause(DELAY_TIME)

            % make sure trigger mode in multi segment is "Next Segment Seamless"
            sendCommand(obj, ':BB:ARBitrary:TRIGger:SMOD NSE')
            % sendCommand(obj, ':BB:ARBitrary:TRIGger:SMOD NEXT')
            pause(DELAY_TIME)

            % make sure trigger mode is armed_auto
%             sendCommand(obj, ':BB:ARB:TRIG:SEQ AAUT')

            sendCommand(obj, [':BB:ARB:WSEG:CLO ', char(39), obj.IQ.internal_path, obj.IQ.list_name, '.inf_mswv', char(39)])
            pause(DELAY_TIME)

            % now we select the multi-segment waveform
            sendCommand(obj, [':BB:ARB:WAV:SEL ', char(39), obj.IQ.internal_path, obj.IQ.list_name, '.wv', char(39)])
            pause(DELAY_TIME)
            % and finally turn on
            sendCommand(obj, ':BB:ARB:STAT ON')
            pause(DELAY_TIME)

            % turn off output sync with trigger
            sendCommand(obj, ':BB:ARB:TRIG:EXT:SYNC:OUTP ON');

            % and we make sure that the trigger is actually working
%             sendCommand(obj, ':BB:ARB:WSEG:NEXT:SOUR NEXT')
            pause(DELAY_TIME)
        end

        function playlist = createPlaylist(waveformNames, exp_name, avg_number)
            playlist.name = [exp_name, '_average_', num2str(avg_number), '.wvs'];
            % we need to create the file according to R&S spec.

            
        end

        function disconnectIQ(obj)
            % turn off ARB
            sendCommand(obj, ':BB:ARB:STAT OFF')

            % turn off RF
            obj.output = false;

            % delete segment wf from the machine
            for i = 1:length(obj.IQ.segment_names)
                filename = [obj.IQ.internal_path, convertStringsToChars(obj.IQ.segment_names(i))];
                sendCommand(obj, [':MMEM:DEL ', char(39), filename, char(39)])
            end

            % delete list and config file and play list
            sendCommand(obj, [':MMEM:DEL ', char(39), obj.IQ.internal_path, obj.IQ.list_name, '.wv', char(39)])
            sendCommand(obj, [':MMEM:DEL ', char(39), obj.IQ.internal_path, obj.IQ.list_name, '.inf_mswv', char(39)])
            sendCommand(obj, [':MMEM:DEL ', char(39), obj.IQ.internal_path, obj.IQ.list_name, '.wvs', char(39)])

            %
        end

        function generateWaveForm()
        end
    end
end