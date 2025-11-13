classdef wfSegment < handle
    properties (SetAccess = private)
        % This class is now a simple data holder for a single pulse segment.
        % The complex generation logic is handled by the main Waveform class.
        
        iq_data_high_res % The pristine, high-resolution complex I+jQ data
        sample_rate       % The sample rate of this segment's data in MHz
        duration         % The duration of the segment in seconds
        startTime        % Start time relative to the sequence beginning
    end

    methods
        function obj = wfSegment(iq_data, fs, duration, startTime)
            % Simple constructor that just stores the pre-generated data.
            obj.iq_data_high_res = iq_data(:); % Ensure it's a column vector
            obj.sample_rate = fs;
            obj.duration = duration;
            obj.startTime = startTime;
        end
    end
end