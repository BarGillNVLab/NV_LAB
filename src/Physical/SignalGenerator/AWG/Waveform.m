classdef Waveform < handle
    properties (SetAccess = private)
        segments          % List of wfSegment objects
        emptyWaveform   % Preallocated empty waveform
        duration        % Waveform time duration
        dt              % Time step
        t               % Time vector
        I               % In-phase component of the full waveform
        Q               % Quadrature component of the full waveform
        tUnder          % Undersampled time vector
        IUnder          % Undersampled I component of the full waveform
        QUnder          % Undersampled Q component of the full waveform
        fsUnder         % Undersampling rate
        
        name            % Waveform name
    end

    properties %(Access = private)
        baseband        % Baseband frequency
        ddc             % Digital Down Converter for full waveform
    end

    methods
        % Constructor
        function obj = Waveform(exp, sequence, fg, idx, baseband)
            % Set waveform name
            obj.name = sequence.name;
            % Extract segments and segment times
            [pulses, ~, pulseTimes] = getPulsesByChannel(sequence, fg);

            % Prepare frequency, amplitude, phase, and envelope
            frequency = repmat(exp.frequency{idx}, size(pulses)./size(exp.frequency{idx}));
            if ~iscell(frequency)
                frequency = num2cell(frequency);
            end

            amplitude = repmat(exp.amplitude{idx}, size(pulses)./size(exp.amplitude{idx}));
            if ~iscell(amplitude)
                amplitude = num2cell(amplitude);
            end

            if ~isempty(exp.phase)
                phase = repmat(exp.phase{idx}, size(pulses)./size(exp.phase{idx}));
                if ~iscell(phase)
                    phase = num2cell(phase);
                end
            else
                phase = num2cell(zeros(size(pulses)));
            end

            if ~isempty(exp.envelope)
                envelope = repmat(exp.envelope{idx}, size(pulses)./size(exp.envelope{idx}));
            else % Create envelope using amplitude parameter
                linear_amplitudes = cellfun(@(x) 10^(x / 20), amplitude, 'UniformOutput', false);
                max_amplitude = max(unique(cell2mat(linear_amplitudes)));
                envelope = cellfun(@(x) string(abs(x / max_amplitude)), linear_amplitudes, 'UniformOutput', false);
            end

            % Calculate baseband (center frequency)
            if ~exist('baseband', 'var')
                obj.baseband = (max(cell2mat(frequency)) + min(cell2mat(frequency))) / 2;
            else
                obj.baseband = baseband;  % Set baseband frequency if provided
            end

            % Initialize time parameters
            obj.dt = 1 / (5 * obj.baseband);
            obj.duration = pulses(end).duration + (pulseTimes(end) - pulseTimes(1));
            pulseTimes = pulseTimes - pulseTimes(1);  % Shift all segments to be relative to the first one
            obj.t = 0:obj.dt:obj.duration;  % Time vector for the entire waveform

            % Initialize waveform object properties
            obj.emptyWaveform = zeros(size(obj.t));  % Pre-allocate empty waveform
            obj.segments = wfSegment.empty(length(pulses), 0);  % Pre-allocate wfSegment array
            % segments = wfSegment.empty(length(pulses), 0);

            % Create wfSegment objects
            for i = 1:length(pulses)
                obj.segments(i) = wfSegment(pulses(i), pulseTimes(i), frequency{i}, phase{i}, envelope{i}, amplitude{i}, obj.dt, obj.baseband, obj.t);
            end

            % obj.segments = segments;

            % % Initialize Digital Down Converter for full waveform
            % bandwidth = max(cellfun(@(f) max(f) - min(f), frequency)); % Approximate bandwidth
            % if bandwidth == 0
            %     bandwidth = max(cellfun(@(f) max(f), frequency)) / 4;
            % end
            % obj.ddc = dsp.DigitalDownConverter(...
            %     'SampleRate', 1/obj.dt, ...
            %     'DecimationFactor', 2, ... % No decimation for now; we'll handle undersampling separately
            %     'Bandwidth', bandwidth, ...
            %     'CenterFrequency', obj.baseband, ...
            %     'PassbandRipple', 0.1, ...
            %     'StopbandAttenuation', 60);
            %                 % 'FilterSpecification', 'Design parameters', ...
            % 
            % 
            % % Demodulate the full waveform
            % obj.demodulateFullWaveform();
            % 
            % % Perform undersampling based on instrument specifications
            % if nargin > 4 && ~isempty(instrumentSpecs)
            %     obj.undersample(instrumentSpecs);
            % end
        end

        % Method to demodulate the full waveform
        function demodulateFullWaveform(obj)
            finalWaveform = obj.reconstructWaveform();
            if mod(length(finalWaveform),2)
                finalWaveform = finalWaveform(1:end-1);
            end
            signal = obj.ddc(finalWaveform(:))';
            obj.I = real(signal); % Ensure real output
            obj.Q = imag(signal); % Ensure real output
        end

        % Method to perform undersampling
        function undersample(obj, instrumentSpecs)
            % Extract instrument specifications
            fsMax = instrumentSpecs.fsMax;  % Maximum sampling rate of the instrument
            bandwidth = max(cellfun(@(f) max(f) - min(f), {obj.segments.frequency}));  % Approximate bandwidth

            % Calculate center frequency (baseband)
            fc = obj.baseband;

            % Determine minimum sampling rate for undersampling
            minFs = 2 * bandwidth;
            kMax = floor((2 * fc + bandwidth) / minFs);
            fsUnder = min(fsMax, (2 * fc + bandwidth) / kMax);  % Choose highest possible fs within constraints

            % Ensure fsUnder is at least 2B
            if fsUnder < minFs
                warning('Instrument sampling rate is too low for proper undersampling. Increasing to minimum required.');
                fsUnder = minFs;
            end

            % Store undersampling rate
            obj.fsUnder = fsUnder;

            % Create undersampled time vector
            dtUnder = 1 / fsUnder;
            obj.tUnder = 0:dtUnder:obj.t(end);

            % Undersample each segment
            for i = 1:length(obj.segments)
                obj.segments(i).undersample(fsUnder, obj.tUnder);
            end

            % Undersample the full waveform I/Q
            obj.IUnder = interp1(obj.t, obj.I, obj.tUnder, 'linear', 0);
            obj.QUnder = interp1(obj.t, obj.Q, obj.tUnder, 'linear', 0);
        end

        % Method to reconstruct the final waveform
        function finalWaveform = reconstructWaveform(obj)
            finalWaveform = obj.emptyWaveform;
            for i = 1:length(obj.segments)
                startIdx = obj.segments(i).startIdx;
                endIdx = obj.segments(i).endIdx;
                finalWaveform(startIdx:endIdx) = finalWaveform(startIdx:endIdx) + obj.segments(i).waveform;
            end
        end

        % Method to reconstruct the undersampled I and Q signals
        function [IUnder, QUnder] = reconstructUnderSampledIQ(obj, level)
            if nargin < 2
                level = 'full'; % Default to full waveform level
            end
            switch lower(level)
                case 'full'
                    IUnder = obj.IUnder;
                    QUnder = obj.QUnder;
                case 'segment'
                    IUnder = zeros(size(obj.tUnder));
                    QUnder = zeros(size(obj.tUnder));
                    for i = 1:length(obj.segments)
                        tSegmentUnder = obj.tUnder(obj.tUnder >= obj.segments(i).startTime & obj.tUnder <= obj.segments(i).startTime + obj.segments(i).duration);
                        if ~isempty(tSegmentUnder)
                            startIdxUnder = find(obj.tUnder == tSegmentUnder(1));
                            endIdxUnder = startIdxUnder + length(tSegmentUnder) - 1;
                            IUnder(startIdxUnder:endIdxUnder) = IUnder(startIdxUnder:endIdxUnder) + obj.segments(i).IUnder;
                            QUnder(startIdxUnder:endIdxUnder) = QUnder(startIdxUnder:endIdxUnder) + obj.segments(i).QUnder;
                        end
                    end
                otherwise
                    error('Invalid level. Use ''full'' or ''segment''.');
            end
        end

        % Method to plot the waveform
        function plot(obj, type, level)
            if nargin < 2
                type = 'waveform';
            end
            if nargin < 3 && strcmpi(type, 'iq_under')
                level = 'full'; % Default to full waveform level for undersampled I/Q
            end
            switch lower(type)
                case 'waveform'
                    finalWaveform = obj.reconstructWaveform();
                    plot(obj.t, finalWaveform);
                    % plot(finalWaveform)
                    xlabel('Time');
                    ylabel('Amplitude');
                    title('Waveform');
                case 'iq'
                    figure;
                    subplot(2, 1, 1);
                    if strcmpi(level, 'segment')
                        for i = 1:length(obj.segments)
                            plot(obj.segments(i).tSegment, obj.segments(i).I, 'b', 'DisplayName', sprintf('Segment %d', i));
                            hold on;
                        end
                    else
                        plot(obj.t, obj.I, 'b');
                    end
                    xlabel('Time');
                    ylabel('I');
                    title('In-Phase Component');
                    if strcmpi(level, 'segment')
                        legend;
                    end
                    hold off;

                    subplot(2, 1, 2);
                    if strcmpi(level, 'segment')
                        for i = 1:length(obj.segments)
                            plot(obj.segments(i).tSegment, obj.segments(i).Q, 'r', 'DisplayName', sprintf('Segment %d', i));
                            hold on;
                        end
                    else
                        plot(obj.t, obj.Q, 'r');
                    end
                    xlabel('Time');
                    ylabel('Q');
                    title('Quadrature Component');
                    if strcmpi(level, 'segment')
                        legend;
                    end
                    hold off;
                case 'iq_under'
                    [IUnder, QUnder] = obj.reconstructUnderSampledIQ(level);
                    figure;
                    subplot(2, 1, 1);
                    plot(obj.tUnder, IUnder, 'b');
                    xlabel('Time');
                    ylabel('I');
                    title('Undersampled In-Phase Component');

                    subplot(2, 1, 2);
                    plot(obj.tUnder, QUnder, 'r');
                    xlabel('Time');
                    ylabel('Q');
                    title('Undersampled Quadrature Component');
            end
        end

        % Method to scale the waveform
        function scaleWaveform(obj, scaleFactor)
            for i = 1:length(obj.segments)
                obj.segments(i).scale(scaleFactor);
            end
            obj.demodulateFullWaveform();
            if ~isempty(obj.tUnder)
                obj.undersample(struct('fsMax', obj.fsUnder));
            end
        end

        % Method to filter the waveform
        function filterWaveform(obj, filterType, cutoffFreq, filterOrder)
            for i = 1:length(obj.segments)
                obj.segments(i).filter(filterType, cutoffFreq, filterOrder);
            end
            obj.demodulateFullWaveform();
            if ~isempty(obj.tUnder)
                obj.undersample(struct('fsMax', obj.fsUnder));
            end
        end

        % Method to add a segment
        function addSegment(obj, segment, segmentTime, freq, pha, env, amp) % need to go over this function
            nSegments = length(obj.segments);
            newSegment = wfSegment(segment, segmentTime, freq, pha, env, amp, obj.dt, obj.baseband, obj.t);
            obj.segments(nSegments + 1) = newSegment;

            % Update waveform length if necessary
            % newWaveformLength = segmentTime + segment.duration;
            newWaveformLength = obj.duration + segment.duration;
            if newWaveformLength > obj.t(end)
                obj.duration = newWaveformLength;
                obj.t = 0:obj.dt:obj.duration;
                obj.emptyWaveform = zeros(size(obj.t));
                % Reconstruct existing segments into the new empty waveform
                tempWaveform = obj.reconstructWaveform();
                obj.emptyWaveform(1:length(tempWaveform)) = tempWaveform;
            end

            % Redemodulate full waveform
            obj.demodulateFullWaveform();

            % Recompute undersampled I/Q if necessary
            if ~isempty(obj.tUnder)
                obj.undersample(struct('fsMax', obj.fsUnder));
            end
        end

        % Method to remove a segment
        function removeSegment(obj, segmentIdx)
            if segmentIdx < 1 || segmentIdx > length(obj.segments)
                error('Invalid segment index.');
            end
            obj.duration = obj.duration - obj.segments(segmentIdx).duration;
            obj.segments(segmentIdx) = [];

            % Redemodulate full waveform
            obj.demodulateFullWaveform();

            % Recompute undersampled I/Q if necessary
            if ~isempty(obj.tUnder)
                obj.undersample(struct('fsMax', obj.fsUnder));
            end
        end
    end

    methods (Static)
        % Serialization: Save object
        function s = saveobj(obj)
            s = struct();
            s.segments = obj.segments;
            s.emptyWaveform = obj.emptyWaveform;
            s.dt = obj.dt;
            s.t = obj.t;
            s.I = obj.I;
            s.Q = obj.Q;
            s.tUnder = obj.tUnder;
            s.IUnder = obj.IUnder;
            s.QUnder = obj.QUnder;
            s.fsUnder = obj.fsUnder;
            s.baseband = obj.baseband;
        end

        % Serialization: Load object
        function obj = loadobj(s)
            if isstruct(s)
                obj = Waveform([], [], [], [], []); % Create empty object
                obj.segments = s.segments;
                obj.emptyWaveform = s.emptyWaveform;
                obj.dt = s.dt;
                obj.t = s.t;
                obj.I = s.I;
                obj.Q = s.Q;
                obj.tUnder = s.tUnder;
                obj.IUnder = s.IUnder;
                obj.QUnder = s.QUnder;
                obj.fsUnder = s.fsUnder;
                obj.baseband = s.baseband;
            else
                obj = s;
            end
        end
    end
end