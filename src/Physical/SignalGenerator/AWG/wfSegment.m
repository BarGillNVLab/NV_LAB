classdef wfSegment < handle
    properties (SetAccess = private)
        duration        % Segment duration
        startTime       % Segment start time
        waveform        % Segment waveform
        startIdx        % Start index in the waveform
        endIdx          % End index in the waveform
        I               % In-phase component
        Q               % Quadrature component
        tUnder          % Undersampled time vector
        IUnder          % Undersampled I component
        QUnder          % Undersampled Q component
    end

    properties (Access = private)
        frequency       % Frequencies
        phase           % Phases
        envelope        % Envelopes
        amplitude       % Amplitudes
        dt              % Time step
        tSegment          % Time vector for the segment
        centerFreq      % Center frequency for demodulation
        ddc             % Digital Down Converter object
    end

    methods
        % Constructor
        function obj = wfSegment(segmentStruct, startTime, freq, pha, env, amp, dt, centerFreq, t)
            obj.duration = segmentStruct.duration;
            obj.startTime = startTime;
            obj.frequency = freq;
            obj.phase = repmat(pha, size(freq)./size(pha));
            obj.envelope = env;
            obj.amplitude = amp;
            obj.dt = dt;
            obj.centerFreq = centerFreq;
            bwidth = max(freq) - min(freq);
            if bwidth == 0
                bwidth = freq / 4;
            end

            % Generate time vector for the segment
            obj.startIdx = round(startTime / dt) + 1; % Convert time to index
            obj.endIdx = obj.startIdx + round(obj.duration / dt); % Duration to indices
            obj.endIdx = min(obj.endIdx, length(t)); % Ensure the end index does not exceed the length of the waveform
            obj.tSegment = t(obj.startIdx:obj.endIdx);  % Extract the time slice for the current segment
            


            % % Initialize Digital Down Converter
            % obj.ddc = dsp.DigitalDownConverter(...
            %     'SampleRate', 1/dt, ...
            %     'DecimationFactor', 2, ... % No decimation for now; we'll handle undersampling separately
            %     'Bandwidth', bwidth, ... % Approximate bandwidth
            %     'CenterFrequency', centerFreq, ...
            %     'PassbandRipple', 0.1, ...
            %     'StopbandAttenuation', 60);

            % Generate segment waveform and I/Q components
            obj.generateWaveform();
        end

        % Method to generate segment waveform and I/Q components
        function generateWaveform(obj)
            TWO_PI = 2 * pi;
            segmentWave = zeros(size(obj.tSegment));
            shaping_window = tukeywin(length(obj.tSegment), 0.1);

            for j = 1:length(obj.frequency)
                a = str2func("@(t) " + obj.envelope);
                timeShift = obj.duration / 2;
                sineWave = a(obj.tSegment - obj.startTime - timeShift) .* cos(TWO_PI * obj.frequency(j) * obj.tSegment + obj.phase(j));
                sineWave = sineWave .* shaping_window';
                segmentWave = segmentWave + sineWave;
            end

            if length(obj.frequency) > 1
                segmentWave = segmentWave / length(obj.frequency);
            end

            obj.waveform = segmentWave;

        %     % Demodulate using Digital Down Converter
        %     if mod(length(segmentWave), 2)
        %         segmentWave = segmentWave(1:end-1);
        %     end
        %     signal = obj.ddc(segmentWave(:))';
        %     obj.I = real(signal); % Ensure real output
        %     obj.Q = imag(signal); % Ensure real output
        end

        % Method to perform undersampling
        function undersample(obj, fsUnder, tFull)
            dtUnder = 1 / fsUnder;
            tSegmentUnder = tFull(tFull >= obj.startTime & tFull <= obj.startTime + obj.duration);

            if ~isempty(tSegmentUnder)
                obj.tUnder = tSegmentUnder;
                obj.IUnder = interp1(obj.tSegment, obj.I, tSegmentUnder, 'linear', 0);
                obj.QUnder = interp1(obj.tSegment, obj.Q, tSegmentUnder, 'linear', 0);
            else
                obj.tUnder = [];
                obj.IUnder = [];
                obj.QUnder = [];
            end
        end

        % Method to scale the segment
        function scale(obj, scaleFactor)
            obj.waveform = obj.waveform * scaleFactor;
            obj.I = obj.I * scaleFactor;
            obj.Q = obj.Q * scaleFactor;
            if ~isempty(obj.IUnder)
                obj.IUnder = obj.IUnder * scaleFactor;
                obj.QUnder = obj.QUnder * scaleFactor;
            end
        end

        % Method to filter the segment
        function filter(obj, filterType, cutoffFreq, filterOrder)
            if nargin < 4
                filterOrder = 4;
            end
            fs = 1 / obj.dt;
            nyquist = fs / 2;
            normalizedCutoff = cutoffFreq / nyquist;

            switch lower(filterType)
                case 'low'
                    [b, a] = butter(filterOrder, normalizedCutoff, 'low');
                case 'high'
                    [b, a] = butter(filterOrder, normalizedCutoff, 'high');
                case 'bandpass'
                    [b, a] = butter(filterOrder, normalizedCutoff, 'bandpass');
                otherwise
                    error('Unsupported filter type. Use ''low'', ''high'', or ''bandpass''.');
            end

            obj.waveform = filtfilt(b, a, obj.waveform);
            obj.I = filtfilt(b, a, obj.I);
            obj.Q = filtfilt(b, a, obj.Q);
        end
    end
end