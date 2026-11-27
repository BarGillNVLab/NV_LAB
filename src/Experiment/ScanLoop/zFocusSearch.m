function r = zFocusSearch(moveTo, readCounts, z0, o)
%ZFOCUSSEARCH Step Z to the best count rate, then settle on it from below
%   r = zFocusSearch(moveTo, readCounts, z0, o)
%   moveTo(z)      move Z to z [mm] and wait until it is there
%   readCounts()   -> [kcps, sterr, std], one reading (e.g. 1 s of SPCM counts
%                  as 10 sub-reads: their mean, its standard error, and the
%                  standard deviation between them)
%   z0             where Z is now [mm] - reached coming from below (smaller Z)
%   o              options (missing fields take the defaults below):
%     stepUm = 3       step [um]
%     maxTravelUm = 30 never further than this from z0, either way [um]
%     backlashUm = 10  the final approach comes up from this far below [um]
%     stdWeight = 1    each reading is scored as  kcps - stdWeight * std :
%                      the best spot has many counts AND steady ones (0: counts only)
%     noiseSigma = 2   "bigger" = a score above the best so far by this many
%                      standard errors of the difference (0: any increase)
%     stopFcn = @() false   checked before every move; true -> stop, stay put
%
%   1. Read at z0. Step +step and read; while the score is bigger than the
%      best so far, keep stepping +.
%   2. If the very first + step was not bigger, try the other way from z0:
%      -step, and keep stepping - while it gets bigger.
%   3. Go to best - backlash, then up to best (the stage has backlash and a
%      repeatability spec, so it always arrives from the same side), and read
%      again to confirm. If that score is clearly lower than the best, the
%      approach is repeated once more.
%
%   r: bestZ, bestKcps, bestStd, bestScore, verifyKcps, verifyStd, finalZ,
%   shiftUm (best - z0), reason ('peak' | 'travel' | 'stopped'), direction
%   (+1 / -1 / 0 = none better), history [z kcps sterr std score] for every
%   reading (verify readings included).

D = struct('stepUm', 3, 'maxTravelUm', 30, 'backlashUm', 10, 'stdWeight', 1, 'noiseSigma', 2, 'stopFcn', @() false);
if nargin < 4 || isempty(o); o = struct(); end
for f = fieldnames(D)'
    if ~isfield(o, f{1}) || isempty(o.(f{1})); o.(f{1}) = D.(f{1}); end
end
assert(o.stepUm > 0 && o.maxTravelUm >= o.stepUm && o.backlashUm >= 0, ...
    'Focus search: step > 0, max travel >= step and backlash >= 0');

step = o.stepUm / 1000; lim = o.maxTravelUm / 1000; back = o.backlashUm / 1000;
history = zeros(0, 5);
r = struct('bestZ', z0, 'bestKcps', NaN, 'bestStd', NaN, 'bestScore', NaN, 'verifyKcps', NaN, ...
    'verifyStd', NaN, 'finalZ', z0, 'shiftUm', 0, ...
    'reason', 'peak', 'direction', 0, 'history', history);

[best, bestErr, bestRow] = read(z0);
bestZ = z0;
for dir = [+1, -1]
    z = z0;
    while true
        zt = z + dir * step;
        if abs(zt - z0) > lim + 1e-9; r.reason = 'travel'; break; end
        if o.stopFcn(); r.reason = 'stopped'; return_(); return; end
        moveTo(zt);
        [k, kErr, row] = read(zt);
        if ~isBigger(k, kErr, best, bestErr); break; end
        best = k; bestErr = kErr; bestRow = row; bestZ = zt; z = zt;
        r.direction = dir;
    end
    if r.direction ~= 0; break; end     % this side was better: do not try the other one
    r.reason = 'peak';                  % a 'travel' on the + side does not end the search
end

% Settle on the best spot, always coming up from below
for attempt = 1:2
    if o.stopFcn(); r.reason = 'stopped'; break; end
    if back > 0; moveTo(bestZ - back); end
    moveTo(bestZ);
    [v, vErr, vRow] = read(bestZ);
    r.verifyKcps = vRow(2); r.verifyStd = vRow(4);
    if ~isBigger(best, bestErr, v, vErr); break; end   % confirmed (within the noise)
end
return_();

    function [score, e, row] = read(z)
        % The score, its standard error, and the history row. A std from
        % n samples is itself uncertain by ~std/sqrt(2(n-1)) ~ 0.75 x the
        % standard error of the mean (n = 10), so score error ~ e*sqrt(1 + w^2/2).
        [k, e, sd] = readCounts();
        score = k - o.stdWeight * sd;
        e = e * sqrt(1 + o.stdWeight^2 / 2);
        row = [z, k, e, sd, score];
        history(end+1, :) = row;
    end

    function tf = isBigger(a, aErr, b, bErr)
        tf = a > b + o.noiseSigma * hypot(aErr, bErr);
    end

    function return_()
        r.bestZ = bestZ; r.bestScore = best; r.history = history;
        r.bestKcps = bestRow(2); r.bestStd = bestRow(4);
        r.shiftUm = (bestZ - z0) * 1000;
        if size(history, 1) > 0; r.finalZ = history(end, 1); end
    end
end
