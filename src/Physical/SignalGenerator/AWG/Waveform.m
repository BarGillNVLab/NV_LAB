classdef Waveform < handle
    properties (SetAccess = private)
        name;           % Waveform name
        segments;       % Cell array of wfSegment objects
        fullWaveform;    % the fullWaveform
        baseband;       % The single carrier frequency (LO) for the entire sequence in MHz
        duration        % full waveform duration
        t
        
        
        % Final, resampled data ready for the instrument
        tUnder;         % Undersampled time vector (final AWG time)
        IUnder;         % Undersampled I component (final AWG I data)
        QUnder;         % Undersampled Q component (final AWG Q data)
        fsUnder;        % Undersampling rate (final AWG sample rate)
        
        % Flags
        keepHiResWaveform = true;  % logical.
        startIdxInternal           % index number indicating the previous pulse's startIdx
        endIdxInternal = 0         % index number indicating the previous pulse's endIdx
    end
    
    methods
        % --- Primary Constructor ---
        function obj = Waveform(exp, sequence, fg, awg, idx, baseband)
            % If called with no arguments, create an empty object (for loadobj)
            if nargin == 0
                return;
            end
            
            % --- 1. Setup and Parameter Handling ---
            obj.name = sequence.name;
            obj.fsUnder = awg.sampleRate; % This is the final AWG sample rate
            
            [pulses, ~, pulseTimes] = getPulsesByChannel(sequence, fg);

            obj.duration = pulses(end).duration + (pulseTimes(end) - pulseTimes(1));
            if exp.appendBlank
                obj.duration = obj.duration + exp.appendBlank;
            end

            pulseTimes = pulseTimes - pulseTimes(1); % normalize all pulses times relevant to the first pulse.

            % Prepare frequency, amplitude, phase, envelope and userWaveform
            frequency = repmat(exp.frequency{idx}, size(pulses)./size(exp.frequency{idx}));
            if ~iscell(frequency)
                frequency = num2cell(frequency);
            end

            amplitude = repmat(exp.amplitude{idx}, size(pulses)./size(exp.amplitude{idx}));
            if ~iscell(amplitude)
                amplitude = num2cell(amplitude);
            end
            % normalize amplitudes
            linear_amplitudes = cellfun(@(x) 10.^(x ./ 10), amplitude, 'UniformOutput', false);
            max_amplitude = max(unique(cell2mat(linear_amplitudes)));
            amplitude = cellfun(@(x) (abs(x / max_amplitude)), linear_amplitudes, 'UniformOutput', false);

            if ~isempty(exp.phase)
                phase = repmat(exp.phase{idx}, size(pulses)./size(exp.phase{idx}));
                if ~iscell(phase)
                    phase = num2cell(phase);
                end
            else
                phase = num2cell(zeros(size(pulses)));
                % phase = num2cell(pi/2*ones(size(pulses)));
            end

            if ~isempty(exp.envelope)
                envelope = repmat(exp.envelope{idx}, size(pulses)./size(exp.envelope{idx}));
            else % we'll use a default shaping window defined in generateSynthesizedPulse
                envelope = cell(size(pulses));
            end

            if ~isempty(exp.userWaveform)
                userWaveform = exp.userWaveform{idx};
                % validate userWaveform and pulses have the same size. If not we don't know which pulse to use
                if size(exp.userWaveform{idx}) ~= size(pulses)
                    error(['User defined waveforms don''t account for all pulses. ' ...
                        'Please make sure that each pulse has a defined waveform (can be empty)']);
                end
            else
                userWaveform = {};
            end

            % Calculate baseband (center frequency)
            if ~exist('baseband', 'var')
                baseband = [];
            end


            % --- 2. Determine the Single, Optimal Hardware Carrier ---
            obj.determineOptimalBaseband(frequency, userWaveform, pulses, baseband);
            
            % --- 3. Create Segments using HYBRID Generation ---
            obj.segments = {};
            fprintf('--- Generating High-Resolution I/Q Segments ---\n');
            for i = 1:length(pulses)
                % Check if this is an arbitrary waveform pulse
                % is_arbitrary = ~isempty(userWaveform) && i <= length(userWaveform) && ~isempty(userWaveform{i});
                is_arbitrary = ~isempty(userWaveform) && ~isempty(userWaveform{i});

                if is_arbitrary
                    % Process user-provided RF waveform using the DDC
                    [iq_data, fs_out] = obj.processArbitraryRFPulse(userWaveform{i});
                else
                    % Synthesize pulse directly at baseband
                    [iq_data, fs_out] = obj.generateSynthesizedPulse(pulses(i).duration, pulseTimes(i), frequency{i}, amplitude{i}, envelope{i}, phase{i});
                end
                
                % Create the segment object and store it
                obj.segments{i} = wfSegment(iq_data, fs_out, pulses(i).duration, pulseTimes(i));
            end
            % if exp.appendBlank
            %     startTime = pulseTimes(end) + pulses(end).duration;
            %     obj.duration = obj.duration + exp.appendBlank;
            %     [iq_data, fs_out] = obj.generateSynthesizedPulse(exp.appendBlank, startTime, obj.baseband, 0, 0, 0);
            %     obj.duration = obj.duration - exp.appendBlank;
            %     iq_data = zeros(size(iq_data), 'like', 1j); % generateSynthesizedPulse returns NaN, so we workaround :)
            %     blank_duration = exp.appendBlank;
            %     obj.segments{end+1} = wfSegment(iq_data, fs_out, blank_duration, startTime);
            %     % [iq_data, fs_out] = obj.generateSynthesizedPulse(obj.baseband+10, 0.005, 1, 0, 0);
            %     % obj.segments{end+1} = wfSegment(iq_data, fs_out, 0.005, startTime+blank_duration);
            % end

            % --- 4. Build the Final Waveform ---
            obj.buildAndResampleFinalWaveform();
        end
        
        % --- Public Methods ---
        function plot(obj)
            if isempty(obj.IUnder)
                disp('No final waveform data to plot. Run buildAndResampleFinalWaveform first.');
                return;
            end
            
            figure('Name', sprintf('Waveform Analysis: %s', obj.name));
            
            % Plot the final I/Q data that goes to the instrument
            ax1 = subplot(2,1,1);
            plot(ax1, obj.tUnder * 1e6, obj.IUnder, 'DisplayName', 'I');
            hold(ax1, 'on');
            plot(ax1, obj.tUnder * 1e6, obj.QUnder, 'DisplayName', 'Q');
            hold(ax1, 'off'); grid(ax1, 'on');
            xlabel(ax1, 'Time (\mus)');
            ylabel(ax1, 'Amplitude');
            title(ax1, sprintf('Final AWG Waveform (Sample Rate: %.1f MHz)', obj.fsUnder/1e6));
            legend(ax1);
            
            % Plot the power spectrum of the final signal
            ax2 = subplot(2,1,2);
            pwelch(obj.IUnder + 1j*obj.QUnder, [], [], [], obj.fsUnder, 'centered', 'power');
            title(ax2, sprintf('Power Spectrum of Final I/Q Waveform (Carrier: %.2f MHz)', obj.baseband/1e6));
        end

        % Methods for modification would trigger a rebuild.
        function addSegment(obj, new_segment_object, segment_time)
            % A proper implementation would be more complex, requiring updates
            % to the pulseTimes array and then a full rebuild.
            obj.segments{end+1} = new_segment_object;
            % In a real application, you'd need to reconstruct the pulseTimes array here.
            % For now, we just trigger a rebuild.
            disp('Segment added. Rebuilding final waveform...');
            obj.buildAndResampleFinalWaveform();
        end

        function removeSegment(obj, segmentIdx)
            if segmentIdx < 1 || segmentIdx > length(obj.segments)
                error('Invalid segment index.');
            end
            obj.segments(segmentIdx) = [];
            % Similar to addSegment, this requires rebuilding with updated pulse times.
            disp('Segment removed. Rebuilding final waveform...');
            obj.buildAndResampleFinalWaveform();
        end
    end

    methods (Access = private)
        % --- Helper methods for generation and assembly ---
        
        function determineOptimalBaseband(obj, frequency_cells, userWaveform_cells, pulses, baseband_in)
            if exist('baseband_in', 'var') && ~isempty(baseband_in)
                obj.baseband = baseband_in;
                fprintf('Using user-provided carrier (baseband): %.2f MHz\n', obj.baseband);
                return;
            end
            
            if ~isempty(userWaveform_cells) && ~all([userWaveform_cells{:}])
                error('Cannot determine optimal baseband. Provide a "baseband" carrier frequency when using only arbitrary waveforms.');
            end

            frequencies = cell2mat(frequency_cells);
            freq_span = max(frequencies) - min(frequencies);
            center_freq = (max(frequencies) + min(frequencies)) / 2;            
            obj.baseband = center_freq;
            % Small offset to break symmetry while maintaining bandwidth efficiency
            % obj.baseband = min(frequencies) + freq_span * 0.05;
            % obj.baseband = center_freq + freq_span * 0.03;

            fprintf('Optimal carrier (baseband) calculated: %.2f MHz\n', obj.baseband);
        end

        function [iq_data, fs_out] = generateSynthesizedPulse(obj, duration, startTime, freqs, amplitude, envelope, phase)
            fs_out = obj.fsUnder; % let's use the AWG's samplerate. % 1e3; % Fixed high internal rate of 10 GS/s
            num_points = round(duration * fs_out);
            t_old= (0:num_points-1)' / fs_out;
            tFull = (0:1/fs_out:obj.duration-1/fs_out)';
            


            % Generate time vector for the segment
            startIdx = round(startTime * fs_out) + 1; % Convert time to index
            startIdx = max(obj.endIdxInternal+1, startIdx); % making sure that the new startIdx is at least one index after the previous segment endIdx.
            endIdx = startIdx + round(duration* fs_out) - 1; % Duration to indices. -1 for cases of overlap between adjacent pulses
            endIdx = min(endIdx, length(tFull)); % Ensure the end index does not exceed the length of the waveform
            % obj.tSegment = t(obj.startIdx:obj.endIdx);  % Extract the time slice for the current segment
            t = tFull(startIdx:endIdx);

            % populate internal indexes for future comparisons
            obj.endIdxInternal = endIdx;


            iq_pulse = zeros(size(t), 'like', 1j);
            phase = phase .* ones(size(freqs));
            amplitude = amplitude .* ones(size(freqs));
            for i = 1:length(freqs)
                f_bb = freqs(i) - obj.baseband;
                iq_pulse = iq_pulse + amplitude(i) * exp(1j * (2*pi*f_bb*t + phase(i)));
            end


            % normalize iq_pulse amplitude
            % if sum(phase) == 0
            %     iq_pulse = iq_pulse / length(freqs);
            % end

            % if all(phase == 0) || all(phase == phase(1))  % No phase differences
                % Safe to scale - all components add constructively
                scaling_factor = max(amplitude) / sum(abs(amplitude));
                iq_pulse = iq_pulse * scaling_factor;
            % end

            % % validate signal
            % recon_signal = cos(2*pi*obj.baseband*t).*real(iq_pulse) - sin(2*pi*obj.baseband*t).*imag(iq_pulse);
            % expected_signal = cos(2*pi*(freqs(1)+freqs(2))*t/2+(phase(1)+phase(2))/2).*cos(2*pi*(freqs(1)-freqs(2))*t/2+(phase(1)-phase(2))/2);
            % base_signal = cos(2*pi*(freqs(1)+freqs(2))*t/2).*cos(2*pi*(freqs(1)-freqs(2))*t/2);
            % if sum(recon_signal - expected_signal) < 1e-9
            %     % signal_fit = fittype(['cos(2*pi*(', num2str(freqs(1)+freqs(2)), ')*x/2+(p1+p2)/2).*cos(2*pi*(', num2str(freqs(1)-freqs(2)), ')*x/2+(p1-p2)/2)']);
            %     signal_fit = fittype(['cos(2*pi*(', num2str(freqs(1)+freqs(2)), ')*x/2+p1).*cos(2*pi*(', num2str(freqs(1)-freqs(2)), ')*x/2+p2)']);
            %     ft_options = fitoptions(signal_fit);
            %     ft_options.Lower = [-pi, -pi];
            %     ft_options.Upper = [pi, pi];
            %     ft_options.StartPoint = [(phase(1)+phase(2))/2, (phase(1)-phase(2))/2];
            %     curr_fit = fit(t, recon_signal, signal_fit, ft_options);
            %     curr_fit.p1 / pi
            %     curr_fit.p2 / pi
            % end

            % phase relations
            % [pi/4, -pi/4] -> carrier: 0, envelope: pi/4
            % [-pi/4, pi/4] -> carrier: 0, envelope: -pi/4
            % [3pi/4, pi/4] -> carrier: pi/2, envelope: pi/4
            % [pi/4, 3pi/4] -> carrier: pi/2, envelope: -pi/4
            % [pi/2, 0] -> carrier: pi/4, envelope: pi/4
            % [0, pi/2] -> carrier: pi/4, envelope: -pi/4
            % [pi, 0] -> carrier: pi/2, envelope: pi/2
            % [0, pi] -> carrier: pi/2, envelope: -pi/2
            % [pi/2, -pi/2] -> carrier: 0, envelope: pi/2
            % [-pi/2, pi/2] -> carrier: 0, envelope: -pi/2

            % Calculate the scaling factor
            % try
            % % scaling_factor = max(amplitude) / max(abs(iq_pulse));
            % % iq_pulse = iq_pulse * scaling_factor;
            % % After combining all frequency components
            % % max_amplitude_in_pulse = max(amplitude);  % This is the intended max for this pulse
            % % actual_max_after_combining = max(abs(iq_pulse));
            % % 
            % % % Scale to preserve the intended maximum amplitude
            % % iq_pulse = iq_pulse * (max_amplitude_in_pulse / actual_max_after_combining);
            % end

            % We want the real-valued output signal when baseband is zero
            if obj.baseband == 0
                iq_pulse = real(iq_pulse);
            end

            % making sure the pulse data is double-complex
            % if isreal(iq_pulse)
            %     iq_pulse = complex(iq_pulse, zeros(size(iq_pulse)));
            % end
            % iq_pulse = iq_pulse + 1j * 0;

            % wrap with an envelope
            if isempty(envelope) || ~ischar(envelope)
                 % shaping_window = tukeywin(length(t), 0.01); % Safe default
                 shaping_window = ones(size(t));
            else
                clean_env_str = strtrim(envelope_str);
                if startsWith(clean_env_str, '@')
                    % --- CASE 1: User-defined mathematical expression ---
                    fprintf('  -> Applying user-defined function envelope: %s\n', clean_env_str);
                    try
                        envelope_func = str2func(clean_env_str);
                        % Create a time vector for the function, centered at t=0
                        % and in the correct units (µs).
                        shaping_window = envelope_func(t - (duration / 2));

                        % Validate the output of the user's function
                        if ~isreal(shaping_window) || ~isequal(size(shaping_window), size(t_us))
                            error('User envelope function did not return a real-valued vector of the correct size.');
                        end
                    catch ME
                        warning('Failed to evaluate user-defined envelope function: %s\nError: %s', clean_env_str, ME.message);
                        warning('Unknown envelope keyword "%s". Using Tukey window.', clean_env_str);
                        shaping_window = tukeywin(length(t), 0.1);
                    end
                else
                    % --- CASE 2: Keyword or scalar value ---
                    clean_env_str = lower(clean_env_str);
                    try
                        win_func = str2func(lower(clean_env_str));
                        shaping_window = win_func(length(t));
                    catch
                        warning('Unknown envelope keyword "%s". Using Tukey window.', clean_env_str);
                        shaping_window = tukeywin(length(t), 0.1);
                    end
                end
            end

            iq_data = iq_pulse .* shaping_window;
            if isempty(iq_data)
                iq_data = zeros(size(tFull), 'like', 1j);
            end
        end
        
        function [iq_data, fs_out] = processArbitraryRFPulse(obj, userWaveformStruct)
            rf_waveform = userWaveformStruct.data;
            rf_fs = userWaveformStruct.fs;
            
            signal_bw = (rf_fs / 2) * 0.95;
            decimationFactor = 1; % Keep it simple: let main resample handle rate change
            
            ddc = dsp.DigitalDownConverter(...
                'SampleRate', rf_fs, 'DecimationFactor', decimationFactor, ...
                'Bandwidth', signal_bw, 'CenterFrequency', obj.baseband);
                
            iq_data = ddc(rf_waveform(:));
            fs_out = rf_fs / decimationFactor;
        end

        function buildAndResampleFinalWaveform(obj)
            if isempty(obj.segments), return; end
            
            fs_master = 0;
            for i = 1:length(obj.segments)
                fs_master = max(fs_master, obj.segments{i}.sample_rate);
            end
            
            last_segment = obj.segments{end};
            % total_duration = last_segment.startTime + last_segment.duration;
            total_duration = obj.duration;
            num_total_points = round(total_duration * fs_master);
            full_iq_high_res = zeros(num_total_points, 1, 'like', 1j);
            tFull = (0:1/fs_master:obj.duration-1/fs_master)';

            end_idx_previous = 0;
            
            for i = 1:length(obj.segments)
                segment = obj.segments{i};
                % if i == 1 % pad from the left
                %     segment.iq_data_high_res = [zeros(100, 1); segment.iq_data_high_res];
                % elseif i == length(obj.segments) % pad from the right
                %     segment.iq_data_high_res = [segment.iq_data_high_res; zeros(100, 1)];
                % end
                segment_iq_master_rate = resample(segment.iq_data_high_res, fs_master, segment.sample_rate);
                
                % % Generate time vector for the segment
                % startIdx = round(segment.startTime * fs_master) + 1; % Convert time to index
                % endIdx = startIdx + length(segment_iq_master_rate) - 1; % Duration to indices
                % endIdx = min(endIdx, length(tFull)); % Ensure the end index does not exceed the length of the waveform
                % % obj.tSegment = t(obj.startIdx:obj.endIdx);  % Extract the time slice for the current segment
                % t = tFull(startIdx:endIdx);
                % 
                % full_iq_high_res(startIdx:endIdx) = full_iq_high_res(startIdx:endIdx) + segment_iq_master_rate;

                
                
                start_idx = round(segment.startTime * fs_master) + 1;
                start_idx = max(end_idx_previous + 1, start_idx);             % making sure we don't have any overlaps between segments.
                end_idx = start_idx + length(segment_iq_master_rate) - 1;

                if end_idx <= num_total_points
                    full_iq_high_res(start_idx:end_idx) = full_iq_high_res(start_idx:end_idx) + segment_iq_master_rate;
                else
                    % Handle potential rounding errors
                    len_to_add = length(full_iq_high_res) - start_idx + 1;
                    full_iq_high_res(start_idx:end) = full_iq_high_res(start_idx:end) + segment_iq_master_rate(1:len_to_add);
                end
                end_idx_previous = end_idx;
            end
            
            % --- Final Resample to AWG Rate ---
            % full_iq_high_res = [zeros(500,1); full_iq_high_res; zeros(500,1)]; %padding for resampling
            final_iq_resampled = resample(full_iq_high_res, obj.fsUnder, fs_master, 100, 7.5);
            % padding_length = round(500 / (fs_master/obj.fsUnder));
            % final_iq_resampled = final_iq_resampled(padding_length:end-padding_length);
            
            % --- Store Final Data ---
            obj.tUnder = (0:length(final_iq_resampled)-1)' / obj.fsUnder;
            obj.IUnder = real(final_iq_resampled);
            obj.QUnder = imag(final_iq_resampled);

            if obj.keepHiResWaveform
                obj.fullWaveform = full_iq_high_res;
                % obj.t = (0:1/fs_out:obj.duration-1/fs_out)';
                obj.t = (0:length(full_iq_high_res)-1)' / fs_master;
            end
        end
    end
    
    methods (Static)
        % --- Serialization and Deserialization ---
        function s = saveobj(obj)
            % Create a struct with all public properties to save
            s = struct();
            s.name = obj.name;
            s.fsUnder = obj.fsUnder;
            s.baseband = obj.baseband;
            
            % It's better to save the final computed data rather than the segments,
            % as the segments themselves contain large, high-resolution data.
            % This makes the saved file much smaller and load faster.
            s.IUnder = obj.IUnder;
            s.QUnder = obj.QUnder;
            
            % We don't save tUnder because it can be trivially reconstructed.
            % We don't save the segments cell array for size reasons.
        end

        function obj = loadobj(s)
            % Create an empty object shell
            obj = Waveform(); 
            
            % Populate the object from the saved struct
            if isstruct(s)
                obj.name = s.name;
                obj.fsUnder = s.fsUnder;
                obj.baseband = s.baseband;
                obj.IUnder = s.IUnder;
                obj.QUnder = s.QUnder;
                
                % Reconstruct the time vector
                if ~isempty(obj.IUnder)
                    obj.tUnder = (0:length(obj.IUnder)-1)' / obj.fsUnder;
                else
                    obj.tUnder = [];
                end
                
                % Segments are not restored. The loaded object represents a
                % "finalized" waveform. If you need to restore segments,
                % the saveobj method would need to save them.
                obj.segments = {}; 
            else
                % Handle old save formats if necessary, or just load the object directly
                obj = s;
            end
        end
    end
end