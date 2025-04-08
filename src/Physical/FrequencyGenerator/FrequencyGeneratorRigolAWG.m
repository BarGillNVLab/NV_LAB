classdef FrequencyGeneratorRigolAWG <  FrequencyGenerator
    
    properties (Constant = true)
        MAX_VPP = 20;         %V the maximal dou to AWG
        MIN_VPP = 0;
        MAX_FREQ = 250;       %250 MHz
        MIN_FREQ = 1e-12;     %1 muHz
        MAX_CYCLES = 1e6;
        TIME_CONVERT = 1e6;
        SETUP_AWG_DELAY = 0;       %mus
        
        TYPE = 'RigolAWG';
        NEEDED_FIELDS = {'address', 'serialNumber', 'triggerChannel', 'triggerChannelName',  'onDelay', 'offDelay'};
        OPTIONAL_FIELDS = [];
        
%         VISA_BRAND = 'ni';              % VISA brand
    end
    
    properties (Dependent = true)
    end
    
    properties
    end
    
    properties (Access = private)
        address
        v                       % visa object
    end
    
    %%
    methods (Access = private)
        function obj = FrequencyGeneratorRigolAWG(name, frequencyLimits, amplitudeLimits, address, triggersNames, channels, delays)
            obj@FrequencyGenerator(name, frequencyLimits, amplitudeLimits);
            obj.address = address;
            try
                obj.connect;
                obj.RegisterPgChannels(triggersNames, channels, delays);
                obj.Reset;
                obj.initialize;
            catch err
                obj.disconnect;
                crethrow(err);
            end
        end
    end
    
    methods
        
        function connect(obj)
            if isempty(obj.v)
                obj.v = visa('NI', obj.address);
            end
            if isempty(obj.v)
                error('failed to open: %s.', obj.address);
            end
            if strcmp(obj.v.Status, 'closed')
                fopen(obj.v);
            end
        end

        function disconnect(obj)
            if strcmp(obj.v.Status, 'open')
                obj.setValue('enableOutput', '0', 1);
                fclose(obj.v);
            end
            disp('Rigol AWG connection closed');
        end
        
        function delete(obj)
            obj.disconnect;
            delete(obj.v)
        end
        
        function sendCommand(obj,command)
            try
                scpi_str = command;
                fwrite(obj.v, scpi_str);
            catch err
                err2warning(err);
                fprintf('An error has occured while sending command: %s\nTrying again\n', command);
                
                try
                    obj.CloseConnection;
                    obj.Connect;
                    fwrite(obj.v, scpi_str);
                catch err2
                    err2warning(err2);
                    rethrow(err);
                end
            end
        end
        
        function value = readOutput(obj, what)
            % Get value returned from object
            value = fscanf(obj.v, '%s');
            switch what
                case {'frequency', 'freq', 'f'}
                    value = num2str(str2double(value)/1e6);  % convert Hz to MHz
                case {'enableoutput', 'output', 'enabled', 'enable'}
                    value = num2str(strcmp(value,'ON'));
            end
        end
        
        function command = createCommand(obj, what, value, channel)
            space = repmat(' ',1,~strcmp(value,'?'));   % '?' shold be without space and value with space
            chan =  num2str(channel);
            switch lower(what)
                case {'enableoutput', 'output', 'enabled', 'enable'}
                    switch value
                        case {'1', 'ON'}
                            command = ['OUTP', chan, ' ON'];
                        case {'0', 'OFF'}
                            command = ['OUTP', chan, ' OFF'];
                        case '?'    
                            command = ['OUTP', chan, '?'];
                        otherwise
                            error('no type of OUTPUT syntax "%s"',value)
                    end
                case {'frequency', 'freq'}
                    if ~strcmp(value, '?')
                        value = value*1e6; % convert MHz to Hz
                    end
                    command = [':SOURce', chan, ':FREQ' , space , num2str(value)];
                case {'amplitude', 'ampl', 'amp'}
                    command = [':SOURce', chan, ':VOLTage', space , num2str(value)];
                otherwise
                    error('Unknown command type %s', what)
            end
        end
        
        function setTimeOut (obj, TimeOut)
            if (TimeOut < 30) || (TimeOut > 1000)
                warning('timeout is not changed, it must be more than 30 and less than 1000')
            else
                obj.v.timeout = TimeOut;
            end
        end
        
        function Reset(obj)
            obj.sendCommand('*RST');
            obj.setTimeOut(100);
        end
        
        
        
        
%         function Initialize(obj)
%             try
%                 if isempty(obj.v)
%                     obj.v = instrfind('Type', 'visa-usb', 'RsrcName', 'USB0::0x1AB1::0x0640::DG5T155000188::0::INSTR', 'Tag', '');
%                 end
%                 if isempty(obj.v)
%                     obj.v = visa('NI', 'USB0::0x1AB1::0x0640::DG5T155000188::0::INSTR');
%                 else
%                     fclose(obj.v);
%                     obj.v = obj.v(1);
%                 end
%                 if isempty(obj.v)
%                     error('failed to open: %s.', obj.address);
%                 end
%                 try
%                     fclose(obj.v);% close the AWG connection - if it was not closed before.
%                 catch
%                 end
%                 set(obj.v,'OutputBufferSize',999999999999999999999999999999999999999999999999999999999999999999999999);
%                 
%                 obj.v.timeout = 30;
%                 
%                 fopen(obj.v);
%                 obj.sendCommand('*RST');
%                 fclose(obj.v);
%                 
%             catch ex %not sure if this is needed here
%                 if ~isempty(obj.v) && strcmp(obj.v.Status, 'open')
%                     flushinput(obj.v);
%                     flushoutput(obj.v);
%                     fclose(obj.v);
%                 end
%                 rethrow(ex)
%             end
%         end
        
    end
    
    %%
    methods
        function setVoltage (obj, newVpp)
            if newVpp > obj.MAX_VPP
                error('max Vpp is %d', obj.MAX_VPP)
            elseif (newVpp < obj.MIN_VPP)
                error('min Vpp is %d', obj.MIN_VPP)
            end
            command = sprintf(':VOLTage %d\n', newVpp);
            obj.sendCommand(command);
        end
        
        function setBurstState (obj) %freq in MHz
            obj.sendCommand(':BURSt ON');
            obj.sendCommand(':BURSt:MODE TRIGgered');
            obj.sendCommand(':BURSt:TRIGger:SOURce EXTernal');
            obj.sendCommand(':OUTPut ON ');

        end
        
        function setFreq (obj, freq) %freq in MHz
            if freq > obj.MAX_FREQ
                error('max frequency is %d', obj.MAX_FREQ)
            elseif freq < obj.MIN_FREQ
                error('min frequency is %d', obj.MIN_FREQ)
            end
            command = sprintf(':FREQuency %d\n', round(freq*obj.TIME_CONVERT,6));
            obj.sendCommand(command);
        end
        
         function setPeriod (obj, period) %freq in MHz
%             if period < 1/obj.MAX_FREQ
%                 error('max frequency is %d', obj.MAX_FREQ)
%             elseif period > 1/obj.MIN_FREQ
%                 error('min frequency is %d', obj.MIN_FREQ)
%             end
            command = sprintf('BURSt:INTernal:PERiod   %d\n', round(period/obj.TIME_CONVERT,12));
            obj.sendCommand(command);
        end
         
        function setImpedance (obj) %Set the input of the counter  and output impedance  to 50 ?
            command = sprintf('COUNter:IMPedance 50');
            obj.sendCommand(command);
            command = sprintf(' OUTPut1:IMPedance 50');
            obj.sendCommand(command);
        end


        
        function setDelay (obj, Time) %Time in us
            command = sprintf(':BURSt:TDELay %d\n', Time/obj.TIME_CONVERT);
            obj.sendCommand(command);
        end
        
        function setPhase (obj, Phase) %Phase in deg
            if (Phase < 0) || (Phase > 360)
                error('Phase must be between 0 to 360 degrees')
            end
            command = sprintf(':BURSt:PHASe  %d\n', Phase);
            obj.sendCommand(command);
        end
        
        function Output(obj, state)
            if ~strcmpi(state,'on') && ~strcmpi(state,'off')
                error('OutputAWG can get just ''ON'' & ''OFF'' strings');
            end
            command = sprintf(':OUTPut %s', upper(state));
            obj.sendCommand(command);
        end
        
        function burstNcycle(obj, N)
            if (N > obj.MAX_CYCLES) || (N < 1) || mod(N,1)
                error('The number of cycles should be integere between 1 to %d', obj.MAX_CYCLES);
            end
            command = sprintf('BURSt:NCYCles %d\n', N);
            obj.sendCommand(command);
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
                FrequencyGeneratorRigolAWG.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Trying to create a Rigol AWG, encountered missing field - "%s". Aborting',...
                    missingField);
            end
            struct = FactoryHelper.supplementStruct(struct, FrequencyGeneratorRigolAWG.OPTIONAL_FIELDS);
            
            name = [FrequencyGeneratorRigolAWG.TYPE, '-', struct.serialNumber];
            frequencyLimits = [FrequencyGeneratorRigolAWG.MIN_FREQ, FrequencyGeneratorRigolAWG.MAX_FREQ];
            amplitudeLimits = [FrequencyGeneratorRigolAWG.MIN_VPP, FrequencyGeneratorRigolAWG.MAX_VPP];
            triggerName = {struct.triggerChannelName};
            channel = struct.triggerChannel;
            delays = [struct.onDelay, struct.offDelay];
            
            obj = FrequencyGeneratorRigolAWG(name, frequencyLimits, amplitudeLimits, struct.address, triggerName, channel, delays);
            addBaseObject(obj);
        end
        
    end

    
    
end