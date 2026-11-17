classdef FocusFinder < handle
    % Find focus by stepping one Kinesis stage to maximise SPCM counts.
    %
    %   f = FocusFinder(KinesisStage.get('Z'));
    %   f.stepUm = 1; f.limitKcps = 10; f.maxTravelUm = 50;
    %   result = f.run();
    %
    % Hill climb from the current position. First step goes +; if counts
    % drop, it returns and climbs the other way. It stops on whichever comes
    % first:
    %   'limit'      counts reached limitKcps          -> stays there
    %   'peak'       counts fell below the best reading for `patience` steps
    %                                                  -> goes back to the best position
    %   'saturation' counts stayed flat (within noise) for `patience` steps
    %                                                  -> goes back to the best position
    %   'travel'     moved maxTravelUm from the start without the above
    %                                                  -> goes back to the best position
    %   'stopped'    stop() was called                 -> stays where it is
    %
    % "Same reading" means within max(noiseSigma * standard error, relTol * value).
    % The laser is not touched: switch it on yourself. Stop the GUI's SPCM
    % counter first - both read the same counter.

    properties
        stage                   % KinesisStage
        stepUm = 1              % step size [um]
        limitKcps = 10          % hard limit: stop as soon as counts reach it
        maxTravelUm = 50        % never go further than this from the start
        integrationS = 0.1      % SPCM integration per point [s]
        patience = 3            % consecutive bad/flat steps before deciding
        noiseSigma = 2
        relTol = 0.01
        onPoint = []            % optional callback @(finder) after every reading
        readFcn = []            % optional @() [kcps, sterr] instead of the SPCM (another detector, or a test)
    end

    properties (SetAccess = private)
        history = zeros(0, 3)   % [position mm, kcps, sterr]
        result = struct()
        isRunning = false
    end

    properties (Access = private)
        stopFlag = false
    end

    methods
        function obj = FocusFinder(stage)
            obj.stage = stage;
        end

        function stop(obj)
            obj.stopFlag = true;
        end

        function result = run(obj)
            assert(~obj.isRunning, 'Focus search already running');
            assert(obj.stepUm > 0 && obj.maxTravelUm >= obj.stepUm && obj.limitKcps > 0 ...
                && obj.integrationS > 0, 'Check the focus settings: all must be positive, travel >= step');
            spcm = [];
            if isempty(obj.readFcn); spcm = obj.prepareSpcm(); end
            c = onCleanup(@() obj.finish(spcm));
            obj.isRunning = true;
            obj.stopFlag = false;
            obj.history = zeros(0, 3);

            step = obj.stepUm / 1000;  travel = obj.maxTravelUm / 1000;
            start = obj.stage.position;
            [best, bestPos] = obj.measure(spcm);
            dir = +1; reversed = false; nBad = 0; nFlat = 0; prev = best;
            reason = '';
            if best >= obj.limitKcps; reason = 'limit'; end

            while isempty(reason)
                target = obj.stage.position + dir * step;
                if abs(target - start) > travel + 1e-9
                    reason = 'travel'; break
                end
                obj.stage.moveTo(target);
                [k, ~, tol] = obj.measure(spcm);
                if obj.stopFlag; reason = 'stopped'; break; end
                if k >= obj.limitKcps
                    best = k; bestPos = obj.stage.position; reason = 'limit'; break
                end

                if k > best + tol
                    best = k; bestPos = obj.stage.position; nBad = 0; nFlat = 0;
                elseif k < best - tol
                    nBad = nBad + 1;
                    if ~reversed && size(obj.history, 1) == 2
                        % The very first step made it worse: climb the other way
                        dir = -dir; reversed = true; nBad = 0;
                        obj.stage.moveTo(start);
                    elseif nBad >= obj.patience
                        reason = 'peak';
                    end
                else
                    nFlat = nFlat + (abs(k - prev) <= tol);
                    if nFlat >= obj.patience; reason = 'saturation'; end
                end
                prev = k;
            end

            if any(strcmp(reason, {'peak', 'saturation', 'travel'}))
                obj.stage.moveTo(bestPos);
            end
            result = struct('reason', reason, 'bestKcps', best, 'bestPosition', bestPos, ...
                'startPosition', start, 'finalPosition', obj.stage.position, 'history', obj.history);
            obj.result = result;
        end
    end

    methods (Access = private)
        function spcm = prepareSpcm(obj)
            counter = getObjByName(SpcmCounter.NAME);
            if ~isempty(counter) && isvalid(counter) && counter.isRunning
                error('Stop the SPCM counter first - the focus search needs the same counter.');
            end
            spcm = getObjByName(Spcm.NAME);
            if isempty(spcm); error('No SPCM on this setup'); end
            try; spcm.stopExperimentCount; catch; end   % a previous experiment may hold the task
            spcm.setSPCMEnable(true);
            spcm.prepareReadByTime(obj.integrationS);
        end

        function [kcps, pos, tol] = measure(obj, spcm)
            if isempty(obj.readFcn)
                [kcps, sterr] = spcm.readFromTime();
            else
                [kcps, sterr] = obj.readFcn();
            end
            pos = obj.stage.position;
            tol = max(obj.noiseSigma * sterr, obj.relTol * abs(kcps));
            obj.history(end+1, :) = [pos, kcps, sterr];
            if ~isempty(obj.onPoint); obj.onPoint(obj); end
            drawnow;    % lets a Stop button get through
        end

        function finish(obj, spcm)
            obj.isRunning = false;
            if ~isempty(spcm); try; spcm.clearTimeRead; catch; end; end
        end
    end
end
