classdef (Abstract) ExperimentAWG < Experiment
    % A subclass that uses the AWG.
    
    properties
        nChannels = 1;              % two channels can be added (with the same frequency)
        defultChannel = 1;
        seperatedTrigger = false;   % 1 if trigger B use for channel 2, 0 if both on triiger A. Not implemented yet!!!
        timeDelay = 0               % double. in mus. Time delay between two AWG channels
        amplitudeDiff = [0 0]       % power difference between the two channels in dB. used with negative value on one channel. ex.: [-1.7 0]
        AWGorSRSswitch = 1;
        RabiFreq
        RabiX0
        halfPiTime          % in us
        piTime              % in us
        frequency           % in MHz
        amplitude       % in dBm
        constantTime
        balancedSequence = 0;       % true to define the reference detection after dark widow equal ti the measurement.
    end
    
    properties (SetAccess = protected)
        AWG
        indexSeq                    % list of the indices of the sequences in the AWG
        indexWF
    end
    
    properties (Constant, Hidden)
        OVERLAP_TIME = 0.05;
        TRIG_DELAY = 0.9890;
        TRIG_DURATION = 0.1; 
    end
    
    properties (Dependent)
        activeChannels
    end

    %% Setters
    methods % add set functions for all of the new parameters
        function set.amplitude(obj, newVal) % newVal is in dBm
            checkAmplitude(obj, newVal)
            % If we got here, then newVal is OK.
            newVal = reshape(newVal, 1, length(newVal));
            ampDiff = reshape(obj.amplitudeDiff, 1, length(obj.amplitudeDiff));
            obj.amplitude = newVal + ampDiff;
            obj.changeFlag = true;
        end
        
        function set.nChannels(obj, newVal)
            checkNumberOfChannels(obj, newVal)
            % If we got here, then newVal is OK.
            obj.nChannels = newVal;
            obj.changeFlag = true;
            if obj.nChannels == 2
                obj.amplitude = obj.amplitude .* [1 1];
                obj.defultChannel = 1;
            end
        end
        
        function set.halfPiTime(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.halfPiTime = newVal;
            obj.changeFlag = true;
        end
        
        function set.defultChannel(obj, newVal)
            if ~ismember(newVal, [1, 2])
                error(' defult channel must be 1 or 2')         
            end
            obj.defultChannel = newVal;
        end
        
        function set.frequency(obj, newVal) % newVal is in MHz
%             checkFrequencyScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.frequency = newVal;
            obj.changeFlag = true;
        end
        
        function set.piTime(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.piTime = newVal;
            obj.changeFlag = true;
        end
        
        function set.seperatedTrigger(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.seperatedTrigger = newVal;
            obj.changeFlag = true;
        end
        
        function set.timeDelay(obj, newVal)
%             checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.timeDelay = newVal;
            obj.changeFlag = true;
        end

        function activeChannels = get.activeChannels(obj)
            if obj.nChannels == 2
                activeChannels = [1 2];
            else
                if strcmp(obj.MWChannel, 'MW')
                    activeChannels = 1;
                else
                    activeChannels = 2;
                end
            end
        end

        function [prePulseTime, phase] = channelsDifference(obj)
            minWaveformTime = obj.AWG.minWaveformDuration;
            w = 2*pi*obj.frequency;
            prePulseTime = minWaveformTime * ones(1, obj.nChannels);
            phase = zeros(1, obj.nChannels);
            roundTimeDelay = obj.RoundDurationByFrequencies(abs(obj.timeDelay), obj.AWG.SampleRate, -1);
            phaseDelay = w * (abs(obj.timeDelay) - roundTimeDelay);
            if obj.timeDelay > 0
                prePulseTime(1) = minWaveformTime + roundTimeDelay;
                phase(1) = phaseDelay;
            else
                prePulseTime(2) = minWaveformTime + roundTimeDelay;
                phase(2) = phaseDelay;
            end
        end
    end
    
    methods
        function obj = ExperimentAWG(name)
            obj@Experiment(name);
            fgs = FrequencyGenerator.getFG();
            for i = 1:length(fgs)
                if contains(fgs{i}.name, 'TektronixAWG') || contains(fgs{i}.name, 'AWGdummy')
                    obj.freqGenName = fgs{i}.name;
                    break;
                end
            end
            if isempty(obj.freqGenName)
                obj.sendError('No AWG Found');
            end
            obj.AWG = getObjByName(obj.freqGenName);
        end

%         function prepareInternal(obj, S)
%             obj@prepareInternal(S)
%             if obj.changeFlag
%                 obj.LoadAWG;
%             end
%         end
        
        function checkPhases(obj, newVal)
            if ismember(0, (newVal == 'X') + (newVal == 'Y'))
                obj.sendError('Phase array must contain just ''X'' and ''Y'' characters')
            end
        end
        
        function [durations, signs] = pulseToDurations(obj, dir, angle)
            dir = dir / norm(dir);
            
            if isequal(dir, [1, 0, 0])
                angles = [angle, 0, 0];
            elseif isequal(dir, [0, 1, 0])  % Changed 'else if' to 'elseif'
                angles = [0, angle, 0];     % Corrected syntax
            elseif isequal(dir, [-1, 0, 0])
                angles = [-angle, 0, 0];
            elseif isequal(dir, [0, -1, 0])
                angles = [0, -angle, 0];    % Corrected syntax
            else
                R = vrrotvec2mat([dir, angle]);
                angles = obj.rotm2eul_XYX(R);
            end
            
            % Assuming angleToDuration function is defined elsewhere
            anglesTime = obj.angleToDuration(angles);
            durations = abs(anglesTime);
            durations(abs(durations) < 1e-3) = 0;
            signs = sign(anglesTime);
        end

        
%         function [f_combined_pulse, total_duration] = createPulse(obj, direction, angle, phi_0)     % not used currently
%             if ~exist('phi_0', 'var')
%                 phi_0 = 0;
%             end
%             
%             % Normalize the direction vector
%             direction = direction / norm(direction);
%             % Calculate the corresponding Bloch sphere angles (theta, phi)
%             R = vrrotvec2mat([direction, angle]);
%             [alpha, beta, gamma] = rotm2eul(R, 'XYX');
%             
%             alphaTime = obj.RoundDurationByFrequencies(obj.angleToDuration(alpha), obj.AWG.SampleRate);
%             betaTime = obj.RoundDurationByFrequencies(obj.angleToDuration(beta), obj.AWG.SampleRate);
%             gammaTime = obj.RoundDurationByFrequencies(obj.angleToDuration(gamma), obj.AWG.SampleRate);
%             
%             total_duration = alphaTime + betaTime + gammaTime;
%             dt = 1 / obj.sampleRate;
%             t = 0 : dt : total_duration - dt; 
%             
%             % Define pulse functions
%             w = 2*pi * obj.frequency;
%             f_pulse = cell(3, 1);
%             f_pulse{1} = @(t) (0 <= t & t < alphaTime) .* cos(w*t - phi_0);
%             f_pulse{2} = @(t) (alphaTime <= t & t < (alphaTime + betaTime)) .* cos(w*t + pi/2 - phi_0);
%             f_pulse{3} = @(t) ((alphaTime + betaTime) <= t & t <  (alphaTime+betaTime+gammaTime)) .* cos(w*t - phi_0);
%             
%             % Create combined pulse function
%             f_combined_pulse = sum(cellfun(@(f) f(t), f_pulse));
%         end
        
        
        function time = angleToDuration(obj, angle)
            time = angle / (2*pi*obj.RabiFreq) + obj.RabiX0;
        end
        
        function angle = durationToAngle(obj, time)
            angle = 2*pi*obj.RabiFreq * (time + obj.RabiX0);
        end
        
        
        function [eul] = rotm2eul_XYX(obj, R)
    
            psi = mod(atan2(-R(2,1),R(3,1)),pi);
            theta = mod(acos(R(1,1)),2*pi);
            phi = mod(atan2(R(1,2), R(1,3)),pi);
            
            % Pack the Euler angles into a 1-by-3 row vector
            eul = [psi, theta, phi];
        end


        function RoundDuration = RoundDurationByFrequencies(obj, duration, frequencies, roundUpwards)
            % round the time 'duration' to be divide by the gcd(frequencies)^-1
            % 'roundUpwards' is the round type: 0 for round, negative for floor and positive for ceil
            if ~exist('roundUpwards', 'var')
                roundUpwards = 0;
            end
            commonFrequency = frequencies(1);
            for i = 2:length(frequencies)
                commonFrequency = gcd(commonFrequency*1000, round(frequencies(i))*1000)/1000;
            end
            if roundUpwards
                if roundUpwards > 0
                    RoundDuration  = ceil(duration * commonFrequency)/commonFrequency;
                else
                    RoundDuration  = floor(duration * commonFrequency)/commonFrequency; 
                end
            else
                RoundDuration  = round(duration * commonFrequency)/commonFrequency;
            end
        end
    end
end