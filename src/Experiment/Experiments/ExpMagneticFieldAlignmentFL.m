classdef ExpMagneticFieldAlignmentFL < Experiment
    % magnetic field alignment throug fluorescence intensity. Usefull for
    % strong magnetic field
    
    properties (Constant)
        NAME = 'ExpMagnetic Field Alignment Fluorescence';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        axesAvaliable
        axesTypes
        axesLowerLimits
        axesUpperLimits

        scanValues
        scanAxis
        randOrder       % boolean. If to scan the points in random order
    end
    
    properties (Access = private)
        stage
    end
    
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpMagneticFieldAlignmentFL()
            obj@Experiment(ExpMagneticFieldAlignmentFL.NAME);
            
            obj.stage = ClassExternalFieldControl.GetInstance();
            obj.axesAvaliable = obj.stage.stage_names_;
            obj.axesTypes = obj.stage.stage_types_;
            obj.axesLowerLimits = obj.stage.stage_lower_limit_;
            obj.axesUpperLimits = obj.stage.stage_upper_limit_;

            obj.repeats = 100; %Less repeats can be used in this experiment.(Pavel 18/3/24)
            obj.averages = 1; % no need for large amount of averages too. (Pavel 18/3/24)
            obj.scanValues = 30:2:50;
            obj.scanAxis = obj.axesAvaliable{1};
            obj.randOrder = 0;
            obj.isTracking = 0; %this expetiment automatically should not track because we look for the change in FL here.(Pavel 18/3/24)
            obj.shouldAutosave = 0; %This experiment will be repeated many times and it will garbage the saves folder no need for autosave(Pavel 18/3/24)

            obj.detectionDuration = 100; % detection window, in us
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME);
        end
    end
    
    %% Setters
    methods
        function set.scanAxis(obj, axis)
            if ~sum(strcmp(obj.axesAvaliable, axis))
                error('no type of axis ''%s'' to scan', axis)
            end
            obj.scanAxis = axis;
        end
    end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.scanValues);
        end
    end
    
    %% Overridden from Experiment
    methods (Access = protected)
       function prepare(obj)
            % Initialize devices (SPCM, PulseGenerator, etc.)
            
            % Sequence
            %%% Useful parameters for what follows
            obj.detectionPeriodsPerRepeat = 1;
            obj.runsPerPerform = 1;
            checkDetectionDuration(obj, obj.detectionDuration); % The mode might have changed; before running, we check obj.detectionDuration again.
            gapTime = 1;
            obj.parameterName = sprintf('stage %s position', obj.scanAxis);

            S = Sequence;
            S.addEvent(gapTime,                 'greenLaser');                       % Gap
            S.addEvent(obj.detectionDuration,   {'greenLaser', 'detector'});          % Detection
            obj.prepareInternal(S)

            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.scanValues;
        end
        
        function perform(obj)
            %%% Initialization
            obj.checkLimits;
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
                if isempty(tracker); throwBaseObjException(Tracker.Name); end
            
            % Some magic numbers
            if obj.randOrder
                scan_perm = randperm(length(obj.scanValues));
            else
                scan_perm = 1:length(obj.scanValues);
            end

            for t = scan_perm
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue % Wat?
                end
                success = false;
                
                for trial = 1 : 10
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        obj.stage.SetPosition(obj.scanAxis, obj.scanValues(t));
                        
                        data = obj.getRawData(pg, spcm);
                        
                        % added by rotem 18.4.21 %
                        if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                            [sig, sterr] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(k-1)+1:end));
                        else
                            [sig, sterr] = obj.processData(data);
                        end
                        
                        obj.signal(1, t, obj.currIter) = sig;
                        obj.sterr(1, t, obj.currIter) = sterr;
                        
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
                                sig, sterr, ... 
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
                             if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                                 obj.restartAverageFlag = 1;
                                 spcm.stopExperimentCount(obj.restartAverageFlag);
                                 break;
                             else
                                 spcm.stopExperimentCount;
                             end
                        catch
                            % But maybe we don't, and that's perfectly ok.
                        end
                    end
                end
                if obj.restartAverageFlag
                    break;
                end
                if ~success
                    obj.emergencyStop;
                    return
                end
            end
            % added by rotem 18.4.21 %
            if length(data) == obj.detectionPeriodsPerRepeat*obj.repeats*obj.getTotalNumberOfParams %if true we're proccessing data at the end of the average
                for k = 1:length(obj.scanValues)
                    [obj.signal(1, scan_perm(k), obj.currIter), obj.sterr(1, scan_perm(k), obj.currIter)] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(k-1)+1:obj.detectionPeriodsPerRepeat*obj.repeats*k));
                end
            end
            
            % Saving results in the Experiment parameters
            S1 = squeeze(obj.signal(1, :, 1:obj.currIter));
            S1sterr = squeeze(obj.sterr(1, :, 1:obj.currIter));
            
            obj.signalParam.value = S1;
            obj.signalParam.sterr = S1sterr;         
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

        function checkLimits(obj)
            i = find(strcmp(obj.scanAxis, obj.axesAvaliable));
            if ~prod(obj.axesLowerLimits(i) <= obj.scanValues) || ~prod(obj.scanValues <= obj.axesUpperLimits(i))
                error('scan values out of range')
            end
        end
    end
end