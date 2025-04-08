classdef ExpESR_Nuclear < Experiment
    %EXPESR ESR (electron spin resonance) Experiment
    
    properties (Constant)
        NAME = 'ExpESR_Nuclear'
        
        ZERO_FIELD_SPLITTING = 2.87e3     % in Mhz
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency           % double. in MHz
        mirrorSweepAround   % double. in MHz
        amplitude           % double. in dBm
        phase               % double. in degrees
        piTime_Electron              % in us. For pulsed ESR.
         tau_0               % in us
        Pi_frequency                   % ('pulsed is to be implemented in the future, if needed)
        nChannels           % int. Must be <= the number of FGs in the system
     equalChannels       % boolean. true if all the channels with the same frequency
        timeDelay           % double. in mus. Time delay between two FG channels (if they are the same)
        CWtime
        doubleMeasurement

        piTime              % in us. For pulsed ESR.
        singletDelay        % in us. For Pulsed ESR. day between Laser and MW
    end
    
    properties %(Hidden, Access = private)
        freqMirrored        % set in private function
    end
    
    methods
        
        function obj = ExpESR_Nuclear(FGs, MWChannel, passedExpName)
            
            if nargin == 3
               expName = passedExpName;
            else
               expName = ExpESR_Nuclear.NAME;
            end
            
            obj@Experiment(expName);
            if exist('MWChannel', 'var')
                obj.MWChannel = MWChannel;
            end
            if exist('FGs', 'var')
               obj.freqGenName = obj.getFgName(FGs);
              fg = FrequencyGenerator.getFG();
              obj.freqGenName = {obj.getFgName(fg{1}), obj.getFgName(fg{2})};
            end

            obj.parameterName = 'frequencies';
                        
            obj.repeats = 10000;
            obj.averages = 1000;
            obj.tau_0 = 0.05;              % in us
             obj.frequency = obj.ZERO_FIELD_SPLITTING + (-100 : 2 : 100);
            obj.Pi_frequency = 13;     %in MHz
            obj.amplitude = [-21, -15];        % dBm
            obj.phase = 0;
            obj.nChannels = 2;          % two channels can be added....
            obj.piTime_Electron = 0.025;
            obj.equalChannels = 0;      % boolean. true if all the channels with the same frequency
            obj.timeDelay = 0;          % double. in mus. Time delay between two FG channels (if they are the same)
            obj.CWtime = 1.64;


            obj.doubleMeasurement = false;   % logical

            obj.detectionDuration =500; %0.25;
            obj.referenceDetectionDuration =500;% 5;
            obj.laserInitializationDuration = 10; % laser initialization
            obj.singletDelay = 1;
            
            obj.mirrorSweepAround = []; % Use this for a single frequency range
            
            obj.displayType2 = 'kcps';
            obj.isPlotAlternateAvailable = true;
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Frequency', [], [], 'MHz', obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, 'Normal');
            obj.signalParam2 = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, 'Mirrored');
        end
        
        function force_prepare(obj)
            obj.prepare();
        end            
    end
    
    %% Setters
    methods
        function set.frequency(obj, newVal)	% newVal in microsec
            checkFrequencyVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.frequency = newVal;
            obj.changeFlag = true;
        end
        function set.Pi_frequency(obj, newVal)	% newVal in microsec
            checkFrequencyVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.Pi_frequency = newVal;
            obj.changeFlag = true;
        end
        
        function set.amplitude(obj, newVal) % newVal is in dBm
            checkAmplitude(obj, newVal)
            % If we got here, then newVal is OK.
            obj.amplitude = newVal;
            obj.changeFlag = true;
        end
        function set.piTime_Electron(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.piTime_Electron = newVal;
            obj.changeFlag = true;
        end
       function set.tau_0(obj, newVal)	% newVal in microsec
            checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.tau_0 = newVal;
            obj.changeFlag = true;
        end
        function set.phase(obj, newVal) % newVal is in degrees
            checkPhase(obj, newVal)
            % If we got here, then newVal is OK.
            obj.phase = newVal;
            obj.changeFlag = true;
        end

        function set.nChannels(obj, newVal)
            checkNumberOfChannels(obj, newVal)
            % If we got here, then newVal is OK.
            obj.nChannels = newVal;
            obj.changeFlag = true;
        end
        
        
        function set.mirrorSweepAround(obj, newVal)
            if ~isempty(newVal)
                % If it is empty, no further checking is needed
                checkFrequencyScalar(obj, newVal)
            end
            
            % If we got here, then newVal is OK.
            obj.mirrorSweepAround = newVal;
            obj.changeFlag = true;
        end
        
        function set.piTime(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.piTime = newVal;
            obj.changeFlag = true;
        end
        
        function set.singletDelay(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.singletDelay = newVal;
            obj.changeFlag = true;
        end
        
        function set.equalChannels(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.equalChannels = newVal;
            obj.changeFlag = true;
        end
            
        function set.timeDelay(obj, newVal)
            obj.timeDelay = newVal;
        end
end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.frequency);
        end
    end
    
    %% Helper functions
    methods
        
        function phase = calculatePhase(obj, f)
            phase = obj.timeDelay * f;
        end
    end
    
    %% Overridden from Experiment
    methods (Access = protected)
        function prepare(obj)
            % Initialize devices (SPCM, PulseGenerator, etc.)
            
            % Sequence
            %%% Useful parameters for what follows
            isSingleMeasurement = (isempty(obj.mirrorSweepAround) || obj.nChannels > 1);
            obj.detectionPeriodsPerRepeat = 2;
            obj.runsPerPerform = (1 + ~isSingleMeasurement);
            MWChannel = obj.MWChannel;
            initDuration = obj.laserInitializationDuration-obj.detectionDuration-obj.referenceDetectionDuration;
            %%% Create
            S = Sequence;
            if obj.laserInitializationDuration > obj.detectionDuration
                warning('A CW experiment is set but it seems that the durations are for a pulsed experiment.');
            end


            lastDelay = Experiment.DEFAULT_LAST_DELAY;
            S.addEvent(obj.piTime_Electron, 'MW2');
            S.addEvent(obj.tau_0,           '');
            S.addEvent(obj.CWtime,          'MW');
            S.addEvent(obj.tau_0,           '');
            S.addEvent(obj.piTime_Electron, 'MW2');
            S.addEvent(lastDelay,           '');                                        % Last delay
            S.addEvent(obj.detectionDuration,               {'greenLaser','detector'});
            S.addEvent(obj.laserInitializationDuration,     {'greenLaser'});                         % MW in x
           S.addEvent(obj.referenceDetectionDuration,...
                                                                {'greenLaser','detector'})  % Reference detection
          
            % MW in x

            % Initialize FrequencyGenerator
            if isempty(obj.givenFG)
                fgCell = FrequencyGenerator.getFG();
                for i = 1:length(fgCell)
                    if fgCell{1}.numChannels == 2
                        obj.freqGenName = cellfun(@(fg)fg.name, fgCell(1:end), 'UniformOutput' ,0);
                    else
                        obj.freqGenName = cellfun(@(fg)fg.name, fgCell, 'UniformOutput' ,0);
                    end
                end
            end
            obj.prepareInternal(S)
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.frequency;
        end
        
        function perform(obj)
            % Initialization
            len = length(obj.frequency);
            f1 = randperm(len);
            
            %%% Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
            if isempty(tracker); throwBaseObjException(Tracker.Name); end
            if obj.nChannels == 1
                fg = getObjByName(obj.freqGenName);
            end
            
            % Some magic numbers
            isSingleMeasurement = (isempty(obj.mirrorSweepAround) || obj.nChannels > 1);
            n = obj.detectionPeriodsPerRepeat * obj.runsPerPerform;
            
            sig = zeros(1, n);
            sterr = zeros(1, n);
            
            % Run - Go over all frequencies, in random order
            for k = 1:len
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, f1(k), obj.currIter)) ~= 0
                    continue
                end
                success = false;
                
                for trial = 1 : 5
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        i = f1(k);
                        
                        obj.setMultipleFGFrequencies([obj.frequency(i), obj.Pi_frequency]);
                        
                        data = obj.getRawData(pg, spcm);
                        if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                            [sig(1:2), sterr(1:2)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(1+~isSingleMeasurement)*(k-1)+1:end));%obj.detectionPeriodsPerRepeat*obj.repeats*k));
                        else
                            [sig(1:2), sterr(1:2)] = obj.processData(data);
                        end
                        
                        if ~isSingleMeasurement % run another sweep with the same source
                            fg.frequency = obj.freqMirrored(i);
                            data = obj.getRawData(pg, spcm);
                            if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                                [sig(3:4), sterr(3:4)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*2*(k-0.5)+1:end));%obj.detectionPeriodsPerRepeat*obj.repeats*k));
                            else
                                [sig(3:4), sterr(3:4)] = obj.processData(data);
                            end
                        end
                        
                        obj.signal(:, i, obj.currIter) = sig;
                        obj.sterr(:, i, obj.currIter) = sterr;
                        
                        success = true;
                        obj.currParamIter = obj.currParamIter + 1;
                        sendEventParamIterationDone(obj);
                        
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
            
            %if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled') %maybe check something different
            if length(data) == obj.detectionPeriodsPerRepeat*obj.repeats*obj.getTotalNumberOfParams*(1+~isSingleMeasurement) %if true we're proccessing data at the end of the average
                for k = 1:len
                    [sig(1:2), sterr(1:2)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(1+~isSingleMeasurement)*(k-1)+(1:obj.detectionPeriodsPerRepeat*obj.repeats)));
                    if ~isSingleMeasurement % run another sweep with the same source
                         [sig(3:4), sterr(3:4)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*2*(k-0.5)+(1:obj.detectionPeriodsPerRepeat*obj.repeats)));
                    end
                    obj.signal(:, f1(k), obj.currIter) = sig';
                    obj.sterr(:, f1(k), obj.currIter) = sterr';
                end
            end
                
                
            
            S1 = squeeze(obj.signal(1, :, 1:obj.currIter));
            S1sterr = squeeze(obj.sterr(1, :, 1:obj.currIter));
            S2 = squeeze(obj.signal(2, :, 1:obj.currIter));
            S2sterr = squeeze(obj.sterr(2, :, 1:obj.currIter));
            
            [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);
            obj.signalParam.value = value;
            obj.signalParam.sterr = sterr;
            
            if isSingleMeasurement
                obj.signalParam2.value = [];
            else
                S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
                S3sterr = squeeze(obj.sterr(3, :, 1:obj.currIter));
                S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
                S4sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));
                
                [value, sterr] = getRatioDistributionValues(obj, S3, S4, S3sterr, S4sterr);
                obj.signalParam2.value = value;
                obj.signalParam2.sterr = sterr;
            end
        end
        
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results and fit from it
            % the resonance frequency/ies
            
            obj.wrapUpInternal()
        end
        
        function params = alternateSignal(obj)
            % Returns alternate view of the data.
            % Return a cell array ExpParams. The first cell is dataParam.
            % The second cell is either another dataParam or a cell of
            % three dataParams. The the last cell is a cell of strings
            % which indiciates what are the ExpParams. It is either
            % {'yParam', 'yParam2'} or {'yParam', 'yParam2+'}
            
            if obj.currIter == 0
                params = ExpResultDoubleVector('FL', [], [], 'kcps', obj.NAME);
                return
            end
            S1 = squeeze(obj.signal(1, :, 1:obj.currIter));
            S1sterr = squeeze(obj.sterr(1, :, 1:obj.currIter));
            S2 = squeeze(obj.signal(2, :, 1:obj.currIter));
            S2sterr = squeeze(obj.sterr(2, :, 1:obj.currIter));
            if obj.currIter ~= 1
                % Calculate the mean
                S1sterr = obj.getCombinedSterr(S1, S1sterr);
                S2sterr = obj.getCombinedSterr(S2, S2sterr);
                S1 = mean(S1, 2);
                S2 = mean(S2, 2);
            end
            dataParam = ExpResultDoubleVector('FL', S1, S1sterr, 'kcps', obj.NAME, 'With MW');
            dataParam2 = ExpResultDoubleVector('FL', S2, S2sterr, 'kcps', obj.NAME, 'Without MW');
            
            isSingleMeasurement = (isempty(obj.mirrorSweepAround) || obj.nChannels > 1);
            if ~isSingleMeasurement
                S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
                S3sterr = squeeze(obj.sterr(3, :, 1:obj.currIter));
                S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
                S4sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));
                
                if obj.currIter ~= 1
                    % Calculate the mean
                    S3sterr = obj.getCombinedSterr(S3, S3sterr);
                    S4sterr = obj.getCombinedSterr(S4, S4sterr);
                    S3 = mean(S3, 2);
                    S4 = mean(S4, 2);
                end
                dataParam3 = ExpResultDoubleVector('FL', S3, S3sterr, 'kcps', obj.NAME, 'With MW - Mirrored');
                dataParam4 = ExpResultDoubleVector('FL', S4, S4sterr, 'kcps', obj.NAME, 'Without MW - Mirrored');
                params = {dataParam, {dataParam2, dataParam3, dataParam4}, {'yParam', 'yParam2+'}};
            else
                params = {dataParam, dataParam2, {'yParam', 'yParam2'}};
            end
        end
    end
end