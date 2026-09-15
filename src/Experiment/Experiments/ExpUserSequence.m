classdef ExpUserSequence < Experiment
    %EXPUSERSEQUENCE Runs a sequence built by hand in the GUI
    %   A normal Experiment in every respect - it takes part in the usual
    %   run loop, tracking, plotting and saving - except that its sequence
    %   comes from a UserSequenceSpec rather than from hardcoded MATLAB.
    %
    %   The spec carries an explicit table of measurement points. Each row
    %   sets its swept variables, which may drive pulse durations, MW
    %   settings, or both; the sequence is rebuilt and the signal generator
    %   updated for every row. The run loop therefore stays one-dimensional
    %   however many variables are swept, and resultsTable gives the counts
    %   back alongside the variable values.
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

        % Experiment.prepareInternal validates and pushes these three, and
        % Experiment itself declares only phase - so they have to live here,
        % as they do in every other experiment.
        frequency = 2870    % MHz
        amplitude = -30     % dBm. Deliberately low: raise it on purpose,
                            % not by running a sequence that never set it.
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

            obj.phase = 0;
            obj.parameterName = 'points';
            obj.isPlotAlternateAvailable = false;

            obj.mCurrentXAxisParam = ExpParamDoubleVector('Point', [], [], '', obj.NAME);
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
            paramList = obj.spec.xAxisValues();
        end

        function [values, headers] = resultsTable(obj)
            % The measurement as a table: one row per point, one column per
            % swept variable, then signal, reference and their ratio.
            %
            % This is the natural way to read a multi-variable scan - counts
            % against frequency against tau - which a single plotted line
            % cannot show.
            headers = [obj.spec.sweptNames, {'signal_kcps', 'reference_kcps', 'ratio'}];
            nPoints = obj.spec.numberOfParams();
            nDone = obj.currIter;

            values = nan(nPoints, numel(headers));
            if ~isempty(obj.spec.combinations)
                values(:, 1:numel(obj.spec.sweptNames)) = obj.spec.combinations;
            end
            if nDone < 1 || isempty(obj.signal); return; end

            iSignal = obj.spec.signalWindow;
            iReference = obj.spec.referenceWindow;
            nVars = numel(obj.spec.sweptNames);

            sig = mean(obj.signal(iSignal, :, 1:nDone), 3, 'omitnan');
            ref = mean(obj.signal(iReference, :, 1:nDone), 3, 'omitnan');
            n = min(nPoints, numel(sig));

            values(1:n, nVars+1) = sig(1:n)';
            values(1:n, nVars+2) = ref(1:n)';
            values(1:n, nVars+3) = (sig(1:n) ./ ref(1:n))';
        end
    end

    %% Overridden from Experiment
    methods
        function S = buildSequence(obj, pointIndex)
            % The sequence, without touching hardware. With no argument it
            % uses the first point, which is what the GUI previews.
            if ~exist('pointIndex', 'var')
                pointIndex = 1;
            end
            S = obj.spec.buildSequence(pointIndex);
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
            [signalDuration, referenceDuration] = obj.spec.windowDurations(1);
            obj.detectionDuration = signalDuration;
            obj.referenceDetectionDuration = referenceDuration;

            % Fold this point's MW settings into the properties before
            % prepareInternal runs, so the generator is configured through
            % setFGparams - the same path every other experiment uses -
            % rather than by poking the SignalGenerator behind its back.
            obj.adoptMwSettings(1);
            S = obj.buildSequence(1);
            obj.prepareInternal(S)

            % Set parameter, for saving and for the x axis
            obj.mCurrentXAxisParam.name = obj.spec.xAxisLabel();
            obj.mCurrentXAxisParam.value = obj.spec.xAxisValues();
            obj.parameterName = BooleanHelper.ifTrueElse( ...
                isempty(obj.spec.sweptNames), 'points', ...
                sprintf('%s points', strjoin(obj.spec.sweptNames, '/')));
        end

        function perform(obj)
            pg = getObjByName(PulseGenerator.NAME);
            spcm = getObjByName(Spcm.NAME);
            tracker = getObjByName(Tracker.NAME);
                if isempty(tracker); throwBaseObjException(Tracker.Name); end

            nPoints = obj.spec.numberOfParams();
            iSignal = obj.spec.signalWindow;
            iReference = obj.spec.referenceWindow;

            for t = 1 : nPoints
                if obj.currIter <= size(obj.signal, 3) && ...
                        sum(obj.signal(:, t, obj.currIter)) ~= 0
                    continue    % Already measured in this average
                end

                success = false;
                for trial = 1 : 10
                    if obj.checkEmergencyStop(); return; end
                    try
                        % A point can move pulse durations, MW settings, or
                        % both, so both are re-applied. The whole sequence is
                        % reloaded rather than patched pulse by pulse, since
                        % one variable may appear in any number of durations.
                        obj.applyMwSettings(t);
                        pg.setSequence(obj.buildSequence(t));
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
                    obj.sendError(sprintf('Could not measure point %d of %d after 10 tries.', ...
                        t, nPoints));
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
        function adoptMwSettings(obj, pointIndex)
            % Copy this point's MW-bound values onto our own properties, and
            % point MWChannel at whatever channels the spec names.
            settings = obj.spec.mwSettings(pointIndex);
            if isempty(settings); return; end

            channels = unique({settings.channel}, 'stable');
            channels = channels(~cellfun(@isempty, channels));
            if ~isempty(channels)
                obj.MWChannel = channels;
            end

            for i = 1 : numel(settings)
                s = settings(i);
                if isprop(obj, s.what)
                    obj.(s.what) = s.value;
                end
            end
        end

        function applyMwSettings(obj, pointIndex)
            % Push this point's MW-bound variables to the signal generator.
            % Nothing to do for a sequence whose variables are all durations.
            settings = obj.spec.mwSettings(pointIndex);
            if isempty(settings); return; end

            sg = getObjByName(SignalGenerator.NAME);
            if isempty(sg) || ~isvalid(sg)
                obj.sendError('The sequence sets an MW parameter, but there is no signal generator.')
            end

            for i = 1 : numel(settings)
                s = settings(i);
                try
                    channelNumber = sg.FGchannelMap(s.channel);
                catch
                    obj.sendError(sprintf('"%s" is not a known MW channel.', s.channel))
                end
                % The [value, channel] form addresses one channel alone
                sg.(s.what) = [s.value, channelNumber];
            end
        end
    end
end
