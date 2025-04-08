classdef AWGExpNAMECooling < ExperimentAWG
    
    properties (Constant)
        NAME = 'NAME Cooling'; % change
    end
    
    properties
        % All of the parameters must have a set function, and when they are changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue running);
        tau
        simulationDetuning % Detuning protocol
        simulationAmplitude % Amplitude protocol (in rabi frequencies, will be converted to dBm)
        conversionParam  % vector with 3 fields a b c Pdbm = a*log10(b*Rabi_MHZ) + c
    end 
    
    properties (Access = private)
        detuningWF
        amplitudeWF
    end
    
    methods
        function obj = AWGExpNAMECooling() % changed
            obj@ExperimentAWG(AWGExpNAMECooling.NAME); % changed
            obj.parameterName = 'tau'; % change ? % What about plotting,yet to be addressed
            
            obj.repeats = 10000;
            obj.averages = 100;
            obj.frequency = 2870;           % in MHz
            
            obj.amplitude = -20;
            
            obj.detectionDuration = 0.25;               % detuningWFection window, in us
            obj.referenceDetectionDuration = 5;         % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;       % laser initialization in pulsed experiments
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Protocol', [], [], '', obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
        end
    end
    
    %% Setters
    methods % add set functions for all of the new parameters
        function set.tau(obj, newVal) % newVal is in us
            checkTimeScalar(obj, newVal)              %% have to check time is scalar
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
        function totalParamNum = getTotalNumberOfParams(obj) %#ok<MANU>
            totalParamNum = 1;
        end
        
        function loadSimulation(obj, address)
            load(address, 'exp');
            obj.simulationDetuning = exp.detuning / 1e6; %Doesn't work for some reason
            obj.simulationAmplitude = exp.ampl / 1e6; %Doesn't work for some reason
            obj.AWG.sampleRate = 1/dt;
            clear exp;
        end
        
        function calculateWFParameters(obj)
            obj.detuningWF = obj.simulationDetuning;
            amplMHz = obj.simulationAmplitude;
            amplMHz(find(amplMHz<0.01))=0.01;
            amplMHz = amplMHz/1e6; % convert to MHz
            amplMHz(find(amplMHz>13.4)) = 13.4; % limit maximal value
            ampldBm = obj.conversionParam(1) * log10(obj.conversionParam(2)*amplMHz) + obj.conversionParam(3);
            ampldBm(find(ampldBm<-37)) = -37; % limit lowest AWG output
            obj.amplitude = max(ampldBm);
            ampl = sqrt(10.^ampldBm);
            obj.amplitudeWF = ampl / max(ampl);
            obj.tau = length(obj.amplitudeWF)/obj.AWG.SampleRate;
        end
    end
    
    %% Overridden from Experiment
    methods (Access = protected)
        
        function prepare(obj) % Change - Need to write the seqeunce
            % Initialize devices (SPCM, PulseGenerator, etc.)
            
            % Sequence
            %%% Useful parameters for what follows
            initDuration = obj.laserInitializationDuration-obj.detectionDuration-obj.referenceDetectionDuration; %% referencetwoDetectiondurationsdifferent
            obj.detectionPeriodsPerRepeat = 6; % for 3 data points (1 protocol 2 reference)
%             obj.detectionPeriodsPerRepeat = 4; % for 2 data points 
            obj.runsPerPerform = 1;
            MWChannel = obj.MWChannel;
            checkDetectionDuration(obj, obj.detectionDuration); % The mode might have changed; before running, we check
            obj.calculateWFParameters();
            
            lastDelay = Experiment.DEFAULT_LAST_DELAY;
            
            % Initialize FrequencyGenerator
            if isempty(obj.givenFG)
                fgCell = FrequencyGenerator.getFG();
                if obj.nChannels == 1
                    obj.freqGenName = fgCell{1}.name;
                else
                    if fgCell{1}.numChannels == 2
                        obj.freqGenName = fgCell{1}.name;
                    else
                        obj.freqGenName = cellfun(@(fg)fg.name, fgCell(1:2), 'UniformOutput' ,0);
                    end
                end
            end
            
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
%             %With NAME COOLING protocol
            S.addEvent(obj.AWG.TRIG_DURATION,   [triggers{:}, MW{:}, {'AWG'}]);                 % AWG trigger
            S.addEvent(obj.tau,                 [MW{:}, {'AWG'}],           'MW')               % MW
            S.addEvent(lastDelay,           '',                             'lastDelay');       % Last delay
            S.addEvent(obj.detectionDuration,...
                {'greenLaser', 'detector'});                                                    % Detection
            S.addEvent(initDuration,        'greenLaser');                                      % Initialization
            S.addEvent(obj.referenceDetectionDuration,...
                {'greenLaser', 'detector'});                                                    % Reference detuningWFection
            % Reference - no NAME Protocol
            S.addEvent(obj.tau + obj.AWG.TRIG_DURATION + lastDelay, '')                         % Dead time
            S.addEvent(obj.detectionDuration,...
                {'greenLaser', 'detector'});                                                    % Detection
            S.addEvent(initDuration,        'greenLaser');                                      % Initialization
            S.addEvent(obj.referenceDetectionDuration,...
                {'greenLaser', 'detector'});                                                    % Reference detuningWFection
 
%             % Reference - no NAME Protocol: Added Another Data Point
            S.addEvent(obj.tau + obj.AWG.TRIG_DURATION + lastDelay, '')                         % Dead time
            S.addEvent(obj.detectionDuration,...
                {'greenLaser', 'detector'});                                                    % Detection
            S.addEvent(initDuration,        'greenLaser');                                      % Initialization
            S.addEvent(obj.referenceDetectionDuration,...
                {'greenLaser', 'detector'}); 

            
            obj.prepareInternal(S)
            if obj.changeFlag
                obj.LoadAWG;
            end
            
%             % Set parameter, for saving
%             obj.mCurrentXAxisParam.value = [1, 0];
             obj.mCurrentXAxisParam.value = [2, 1, 0]; %% one for additional reference detection 
        end
        
        function LoadAWG(obj) % Change - Set waveform
            obj.AWG.ResetStoredData;
            obj.AWG.workChannels = 1:obj.nChannels;
            obj.AWG.setAmplitude(obj.amplitude);
            
            % obj.tau = tau;
%             waveform = A * obj.amplitudeWF .* cos((w+2*pi*obj.detuningWF/1e6).*t);
%             waveform = A .* cos(w*t);
            
            
            % creating waveforms: 
            A = obj.AWG.MaxNormPowerAllowed;
            w = 2*pi*obj.frequency;
            t = 0:1/obj.AWG.SampleRate:obj.tau-1/obj.AWG.SampleRate;
            waveform = A * obj.amplitudeWF .* cos((w + 2*pi*obj.detuningWF/1e6).*t);
            WaveformsIndex = obj.AWG.AddWaveformByPoints(waveform, obj.AWG.MIN_WAVEFORM_LENGTH);
            obj.AWG.LoadWaveform();
            
            % creating sequences:
            obj.indexSeq = obj.AWG.AddSequence(WaveformsIndex, 1, 1,1);
            obj.AWG.LoadSequence()
        end
%             time_waveForm =waveFormData.time;
%             total_WF =waveFormData.total_WF;
%             figure;plot(time_waveForm,total_WF)
        function perform(obj)
            %%% Initialization
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
            if isempty(tracker); throwBaseObjException(Tracker.Name); end
            
            % Some magic numbers
            
            success = false;
            for trial = 1 : 3
                if obj.checkEmergencyStop()
                    return;
                end
                try
                    obj.AWG.assignSequence(obj.indexSeq)
                    obj.AWG.Run;
                    
                    data = obj.getRawData(pg, spcm);
                    [sig, sterr] = obj.processData(data);
                    obj.signal(:, obj.currIter) = sig;
                    obj.sterr(:, obj.currIter) = sterr;
                    
                    success = true;
                    obj.currParamIter = obj.currParamIter + 1;
                    
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
            
            % Saving results in the Experiment parameters
            S1 = squeeze(obj.signal(1, 1:obj.currIter)); % Meas with NAME
            S1sterr = squeeze(obj.sterr(1, 1:obj.currIter));
            S2 = squeeze(obj.signal(2, 1:obj.currIter)); % Ref with NAME
            S2sterr = squeeze(obj.sterr(2, 1:obj.currIter));
            S3 = squeeze(obj.signal(3, 1:obj.currIter)); % Meas without NAME
            S3sterr = squeeze(obj.sterr(3, 1:obj.currIter));
            S4 = squeeze(obj.signal(4, 1:obj.currIter)); % Ref without NAME
            S4sterr = squeeze(obj.sterr(4, 1:obj.currIter));
% %             added another data point for extra reference
            S5 = squeeze(obj.signal(5, 1:obj.currIter)); % Meas without NAME
            S5sterr = squeeze(obj.sterr(5, 1:obj.currIter));
            S6 = squeeze(obj.signal(6, 1:obj.currIter)); % Ref without NAME
            S6sterr = squeeze(obj.sterr(6, 1:obj.currIter));
            
%             
            [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);
            [value2, sterr2] = getRatioDistributionValues(obj, S3, S4, S3sterr, S4sterr);
            [value3, sterr3] = getRatioDistributionValues(obj, S5, S6,S5sterr, S6sterr); %forExtraDataPoint

            obj.signalParam.value = [value value2];
            obj.signalParam.sterr = [sterr sterr2];
            obj.signalParam.value = [value value2 value3];
            obj.signalParam.sterr = [sterr sterr2 sterr3];
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