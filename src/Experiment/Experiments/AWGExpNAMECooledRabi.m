classdef AWGExpNAMECooledRabi < ExperimentAWG
    
    properties (Constant)
        NAME = 'NAME Cooled Rabi';
    end
    
    properties
        % All of the parameters must have a set function, and when they are changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue running);
        tau             % in us
        totalZero
        NAMEamplitude
        simulationDetuning  % Detuning protocol
        simulationAmplitude % Amplitude protocol (in rabi frequencies, will be converted to dBm)
        conversionParam     % vector with 3 fields a b c Pdbm = a*log10(b*Rabi_MHZ)+ c
    end
    properties (Access = private)
        detuningWF
        amplitudeWF
        Duration_WF_NAME
    end
    methods
        % Constructor
        function obj = AWGExpNAMECooledRabi()
            obj@ExperimentAWG(AWGExpNAMECooledRabi.NAME);
            obj.parameterName = 'taus';
            
            obj.repeats = 10000;
            obj.averages = 100;
            obj.frequency = 2023;           % in MHz
            obj.amplitude = -25 + [0 0];    % in dBm
            obj.tau = 0.005:0.02:0.6;       % us
            obj.constantTime = true;
            
            obj.detectionDuration = 0.25;               % detection window, in us
            obj.referenceDetectionDuration = 5;         % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;       % laser initialization in pulsed experiments
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
            obj.Duration_WF_NAME = 1/obj.AWG.SampleRate*length(obj.simulationAmplitude);
        end 
    end

%% Setters
    methods
        function set.tau(obj, newVal) % newVal is in us
            checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.tau = newVal;
            obj.changeFlag = true;
        end
        
        function set.simulationDetuning(obj, newVal) % newVal is in us
            checkFrequencyVector(obj, obj.frequency+newVal)
            % If we got here, then newVal is OK.
            obj.simulationDetuning = newVal;
            obj.changeFlag = true;
        end
        
        function set.simulationAmplitude(obj, newVal) % newVal is in dBm
            % If we got here, then newVal is OK.
            obj.simulationAmplitude = newVal;
            obj.changeFlag = true;
        end

        function set.conversionParam(obj, newVal) % vector with 3 fields a b c Pdbm = a*log10(b*Rabi_MHZ)+ c
            if length(newVal) ~= 3
                error('Conversion params length is wrong');
            end
            % If we got here, then newVal is OK.
            obj.conversionParam = newVal;
            obj.changeFlag = true;
        end
    end
    
    
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.tau);
        end
        function calculateWFParameters(obj)
            obj.detuningWF = obj.simulationDetuning;
            amplHz = obj.simulationAmplitude;
            amplHz(find(amplHz<0.01))=0.01;
            amplMHz = amplHz/1e6; % convert to MHz
            amplMHz(find(amplMHz>13.4)) = 13.4; % limit maximal value
            ampldBm = obj.conversionParam(1) * log10(obj.conversionParam(2)*amplMHz) + obj.conversionParam(3);
            ampldBm(find(ampldBm<-37)) = -37; % limit lowest AWG output
            obj.NAMEamplitude = max(ampldBm);
            ampl = sqrt(10.^ampldBm);
            obj.amplitudeWF = ampl / max(ampl);
        end
        
        
    end
    
%% Overridden from Experiment

    methods (Access = protected)
        
        function prepare(obj)
            % Initialize devices (SPCM, PulseGenerator, etc.)
            
            % Sequence
            %%% Useful parameters for what follows
            initDuration = obj.laserInitializationDuration-obj.detectionDuration-obj.referenceDetectionDuration;
            obj.detectionPeriodsPerRepeat = 2;
            obj.runsPerPerform = 1;
            MWChannel = obj.MWChannel;
            checkDetectionDuration(obj, obj.detectionDuration); % The mode might have changed; before running, we check
            obj.calculateWFParameters();
            lastDelay = Experiment.DEFAULT_LAST_DELAY;
            
            obj.Duration_WF_NAME = 1/obj.AWG.SampleRate*length(obj.simulationAmplitude);
            
            %%% Creating the sequence
            if obj.seperatedTrigger                         % AWG trigger
                triggers = {'trigger', 'trigger2'};
            else
                triggers = {'trigger'};
            end
            switch obj.nChannels
                case 1
                    MW = {MWChannel};
                case 2
                    MW = {MWChannel, 'MW2'};
                otherwise
                    obj.sendError('What should we do here?')
            end
            
            S = Sequence;
            S.addEvent(obj.AWG.TRIG_DURATION,   [triggers{:}, MW{:}, {'AWG'}]);             % AWG trigger
            S.addEvent(obj.Duration_WF_NAME,        [MW{:}, {'AWG'}])                           % NAME cooling protocol
            S.addEvent(obj.tau(end),            [MW{:}, {'AWG'}],     'MW')                 % MW
            S.addEvent(lastDelay,           '',                       'lastDelay');         % Last delay
            if ~obj.photoDiodeMeas
                S.addEvent(obj.detectionDuration,...
                    {'greenLaser', 'detector'});                                                % Detection
                S.addEvent(initDuration,        'greenLaser');                                  % Initialization
                S.addEvent(obj.referenceDetectionDuration,...
                    {'greenLaser', 'detector'});                                                % Reference detection
            else
                S.addEvent(obj.detectionDuration,...
                    {'greenLaser', 'GIgate', 'GIdetector'});                                    % Detection
                S.addEvent(obj.acquisitionDuration,...
                    {'greenLaser', 'detector', 'GIreset'});                                     % Acquisition and reset
                S.addEvent(initDuration - obj.acquisitionDuration,    'greenLaser');            % Initialization
                S.addEvent(obj.referenceDetectionDuration,...
                    {'greenLaser', 'GIgate', 'GIdetector'});                                    % Reference detection
                S.addEvent(obj.acquisitionDuration,...
                    {'greenLaser', 'detector', 'GIreset'});                                     % Reference acquisition and reset
            end
            obj.prepareInternal(S)
            if obj.changeFlag
                obj.LoadAWG;
            end
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.tau;
        end
        
        function LoadAWG(obj)
            obj.AWG.ResetStoredData;
            obj.AWG.workChannels = 1:obj.nChannels;
            obj.AWG.setAmplitude(obj.amplitude);
            
            minWaveformTime = obj.AWG.minWaveformDuration;
            N = length(obj.tau);
            WaveformsIndex = zeros(obj.nChannels,N);
            obj.indexSeq = zeros(obj.nChannels,N);
            
            A = obj.AWG.MaxNormPowerAllowed;
            w = 2*pi*obj.frequency;

            % creating waveforms:
%           Name Cooling WaveForm
            B = 10^((obj.NAMEamplitude - obj.amplitude)/20) * A;
            tNAME = 0:1/obj.AWG.SampleRate:obj.Duration_WF_NAME-1/obj.AWG.SampleRate;
            waveform =B .* obj.amplitudeWF .* cos((w+2*pi*obj.detuningWF/1e6).*tNAME);
            NAMEWaveformsIndex = obj.AWG.AddWaveformByPoints(waveform, obj.AWG.MIN_WAVEFORM_LENGTH);
            
%           RabiWaveform
            fprintf('Loading %d waveforms: ', N+1);
            for i = 1:N
                for chan = 1:obj.nChannels
                    f = @(t) A(chan) * (0<=t & t<obj.tau(i)) .* cos(w*t);
                    if obj.timeDelay > 0
                        prePulseTime = minWaveformTime + obj.timeDelay*(chan==1);
                    else
                        prePulseTime = minWaveformTime + obj.timeDelay*(chan==2);
                    end
                    WaveformsIndex(chan,i) = obj.AWG.AddWaveformByFunction(f, prePulseTime+obj.tau(i), prePulseTime, 1);
                    fprintf('%d ', i);
                end
            end
            f = @(t) 0*t;
            lastZeroIndex = obj.AWG.AddWaveformByFunction(f, minWaveformTime, 0, 1);
            fprintf('%d\n', N+1);
            obj.AWG.LoadWaveform();
            
            % creating sequences:
            for i = 1:N
                for chan = 1:obj.nChannels
                    obj.indexSeq(chan,i) = obj.AWG.AddSequence([NAMEWaveformsIndex, WaveformsIndex(chan,i) lastZeroIndex], [1 1 1], [1 0 0], 0);
                end    
            end
           
%             time_waveForm =waveFormData.time;
%             total_WF =waveFormData.total_WF;
% 
%             save('waveformData.mat','time_waveForm','total_WF');

            obj.AWG.LoadSequence()
        end
       
        function perform(obj)
            %%% Initialization
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
                if isempty(tracker); throwBaseObjException(Tracker.Name); end

            % Some magic numbers
            maxLastDelay = Experiment.DEFAULT_LAST_DELAY + max(obj.tau);
            
            for t = randperm(length(obj.tau))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue
                end
                success = false;
                
                for trial = 1 : 10
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        pg.changeSequence('MW', 'duration', obj.tau(t));
                        if obj.constantTime
                            pg.changeSequence('lastDelay', 'duration', maxLastDelay - obj.tau(t));
                        end
                        obj.AWG.assignSequence(obj.indexSeq(1,t),1)
                        if obj.nChannels == 2
                            obj.AWG.assignSequence(obj.indexSeq(2,t),2);
                        end
                        obj.AWG.Run;
                        
                        data = obj.getRawData(pg, spcm);
                        [sig, sterr] = obj.processData(data);
                        obj.signal(:, t, obj.currIter) = sig;
                        obj.sterr(:, t, obj.currIter) = sterr;
                        
                        success = true;
                        obj.currParamIter = obj.currParamIter + 1;
                        if obj.currParamIter == 1 || mod(obj.currParamIter, 5) == 0 || obj.currParamIter == obj.totalNumberOfParams
                            if obj.currParamIter > obj.totalNumberOfParams
                                '';
                            end
                            sendEventParamIterationDone(obj);
                        end
                        
                        if obj.isTracking
                            if obj.checkEmergencyStop()
                                return;
                            end
                            isTrackingNeeded = tracker.compareReference(...
                                sig(2), sterr(2), ... % 2 for reference
                                Tracker.REFERENCE_TYPE_KCPS, obj.trackThreshhold);
                            if isTrackingNeeded
                                tracker.trackUsing(TrackablePosition.NAME)
                                obj.prepare;    % Before next measurement
                            end
                        end
                        
                        break;
                    catch err
                        err2warning(err);
                        fprintf('Experiment failed at trial %d, attempting again.\n', trial);
                        try
                            % Maybe we need to manually clear the resources
                            spcm.stopExperimentCount;
                        catch
                            % But maybe we don't, and that's perfectly ok.
                        end
                    end
                end
                if ~success
                    obj.emergencyStop;
                    return
                end
            end
            
            % Saving results in the Experiment parameters
            S1 = squeeze(obj.signal(1, :, 1:obj.currIter));
            S1sterr = squeeze(obj.sterr(1, :, 1:obj.currIter));
            S2 = squeeze(obj.signal(2, :, 1:obj.currIter));
            S2sterr = squeeze(obj.sterr(2, :, 1:obj.currIter));
            
            [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);
            obj.signalParam.value = value;
            obj.signalParam.sterr = sterr;         
        end
        
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results.
            
            obj.wrapUpInternal()
        end
        
        function dataParam = alternateSignal(obj) %#ok<MANU>
            % Returns alternate view ("referenced") of the data, as an
            % ExpParam, if possible. If not, it returns an empty variable.
            dataParam = [];
        end
    end

end
