classdef (Abstract) FrequencyGenerator < BaseObject
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
    
    
    properties (Dependent)
        frequency   % MHz
        amplitude   % dB
        output      % logical. On/off
        phase       % degrees
        numChannels % int
    end
    
    properties
        keepOn      % keep the FG always on
    end
    
    properties (Abstract, Constant)
        TYPE    % for now, one of: {'srs', 'synthhd', 'synthnv', 'TektrinixAWG'}
    end
    
    properties (Constant, Access = private)
        NEEDED_FIELDS = {'address', 'MW', 'AWG'}
        OPTIONAL_FIELDS = {'MW2'}
        % NEEDED_FIELDS = {'address', 'switchChannelName'}
        % OPTIONAL_FIELD_IS_ENABLED = {'isEnabled'} % copied from LaserSwitchPhysicalFactory
        % OPTIONAL_FIELDS_DELAY = {'onDelay', 'offDelay'}
    end
    
    properties (Access = private)
        % Store values internally, to reduce time spent over serial connection
        frequencyPrivate    % double
        amplitudePrivate    % double
        outputPrivate       % logical. Output on or off;
        phasePrivate        % double
    end
    
    properties (SetAccess = protected)
        minFreq
        maxFreq
        minAmpl
        maxAmpl
        minPhase
        maxPhase
    end
    
    methods (Access = protected)
        function obj = FrequencyGenerator(name, freqLimits, amplLimits, keepOn)
            obj@BaseObject(name);
            
            obj.minFreq = freqLimits(1);
            obj.maxFreq = freqLimits(2);
            obj.minAmpl = amplLimits(1);
            obj.maxAmpl = amplLimits(2);
            obj.minPhase = -180;
            obj.maxPhase = 180;
            
            if ~exist('keepOn', 'var')
                keepOn = false;
            end
            if isempty(keepOn); keepOn = false; end
            obj.keepOn = keepOn;
                
        end
        
        function initialize(obj)
            obj.frequencyPrivate = obj.queryValue('frequency');
            obj.amplitudePrivate = obj.queryValue('amplitude');
            obj.outputPrivate    = obj.queryValue('enableOutput');
            if contains(obj.name, 'TektronixAWG')
                obj.phasePrivate = obj.queryValue('phase');   
                obj.ResetStoredData;
            else
                obj.phasePrivate = 0;   % until phase will implement in all generator types
            end
        end
    end
    
    methods
        function frequency = get.frequency(obj)
            frequency = obj.frequencyPrivate;
        end
        function amplitude = get.amplitude(obj)
            amplitude = obj.amplitudePrivate;
        end
        function phase = get.phase(obj)
            phase = obj.phasePrivate;
        end
        function output = get.output(obj)
            output = obj.outputPrivate;
        end
        function numChannels = get.numChannels(obj)
            if contains(obj.name, FrequencyGeneratorWindfreak.TYPE_HD) || contains(obj.name, 'TektronixAWG') || contains(obj.name, 'AWGdummy')% HD has two channels
                numChannels = 2;
            else
                numChannels = 1;
            end
        end
        
        function set.output(obj, value)
            % Enable/Disable the output
            if length(value) > obj.numChannels
                EventStation.anonymousError('Frequency Generator: output vector size mismatch!');
            end
            for i = 1:length(value)
                switch value(i)
                    case {'1', 1, 'on', true}
                        obj.setValue('enableOutput', '1', i)
                        obj.outputPrivate(i) = true;
                    case {'0', 0, 'off', false}
                        obj.setValue('enableOutput', '0', i)
                        obj.outputPrivate(i) = false;
                    otherwise
                        error('Unknown command. Ignoring')
                end
            end
        end
        
        function set.amplitude(obj, newAmplitude)  % in dB
            % Change amplitude level of the frequency generator
            if ~ValidationHelper.isInBorders(newAmplitude, obj.minAmpl, obj.maxAmpl)
                error('MW amplitude must be between %g and %g.\nRequested: %g', ...
                    obj.minAmpl, obj.maxAmpl, newAmplitude)
            end
            if length(newAmplitude) > obj.numChannels
                EventStation.anonymousError('Frequency Generator: amplitude vector size mismatch!');
            end
            for i = 1:length(newAmplitude)
                obj.setValue('amplitude', newAmplitude(i), i);
                obj.amplitudePrivate(i) = newAmplitude(i);
            end
        end
        
        function set.frequency(obj, newFrequency)      % in Hz
            % Change frequency level of the frequency generator
            if ~ValidationHelper.isInBorders(newFrequency, obj.minFreq, obj.maxFreq)
                error('MW frequency must be between %d and %d.\nRequested: %d', ...
                    obj.minFreq, obj.maxFreq, newFrequency)
            end
            
            if length(newFrequency) > obj.numChannels
                EventStation.anonymousError('Frequency Generator: frequency vector size mismatch!');
            end
            for i = 1:length(newFrequency)
                obj.setValue('frequency', newFrequency(i), i);
                obj.frequencyPrivate(i) = newFrequency(i); %added indexing 09.12.2021 Galya & Rotem
            end
        end

        function set.phase(obj, newPhase)      % in degrees
            % Change phase of the frequency generator
            newPhase = mod(newPhase-obj.minPhase,360) + obj.minPhase;
            if ~ValidationHelper.isInBorders(newPhase, obj.minPhase, obj.maxPhase)
                error('phase must be between %d and %d.\nRequested: %d', ...
                    obj.minPhase, obj.maxPhase, newPhase)
            end
            
            if length(newPhase) > obj.numChannels
                EventStation.anonymousError('Frequency Generator: phase vector size mismatch!');
            end
            for i = 1:length(newPhase)
                obj.setValue('phase', newPhase(i), i);
                obj.phasePrivate(i) = newPhase(i);
            end

            % for i = 1:length(newFrequency)
            %     obj.setValue('frequency', newFrequency(i), i);
            %     obj.frequencyPrivate(i) = newFrequency(i); %added indexing 09.12.2021 Galya & Rotem
            % end
        end

        function value = queryValue(obj, what, channel)
            % If channel is not specified, returns value for all channels
            if ~exist('channel', 'var') || isempty(channel)
                channel = 1:obj.numChannels;
            end
            value = [];
            for i = 1:length(channel)
                command = obj.createCommand(what, '?', channel(i));
                sendCommand(obj, command);
                value = [value, str2double(obj.readOutput(what))]; %#ok<AGROW>
            end
        end
        
        function setValue(obj, what, value, channel)
            % If channel is not specified, then checks the length of value.
            if ~exist('channel', 'var') || isempty(channel)
                if ~(isnumeric(value) || iscell(value)) % value is string, which implies single channel
                    channel = 1;
                elseif length(value) > obj.numChannels
                    EventStation.anonymousError('Frequency Generator: vector size mismatch!');
                else
                    channel = 1:length(value);
                end
            end
            for i = 1:length(channel)
                command = obj.createCommand(what, value, channel(i)); % 14.1.22 rotem - added indexing to value
                sendCommand(obj, command);
            end
        end
    end
    
    methods (Abstract)
        sendCommand(obj, command)
        % Actually sends command to hardware
        
        value = readOutput(obj)
        % Get value returned from object

        connect(obj)
        % Starts connection with FG (might be empty)

        disconnect(obj)
        % Closes connection with FG (might be empty)
    end
    
    methods (Abstract, Static)
        obj = getInstance(struct)
        % So that the constructor remains private
        
        command = createCommand(what, value, channel)
        % Converts request type and value to a command that can be sent to Hardware.
    end
    
    %% Initializtion and Setup
    methods (Static)
        function freqGens = getFG()
            % Returns an instance of cell{all FG's}
            %
            % The cell is ordered, so that the first one is the default FG
            
            persistent fgCellContainer
            if isempty(fgCellContainer) || ~isvalid(fgCellContainer) || isempty(fgCellContainer.cells)
                FGjson = JsonInfoReader.getJson.frequencyGenerators;
                fgCellContainer = CellContainer;
                isDefault = false(size(FGjson));    % initialize
                
                for i = 1: length(FGjson)
                    try
                    %%% Checks on each individual struct %%%
                    if iscell(FGjson); curFgStruct = FGjson{i}; ...
                        else; curFgStruct = FGjson(i); end
                    
                    % If there is no type, then it is a dummy
                    if isfield(curFgStruct, 'type'); type = curFgStruct.type; ...
                        else; type = FrequencyGeneratorDummy.TYPE; end
                    
                    % Usual checks on fields
                    missingField = FactoryHelper.usualChecks(curFgStruct, ...
                        FrequencyGenerator.NEEDED_FIELDS);
                    if ischar(missingField) && ~any(isnan(missingField)) && ...  Some field is missing
                            ~strcmp(type, FrequencyGeneratorDummy.TYPE) && ...
                            ~strcmp(type, FrequencyGeneratorTektronixAWGDummy.TYPE) % This FG is not dummy
                        EventStation.anonymousError(...
                            'Trying to create a %s frequency generator, encountered missing field - "%s". Aborting',...
                            type, missingField);
                    end
                    
                    % Check whether this is THE default FG
                    if isfield(curFgStruct, 'default'); isDefault(i) = true; end
            
                    %%% Get instance (create, if one doesn't exist) %%%
                    t = lower(type);
                    name = [t, '-', curFgStruct.serialNumber];
                    newFG = getObjByName(name);
                    if isempty(newFG)
                        switch t
                            case lower(FrequencyGeneratorSRS.TYPE)
                                newFG = FrequencyGeneratorSRS.getInstance(curFgStruct);
                            case lower(FrequencyGeneratorWindfreak.TYPE)
                                newFG = FrequencyGeneratorWindfreak.getInstance(curFgStruct);
                            case lower(FrequencyGeneratorSGT100A.TYPE)
                                newFG = FrequencyGeneratorSGT100A.getInstance(curFgStruct);
                            case lower(FrequencyGeneratorTektronixAWG.TYPE)
                                newFG = FrequencyGeneratorTektronixAWG.getInstance(curFgStruct);
                            case lower(FrequencyGeneratorRigolAWG.TYPE)
                                newFG = FrequencyGeneratorRigolAWG.getInstance(curFgStruct);
                            case lower(FrequencyGeneratorDummy.TYPE)
                                newFG = FrequencyGeneratorDummy.getInstance(curFgStruct);
                            case lower(FrequencyGeneratorTektronixAWGDummy.TYPE)
                                newFG = FrequencyGeneratorTektronixAWGDummy.getInstance(curFgStruct);
                            otherwise
                                EventStation.anonymousWarning('Could not create Frequency Generator of type %s!', type)
                        end

                        % register FG outputs with the PG, if MW/AWG are "null" in the JSON no channel is registered
                        createSwitch(curFgStruct.MW)
                        createSwitch(curFgStruct.AWG)
                        if isfield(curFgStruct, 'MW2') % we have two channels in the FG, e.g. synthHD
                           curFgStruct = FactoryHelper.supplementStruct(curFgStruct, FrequencyGenerator.OPTIONAL_FIELDS);
                           createSwitch(curFgStruct.MW2)
                        end
                    end
                    fgCellContainer.cells{end + 1} = newFG;
                    catch err
                        warning('FG "%s" not loaded because of the following error:\n', t);
                        err2warning(err);
                    end
                end
                
                nDefault = sum(isDefault);
                switch nDefault
                    case 0
                        % Nothing.
                    case 1
                        % We move the default one to index 1
                        ind = 1:find(isDefault);
                        indNew = [circshift(ind, 1), length(ind)+1:length(fgCellContainer.cells)]; % = [ind, 1, 2, ..., ind-1, ind+1, ...]
                        fgCellContainer.cells = fgCellContainer.cells(indNew);
                    otherwise
                        EventStation.anonymousError('Too many Frequency Generators were set as default! Aborting.')
                end
                
            end
            
            freqGens = fgCellContainer.cells;
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
        
        function num = nChannelsAvailable()
            num = 0;
            FGs = FrequencyGenerator.getFG;
            for i = 1:length(FGs)
                num = num + FGs{i}.numChannels;
            end
        end
        
        function name = getDefaultFgName()
            fgCells = FrequencyGenerator.getFG;
            if isempty(fgCells)
                EventStation.anonymousError('There is no active frequency generator!')
            end
            fg = fgCells{1};   % We sorted the array so that the default FG is first
            name = fg.name;
        end
    end
end