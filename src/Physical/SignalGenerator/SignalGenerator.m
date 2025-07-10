classdef SignalGenerator < BaseObject
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

        % numChannels
        defaultChannel = 1 % default value, if the json contains a default device this property will be updated accordingly.
    end
    
    properties
        % keepOn      % keep the FG always on
        useAWG

        FGs
        AWGs
        FGchannels
        AWGchannels
        FGchannelMap
        AWGchannelMap
        % FG2AWGmap
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
            FGchannelNames = {};
            FGchannelNumbers = [];
            AWGchannelNames = {};
            AWGchannelNumbers = [];
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
                if currSGstruct.isFreqGen
                    obj.FGs{end+1} = FrequencyGenerator.getFG(currSGstruct);
                    for j = 1:length(currSGstruct.fgChannels)
                        obj.createSwitch(currSGstruct.fgChannels(j));

                        if ~isfield(currSGstruct.fgChannels(j), 'deviceChannel')
                            currSGstruct.fgChannels(j).deviceChannel = [];
                        end

                        if ~isfield(currSGstruct.fgChannels(j), 'linkedAWG')
                            currSGstruct.fgChannels(j).linkedAWG = [];
                        end

                        if ~isfield(currSGstruct.fgChannels(j), 'keepPGchannelOn')
                            currSGstruct.fgChannels(j).keepPGchannelOn = false;
                        end

                        obj.FGchannels{end+1} = struct('pgChannelName', currSGstruct.fgChannels(j).switchChannelName, ...
                                                       'pgChannelNumber', currSGstruct.fgChannels(j).switchChannel, ...
                                                       'device', obj.FGs{end}, ...
                                                       'deviceChannel', currSGstruct.fgChannels(j).deviceChannel, ...
                                                       'linkedAWG', {currSGstruct.fgChannels(j).linkedAWG}, ...
                                                       'keepPGchannelOn', currSGstruct.fgChannels(j).keepPGchannelOn);
                        FGchannelNames{end+1} = currSGstruct.fgChannels(j).switchChannelName;
                        FGchannelNumbers(end+1) = currSGstruct.fgChannels(j).switchChannel;
                        if isfield(currSGstruct.fgChannels(j), 'default'); isDefault(i) = currSGstruct.fgChannels(j).default; end
                    end
                end
                if currSGstruct.isAWG
                    obj.AWGs{end+1} = AWG.getAWG(currSGstruct);
                    for j = 1:length(currSGstruct.awgChannels)
                        obj.createSwitch(currSGstruct.awgChannels(j));
                        if ~isfield(currSGstruct.awgChannels(j), 'deviceChannel')
                            currSGstruct.awgChannels(j).deviceChannel = [];
                        end
                    end
                    obj.AWGchannels{end+1} = struct('pgChannelName', currSGstruct.awgChannels(j).switchChannelName, ...
                                                    'pgChannelNumber', currSGstruct.awgChannels(j).switchChannel, ...
                                                    'device', obj.AWGs{end}, ...
                                                    'deviceChannel', currSGstruct.awgChannels(j).deviceChannel);
                    AWGchannelNames{end+1} = currSGstruct.awgChannels(j).switchChannelName;
                    AWGchannelNumbers(end+1) = currSGstruct.awgChannels(j).switchChannel;
                end
            end
            obj.FGchannelMap = dictionary(FGchannelNames, FGchannelNumbers);
            obj.AWGchannelMap = dictionary(AWGchannelNames, AWGchannelNumbers);
            defaultChannelIDX = find(isDefault, 1);
            if all(isDefault) > 1
                error('can''t be more than one default frequency Generator');
            end
            obj.defaultChannel = find(isDefault, 1); % Identify the default channel
            % defaultChannel
            
            % for i=1:length(obj.FGchannels) % there's an issue with the set function
            %      obj.frequency(end+1) = obj.queryValue('frequency', obj.FGchannels{i}.pgChannelNumber);
            %      obj.amplitude(end+1) = obj.queryValue('amplitude', obj.FGchannels{i}.pgChannelNumber);
            %      obj.output(end+1)    = obj.queryValue('enableOutput', obj.FGchannels{i}.pgChannelNumber);
            %      obj.phase(end+1)     = obj.queryValue('phase', obj.FGchannels{i}.pgChannelNumber);
            % end

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

        function createSwitch(obj, outputChannel)
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
        function set.output(obj, value)
            if ~strcmp(class(obj), 'SignalGenerator'); obj = getObjByName(SignalGenerator.NAME); end % making sure we're using the superclass and not a child
             if size(value,2) < 2 && (size(value,1) == length(obj.FGchannels) || size(value,1) == 1)
                pgChannels = cellfun(@(c) c.pgChannelNumber, obj.FGchannels);
                value = value .* ones(size(pgChannels))'; % we need a column vector, as each row is for a different fg
            elseif size(value,1) == 1
                pgChannels = value(:,2);
            else
                error('data input incorrect')
             end
             value(isnan(value(:, 1)), 1) = 0; % if there's no connection and the value is NaN, convert to 0 (output off)
            idx = find(cellfun(@(s) ismember(s.pgChannelNumber, pgChannels), obj.FGchannels));
            % Enable/Disable the output
            for i = 1:length(pgChannels)
                fg = obj.FGchannels{idx(i)}.device;
                switch value(i)
                    case {'1', 1, 'on', true}
                        fg.setValue('enableOutput', '1', obj.FGchannels{idx(i)}.deviceChannel)
                    case {'0', 0, 'off', false}
                        fg.setValue('enableOutput', '0', obj.FGchannels{idx(i)}.deviceChannel)
                    otherwise
                        error('Unknown command. Ignoring')
                end
                obj.output(idx(i)) = value(i);
            end
        end
        
        function set.amplitude(obj, newAmplitude)  % in dB
            if ~strcmp(class(obj), 'SignalGenerator'); obj = getObjByName(SignalGenerator.NAME); end % making sure we're using the superclass and not a child
            if size(newAmplitude,2) < 2 && (size(newAmplitude,1) == length(obj.FGchannels) || size(newAmplitude,1) == 1)
                pgChannels = cellfun(@(c) c.pgChannelNumber, obj.FGchannels);
                newAmplitude = newAmplitude .* ones(size(pgChannels))'; % we need a column vector, as each row is for a different fg
            elseif size(newAmplitude,1) == 1
                pgChannels = newAmplitude(:,2);
            else
                error('data input incorrect')
            end
            idx = find(cellfun(@(s) ismember(s.pgChannelNumber, pgChannels), obj.FGchannels));
            % Change amplitude level of the frequency generator
            for i = 1:length(pgChannels)
                % fg = getObjByName(obj.FGchannels{idx(i)}.device.name);
                fg = obj.FGchannels{idx(i)}.device;
                if ~ValidationHelper.isInBorders(newAmplitude(i), fg.minAmpl, fg.maxAmpl)
                    % error('MW amplitude must be between %g and %g.\nRequested: %g', ...
                    %     obj.minAmpl, obj.maxAmpl, newAmplitude(i))
                end
                fg.setValue('amplitude', newAmplitude(i,1), obj.FGchannels{idx(i)}.deviceChannel);
                obj.amplitude(idx(i)) = newAmplitude(i,1);
            end
        end

        function set.frequency(obj, newFrequency)      % in Hz
            if ~strcmp(class(obj), 'SignalGenerator'); obj = getObjByName(SignalGenerator.NAME); end % making sure we're using the superclass and not a child
            if size(newFrequency,2) < 2 && (size(newFrequency,1) == length(obj.FGchannels) || size(newFrequency,1) == 1)
                pgChannels = cellfun(@(c) c.pgChannelNumber, obj.FGchannels);
                newFrequency = newFrequency .* ones(size(pgChannels))'; % we need a column vector, as each row is for a different fg
            elseif size(newFrequency,1) == 1
                pgChannels = newFrequency(:,2);
            else
                error('data input incorrect')
            end
            idx = find(cellfun(@(s) ismember(s.pgChannelNumber, pgChannels), obj.FGchannels));
            % Change frequency level of the frequency generator
            for i = 1:length(pgChannels)
                % fg = getObjByName(obj.FGchannels{idx(i)}.device.name);
                fg = obj.FGchannels{idx(i)}.device;
                if ~ValidationHelper.isInBorders(newFrequency(i), fg.minFreq, fg.maxFreq)
                    % error('MW frequency must be between %d and %d.\nRequested: %d', ...
                    %     fg.minFreq, fg.maxFreq, newFrequency)
                end
                fg.setValue('frequency', newFrequency(i,1), obj.FGchannels{idx(i)}.deviceChannel);
                obj.frequency(idx(i)) = newFrequency(i,1);
            end
        end

        function set.phase(obj, newPhase)      % in degrees
            if ~strcmp(class(obj), 'SignalGenerator'); obj = getObjByName(SignalGenerator.NAME); end % making sure we're using the superclass and not a child
             if size(newPhase,2) < 2 && (size(newPhase,1) == length(obj.FGchannels) || size(newPhase,2) == 1)
                pgChannels = cellfun(@(c) c.pgChannelNumber, obj.FGchannels); 
                newPhase = newPhase .* ones(size(pgChannels))'; % we need a column vector, as each row is for a different fg
            elseif size(newPhase,1) == 1
                pgChannels = newPhase(:,2);
            else
                error('data input incorrect')
             end
            idx = find(cellfun(@(s) ismember(s.pgChannelNumber, pgChannels), obj.FGchannels));
            for i = 1:length(pgChannels)
                fg = obj.FGchannels{idx(i)}.device;
                % Change phase of the frequency generator
                newPhase = mod(newPhase-fg.minPhase,360) + fg.minPhase;
                if ~ValidationHelper.isInBorders(newPhase(i), fg.minPhase, fg.maxPhase)
                    % error('phase must be between %d and %d.\nRequested: %d', ...
                    %     fg.minPhase, fg.maxPhase, newPhase)
                end
                fg.setValue('phase', newPhase(i,1), obj.FGchannels{idx(i)}.deviceChannel);
                obj.phase(idx(i)) = newPhase(i,1);
            end
        end

        function value = queryValue(obj, what, channel)
            % If channel is not specified, returns value for all channels
            if ~exist('channel', 'var') || isempty(channel)
                channel = cellfun(@(s) s.pgChannelNumber, obj.FGchannels);
            end
            idx = find(cellfun(@(s) ismember(s.pgChannelNumber, channel), obj.FGchannels));
            value = [];
            for i = idx
                fg = obj.FGchannels{i};
                value = [value; fg.device.queryValue(what, fg.deviceChannel)]; %#ok<AGROW>
                % command = fg.createCommand(what, '?', obj.FGchannels{i}.deviceChannel);
                % sendCommand(fg, command);
                % value = [value; str2double(fg.readOutput(what))]; %#ok<AGROW>
            end
        end
        
        function setValue(obj, what, value, channel)
            % If channel is not specified, then checks the length of value.
            if ~exist('channel', 'var') || isempty(channel)
                channel = cellfun(@(s) s.pgChannelNumber, obj.FGchannels);
            end
            value = value .* ones(size(channel));
            idx = find(cellfun(@(s) ismember(s.pgChannelNumber, channel), obj.FGchannels));
            for i = length(channel)
                fg = getObjByName(obj.FGchannels{idx(i)}.device.name);
                command = fg.createCommand(what, value(i), obj.FGchannels{i}.deviceChannel);
                sendCommand(fg, command);
            end
        end

        function idx = findOrderedFGindex(obj, fgChannel)
            channelNumbers = cellfun(@(x) x.pgChannelNumber, obj.FGchannels);
            idx = arrayfun(@(x) find(channelNumbers == x), fgChannel);
        end

        function setSequence(obj, paramIdx, fgChannels)
            if ~iscell(fgChannels)
                fgChannels = cell(fgChannels);
            end
            fgIdx = obj.findOrderedFGindex(obj.FGchannelMap(fgChannels));
            for i = fgIdx
                fg = obj.FGchannels{i};
                for j = 1:length(fg.linkedAWG)
                    awg = obj.AWGchannels{obj.AWGchannelMap({fg.linkedAWG{j}})}.device;
                    awg.setPlayList(awg, paramIdx);
                end
            end
        end

        % function value = validateInput(obj, value)
        %     % Validate input dimensions and prepare pgChannels
        %     if size(value, 2) < 2 && (size(value, 1) == length(obj.FGchannels) || size(value, 1) == 1)
        %         pgChannels = cellfun(@(c) c.pgChannelNumber, obj.FGchannels);
        %         value = repmat(value, size(pgChannels, 1), 1); % Create a column vector
        %     elseif size(value, 1) == 1
        %         pgChannels = value(:, 2);
        %     else
        %         error('Data input incorrect');
        %     end
        % end
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