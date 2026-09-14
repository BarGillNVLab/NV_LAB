classdef UserSequenceExporter
    %USERSEQUENCEEXPORTER Turns a UserSequenceSpec into a real Exp*.m class
    %   The generated file is an ordinary Experiment subclass - it is
    %   discovered by Experiment.getExperimentNames, appears in the GUI's
    %   experiment list, and can be edited by hand afterwards.
    %
    %   The export is one-way on purpose. It is a starting point for an
    %   experiment worth keeping, not a format the builder reads back; the
    %   JSON file is what round-trips.
    %
    %   Each declared variable becomes a property. The swept one becomes a
    %   vector property indexed by the run loop; the rest are scalars. The
    %   duration expressions are emitted verbatim, because they are already
    %   valid MATLAB arithmetic once the variables are local.
    %
    %   See also USERSEQUENCESPEC, EXPUSERSEQUENCE

    properties (Constant)
        CLASS_PREFIX = 'Exp'
    end

    methods (Static)
        function name = classNameFor(spec)
            name = [UserSequenceExporter.CLASS_PREFIX, spec.name];
        end

        function fullPath = defaultPathFor(spec)
            fullPath = fullfile(Experiment.PATH_ALL_EXPERIMENTS, ...
                [UserSequenceExporter.classNameFor(spec), '.m']);
        end

        function [fullPath, isOk, message] = export(spec, fullPath)
            % Write the generated class. Refuses to overwrite silently.
            isOk = false;
            if ~exist('fullPath', 'var') || isempty(fullPath)
                fullPath = UserSequenceExporter.defaultPathFor(spec);
            end

            [specOk, why] = spec.validate();
            if ~specOk
                message = sprintf('The sequence is not valid yet: %s', why);
                return
            end

            if PathHelper.isFileExists(fullPath)
                message = sprintf('"%s" already exists. Choose another name, or delete it first.', fullPath);
                return
            end

            code = UserSequenceExporter.generate(spec);

            fid = fopen(fullPath, 'w');
            if fid == -1
                message = sprintf('Could not write to "%s".', fullPath);
                return
            end
            closeFile = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fwrite(fid, code, 'char');

            isOk = true;
            message = sprintf('Wrote %s', fullPath);
        end

        function code = generate(spec)
            % The full text of the generated class
            className = UserSequenceExporter.classNameFor(spec);
            swept = spec.sweptNames;
            hasSweep = ~isempty(swept);

            % An applyMwSettings() is emitted only when a variable drives
            % the signal generator, so a purely time-domain sequence exports
            % a class with no MW code in it at all.
            mwIdx = [];
            for i = 1 : numel(spec.variables)
                if ~isempty(UserSequenceSpec.mwPropertyFor(spec.variables(i).binding))
                    mwIdx(end+1) = i; %#ok<AGROW>
                end
            end
            hasMw = ~isempty(mwIdx);


            L = {};     % lines

            L{end+1} = sprintf('classdef %s < Experiment', className);
            L{end+1} = sprintf('    %%%s Generated from a sequence built in the GUI.', upper(className));
            L{end+1} = sprintf('    %%   Created %s by UserSequenceExporter.', datestr(now, 'yyyy-mm-dd HH:MM'));
            L{end+1} = '    %   This is a normal Experiment - edit it freely.';
            L{end+1} = '';
            L{end+1} = '    properties (Constant)';
            L{end+1} = sprintf('        NAME = ''%s''', spec.name);
            L{end+1} = '    end';
            L{end+1} = '';
            L{end+1} = '    properties';
            for i = 1 : numel(spec.variables)
                v = spec.variables(i);
                units = UserSequenceSpec.unitsFor(v.binding);
                if any(strcmp(swept, v.name))
                    L{end+1} = sprintf('        %-16s %% swept, in %s', v.name, units); %#ok<AGROW>
                else
                    L{end+1} = sprintf('        %-16s %% in %s', v.name, units); %#ok<AGROW>
                end
            end
            if hasSweep
                L{end+1} = '        combinations     % one row per measurement point';
            end
            L{end+1} = '    end';
            L{end+1} = '';

            %% Constructor
            L{end+1} = '    methods';
            L{end+1} = sprintf('        function obj = %s()', className);
            L{end+1} = sprintf('            obj@Experiment(%s.NAME);', className);
            L{end+1} = '';
            L{end+1} = '            obj.repeats = 100;';
            L{end+1} = '            obj.averages = 500;';
            for i = 1 : numel(spec.variables)
                v = spec.variables(i);
                L{end+1} = sprintf('            obj.%s = %s;', v.name, ...
                    UserSequenceExporter.numberLiteral(v.value)); %#ok<AGROW>
            end
            if hasSweep
                L{end+1} = sprintf('            %% Columns: %s', strjoin(swept, ', '));
                L{end+1} = sprintf('            obj.combinations = %s;', ...
                    UserSequenceExporter.matrixLiteral(spec.combinations));
            end
            [signalDuration, referenceDuration] = spec.windowDurations(1);
            L{end+1} = sprintf('            obj.detectionDuration = %s;', UserSequenceExporter.numberLiteral(signalDuration));
            L{end+1} = sprintf('            obj.referenceDetectionDuration = %s;', UserSequenceExporter.numberLiteral(referenceDuration));
            L{end+1} = '';
            if hasSweep
                L{end+1} = sprintf('            obj.parameterName = ''%s points'';', strjoin(swept, '/'));
            else
                L{end+1} = '            obj.parameterName = ''points'';';
            end
            axisName = spec.xAxisLabel();
            xColumn = find(strcmp(swept, spec.xAxisName), 1);
            L{end+1} = sprintf('            obj.mCurrentXAxisParam = ExpParamDoubleVector(''%s'', [], [], ''\\mus'', obj.NAME);', axisName);
            L{end+1} = '            obj.signalParam = ExpResultDoubleVector(''FL'', [], [], ''Normalized'', obj.NAME, ''Signal / Reference'');';
            L{end+1} = '        end';
            L{end+1} = '';

            %% getTotalNumberOfParams
            L{end+1} = '        function [totalParamNum, paramList] = getTotalNumberOfParams(obj)';
            if hasSweep
                L{end+1} = '            totalParamNum = size(obj.combinations, 1);';
                if isempty(xColumn)
                    L{end+1} = '            paramList = 1 : totalParamNum;';
                else
                    L{end+1} = sprintf('            paramList = obj.combinations(:, %d)'';', xColumn);
                end
            else
                L{end+1} = '            totalParamNum = 1;';
                L{end+1} = '            paramList = 1;';
            end
            L{end+1} = '        end';
            L{end+1} = '    end';
            L{end+1} = '';

            %% buildSequence
            L{end+1} = '    %% Overridden from Experiment';
            L{end+1} = '    methods';
            L{end+1} = '        function S = buildSequence(obj, idx)';
            L{end+1} = '            % Build the sequence for one sweep point, without';
            L{end+1} = '            % touching hardware. Also used for the live preview.';
            L{end+1} = '            if ~exist(''idx'', ''var''); idx = 1; end';
            L{end+1} = '';
            for i = 1 : numel(spec.variables)
                v = spec.variables(i);
                if ~strcmp(v.binding, UserSequenceSpec.BIND_DURATION)
                    continue    % MW settings are applied in prepare/perform
                end
                column = find(strcmp(swept, v.name), 1);
                if isempty(column)
                    L{end+1} = sprintf('            %s = obj.%s;', v.name, v.name); %#ok<AGROW>
                else
                    L{end+1} = sprintf('            %s = obj.combinations(idx, %d);', ...
                        v.name, column); %#ok<AGROW>
                end
            end
            L{end+1} = '';
            L{end+1} = '            S = Sequence;';
            for i = 1 : numel(spec.pulses)
                p = spec.pulses(i);
                L{end+1} = sprintf('            S.addEvent(%s, %s, ''%s'');', ...
                    p.duration, ...
                    UserSequenceExporter.channelsLiteral(p.channels), ...
                    UserSequenceExporter.escapeQuotes(p.nickname)); %#ok<AGROW>
            end
            L{end+1} = '        end';
            L{end+1} = '    end';
            L{end+1} = '';

            %% prepare / perform / wrapUp
            detectors = spec.detectorPulseIndices();
            L{end+1} = '    methods (Access = protected)';
            L{end+1} = '        function prepare(obj)';
            L{end+1} = sprintf('            obj.detectionPeriodsPerRepeat = %d;', numel(detectors));
            L{end+1} = '            obj.runsPerPerform = 1;';
            L{end+1} = '';
            if hasMw
                L{end+1} = '            obj.applyMwSettings(1);';
            end
            L{end+1} = '            S = obj.buildSequence(1);';
            L{end+1} = '            obj.prepareInternal(S)';
            L{end+1} = '';
            if hasSweep
                L{end+1} = '            [~, paramList] = obj.getTotalNumberOfParams;';
                L{end+1} = '            obj.mCurrentXAxisParam.value = paramList;';
            else
                L{end+1} = '            obj.mCurrentXAxisParam.value = 1;';
            end
            L{end+1} = '        end';
            L{end+1} = '';

            if hasMw
                L{end+1} = '        function applyMwSettings(obj, idx) %#ok<INUSD>';
                L{end+1} = '            sg = getObjByName(SignalGenerator.NAME);';
                L{end+1} = '            if isempty(sg); throwBaseObjException(SignalGenerator.NAME); end';
                for k = mwIdx
                    v = spec.variables(k);
                    what = UserSequenceSpec.mwPropertyFor(v.binding);
                    column = find(strcmp(swept, v.name), 1);
                    if isempty(column)
                        valueExpr = sprintf('obj.%s', v.name);
                    else
                        valueExpr = sprintf('obj.combinations(idx, %d)', column);
                    end
                    L{end+1} = sprintf('            sg.%s = [%s, sg.FGchannelMap(''%s'')];', ...
                        what, valueExpr, v.channel); %#ok<AGROW>
                end
                L{end+1} = '        end';
                L{end+1} = '';
            end

            L{end+1} = '        function perform(obj)';
            L{end+1} = '            pg = getObjByName(PulseGenerator.NAME);';
            L{end+1} = '            spcm = getObjByName(Spcm.NAME);';
            L{end+1} = '            tracker = getObjByName(Tracker.NAME);';
            L{end+1} = '                if isempty(tracker); throwBaseObjException(Tracker.Name); end';
            L{end+1} = '';
            L{end+1} = sprintf('            iSignal = %d;      %% detection window used as signal', spec.signalWindow);
            L{end+1} = sprintf('            iReference = %d;   %% detection window used as reference', spec.referenceWindow);
            L{end+1} = '';
            L{end+1} = '            for t = 1 : obj.getTotalNumberOfParams';
            L{end+1} = '                if obj.currIter <= size(obj.signal, 3) && ...';
            L{end+1} = '                        sum(obj.signal(:, t, obj.currIter)) ~= 0';
            L{end+1} = '                    continue    % Already measured in this average';
            L{end+1} = '                end';
            L{end+1} = '';
            L{end+1} = '                success = false;';
            L{end+1} = '                for trial = 1 : 10';
            L{end+1} = '                    if obj.checkEmergencyStop(); return; end';
            L{end+1} = '                    try';
            if hasMw
                L{end+1} = '                        obj.applyMwSettings(t);';
            end
            L{end+1} = '                        pg.setSequence(obj.buildSequence(t));';
            L{end+1} = '                        pg.repeats = obj.repeats;';
            L{end+1} = '';
            L{end+1} = '                        data = obj.getRawData(pg, spcm);';
            L{end+1} = '                        [sig, sterr] = obj.processData(data);';
            L{end+1} = '';
            L{end+1} = '                        obj.signal(:, t, obj.currIter) = sig;';
            L{end+1} = '                        obj.sterr(:, t, obj.currIter) = sterr;';
            L{end+1} = '';
            L{end+1} = '                        success = true;';
            L{end+1} = '                        obj.currParamIter = obj.currParamIter + 1;';
            L{end+1} = '                        sendEventParamIterationDone(obj);';
            L{end+1} = '';
            L{end+1} = '                        if obj.isTracking';
            L{end+1} = '                            if obj.checkEmergencyStop(); return; end';
            L{end+1} = '                            isTrackingNeeded = tracker.compareReference( ...';
            L{end+1} = '                                sig(iReference), sterr(iReference), ...';
            L{end+1} = '                                Tracker.REFERENCE_TYPE_KCPS, obj.trackThreshhold);';
            L{end+1} = '                            if isTrackingNeeded';
            L{end+1} = '                                tracker.trackUsing(TrackablePosition.NAME)';
            L{end+1} = '                                obj.prepare;';
            L{end+1} = '                            end';
            L{end+1} = '                        end';
            L{end+1} = '';
            L{end+1} = '                        break';
            L{end+1} = '                    catch err';
            L{end+1} = '                        err2warning(err);';
            L{end+1} = '                    end';
            L{end+1} = '                end';
            L{end+1} = '';
            L{end+1} = '                if ~success';
            L{end+1} = '                    obj.sendError(sprintf(''Could not measure point %d after 10 tries.'', t));';
            L{end+1} = '                end';
            L{end+1} = '            end';
            L{end+1} = '';
            L{end+1} = '            nDone = obj.currIter;';
            L{end+1} = '            S1 = squeeze(obj.signal(iSignal, :, 1:nDone));';
            L{end+1} = '            S1sterr = squeeze(obj.sterr(iSignal, :, 1:nDone));';
            L{end+1} = '            S2 = squeeze(obj.signal(iReference, :, 1:nDone));';
            L{end+1} = '            S2sterr = squeeze(obj.sterr(iReference, :, 1:nDone));';
            L{end+1} = '';
            L{end+1} = '            [value, sterr] = getRatioDistributionValues(obj, S1, S2, S1sterr, S2sterr);';
            L{end+1} = '            obj.signalParam.value = value;';
            L{end+1} = '            obj.signalParam.sterr = sterr;';
            L{end+1} = '        end';
            L{end+1} = '';
            L{end+1} = '        function wrapUp(obj)';
            L{end+1} = '            obj.wrapUpInternal()';
            L{end+1} = '        end';
            L{end+1} = '';
            L{end+1} = '        function dataParam = alternateSignal(obj) %#ok<MANU>';
            L{end+1} = '            dataParam = [];';
            L{end+1} = '        end';
            L{end+1} = '    end';
            L{end+1} = 'end';
            L{end+1} = '';

            code = strjoin(L, sprintf('\r\n'));
        end
    end

    %% Literal formatting
    methods (Static)
        function str = numberLiteral(value)
            if isempty(value)
                str = '[]';
            else
                str = sprintf('%.10g', value);
            end
        end

        function str = vectorLiteral(values)
            if isempty(values)
                str = '[]';
                return
            end
            % Prefer the colon form when the vector is regular - it is how a
            % person would have written it, and it survives editing better
            if numel(values) > 2
                steps = diff(values);
                if all(abs(steps - steps(1)) <= 1e-12 * max(abs(values)))
                    str = sprintf('%s : %s : %s', ...
                        UserSequenceExporter.numberLiteral(values(1)), ...
                        UserSequenceExporter.numberLiteral(steps(1)), ...
                        UserSequenceExporter.numberLiteral(values(end)));
                    return
                end
            end
            parts = arrayfun(@UserSequenceExporter.numberLiteral, values, 'UniformOutput', false);
            str = sprintf('[%s]', strjoin(parts, ' '));
        end

        function str = matrixLiteral(values)
            % A combinations table, one row per line so it stays readable
            if isempty(values)
                str = '[]';
                return
            end
            rows = cell(1, size(values, 1));
            for r = 1 : size(values, 1)
                parts = arrayfun(@UserSequenceExporter.numberLiteral, values(r, :), ...
                    'UniformOutput', false);
                rows{r} = strjoin(parts, ' ');
            end
            str = sprintf('[ ...\n                %s]', ...
                strjoin(rows, sprintf('; ...\n                ')));
        end

        function str = channelsLiteral(channels)
            if isempty(channels)
                str = '''''';
                return
            end
            quoted = cellfun(@(c) sprintf('''%s''', UserSequenceExporter.escapeQuotes(c)), ...
                channels, 'UniformOutput', false);
            if numel(quoted) == 1
                str = quoted{1};
            else
                str = sprintf('{%s}', strjoin(quoted, ', '));
            end
        end

        function str = escapeQuotes(str)
            str = strrep(str, '''', '''''');
        end
    end
end
