classdef (Abstract) SignalGenerator < BaseObject
    %FREQUENCYGENERATOR Abstract class for frequency generators
    % Has 3 public (and Dependent) properties:
    % # output (On/Off),
    % # frequency (in MHz) and
    % # amplitude (in dB)
    %
    % Subclasses need to:
    % 1. implement the functions:
    %       varargout = sendCommand(obj, command, value)
    %       value = readOutput(obj)
    %       (Static) newFG = getInstance(struct)
    %       (Static) command = createCommand(what, value, channel)
    % 2. call obj.initialize by the end of the constructor
    
    
    properties
        frequency   % MHz
        amplitude   % dB
        output      % logical. On/off
        phase       % degrees

        numChannels
        defultChannel
    end
    
    properties
        keepOn      % keep the FG always on
        useAWG

        FGs
        AWGs
        FGchannels
        AWGchannels
    end
    
    properties (Constant)
        NAME = 'signalGenerator'
    end
    
    properties (Constant, Access = private)
        NEEDED_FIELDS = {'address', 'isFreqGen', 'isAWG', 'MWchannel'}
        OPTIONAL_FIELDS = {'AWGchannel'}
    end
    
    methods (Access = protected)
        function obj = SignalGenerator(name)
            obj@BaseObject(name);
        end
        
        function initialize(obj, SGstruct)
            obj.FGs = {};
            obj.AWGs = {};
            obj.FGchannels = {};
            obj.AWGchannels = {};
            isDefault = zeros(size(SGstruct));
            for i = 1:length(SGstruct)
                currSGstruct =  SGstruct{i};
                % if currSG.isFreqGen && ~currSG.isAWG
                %     type = 'fg';
                % elseif ~currSG.isFreqGen && currSG.isAWG
                %     type = 'awg';
                % elseif currSG.isFreqGen && currSG.isAWG
                %     type = 'both';
                % else
                %     error('Signal Generator type is not supported')
                % end
                if currSG.isFreqGen
                    obj.FGs{end+1} = FrequencyGenerator.getFG(currSGstruct);
                    for j = 1:length(currSGstruct.fgChannels)
                        createSwitch(currSGstruct.fgChannels{j});
                        if ~isfield(currSGstruct.fgChannels{j}, deviceChannel)
                            currSGstruct.fgChannels{j}.deviceChannel = [];
                        end
                        obj.FGchannels{end+1} = struct('pgChannelName', currSGstruct.fgChannels{j}.switchChannelName, ...
                                                       'pgChannelNumber', currSGstruct.fgChannels{j}.switchChannel, ...
                                                       'device', obj.FGs{end}, ...
                                                       'deviceChannel', currSGstruct.fgChannels{j}.deviceChannel);
                        if isfield(currSGstruct.fgChannels{j}, 'default'); isDefault(i) = currSGstruct.fgChannels{j}.defult; end
                    end
                end
                if currSG.isAWG
                    obj.AWGs{end+1} = AWG.getFG(currSGstruct);
                    for j = 1:length(currSGstruct.awgChannels)
                        createSwitch(currSGstruct.awgChannels{j});
                    end
                        obj.AWGchannels{end+1} = struct('pgChannelName', currSGstruct.awgChannels{j}.switchChannelName, ...
                                                        'pgChannelNumber', currSGstruct.awgChannels{j}.switchChannel, ...
                                                        'device', obj.AWGs{end}, ...
                                                        'deviceChannel', currSGstruct.awgChannels{j}.deviceChannel);
                end
            end
            defaultChannelIDX = find(isDefault, 1);
            if all(isDefault) > 1
                error('can''t be more than one default frequency Generator');
            end
            obj.defultChannel = find(isDefault, 1); % Identify the default channel
            % defultChannel
            
            for i=1:length(obj.FGchannels)
                 obj.frequency(end+1) = obj.queryValue('frequency', obj.FGchannels(i).pgChannelNumber);
                 obj.amplitude(end+1) = obj.queryValue('amplitude', obj.FGchannels(i).pgChannelNumber);
                 obj.output(end+1)    = obj.queryValue('enableOutput', obj.FGchannels(i).pgChannelNumber);
                 obj.phase(end+1)     = obj.queryValue('phase', obj.FGchannels(i).pgChannelNumber);
            end

            obj.frequency = obj.queryValue('frequency');
            obj.amplitude = obj.queryValue('amplitude');
            obj.output    = obj.queryValue('enableOutput');
            obj.phase     = obj.queryValue('phase');
            
            % persistent fgCellContainer
            % if isempty(fgCellContainer) || ~isvalid(fgCellContainer) || isempty(fgCellContainer.cells)
            %     FGjson = JsonInfoReader.getJson.frequencyGenerators;
            %     fgCellContainer = CellContainer;
            %     isDefault = false(size(FGjson));    % initialize
            % 
            %     for i = 1: length(FGjson)
            %         try
            %         %%% Checks on each individual struct %%%
            %         if iscell(FGjson); curFgStruct = FGjson{i}; ...
            %             else; curFgStruct = FGjson(i); end
            % 
            %         % If there is no type, then it is a dummy
            %         if isfield(curFgStruct, 'type'); type = curFgStruct.type; ...
            %             else; type = FrequencyGeneratorDummy.TYPE; end
            % 
            %         % Usual checks on fields
            %         missingField = FactoryHelper.usualChecks(curFgStruct, ...
            %             SignalGenerator.NEEDED_FIELDS);
            %         if ischar(missingField) && ~any(isnan(missingField)) && ...  Some field is missing
            %                 ~strcmp(type, FrequencyGeneratorDummy.TYPE) && ...
            %                 ~strcmp(type, FrequencyGeneratorTektronixAWGDummy.TYPE) % This FG is not dummy
            %             EventStation.anonymousError(...
            %                 'Trying to create a %s frequency generator, encountered missing field - "%s". Aborting',...
            %                 type, missingField);
            %         end
            % 
            %         % Check whether this is THE default FG
            %         if isfield(curFgStruct, 'default'); isDefault(i) = true; end
            % 
            %         %%% Get instance (create, if one doesn't exist) %%%
            %         t = lower(type);
            %         name = [t, '-', curFgStruct.serialNumber];
            %         newFG = getObjByName(name);
            %         if isempty(newFG)
            %             switch t
            %                 case lower(FrequencyGeneratorSRS.TYPE)
            %                     newFG = FrequencyGeneratorSRS.getInstance(curFgStruct);
            %                 case lower(FrequencyGeneratorWindfreak.TYPE)
            %                     newFG = FrequencyGeneratorWindfreak.getInstance(curFgStruct);
            %                 case lower(FrequencyGeneratorSGT100A.TYPE)
            %                     newFG = FrequencyGeneratorSGT100A.getInstance(curFgStruct);
            %                 case lower(FrequencyGeneratorTektronixAWG.TYPE)
            %                     newFG = FrequencyGeneratorTektronixAWG.getInstance(curFgStruct);
            %                 case lower(FrequencyGeneratorRigolAWG.TYPE)
            %                     newFG = FrequencyGeneratorRigolAWG.getInstance(curFgStruct);
            %                 case lower(FrequencyGeneratorDummy.TYPE)
            %                     newFG = FrequencyGeneratorDummy.getInstance(curFgStruct);
            %                 case lower(FrequencyGeneratorTektronixAWGDummy.TYPE)
            %                     newFG = FrequencyGeneratorTektronixAWGDummy.getInstance(curFgStruct);
            %                 otherwise
            %                     EventStation.anonymousWarning('Could not create Frequency Generator of type %s!', type)
            %             end
            % 
            %             % register FG outputs with the PG, if MW/AWG are "null" in the JSON no channel is registered
            %             createSwitch(curFgStruct.MW)
            %             createSwitch(curFgStruct.AWG)
            %             if isfield(curFgStruct, 'MW2') % we have two channels in the FG, e.g. synthHD
            %                curFgStruct = FactoryHelper.supplementStruct(curFgStruct, SignalGenerator.OPTIONAL_FIELDS);
            %                createSwitch(curFgStruct.MW2)
            %             end
            %         end
            %         fgCellContainer.cells{end + 1} = newFG;
            %         catch err
            %             warning('FG "%s" not loaded because of the following error:\n', t);
            %             err2warning(err);
            %         end
            %     end
            % 
            %     nDefault = sum(isDefault);
            %     switch nDefault
            %         case 0
            %             % Nothing.
            %         case 1
            %             % We move the default one to index 1
            %             ind = 1:find(isDefault);
            %             indNew = [circshift(ind, 1), length(ind)+1:length(fgCellContainer.cells)]; % = [ind, 1, 2, ..., ind-1, ind+1, ...]
            %             fgCellContainer.cells = fgCellContainer.cells(indNew);
            %         otherwise
            %             EventStation.anonymousError('Too many Frequency Generators were set as default! Aborting.')
            %     end
            % 
            % end
            % 
            % freqGens = fgCellContainer.cells;
        end

        function createSwitch(outputChannel)
            if isempty(outputChannel)
                return;
            end

            switch lower(outputChannel.classname)
                case {'pulsegenerator', 'pulsestreamer', 'pulseblaster'}
                    SwitchPgControlled.create(outputChannel.switchChannelName, outputChannel);
                otherwise
                    EventStation.anonymousError(...
                        'Can''t create a %s-class fast switch - unknown classname! Aborting.', ...
                        S.classname);
            end
        end
    end
    
    methods
        function set.output(obj, value, channel)
            if ~isexist('channel', 'var')
                channel = 1:obj.numChannels;
            end
            if length(value) ~= length(channel) && ~isscalar(value)
                error('Frequency Generator: output vector size mismatch!')
            end
            value = value .* ones(size(channel));
            % Enable/Disable the output
            for i = 1:length(channel)
                fg = getObjByName(obj.FGchannels{i}.instumentName);
                switch value(i)
                    case {'1', 1, 'on', true}
                        obj.setValue('enableOutput', '1', obj.FGchannels{i}.deviceChannel)
                    case {'0', 0, 'off', false}
                        obj.setValue('enableOutput', '0', obj.FGchannels{i}.deviceChannel)
                    otherwise
                        error('Unknown command. Ignoring')
                end
            end
        end
        
        function set.amplitude(obj, newAmplitude, channel)  % in dB
            if ~isexist('channel', 'var')
                channel = 1:obj.numChannels;
            end
            if length(newAmplitude) ~= length(channel) && ~isscalar(newAmplitude)
                error('Frequency Generator: amplitude vector size mismatch!')
            end
            newAmplitude = newAmplitude .* ones(size(channel));
            % Change amplitude level of the frequency generator
            for i = 1:length(channel)
                fg = getObjByName(obj.FGchannels{i}.instumentName);
                if ~ValidationHelper.isInBorders(newAmplitude(i), fg.minAmpl, obj.maxAmpl)
                    error('MW amplitude must be between %g and %g.\nRequested: %g', ...
                        obj.minAmpl, obj.maxAmpl, newAmplitude(i))
                end
                fg.setValue('amplitude', newAmplitude(i), obj.FGchannels{i}.deviceChannel);
            end
        end
        
        function set.frequency(obj, newFrequency, channel)      % in Hz
            if ~isexist('channel', 'var')
                channel = 1:obj.numChannels;
            end
            if length(newFrequency) ~= length(channel) && ~isscalar(newFrequency)
                error('Frequency Generator: frequency vector size mismatch!')
            end
            newFrequency = newFrequency .* ones(size(channel));
            % Change frequency level of the frequency generator
            for i = 1:length(newFrequency)
                fg = getObjByName(obj.FGchannels{i}.instumentName);
                if ~ValidationHelper.isInBorders(newFrequency, fg.minFreq, fg.maxFreq)
                    error('MW frequency must be between %d and %d.\nRequested: %d', ...
                        fg.minFreq, fg.maxFreq, newFrequency)
                end
                obj.setValue('frequency', newFrequency(i), obj.FGchannels{i}.deviceChannel);
            end
        end

        function set.phase(obj, newPhase, channel)      % in degrees
            if ~isexist('channel', 'var')
                channel = 1:obj.numChannels;
            end
            if length(newPhase) ~= length(channel) && ~isscalar(newPhase)
                error('Frequency Generator: phase vector size mismatch!')
            end
            newPhase = newPhase .* ones(size(channel));
            for i = 1:length(newPhase)
                fg = getObjByName(obj.FGchannels{i}.instumentName);
                % Change phase of the frequency generator
                newPhase = mod(newPhase-fg.minPhase,360) + fg.minPhase;
                if ~ValidationHelper.isInBorders(newPhase, fg.minPhase, fg.maxPhase)
                    error('phase must be between %d and %d.\nRequested: %d', ...
                        fg.minPhase, fg.maxPhase, newPhase)
                end
                obj.setValue('phase', newPhase(i), obj.FGchannels{i}.deviceChannel);
            end
        end

        function value = queryValue(obj, what, channel)
            % If channel is not specified, returns value for all channels
            if ~exist('channel', 'var') || isempty(channel)
                channel = 1:obj.numChannels;
            end
            value = [];
            for i = 1:length(channel)
                fg = getObjByName(obj.FGchannels{i}.instumentName);
                command = obj.createCommand(what, '?', obj.FGchannels{i}.deviceChannel);
                sendCommand(fg, command);
                value = [value, str2double(fg.readOutput(what))]; %#ok<AGROW>
            end
        end
        
        function setValue(obj, what, value, channel)
            % If channel is not specified, then checks the length of value.
            if ~exist('channel', 'var') || isempty(channel)
                channel = 1:obj.numChannels;
            end
            for i = 1:length(channel)
                fg = getObjByName(obj.FGchannels{i}.instumentName);
                command = obj.createCommand(what, value, obj.FGchannels{i}.deviceChannel); % 14.1.22 rotem - added indexing to value
                sendCommand(fg, command);
            end
        end
    end

    %% Initializtion and Setup
    methods (Static)
        function obj = create(SGstruct)
            obj = SignalGenerator(SignalGenerator.NAME);
            obj.initialize(SGstruct);
            addBaseObject(obj);
        end


        function num = nChannelsAvailable()
            num = 0;
            FGs = SignalGenerator.getFG;
            for i = 1:length(FGs)
                num = num + FGs{i}.numChannels;
            end
        end
        
        function name = getDefaultFgName()
            fgCells = SignalGenerator.getFG;
            if isempty(fgCells)
                EventStation.anonymousError('There is no active frequency generator!')
            end
            fg = fgCells{1};   % We sorted the array so that the default FG is first
            name = fg.name;
        end
    end
end