classdef (Abstract) FrequencyGenerator < SignalGenerator
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
    %       (Static) freqGen = getInstance(struct)
    %       (Static) command = createCommand(what, value, channel)
    % 2. call obj.initialize by the end of the constructor
    
    properties
        keepOn          % keep the FG always on
        numChannels     % double

    end
    
    properties (Abstract, Constant)
        TYPE    % for now, one of: {'srs', 'synthhd', 'synthnv', 'TektrinixAWG'}
    end
    
    properties (Constant, Access = private)
        NEEDED_FIELDS = {'address'}
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
        function obj = FrequencyGenerator(name, freqLimits, amplLimits, numChannels, keepOn)
            obj@SignalGenerator(name);
            
            obj.minFreq = freqLimits(1);
            obj.maxFreq = freqLimits(2);
            obj.minAmpl = amplLimits(1);
            obj.maxAmpl = amplLimits(2);
            obj.minPhase = -180;
            obj.maxPhase = 180;
            obj.numChannels = numChannels;
            
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
            obj.phasePrivate     = obj.queryValue('phase');
        end
    end
    
    methods
        function frequency = get.frequencyPrivate(obj)
            frequency = obj.frequencyPrivate;
        end
        function amplitude = get.amplitudePrivate(obj)
            amplitude = obj.amplitudePrivate;
        end
        function phase = get.phasePrivate(obj)
            phase = obj.phasePrivate;
        end
        function output = get.outputPrivate(obj)
            output = obj.outputPrivate;
        end

        function set.outputPrivate(obj, value)
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
        
        function set.amplitudePrivate(obj, newAmplitude)  % in dB
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
        
        function set.frequencyPrivate(obj, newFrequency)      % in Hz
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

        function set.phasePrivate(obj, newPhase)      % in degrees
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
                % sendCommand(obj, command);
                value = [value, str2double(obj.readOutput(command))]; %#ok<AGROW>
                % value = [value, str2double(obj.readOutput(what))]; %#ok<AGROW>
                if value(i) > 1e6
                    value(i) = value(i)*1e-6; % convert frequency to MHz
                end
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
        function freqGen = getFG(FgStruct)
            try
                % If there is no type, then it is a dummy
                if isfield(FgStruct, 'type'); type = FgStruct.type; ...
                else; type = FrequencyGeneratorDummy.TYPE; end

                % Usual checks on fields
                missingField = FactoryHelper.usualChecks(FgStruct, ...
                    FrequencyGenerator.NEEDED_FIELDS);
                if ischar(missingField) && ~any(isnan(missingField)) && ...  Some field is missing
                        ~strcmp(type, FrequencyGeneratorDummy.TYPE) % This FG is not dummy
                    EventStation.anonymousError(...
                        'Trying to create a %s frequency generator, encountered missing field - "%s". Aborting',...
                        type, missingField);
                end

                %%% Get instance (create, if one doesn't exist) %%%
                t = lower(type);
                name = [t, '-', FgStruct.serialNumber];
                freqGen = getObjByName(name);
                if isempty(freqGen)
                    switch t
                        case lower(FrequencyGeneratorSRS.TYPE)
                            freqGen = FrequencyGeneratorSRS.getInstance(FgStruct);
                        case lower(FrequencyGeneratorWindfreak.TYPE)
                            freqGen = FrequencyGeneratorWindfreak.getInstance(FgStruct);
                        case lower(FrequencyGeneratorSGT100A.TYPE)
                            freqGen = FrequencyGeneratorSGT100A.getInstance(FgStruct);
                        case lower(FrequencyGeneratorTektronixAWG.TYPE)
                            freqGen = FrequencyGeneratorTektronixAWG.getInstance(FgStruct);
                        case lower(FrequencyGeneratorRigolAWG.TYPE)
                            freqGen = FrequencyGeneratorRigolAWG.getInstance(FgStruct);
                        case lower(FrequencyGeneratorDummy.TYPE)
                            freqGen = FrequencyGeneratorDummy.getInstance(FgStruct);
                        otherwise
                            EventStation.anonymousWarning('Could not create Frequency Generator of type %s!', type)
                    end

                    % register FG outputs with the PG, if MW/AWG are "null" in the JSON no channel is registered
                end
            catch err
                warning('FG "%s" not loaded because of the following error:\n', t);
                err2warning(err);
            end
        end

    end
end