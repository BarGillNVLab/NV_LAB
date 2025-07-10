classdef FrequencyGeneratorSGT100A < FrequencyGenerator & AWG
    %FREQUENCYGENERATORWINDFREAK Windfreak frequency generator class
    % includes, for now, synthHD & synthNV
    
    properties (Constant, Hidden)
        TYPE = 'sgt100a';
        
        NEEDED_FIELDS = {'address', 'serialNumber', 'minFrequency', 'maxFrequency', 'minAmplitude', 'maxAmplitude'}
        OPTIONAL_FIELDS = {'keepOn', 'mode'};
        NUM_CHANNELS = 1;
        WF_PATH = '/var/user/';
        USE_VISA = false;            % true - use visa; false - use visadev
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
        baseband
        triggerDuration = 0.05  % double. in us.

                
    end
    
    methods (Access = private)
        function obj = FrequencyGeneratorSGT100A(name, address, port, frequencyLimits, amplitudeLimits, numChannels, keepOn, bandwidth, sampleRate, useAWG, mode, channelName, directAmplitudeControl, waveformPath)
            % All models are the same in regards to controlling them, but
            % the limitations on the amplitude and on the allowed frequencies may vary.
            obj@FrequencyGenerator(name, frequencyLimits, amplitudeLimits, numChannels, keepOn);
            obj@AWG(name, bandwidth, sampleRate, useAWG, mode, channelName, directAmplitudeControl, waveformPath);
            % [~, obj.visa] = rs_connect('visa', 'ni', address);
            if FrequencyGeneratorSGT100A.USE_VISA
                obj.visa = visa('ni', address);
            else
                obj.visa = visadev(address);
            end
            
            obj.initialize;
        end
    end

    methods
        function connect(obj)
            if ~isa(obj.visa, 'visa')
                % [status, obj.visa] = rs_connect( 'visa', 'ni', obj.address ); % connects and closes the connection.
                fopen(obj.visa);
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
            % obj.disconnect;
            delete(obj.visa);
        end

        function sendCommand(obj, command)
            % Actually sends command to hardware
            % [Status] = rs_send_command(obj.visa, command);
            if obj.USE_VISA
                fopen(obj.visa);
                % fwrite(obj.visa, command, 'uchar');
                fprintf(obj.visa, command);
                fclose(obj.visa);
            else % using visadev
                writeline(obj.visa, command)
            end
        end

        function value = readOutput(obj, command)
            % Get value returned from object
            % [Status, value] = rs_send_query(obj.visa, command);
            if obj.USE_VISA
                fopen(obj.visa);
                % fwrite(obj.visa, [command, char(10)], 'uchar');
                % value = fread(obj.visa, obj.visa.BytesAvailable, 'uchar');
                value = query(obj.visa, command);
                fclose(obj.visa);
            else % using visadev
                value = writeread(obj.visa, command);
            end
            % value = fscanf(obj.t, '%s');
            % switch what
            %     case {'frequency', 'freq', 'f'}
            %         value = num2str(str2double(value)/1e6);  % convert Hz to MHz
            % end
        end

%         function value = queryValue(obj, what, channel)
%             if ~exist('channel', 'var') || isempty(channel)
%                 channel = 1:obj.numChannels;
%             end
%             value = [];
%             for i = 1:length(channel)
%                 command = obj.createCommand(what, '?', channel(i));
%                 value = [value, str2double(obj.readOutput(command))]; %#ok<AGROW>
% %                 value = [value, str2double(obj.readOutput(what))]; %#ok<AGROW>
%                 if value(i) > 1e6
%                     value(i) = value(i)*1e-6; % convert frequency to MHz
%                 end
%             end
%             command = createCommand(what, '?', channel);
%             value = readOutput(obj, command);
        % end

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
                FrequencyGeneratorSGT100A.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Trying to create an SRS frequency generator, encountered missing field - "%s". Aborting',...
                    missingField);
            end
            struct = FactoryHelper.supplementStruct(struct, FrequencyGeneratorSGT100A.OPTIONAL_FIELDS);
            
            name = [FrequencyGeneratorSGT100A.TYPE, '-', struct.serialNumber];
            address = ['TCPIP0::', struct.address, '::hislip0,4880::INSTR'];
            frequencyLimits = [struct.minFrequency, struct.maxFrequency];
            amplitudeLimits = [struct.minAmplitude, struct.maxAmplitude];
            keepOn = struct.keepOn;
            bandwidth = 10;
            sampleRate = 300e6;
            channelName = 'channel';
            directAmplitudeControl = false;
            wavformPath = '';
            useAWG = true;
            useMode = '';
            numChannels = FrequencyGeneratorSGT100A.NUM_CHANNELS;
            waveformPath = FrequencyGeneratorSGT100A.WF_PATH;
            obj = FrequencyGeneratorSGT100A(name, address, struct.port, frequencyLimits, amplitudeLimits, numChannels, keepOn, bandwidth, sampleRate, useAWG, useMode, channelName, directAmplitudeControl, waveformPath);
            % obj =                          (name, bandwidth, sampleRate, useAWG, mode, channelName, directAmplitudeControl, wavformPath)

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
            default = {'clock', 300e6, 'duration', 0.1e-6, 'StartPlayback', 0, 'KeepLocalFile', 0, 'path', '/hdd/', 'filename','untitled.wv', 'comment', '', 'copyright', '', 'no_scaling', 0};
            IQinfo.clock = obj.sampleRate;
            IQinfo.duration = length(waveforms{1}.emptyWaveform); %length(waveforms)/sampleRate; % needs to be in us
            IQinfo.StartPlayback = 0;
            IQinfo.KeepLocalFile = 0;
            IQinfo.path = obj.waveformPath;
            IQinfo.comment = '';
            IQinfo.copyright = '';
            IQinfo.no_scaling = 0;


            % waveform down conversion
            for i = 1:length(waveforms)
                [time, I, Q] = obj.generateIQFromWaveform(waveforms{i}.reconstructWaveform, waveforms{i}.baseband, 1/waveforms{i}.dt);
                [tUnder, signalUnder] = obj.underSampling(time, [I, Q], obj.sampleRate);
                IQinfo.I_data = signalUnder(:,1);
                IQinfo.Q_data = signalUnder(:,2);
                IQinfo.filename = [waveforms{i}.name, '.wv'];

                if obj.USE_VISA
                    [Status] = rs_generate_wave( obj.visa, IQinfo, IQinfo.StartPlayback, IQinfo.KeepLocalFile );
                else
                    [Status] = rs_generate_wave_visadev( obj.visa, IQinfo, IQinfo.StartPlayback, IQinfo.KeepLocalFile );
                end
            end
            
            
            %%
            DELAY_TIME = 0.2;
            % 
            % % make sure that pulse modulation is turned on
            % % sendCommand(obj, ':PULM:STAT ON')
            % sendCommand(obj, ':PULM:STAT OFF')
            % pause(DELAY_TIME)
            % % sendCommand(obj, ':BB:ARB:WSEG:NEXT:SOUR NEXT')
            % pause(DELAY_TIME)

            % % make sure the correct channel is configured for triggering
            % trigger_command = [':CONNector:USER', num2str(obj.IQ.trigger_output), ':OMODe TRIG'];
            % trigger_command = [':CONNector:USER', num2str(obj.IQ.trigger_output), ':OMODe NEXT'];
            % trigger_command = [':CONNector:USER', num2str(obj.IQ.trigger_output), ':OMODe PEMSource'];
            % trigger_command = [':CONNector:USER1:OMODe TRIG'];
            % sendCommand(obj, trigger_command)
            % pause(DELAY_TIME)

            % % make sure trigger mode is single
%             sendCommand(obj, ':BB:ARB:TRIG:SEQ AAUT')
            % sendCommand(obj, ':BB:ARB:TRIG:SEQ RETR')
            % sendCommand(obj, ':BB:ARB:TRIG:SEQ SING');
            % pause(DELAY_TIME)
%             if obj.IQ.trigger_next
%                 trigger_command = [':CONNector:USER', num2str(obj.IQ.trigger_next), ':OMODe NEXT'];
%                 % trigger_command = [':CONNector:USER', num2str(obj.IQ.trigger_next), ':OMODe TRIG'];
%                 sendCommand(obj, trigger_command)
%                 pause(DELAY_TIME)
%                 % if we're working with two trigger channels, make sure trigger mode is auto
% %                 sendCommand(obj, 'BB:ARB:TRIG:SEQ AUTO')  % NEEDS TO BE TESTED
%             end

            % arm the instrument
%             sendCommand(obj, ':BB:ARB:TRIG:ARM:EXEC')
            pause(DELAY_TIME)

            % choose list file-name
            % if ~exist(obj.IQ.list_name)
            %     obj.IQ.list_name = 'untitled_list';
            % end
%             sendCommand(obj, [':BB:ARB:WSEG:CONF:OFIL ', char(39), obj.IQ.list_name, char(39)]) % char(39) is the special character single apostrophe (')
            % sendCommand(obj, [':BB:ARB:WSEG:CONF:SEL ', char(39), obj.IQ.list_name, char(39)])
            expName = split(waveforms{1}.name, '_');
            listName = [expName{1}, '_', 'list'];


            % set the working directory
            sendCommand(obj, [':MMEM:CDIR ', char(39), obj.waveformPath, char(39)]);
            
            % create new multi-segment waveform list
            sendCommand(obj, [':BB:ARB:WSEG:CONF:SEL ', char(39), listName, char(39)]);
            pause(DELAY_TIME)

            % append all waveforms to the list
            for i = 1:length(waveforms)
                sendCommand(obj, [':BB:ARB:WSEG:CONF:SEGM:APP ', char(39), waveforms{i}.name, '.wv', char(39)]);
                % pause(DELAY_TIME)
                % status = 0;
                % while status < 1
                %     status = obj.readOutput('*OPC?');
                %     pause(0.01);
                % end
            end

            % select output (multi-segment waveform file) file name
            sendCommand(obj, [':BB:ARB:WSEG:CONF:OFIL ', char(39), expName{1}, char(39)]);
            pause(DELAY_TIME)

            % create and load the output file
            sendCommand(obj, [':BB:ARB:WSEG:CLO ', char(39), obj.waveformPath, listName, '.inf_mswv', char(39)])
            % This can take time, so we'll check when the instrument is finished
            for i = 1:5
                try
                    obj.readOutput('*OPC?');
                    break
                catch
                    obj.visa.Timeout = Timeout + 5;
                end
            end
            obj.visa.Timeout = obj.visa.Timeout - 5*(i-1);

            % status = 0;
            % while status < 1
            %     status = str2double(obj.readOutput('*OPC?'));
            %     pause(0.01);
            % end
            % pause(DELAY_TIME);
            
            % create sequencing play lists - for now each playlist has a
            % single waveform. In the future this might need to be changed
            % to a function to create more elaborate sequencing play lists.
            for i = 1:length(waveforms)
                % create new sequencing play list
                sendCommand(obj, ['BB:ARB:WSEG:SEQ:SEL ', char(39), waveforms{i}.name, char(39)]);
                pause(DELAY_TIME)
                sendCommand(obj, [':BB:ARB:WSEG:SEQuence:APP ', 'ON,', num2str(i-1),',', '1,', 'NEXT']);
                pause(DELAY_TIME)
            end

            % make sure the correct trigger channel is used
            sendCommand(obj, ':CONNector:USER1:OMODe TRIG')
            pause(DELAY_TIME)
            
            % make sure trigger source is external
            sendCommand(obj, ':BB:ARB:TRIG:SOUR EXT')
            pause(DELAY_TIME)

            % make sure trigger mode in multi segment is "Next Segment"
            sendCommand(obj, ':BB:ARBitrary:TRIGger:SMOD NEXT')
            pause(DELAY_TIME)

            % make sure trigger mode is single
            sendCommand(obj, ':BB:ARB:TRIG:SEQ SING');

            % now we select the multi-segment waveform
            sendCommand(obj, [':BB:ARB:WAV:SEL ', char(39), obj.waveformPath, expName{1}, '.wv', char(39)])
            pause(DELAY_TIME)

            % turn off output sync with trigger
            sendCommand(obj, ':BB:ARB:TRIG:EXT:SYNC:OUTP OFF');
            
            % and finally turn on
            sendCommand(obj, ':BB:ARB:STAT ON');
            pause(DELAY_TIME)

            obj.waveforms = waveforms;

            


%             % load the new sequencing play list to append segments
%             state = 'ON';
%             for i=1:length(obj.IQ.segment_names)
% %                 segment_name = ['untitled', num2str(i), '.wv']
%                 waveformNames = [waveformNames, '.wv'];
%                 if obj.IQ.repeats(i) == -1
%                     obj.IQ.repeats(i) = 1;
%                 end
%                 sendCommand(obj, [':BB:ARB:WSEG:CONF:SEGM:APP ', char(39), convertStringsToChars(obj.IQ.segment_names(i)), char(39)]);
%                 pause(DELAY_TIME)
%                 sendCommand(obj, [':BB:ARB:WSEG:SEQuence:APP ', state,',', num2str(i-1),',', num2str(obj.IQ.repeats(i)),',', 'NEXT'])
%                 pause(DELAY_TIME)
%                 % sendCommand(obj, [':BB:ARB:WSEG:CONF:BLANk:APP ',  '',num2str(300e6)])
%             end

%             % create multi segment list with the chosen filename
% %             full_filename
%             sendCommand(obj, [':BB:ARB:WSEG:CRE ', char(39), obj.waveformPath, listName, '.inf_mswv', char(39)])
%             pause(DELAY_TIME)

            

            % make sure trigger mode is armed_auto
%             sendCommand(obj, ':BB:ARB:TRIG:SEQ AAUT')

            % sendCommand(obj, [':BB:ARB:WSEG:CLO ', char(39), obj.IQ.internal_path, obj.IQ.list_name, '.inf_mswv', char(39)])
            % pause(DELAY_TIME)

            
            % and we make sure that the trigger is actually working
%             sendCommand(obj, ':BB:ARB:WSEG:NEXT:SOUR NEXT')
            % pause(DELAY_TIME)
            %%
        end

        function setPlayList(obj, idx)
            sendCommand(obj, [':BB:ARB:WSEG:SEQ:SEL ', char(39), obj.waveformPath, obj.waveforms{idx}.name, char(39)]);
        end

        function playlist = createPlaylist(waveformNames, exp_name, avg_number)
            playlist.name = [exp_name, '_average_', num2str(avg_number), '.wvs'];
            % we need to create the file according to R&S spec.

            
        end

        function disconnectIQ(obj)
            % turn off ARB
            sendCommand(obj, ':BB:ARB:STAT OFF')

            % % turn off RF
            % obj.output = false;

            % delete waveforms and playlists from the instrument
            for i = 1:length(obj.waveforms)
                sendCommand(obj, [':MMEM:DEL ', char(39), obj.waveformPath, obj.waveforms{i}.name, '.wv', char(39)])
                sendCommand(obj, [':MMEM:DEL ', char(39), obj.waveformPath, obj.waveforms{i}.name, '.wvs', char(39)])
            end

            expName = split(obj.waveforms{1}.name, '_');
            listName = [expName{1}, '_list'];

            % delete list and multi-segment waveform
            sendCommand(obj, [':MMEM:DEL ', char(39), obj.waveformPath, expName{1}, '.wv', char(39)])
            sendCommand(obj, [':MMEM:DEL ', char(39), obj.waveformPath, listName, '.inf_mswv', char(39)])

            % clear all the stored waveforms
            obj.waveforms = {};
        end

        function generateWaveForm()
        end
    end
end