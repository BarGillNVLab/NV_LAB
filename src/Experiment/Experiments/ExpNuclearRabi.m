classdef ExpNuclearRabi < Experiment
  % Exp Rabi for nuclear states with 50 % fidality in both nuclear spin
  % states

    properties (Constant)
        NAME = 'ExpNuclearRabi';
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        frequency           % in MHz
        amplitude           % in dBm
        phase               % in deg - phase of 'MW', assuming it is phase locked with 'MW2'
        
        tau_0               % in us
        tau_1               % in us
        piTime              % in us  
        tau                 % in us ( during this time the RF for Rabi will be )
        constantTime        % logical
        doubleMeasurement   % logical
        useIQ               % logical
        mixer               % logical - MW and MW2 are connected through a mixer
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        function obj = ExpNuclearRabi(FG, MWChannel)
            obj@Experiment(ExpNuclearRabi.NAME);
            obj.parameterName = 'taus';
            
            % First, get a frequency generator
            if exist('MWChannel', 'var')
                obj.MWChannel = MWChannel;
            end
            if exist('FG', 'var')
                obj.givenFG = FG;
            else
                FG = [];
            end
             obj.freqGenName = obj.getFgName(FG);
            fg = FrequencyGenerator.getFG();
            obj.freqGenName = {obj.getFgName(fg{1}), obj.getFgName(fg{2})};
            
            % Set properties inherited from Experiment
            obj.repeats = 5000;
            obj.averages = 1000;
            
            obj.frequency = [2870, 2870];   % in MHz
            obj.amplitude = [-10,-10];      % in dBm
            obj.phase = 0;                  % in deg
            obj.tau_0 = 0.025;              % in us
            obj.piTime = 0.05;              % in us
            obj.tau =[ 0.1 ,0.1] ;
            obj.constantTime = true;        % logical
            obj.doubleMeasurement = true;   % logical
            obj.useIQ = true;               % logical
            obj.mixer = true;               % true - MW and MW2 are connected through a mixer
            obj.tau_1 = 0.04;
            obj.detectionDuration = 0.25;           % detection window, in us
            obj.referenceDetectionDuration = 5;     % in us. Detection duration of the reference read
            obj.laserInitializationDuration = 10;   % laser initialization in pulsed experiments in us
            
            obj.mCurrentXAxisParam = ExpParamDoubleVector('Time', [], [], StringHelper.MICROSEC, obj.NAME);
            obj.topParam = ExpParamDoubleVector(StringHelper.TAU, [], [], StringHelper.MICROSEC, obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|1>');
            obj.signalParam2 = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, '|0>');
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
            checkAmplitudeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.amplitude = newVal;
            obj.changeFlag = true;
        end
        
        function set.phase(obj, newVal) % newVal is in dBm
            checkAmplitude(obj, newVal)
            % If we got here, then newVal is OK.
            obj.phase = newVal;
            obj.changeFlag = true;
        end
        
        function set.tau_0(obj, newVal)	% newVal in microsec
            checkTimeVector(obj, newVal)
            % If we got here, then newVal is OK.
            obj.tau_0 = newVal;
            obj.changeFlag = true;
        end
        
         function set.tau_1(obj, newVal)	% newVal in microsec
            checkTimeVector(obj, newVal)
             % If we got here, then newVal is OK.
             obj.tau_1 = newVal;
             obj.changeFlag = true;
         end
        
        function set.constantTime(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.constantTime = newVal;
            obj.changeFlag = true;
        end
        
        function set.doubleMeasurement(obj, newVal)
            checkBoolean(obj, newVal)
            % If we got here, then newVal is OK.
            obj.doubleMeasurement = newVal;
            obj.changeFlag = true;
        end
        
        
        
        function set.piTime(obj, newVal)
            checkTimeScalar(obj, newVal)
            % If we got here, then newVal is OK.
            obj.piTime = newVal;
            obj.changeFlag = true;
        end
        

        function set.tau(obj, newVal)
            checkTimeVectorWithZero(obj, newVal)
            % If we got here, then newVal is OK.
            obj.tau = newVal;
            obj.changeFlag = true;
        end
    end
    
    methods
        function totalParamNum = getTotalNumberOfParams(obj)
            totalParamNum = length(obj.tau);
        end
    end
    
    %% Overridden from Experiment
    methods (Access = protected)
        function prepare(obj)
            % Initialize devices (SPCM, PulseGenerator, etc.)
            
            % Sequence
            %%% Useful parameters for what follows
            initDuration = obj.laserInitializationDuration-obj.detectionDuration-obj.referenceDetectionDuration;
            obj.detectionPeriodsPerRepeat = 2 * (1 + double(obj.doubleMeasurement));
            obj.runsPerPerform = 1;
            
            %%% Creating the sequence
            S = Sequence;
             for k = 1:1+obj.doubleMeasurement
                S.addEvent(obj.piTime, 'MW');                           % MW in x
                
                % tau0 before rotation
                S.addEvent(obj.tau_0, '', 'tau_0');                         % Delay
                
                % RF frequency to translate bw nuclear states 
                if obj.mixer % mixing 'MW' and 'MW2' (hardware connected through mixer)
                     
                     S.addEvent(obj.tau(end), 'MW2',...
                                'small pertubation');                       % MW2 in x + MW.phase
                else
                    S.addEvent(obj.tau_1, 'MW2', 'makeup for srs delay');
                    S.addEvent(obj.tau(end), {'MW2', 'MW'},...
                                'small pertubation');                       % MW2 in x + MW.phase
                    S.addEvent(obj.tau_1, 'MW2', 'makeup for srs delay');
                end
                % tau0 after rotation
                S.addEvent(obj.tau_0, '', 'tau_0');
                    
      
                S.addEvent(obj.piTime, 'MW');                       % MW in 
               
                S.addEvent(Experiment.DEFAULT_LAST_DELAY, '', 'lastDelay'); % Last delay
                S.addEvent(obj.detectionDuration,...
                           {'greenLaser', 'detector'});                     % Detection
                S.addEvent(initDuration, 'greenLaser');                     % Initialization
                S.addEvent(obj.referenceDetectionDuration,...
                           {'greenLaser', 'detector'});
             end
            obj.prepareInternal(S)
            
            % Set parameter, for saving
            obj.mCurrentXAxisParam.value = obj.tau;
            obj.topParam.value = obj.tau;
            
            obj.isPlotAlternateAvailable = obj.doubleMeasurement;
        end
        
        function perform(obj)
            %%% Initialization
            
            % Devices (+ Tracker)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
                if isempty(tracker); throwBaseObjException(Tracker.Name); end
            
            %the two lines below actually do nothing - Pavel - 03/03/22
%             fg = getObjByName(obj.freqGenName);
%             fg.phase = obj.phase;
            %these two lines below should really change the phase of the SRS only
            
            % Some magic numbers
            maxLastDelay = Experiment.DEFAULT_LAST_DELAY + 2 * max(obj.tau);
            
            k = 0;      
            f1 = [];    
            
            %%% Run - Go over all tau's, in random order
            for t = randperm(length(obj.tau))
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue
                end
                success = false;
                
                k = k + 1;      
                f1 = [f1, t];  
                
                for trial = 1 : 5
                    if obj.checkEmergencyStop()
                        return;
                    end
                    try
                        pg.changeSequence('small pertubation', 'duration', obj.tau(t));
                        
                        if obj.constantTime
                            pg.changeSequence('lastDelay', 'duration', maxLastDelay - obj.tau(t));
                        end
                        
                        data = obj.getRawData(pg, spcm);
                        
                        % added by Ty on 29.07.21 %
                        if isa(spcm, 'SpcmTimeTaggerControlledNiDaqEnabled')
                            [sig, sterr] = obj.processData(data(obj.detectionPeriodsPerRepeat*obj.repeats*(k-1)+1:end));%obj.detectionPeriodsPerRepeat*obj.repeats*k));
                        else
                            [sig, sterr] = obj.processData(data);
                        end
                        
                        obj.signal(:, t, obj.currIter) = sig;
                        obj.sterr(:, t, obj.currIter) = sterr;
                        
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
            
            % added by Ty on 29.07.21 %
            if length(data) == obj.detectionPeriodsPerRepeat*obj.repeats*obj.getTotalNumberOfParams % if true we're proccessing data at the end of the average
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
            
            if obj.doubleMeasurement
                S3 = squeeze(obj.signal(3, :, 1:obj.currIter));
                S3sterr = squeeze(obj.sterr(3, :, 1:obj.currIter));
                S4 = squeeze(obj.signal(4, :, 1:obj.currIter));
                S4sterr = squeeze(obj.sterr(4, :, 1:obj.currIter));
                
                [value, sterr] = getRatioDistributionValues(obj, S3, S4, S3sterr, S4sterr);
                obj.signalParam2.value = value;
                obj.signalParam2.sterr = sterr;
            else    
                obj.signalParam2.value = [];
            end
        end
        
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results and fit from it
            % the coherence time.
            
            obj.wrapUpInternal()
        end
        
        function dataParam = alternateSignal(obj)
            % Returns alternate view ("referenced") of the data, as an
            % ExpParam.
            
            N1 = obj.signalParam.value;
            N0 = obj.signalParam2.value;

            value = N0 - N1;
            sterr = sqrt(obj.signalParam.sterr.^2 + obj.signalParam2.sterr.^2);
            dataParam = ExpResultDoubleVector('FL', value, sterr, 'Normalized', obj.NAME);
        end
        
    end
end

