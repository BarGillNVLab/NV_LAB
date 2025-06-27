classdef (Abstract) AWG < SignalGenerator

    properties
        bandwidth
        sampleRate
        % useAWG
        mode % internal or external
        waveforms
        channelName
        directAmplitudeControl  % logical. Can the AWG control amplitude (true) or phase only (false)
        wavformPath             % string. Waveform location path in the instrument
        segmentIQ               % cell array. Each cell is a matrix 2xN (I,Q by IQ length) containing the IQ data for a specific pulse in the sequence.
    end

    properties (Abstract, Constant)
        TYPE    % for now, one of: {'srs', 'synthhd', 'synthnv', 'TektrinixAWG'}
    end

    properties (Constant, Access = private)
        NEEDED_FIELDS = {}
    end

    methods
        function obj = AWG(name, bandwidth, sampleRate, useAWG, mode, channelName, directAmplitudeControl, wavformPath)
            obj@SignalGenerator(name);
            obj.bandwidth = bandwidth;
            obj.sampleRate = sampleRate;
            obj.useAWG = useAWG;
            obj.mode = mode;
            obj.channelName = channelName;
            obj.directAmplitudeControl = directAmplitudeControl;
            obj.wavformPath = wavformPath;
            obj.waveforms = {}; % Initialize waveforms as an empty cell array
        end

        function displayProperties(obj)
            fprintf('Bandwidth: %f\n', obj.bandwidth);
            fprintf('Sample Rate: %f\n', obj.sampleRate);
            fprintf('Use AWG: %d\n', obj.useAWG);
            fprintf('Mode: %s\n', obj.mode);
            fprintf('Channel Name: %s\n', obj.channelName);
            fprintf('Direct Amplitude Control: %d\n', obj.directAmplitudeControl);
            fprintf('Waveforms: %s\n', strjoin(obj.waveforms, ', '));
        end
    end

    methods (Abstract)

        loadAWGInternal(obj, waveform, waveformName)

    end

    methods
        function [I, Q] = generateIQFromWaveform(waveform, f0, Fs)
            persistent dwnConv;
            dwnConv = dsp.DigitalDownConverter(...
                DecimationFactor=2,...
                SampleRate=Fs,...
                PassbandRipple=0.001,...
                Bandwidth=f0/2,...   % must be less than SampleRate/DecimationFactor
                CenterFrequency=f0);  % The value of center frequency must be less than or equal to half the value of the SampleRate

            signal = dwnConv(waveform');

            I = sqrt(2)*real(signal);
            Q = sqrt(2)*imag(signal);

        end

        function [outputTime, outputSignal] = underSampling(time, signal, destSampleRate)
            % Validate inputs
            if length(time) ~= size(signal, 2)
                error('Time and signal vectors must be the same length.');
            end

            % Estimate original sampling rate
            dt = mean(diff(time));
            origFs = 1 / dt;

            % Calculate resampling ratio as integers
            [P, Q] = rat(destSampleRate / origFs, 1e-6);  % rational approximation

            % Resample the signal
            outputSignal = [];
            for i = 1:size(signal, 1)
                outputSignal(i, :) = resample(signal, P, Q);  % uses linear-phase FIR filter
            end

            % Compute new time vector
            outputTime = (0:length(outputSignal)-1) / destSampleRate;
        end
    end

    %% Initializtion and Setup
    methods (Static)
        function awg = getAWG(AWGStruct)
            try
                % If there is no type, then it is a dummy
                if isfield(AWGStruct, 'type'); type = AWGStruct.type; ...
                else; type = AWGDummy.TYPE; end

                % Usual checks on fields
                missingField = FactoryHelper.usualChecks(AWGStruct, ...
                    AWG.NEEDED_FIELDS);
                if ischar(missingField) && ~any(isnan(missingField)) && ...  Some field is missing
                        ~strcmp(type, AWGDummy.TYPE) % This FG is not dummy
                    EventStation.anonymousError(...
                        'Trying to create a %s AWG, encountered missing field - "%s". Aborting',...
                        type, missingField);
                end

                %%% Get instance (create, if one doesn't exist) %%%
                t = lower(type);
                name = [t, '-', AWGStruct.serialNumber];
                awg = getObjByName(name);
                if isempty(awg)
                    switch t
                        case lower(FrequencyGeneratorSRS.TYPE)
                            awg = FrequencyGeneratorSRS.getInstance(AWGStruct);
                        case lower(FrequencyGeneratorWindfreak.TYPE)
                            awg = FrequencyGeneratorWindfreak.getInstance(AWGStruct);
                        case lower(FrequencyGeneratorSGT100A.TYPE)
                            awg = FrequencyGeneratorSGT100A.getInstance(AWGStruct);
                        case lower(FrequencyGeneratorTektronixAWG.TYPE)
                            awg = FrequencyGeneratorTektronixAWG.getInstance(AWGStruct);
                        case lower(FrequencyGeneratorRigolAWG.TYPE)
                            awg = FrequencyGeneratorRigolAWG.getInstance(AWGStruct);
                        case lower(FrequencyGeneratorDummy.TYPE)
                            awg = FrequencyGeneratorDummy.getInstance(AWGStruct);
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