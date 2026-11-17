function L = buildCurrentXScan(s)
% The current x X scan with an ESR at every point, as a ScanLoop.
%   s.current_mA  vector of wire currents [mA]
%   s.x_um        vector of X positions [um], relative to X at Start
%   s.zBack_um    Z retract [um] ("back" = smaller Z on this setup, so negative)
%   s.settle_s    wait after Z returns, before the ESR [s]
%   s.order       (optional) 'current-outer' (default): a full X scan per current
%                 'x-outer': at each X position, every current in turn
%
% current-outer, at every point: current, Z back, X to x, Z to its start
%   height, wait, ESR (the current is only re-sent when it changes).
% x-outer: Z back, X, Z down and the settle happen only when x changes; at
%   every point the current is set and the ESR runs, with the stage still.
% After a full run: Z back, X to its start, Z to its start, current 0 A.
% X never moves with Z at the scan height.
%
% Used by scanCurrentX_ESR (the start window). L.run() asks before moving.

assert(~isempty(s.current_mA) && ~isempty(s.x_um), 'The current and X lists must not be empty');
assert(isscalar(s.zBack_um) && s.zBack_um ~= 0, 'Z retract must be a non-zero number of um');

if ~isfield(s, 'order') || isempty(s.order); s.order = 'current-outer'; end

L = ScanLoop();
L.experimentName = 'ESR';
zBack = sprintf('%.12g/1000', s.zBack_um);
switch s.order
    case 'current-outer'
        L.addVariable('I', s.current_mA);
        L.addVariable('x', s.x_um);
        L.addSet('Current', 'I/1000');      % mA -> A
        L.addSet('Z', zBack, true);         % retract, relative to the start height
        L.addSet('X', 'x/1000', true);      % um -> mm, relative to the start
        L.addSet('Z', '0', true);           % back to the start height
        L.addWait(s.settle_s);
    case 'x-outer'
        L.addVariable('x', s.x_um);
        L.addVariable('I', s.current_mA);
        L.addSet('Z', zBack, true, 'x');    % lift / move / lower only when x changes
        L.addSet('X', 'x/1000', true, 'x');
        L.addSet('Z', '0', true, 'x');
        L.addSet('Current', 'I/1000');      % every point
        L.addWait(s.settle_s);
    otherwise
        error('Unknown order "%s" (use current-outer or x-outer)', s.order);
end
L.addExperiment();

% End of a full run: lift Z before X goes home
L.returnAtEnd = false;
L.addFinalSet('Z', zBack, true);
L.addFinalSet('X', '0', true);
L.addFinalSet('Z', '0', true);
L.addFinalSet('Current', '0');
end
