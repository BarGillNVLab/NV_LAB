classdef ExpCalibrateDelaysSNR < Experiment
    % ExpCalibrateDelaysSNR Experiment with PiTime  Rabi 
    
    properties (Constant)
        NAME = 'ExpCalibrateDelaysSNR';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency       % in MHz
        amplitude       % in dBm
        delays             % in us
        piTime              % in us
        constantTime    % logical
        MWdelay         % in us
        laseroffdelay
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpCalibrateDelaysSNR(FG, MWChannel)
            obj@Experiment(ExpCalibrateDelaysSNR.NAME);
            obj.parameterName = 'taus';
            
%            First, get a frequency generator
            if exist('MWChannel', 'var')
                obj.MWChannel = MWChannel;
            end
            if exist('FG', 'var')
                obj.givenFG = FG;
            else
                FG = [];
            end
            obj.freqGenName = obj.getFgName(FG);

%             %%% To use MW2 comment the aboove block and unomment the block
%             %%% below. make sure to pass the amplitude and frequency as a
%             %%% 2d vector, e.g. frequency=[2870,2870], amplitude=[-10,-10]
            if ~exist('FGs', 'var')
                fgCell = FrequencyGenerator.getFG();
                if fgCell{1}.numChannels == 2 || length(fgCell) == 1
                    obj.freqGenName = fgCell{1}.name;
                else
                    obj.freqGenName = cellfun(@(fg)fg.name, fgCell(1:end), 'UniformOutput' ,0);
                end
            else
                obj.freqGenName = obj.getFgName(FGs);
            end
            obj.delays=0.5:0.005:0.6;
            obj.repeats = 10000;
            obj.averages = 1000;
            obj.laseroffdelay=0.8;
            obj.frequency = 3029; %in MHz
            obj.amplitude = -10; % in dBm
            obj.constantTime = true;
            obj.piTime=0.05;
            obj.detectionDuration = 0.25; % detection window, in us
            obj.referenceDetectionDuration = 0.56; % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10; % laser initialization in pulsed experiments
            obj.fixDelays = 1;              % Do not fix delays for this experiment!
            obj.isPlotAlternateAvailable = true;
            obj.MWdelay=0.1;            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('delay Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
            
            obj.displayType1 =  'Contrast';
            obj.displayType2 =  'SNR';
        end
    end
    
    %% Setters
    methods
        function set.frequency(obj, newVal) % newVal is in MHz
            checkFrequencyVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.frequency = newVal;
            obj.changeFlag = true;
        end
        
        function set.amplitude(obj, newVal) % newVal is in dBm
            checkAmplitude(obj, newVal)
            % If we got here, then newVal is OK.
            obj.amplitude = newVal;
            obj.changeFlag = true;
        end
        
        function set.delays(obj, newVal) % newVal is in us
            checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.delays = newVal;
            obj.changeFlag = true;
        end
        function set.MWdelay(obj, newVal) % newVal is in us
            checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.MWdelay = newVal;
            obj.changeFlag = true;
        end
        function set.laseroffdelay(obj, newVal) % newVal is in us
            checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.laseroffdelay = newVal;
            obj.changeFlag = true;
        end
        function set.constantTime(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.constantTime = newVal;
            obj.changeFlag = true;
        end
    end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.delays);
        end
    end
    
    %% Overridden from Experiment
    methods (Access = protected)
       function prepare(obj)
            % Initialize devices (SPCM, PulseGenerator, etc.)
            
            % Sequence
            %%% Useful parameters for what follows
            initDuration = obj.laserInitializationDuration-obj.detectionDuration-obj.referenceDetectionDuration-obj.delays(end);
            obj.detectionPeriodsPerRepeat = 2;
            obj.runsPerPerform = 1;
            MWChannel = obj.MWChannel;
            checkDetectionDuration(obj, obj.detectionDuration); % The mode might have changed; before running, we check
                                                                % obj.detectionDuration again.

            lastDelay = Experiment.DEFAULT_LAST_DELAY;
            
            %%% Creating the sequence
            S = Sequence;

            S.addEvent(obj.piTime,        MWChannel,                  'MW')
             S.addEvent(5*lastDelay,           '',                         'lastDelay');       % Last delay

            S.addEvent(obj.MWdelay,'','Delay');
            S.addEvent(obj.delays(end), {'greenLaser'}, 'detectDelay');                    % Initialization part A
            S.addEvent(obj.detectionDuration,...
                                            { 'detector','greenLaser'});                    % Detection
            S.addEvent(initDuration,        'greenLaser');                                  % Initialization part B
            S.addEvent(obj.laseroffdelay+obj.piTime+5*lastDelay+obj.MWdelay,                   '',                         'Delay');           %1usec delay 
            S.addEvent(obj.delays(end), {'greenLaser'}, 'detectDelay');                    % Initialization part A
            S.addEvent(obj.referenceDetectionDuration,...
                                            {'greenLaser', 'detector'});                    % Reference detection
             S.addEvent(1,                   'greenLaser');                                  % 1usec delay to ensure full overlap of ref detection and laser, and to init first repaet (less important), Yachel 27.02.22
            S.addEvent(obj.laseroffdelay,'','laserOffDelay');

             obj.prepareInternal(S)

            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.delays;
        end
        
        function perform(obj)
            %%% Initialization
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
                if isempty(tracker); throwBaseObjException(Tracker.Name); end
            
            % Some magic numbers
            maxLastDelay = Experiment.DEFAULT_LAST_DELAY + max(obj.delays);
            
            k = 0; %added by rotem 18.4.21
            f1 = []; %added by rotem 18.4.21
            for t = randperm(length(obj.delays))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue
                end
                success = false;
                f1 = [f1, t]; %added by rotem 18.4.21
                k = k + 1; %added by rotem 18.4.21
                
                for trial = 1 : 10
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        pg.changeSequence('detectDelay', 'duration', obj.delays(t));
                        if obj.constantTime
                            pg.changeSequence('lastDelay', 'duration', maxLastDelay - obj.delays(t));
                        end
                        
                        data = obj.getRawData(pg, spcm);
                        
                        % added by rotem 18.4.21 %
                        if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                            [sig(1:2), sterr(1:2)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(k-1)+1:end));%obj.detectionPeriodsPerRepeat*obj.repeats*k));
                        else
                            [sig(1:2), sterr(1:2)] = obj.processData(data);
                        end

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
            
            % added by rotem 18.4.21 %
            if length(data) == obj.detectionPeriodsPerRepeat*obj.repeats*obj.getTotalNumberOfParams %if true we're proccessing data at the end of the average
                for k = 1:length(obj.tau)
                    [obj.signal(:, f1(k), obj.currIter), obj.sterr(:, f1(k), obj.currIter)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(k-1)+1:obj.detectionPeriodsPerRepeat*obj.repeats*k));
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
%             obj.signalParam2.value =  value;
%             obj.signalParam2.sterr =  sterr;
        end
        
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results.
            
            obj.wrapUpInternal()
        end
        
        function dataParam = alternateSignal(obj)
            % Returns alternate view ("referenced") of the data, as an
            % ExpParam, if possible. If not, it returns an empty variable.
            
            
%             obj.signalParam2.sterr = sterr; 
            value = (1-obj.signalParam.value)./obj.signalParam.sterr;
            dataParam = ExpResultDoubleVector('SNR', value, [], 'Normalized', obj.NAME);
        end
    end
end