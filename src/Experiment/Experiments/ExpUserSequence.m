classdef ExpUserSequence < Experiment
    %EXPUSERSEQUENCE Runs a sequence built by hand in the GUI
    %   A normal Experiment in every respect - it takes part in the usual
    %   run loop, tracking, plotting and saving - except that its sequence
    %   comes from a UserSequenceSpec rather than from hardcoded MATLAB.
    %
    %   The swept variable of the spec is the x axis. For each of its
    %   values the sequence is rebuilt and reloaded into the pulse
    %   generator, then measured like any other pulsed experiment.
    %
    %   Signal and reference are whichever detection windows the user
    %   picked, not the first and second by convention.
    %
    %   See also USERSEQUENCESPEC, SEQUENCEEXPRESSION

    properties (Constant)
        NAME = 'UserSequence'
    end

    properties
        spec        % UserSequenceSpec
    end

    methods
        function obj = ExpUserSequence(spec)
            obj@Experiment(ExpUserSequence.NAME);

            if exist('spec', 'var') && isa(spec, 'UserSequenceSpec')
                obj.spec = spec;
            else
                obj.spec = UserSequenceSpec();
            end

            obj.repeats = 100;
            obj.averages = 500;
            obj.detectionDuration = 0.3;
            obj.referenceDetectionDuration = 0.3;
            obj.laserInitializationDuration = 20;

            obj.parameterName = 'sweep points';
            obj.isPlotAlternateAvailable = false;

            obj.mCurrentXAxisParam = ExpParamDoubleVector('Sweep', [], [], '\mus', obj.NAME);
            obj.signalParam = ExpResultDoubleVector('FL', [], [], 'Normalized', obj.NAME, 'Signal / Reference');
        end

        function setSpec(obj, spec)
            % Point the experiment at a different (or edited) sequence
            if ~isa(spec, 'UserSequenceSpec')
                obj.sendError('setSpec expects a UserSequenceSpec.')
            end
            obj.spec = spec;
            obj.changeFlag = true;
        end

        function [totalParamNum, paramList] = getTotalNumberOfParams(obj)
            totalParamNum = obj.spec.numberOfParams();
            paramList = obj.sweepAxis();
        end

        function values = sweepAxis(obj)
            % The x axis: the swept variable's values, or a single point
            if isempty(obj.spec.sweepName) || isempty(obj.spec.sweepValues)
                values = 1;
            else
                values = obj.spec.sweepValues;
            end
        end
    end

    %% Overridden from Experiment
    methods
        function S = buildSequence(obj, sweepValue)
            % The sequence, without touching hardware. With no argument it
            % uses the first sweep point, which is what the GUI previews.
            if ~exist('sweepValue', 'var')
                sweepValue = obj.spec.sweepValueAt(1);
            end
            S = obj.spec.buildSequence(sweepValue);
        end
    end

    methods (Access = protected)
        function prepare(obj)
            % Initialize devices (SPCM, PulseGenerator, etc.)

            [isOk, message] = obj.spec.validate();
            if ~isOk
                obj.sendError(sprintf('The sequence cannot be run: %s', message));
            end

            detectors = obj.spec.detectorPulseIndices();
            obj.detectionPeriodsPerRepeat = numel(detectors);
            obj.runsPerPerform = 1;

            % processData converts counts to kcps using these two, so they
            % must describe the windows the user actually picked.
            [signalDuration, referenceDuration] = obj.spec.windowDurations(obj.spec.sweepValueAt(1));
            obj.detectionDuration = signalDuration;
            obj.referenceDetectionDuration = referenceDuration;

            S = obj.buildSequence();
            obj.prepareInternal(S)

            % Set parameter, for saving and for the x axis
            obj.mCurrentXAxisParam.name = obj.axisName();
            obj.mCurrentXAxisParam.value = obj.sweepAxis();
        end

        function perform(obj)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
                if isempty(tracker); throwBaseObjException(Tracker.Name); end

            sweepValues = obj.sweepAxis();
            iSignal = obj.spec.signalWindow;
            iReference = obj.spec.referenceWindow;

            for t = 1 : numel(sweepValues)
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue    % Already measured in this average
                end

                success = false;
                for trial = 1 : 10
                    if obj.checkEmergencyStop(); return; end
                    try
                        % Rebuild for this sweep point. The whole sequence is
                        % reloaded rather than patched pulse by pulse, since
                        % one variable can appear in any number of durations.
                        pg.setSequence(obj.buildSequence(sweepValues(t)));
                        pg.repeats = obj.repeats;

                        data = obj.getRawData(pg, spcm);
                        [sig, sterr] = obj.processData(data);

                        obj.signal(:, t, obj.currIter) = sig;
                        obj.sterr(:, t, obj.currIter) = sterr;

                        success = true;
                        obj.currParamIter = obj.currParamIter + 1;
                        if obj.currParamIter == 1 || mod(obj.currParamIter, 5) == 0 ...
                                || obj.currParamIter == obj.totalNumberOfParams
                            sendEventParamIterationDone(obj);
                        end

                        if obj.isTracking
                            if obj.checkEmergencyStop(); return; end
                            isTrackingNeeded = tracker.compareReference( ...
                                sig(iReference), sterr(iReference), ...
                                Tracker.REFERENCE_TYPE_KCPS, obj.trackThreshhold);
                            if isTrackingNeeded
                                tracker.trackUsing(TrackablePosition.NAME)
                                obj.prepare;    % Before next measurement
                            end
                        end

                        break
                    catch err
                        err2warning(err);
                    end
                end

                if ~success
                    obj.sendError(sprintf('Could not measure sweep point %d (%g) after 10 tries.', ...
                        t, sweepValues(t)));
                end
            end

            % Saving results in the Experiment parameters, using the windows
            % the user nominated rather than the first two
            nDone = obj.currIter;
            S1 = squeeze(obj.signal(iSignal, :, 1:nDone));
            S1sterr = squeeze(obj.sterr(iSignal, :, 1:nDone));
            S2 = squeeze(obj.signal(iReference, :, 1:nDone));
            S2sterr = squeeze(obj.sterr(iReference, :, 1:nDone));

            [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);
            obj.signalParam.value = value;
            obj.signalParam.sterr = sterr;
        end

        function wrapUp(obj)
            % Counterpart of prepare
            obj.wrapUpInternal()
        end

        function dataParam = alternateSignal(obj) %#ok<MANU>
            % No alternate view: the ratio is already the natural one here
            dataParam = [];
        end
    end

    methods (Access = private)
        function name = axisName(obj)
            if isempty(obj.spec.sweepName)
                name = 'Single point';
            else
                name = obj.spec.sweepName;
            end
        end
    end
end
