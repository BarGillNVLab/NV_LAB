classdef GIA_laserOn_ExpCalibrateDelays < ExperimentAWG
    % calibration experiment of the delays between laaser to GIgate on
    % delay
    % Important: positive off delay means that the first channel should be
    % off after the second! unlike in our josn files!!!
    
    
    properties (Constant)
        NAME = 'GIA GIgate Calibration Delays';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency                   % in MHz
        amplitude                   % in dBm
        
        listOfChannels              % Cell array of channels, the channels will be turned on according to the order listed
        delays                      % vector of on/off delays to measure
        otherDelays                 % fixed off/on delay
        centerDuration              % the duration of all the channels on
        onDelayMeas                 % boolean. 1 for on delay measurement, 0 for off delay measurement
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = GIA_laserOn_ExpCalibrateDelays(FG)
            obj@ExperimentAWG(ExpCalibrateDelays.NAME);
            obj.parameterName = 'delays';
            
            % First, get a frequency generator
            if exist('FG', 'var')
                obj.givenFG = FG;
            else
                FG = [];
            end
            obj.freqGenName = obj.getFgName(FG);
            
            % Set properties inherited from Experiment
            obj.frequency = 3029;           % in MHz
            obj.amplitude = -10;            % in dBm
            
            obj.repeats = 1000;
            obj.averages = 100;
            obj.isTracking = false;          % Initialize tracking
            obj.trackThreshhold = 0.7;
            obj.shouldAutosave = true;
            obj.fixDelays = 0;              % Do not fix delays for this experiment!
            
%             obj.delays = -0.5:0.01:1;
            obj.delays = 0:0.005:0.6;
            
            obj.detectionDuration = 1;
            obj.referenceDetectionDuration = [];
            obj.GIMeas = 1;

            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'volt', obj.NAME);
        end
    end
    
    %% Setters & Getters
    methods
        function set.frequency(obj, newVal) % newVal is in MHz
            checkFrequencyScalar(obj, newVal)
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
        
        function set.listOfChannels(obj, newVal)
            checkChannels(obj, newVal)
            % If we got here, then newVal is OK.
            obj.listOfChannels = newVal;
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
            % Initializtions before run
            obj.detectionPeriodsPerRepeat = 1;
            obj.runsPerPerform = 1;
            
            S = Sequence;
            S.addEvent(2,                           {'GIenable'});
            S.addEvent(abs(max(obj.delays)),        {'GIenable', 'greenLaser'},             'delay1');
            S.addEvent(0,                           {'GIenable', 'GIgate'},                 'delay2');
            S.addEvent(abs(min(obj.delays)),        {'GIenable', 'greenLaser', 'GIgate'},   'delayBoth');
            S.addEvent(obj.detectionDuration - abs(min(obj.delays)),  ...
                                                    {'greenLaser', 'GIenable', 'GIgate'});
            S.addEvent(obj.stabilizationDuration,   {'greenLaser', 'GIenable'});
            S.addEvent(obj.acquisitionDuration,     {'greenLaser', 'GIenable', 'detector'});
            S.addEvent(obj.GIresetDuration,         '');    
            S.addEvent(10,         '');           % NVs decay into mix state
            obj.prepareInternal(S)
            obj.isPlotAlternateAvailable = 1;
            
            if obj.changeFlag
                obj.LoadAWG;
            end
            obj.mCurrentXAxisParam.value = obj.delays;
        end
        
        function LoadAWG(obj)
        end
        
        function perform(obj)
            %%% Initialization
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
            if isempty(tracker); throwBaseObjException(Tracker.NAME); end
            
            % Some magic numbers
            
            %%% Run - Go over all shifts's, in random order
            for n = randperm(length(obj.delays))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, n, obj.currIter)) ~= 0
                    continue
                end
                success = false;
            
                for trial = 1 : 5
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        if obj.delays(n) >= 0
                            pg.changeSequence('delay1', 'duration', obj.delays(n));
                            pg.changeSequence('delay2', 'duration', 0);
                            pg.changeSequence('delayBoth', 'duration', abs(min(obj.delays)));
                        else
                            pg.changeSequence('delay1', 'duration', 0);
                            pg.changeSequence('delay2', 'duration', abs(obj.delays(n)));
                            pg.changeSequence('delayBoth', 'duration', abs(min(obj.delays) - obj.delays(n)));
                        end
                        
                        data = obj.getRawData(pg, spcm);
                        [sig, sterr] = obj.processData(data);
                        obj.signal(:, n, obj.currIter) = sig;
                        obj.sterr(:, n, obj.currIter) = sterr;
                        
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
                    obj.emergencyStop
                    return
                end
            end
            
            % Saving results in the Experiment parameters
            S = squeeze(obj.signal(:, :, 1:obj.currIter));
            Ssteerr = squeeze(obj.sterr(:, :, 1:obj.currIter));
            
            if obj.currIter > 1
                n = BooleanHelper.ifTrueElse(length(obj.delays) > 1, 2, 1);
                S = mean(S, n);
                Ssteerr = mean(Ssteerr, n)./sqrt(size(Ssteerr, n));
            end
            obj.signalParam.value = S;
            obj.signalParam.sterr = Ssteerr;
        end
        
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results and fit from it
            % the coherence time.
            
            obj.wrapUpInternal()
        end
        
        function dataParam = alternateSignal(obj) %#ok<MANU>
            % Returns alternate view ("referenced") of the data, as an
            % ExpParam, if possible. If not, it returns an empty variable.
            dataParam = [];
        end
    end
    
end