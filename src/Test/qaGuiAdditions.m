function qaGuiAdditions()
%QAGUIADDITIONS Headless regression pass over the GUI additions
%   Exercises every layer that does not need instruments: the expression
%   parser, the sequence model, persistence and format migration, the
%   Exp*.m exporter, the helper catalog, the parameter table, the MW
%   indicator logic, the lane renderer, and the rendering of every view.
%
%   Run it after touching any of them:
%
%       cd <...>\src; PathHelper.addSourceFoldersToPath(); qaGuiAdditions
%
%   Needs the GUI Layout Toolbox on the path (it is, via the Add-On
%   manager) - restoredefaultpath removes it and every view will fail.
%
%   Nothing here talks to hardware, so a clean run does not mean a
%   measurement will work; it means nothing is broken before you try.

fprintf('\n================ QA: NV_LAB GUI additions ================\n');
state = struct('pass', 0, 'fail', 0, 'names', {{}});

%% ---------- 1. paths and class loading ----------
section('Paths and class loading');
names = {'ExpGuiParam','SequenceExpression','UserSequenceSpec','UserSequenceExporter', ...
    'ExpUserSequence','HelperFunctionCatalog','GuiSessionState','SequenceLanes', ...
    'ViewMainExperiment','GuiControllerMainExp','ViewExperimentColumn','ViewExperimentSelector', ...
    'ViewExperimentParams','ViewExperimentSequence','ViewExperimentResult', ...
    'ViewExperimentRunControl','ViewHelperFunctions','ViewSequenceBuilder', ...
    'GuiControllerSequenceBuilder','ViewMwChannel','ViewMwContainer'};
for i = 1:numel(names)
    state = check(state, sprintf('%s loads', names{i}), ~isempty(meta.class.fromName(names{i})));
end

%% ---------- 2. expression evaluator ----------
section('Expression evaluator');
v = struct('tau', 1.5, 'piTime', 0.04, 'n', 3);
good = {'3',3; 'tau',1.5; '2*tau',3; 'tau/2',0.75; '(tau+0.1)*2',3.2; '-tau',-1.5; ...
    '2^n',8; '1e-3',1e-3; '.5*tau',0.75; '2^3^2',512; '- -tau',1.5};
for i = 1:size(good,1)
    [val, ok] = SequenceExpression.evaluate(good{i,1}, v);
    state = check(state, sprintf('eval %s', good{i,1}), ok && abs(val-good{i,2}) < 1e-12);
end
bad = {'','tau +','2*','(tau','tau)','system(''calc'')','exp.run','x','tau/0','1,2','tau!','#'};
for i = 1:numel(bad)
    [~, ok] = SequenceExpression.evaluate(bad{i}, v);
    state = check(state, sprintf('reject [%s]', bad{i}), ~ok);
end

%% ---------- 3. sequence spec ----------
section('Sequence spec');
s = exampleSpec();
[ok, msg] = s.validate();
state = check(state, 'example spec validates', ok, msg);
state = check(state, 'detector windows found', isequal(s.detectorPulseIndices(), [6 8]));
S1 = s.buildSequence(1);
state = check(state, 'builds at point 1', abs(S1.duration - 2.9) < 1e-9);
s.setVariable('mwFreq', 2870, UserSequenceSpec.BIND_FREQUENCY, 'MW');
s.setSwept({'mwFreq','tau'});
state = check(state, 'setSwept keeps both declared names', numel(s.sweptNames) == 2);
s.fillGrid({[2860 2870 2880], [0.5 1.5]});
state = check(state, 'grid 3x2 = 6 points', s.numberOfParams() == 6);
state = check(state, 'first column slowest', isequal(s.combinations(:,1)', [2860 2860 2870 2870 2880 2880]));
state = check(state, 'second column fastest', isequal(s.combinations(:,2)', [0.5 1.5 0.5 1.5 0.5 1.5]));
state = check(state, 'independent lengths (1x5)', ...
    begetPoints(s, {[2870], 0.1:0.1:0.5}) == 5);
s.fillGrid({[2860 2870 2880], [0.5 1.5]});
state = check(state, 'duration tracks the point', ...
    abs(s.buildSequence(2).duration - s.buildSequence(1).duration - 2) < 1e-9);
mw = s.mwSettings(5);
state = check(state, 'MW setting follows the row', ...
    numel(mw)==1 && strcmp(mw.what,'frequency') && mw.value==2880 && strcmp(mw.channel,'MW'));
vars = s.variableStruct(1);
state = check(state, 'expressions see only durations', ...
    isfield(vars,'tau') && isfield(vars,'piTime') && ~isfield(vars,'mwFreq'));

% failure modes
bad = exampleSpec(); bad.pulses(8).channels = {'greenLaser'};
[ok, msg] = bad.validate();
state = check(state, 'one detector window rejected', ~ok && contains(msg,'detection window'));
bad = exampleSpec(); bad.referenceWindow = 1;
[ok, msg] = bad.validate();
state = check(state, 'same signal/reference rejected', ~ok && contains(msg,'cannot be the same'));
bad = exampleSpec(); bad.pulses(2).duration = 'nope';
[ok, msg] = bad.validate();
state = check(state, 'unknown variable rejected', ~ok && contains(msg,'not a declared variable'));
bad = exampleSpec(); bad.addPulse('d3','0.3',{'detector'});
[ok, msg] = bad.validate();
state = check(state, 'odd window count rejected', ~ok && contains(msg,'even number'));
bad = exampleSpec(); bad.variables(1).name = '2bad';
[ok, msg] = bad.validate();
state = check(state, 'invalid variable name rejected', ~ok && contains(msg,'not a usable variable name'));

%% ---------- 4. persistence and migration ----------
section('Persistence');
tmp = fullfile(tempdir, ['qa' UserSequenceSpec.FILE_SUFFIX]);
s.save(tmp);
r = UserSequenceSpec.load(tmp);
state = check(state, 'round trip: combinations', isequal(r.combinations, s.combinations));
state = check(state, 'round trip: swept names', isequal(r.sweptNames, s.sweptNames));
state = check(state, 'round trip: bindings', ...
    strcmp(r.variables(r.variableIndex('mwFreq')).binding, UserSequenceSpec.BIND_FREQUENCY));
state = check(state, 'round trip: mw channel', ...
    strcmp(r.variables(r.variableIndex('mwFreq')).channel, 'MW'));
state = check(state, 'round trip: rebuilds identically', ...
    abs(r.buildSequence(3).duration - s.buildSequence(3).duration) < 1e-12);
delete(tmp);

v1 = struct('formatVersion',1,'name','OldOne', ...
    'pulses',{{struct('nickname','a','duration','tau','channels',{{'MW'}}), ...
               struct('nickname','d1','duration','0.3','channels',{{'detector'}}), ...
               struct('nickname','d2','duration','0.3','channels',{{'detector'}})}}, ...
    'variables',{{struct('name','tau','value',1)}}, ...
    'sweepName','tau','sweepValues',[0.1 0.2 0.3],'signalWindow',1,'referenceWindow',2);
old = fullfile(tempdir, ['qav1' UserSequenceSpec.FILE_SUFFIX]);
fid = fopen(old,'w'); fwrite(fid, jsonencode(v1), 'char'); fclose(fid);
m = UserSequenceSpec.load(old);
state = check(state, 'v1 migrates: swept', isequal(m.sweptNames, {'tau'}));
state = check(state, 'v1 migrates: points', isequal(m.combinations', [0.1 0.2 0.3]));
state = check(state, 'v1 migrates: binding defaults', ...
    strcmp(m.variables(1).binding, UserSequenceSpec.BIND_DURATION));
state = check(state, 'v1 migrates: validates', m.validate());
delete(old);
state = check(state, 'missing session file is empty', isempty(fieldnames(GuiSessionState.load())));

%% ---------- 5. exporter ----------
section('Exporter');
out = fullfile(tempdir, 'qa_export'); if ~exist(out,'dir'); mkdir(out); end
addpath(out);
for variant = {'plain', 'mixed'}
    spec = exampleSpec();
    spec.name = ['QA' upper(variant{1}(1)) variant{1}(2:end)];
    if strcmp(variant{1}, 'mixed')
        spec.setVariable('mwFreq', 2870, UserSequenceSpec.BIND_FREQUENCY, 'MW');
        spec.setSwept({'mwFreq','tau'});
        spec.fillGrid({[2860 2880], [0.5 1.5]});
    end
    target = fullfile(out, ['Exp' spec.name '.m']);
    if exist(target,'file'); delete(target); end
    [~, ok, msg] = UserSequenceExporter.export(spec, target);
    state = check(state, sprintf('export %s', variant{1}), ok, msg);
    if ~ok; continue; end
    errs = parseErrors(target);
    state = check(state, sprintf('%s generated file parses', variant{1}), isempty(errs), strjoin(errs, '; '));
    rehash path;
    mc = meta.class.fromName(['Exp' spec.name]);
    state = check(state, sprintf('%s generated class loads', variant{1}), ~isempty(mc));
    text = fileread(target);
    if strcmp(variant{1}, 'mixed')
        state = check(state, 'mixed emits applyMwSettings', contains(text, 'function applyMwSettings'));
        state = check(state, 'mixed indexes combinations', contains(text, 'obj.combinations(idx,'));
    else
        state = check(state, 'plain emits no MW code', ~contains(text, 'applyMwSettings'));
    end
    state = check(state, sprintf('%s refuses to overwrite', variant{1}), ...
        ~nth(2, @() UserSequenceExporter.export(spec, target)));
end

%% ---------- 6. helper catalog ----------
section('Helper catalog');
e = HelperFunctionCatalog.discover();
state = check(state, 'helpers discovered', numel(e) >= 30);
state = check(state, 'no absolute paths in groups', ~any(contains({e.group}, ':')));
i = find(strcmp({e.name},'ESRfit'),1);
state = check(state, 'ESRfit signature parsed', ~isempty(i) && ...
    isequal(e(i).inputs, {'Exp','toSave','path','toPlot'}));
state = check(state, 'scripts detected', sum([e.isScript]) == 4);
state = check(state, 'exp default', strcmp(HelperFunctionCatalog.defaultFor('Exp'), HelperFunctionCatalog.TOKEN_EXPERIMENT));
state = check(state, 'toSave default false', strcmp(HelperFunctionCatalog.defaultFor('toSave'), 'false'));
[~, ok] = HelperFunctionCatalog.resolveArguments({'5','','true'}, []);
state = check(state, 'argument gap refused', ~ok);
[a, ok] = HelperFunctionCatalog.resolveArguments({'5','',''}, []);
state = check(state, 'trailing blanks dropped', ok && numel(a)==1);
[~, ok] = HelperFunctionCatalog.parseValue('nosuchvariable', []);
state = check(state, 'unknown name refused', ~ok);
entry = e(find(strcmp({e.name},'round2significant'),1));
[outs, outNames, err] = HelperFunctionCatalog.run(entry, {3.14159, 0.0123});
state = check(state, 'helper runs', isempty(err) && numel(outs)==2, err);
state = check(state, 'helper outputs named', isequal(outNames, {'value','err'}));

%% ---------- 7. parameter specs ----------
section('Parameter table');
cases = {'2870','double',2870; '2770 : 2 : 2774','vector',[2770 2772 2774]; ...
    '[1 2 3]','vector',[1 2 3]; 'true','logical',true; 'off','logical',false};
for i = 1:size(cases,1)
    [val, ok] = ExpGuiParam.stringToValue(cases{i,1}, cases{i,2});
    state = check(state, sprintf('parse %s', cases{i,1}), ok && isequal(val, cases{i,3}));
end
[~, ok] = ExpGuiParam.stringToValue('banana','double');
state = check(state, 'reject non-numeric', ~ok);
state = check(state, 'vector compaction', strcmp(ExpGuiParam.valueToString(2770:2:2790), '2770 : 2 : 2790'));
state = check(state, 'small tau survives', strcmp(ExpGuiParam.valueToString(0.001), '0.001'));
state = check(state, 'prettify', strcmp(ExpGuiParam.prettify('referenceDetectionDuration'), 'Reference Detection Duration'));

%% ---------- 8. MW indicator ----------
section('MW indicator');
expect = {false,1,1,'OFF'; false,2,1,'OFF'; true,1,1,'ARMED'; true,2,1,'ON - CW'; ...
    true,3,1,'ON - pulsed 1%'; true,3,50,'ON - pulsed 50%'; true,3,NaN,'ON - pulsed'};
for i = 1:size(expect,1)
    txt = ViewMwChannel.stateFor(expect{i,1}, expect{i,2}, expect{i,3});
    state = check(state, sprintf('state %s', expect{i,4}), strcmp(txt, expect{i,4}), txt);
end
cols = [ViewMwChannel.COLOUR_OFF; ViewMwChannel.COLOUR_ARMED; ViewMwChannel.COLOUR_CW; ViewMwChannel.COLOUR_PULSED];
state = check(state, 'indicator colours distinct', size(unique(cols,'rows'),1)==4);

%% ---------- 9. lane renderer ----------
section('Lane renderer');
S = Sequence;
S.addEvent(0, '', 'smallDelay');  S.addEvent(10, 'MW', 'MW');
S.addEvent(0, '', 'smallDelay2'); S.addEvent(0.1, '', 'lastDelay');
S.addEvent(0.25, {'greenLaser','detector'}, 'detection');
S.addEvent(9.75, 'greenLaser', 'init');
S.addEvent(5, {'greenLaser','detector'}, 'reference');
f = figure('Visible','off'); ax = axes('Parent', f);
blocks = SequenceLanes.draw(ax, S);
state = check(state, 'blocks drawn', numel(blocks) == 4);
pats = findobj(ax,'Type','patch');
rect = arrayfun(@(h) numel(unique(round(h.Vertices(:,1),9)))==2 && abs(h.Vertices(1,2)-h.Vertices(2,2))<1e-9, pats);
state = check(state, 'all patches rectangular', all(rect));
txt = findobj(ax,'Type','text');
state = check(state, 'labels suppressed on collision', numel(txt) < 7);
state = check(state, 'labels not TeX', all(strcmp({txt.Interpreter},'none')));
state = check(state, 'tick labels not TeX', strcmp(ax.TickLabelInterpreter,'none'));
state = check(state, 'lanes in order', isequal(cellstr(ax.YTickLabel)', {'greenLaser','detector','MW'}));
close(f);
Sempty = Sequence;
f = figure('Visible','off'); ax = axes('Parent', f);
state = check(state, 'empty sequence survives', isempty(SequenceLanes.draw(ax, Sempty)));
close(f);

%% ---------- 10. views render ----------
section('Views render');
state = renderCheck(state, 'sequence builder', @() GuiControllerSequenceBuilder());
if ~isempty(which('TestColumnGui'))
    state = renderCheck(state, 'experiment column', @() TestColumnGui());
end
if ~isempty(which('TestHelperGui'))
    state = renderCheck(state, 'helper panel', @() TestHelperGui());
end

% builder internals
c = GuiControllerSequenceBuilder(); c.start(); fg = c.figureWindow;
ax = findobj(fg,'Type','axes'); ax = ax(1);
pats = findobj(ax,'Type','patch');
grab = pats(arrayfun(@(h) ~isempty(h.ButtonDownFcn), pats));
state = check(state, 'builder preview drew', numel(pats) > 0);
state = check(state, 'blocks grabbable', numel(grab) > 0);
state = check(state, 'lane backgrounds not grabbable', numel(grab) < numel(pats));
spec = c.spec;
tagged = arrayfun(@(h) h.UserData, grab);
state = check(state, 'tags are valid pulse indices', all(tagged >= 1 & tagged <= numel(spec.pulses)));
% expression-driven block refuses the drag and leaves callbacks alone
h = grab(arrayfun(@(g) isnan(str2double(spec.pulses(g.UserData).duration)), grab));
if ~isempty(h)
    before = spec.pulses(h(1).UserData).duration;
    feval(h(1).ButtonDownFcn, h(1), []);
    state = check(state, 'expression pulse refuses drag', ...
        strcmp(before, spec.pulses(h(1).UserData).duration));
    state = check(state, 'figure callbacks not hijacked', isempty(fg.WindowButtonMotionFcn));
end
tabs = findobj(fg,'Type','uitable');
state = check(state, 'three tables present', numel(tabs) == 3);
state = check(state, 'points header is plain text', ~any(contains(tabs(end-2).ColumnName, '\')));
close(fg);

% the column's tabbed sequence/results
if isempty(which('TestColumnGui'))
    disp('  skip  column internals (TestColumnGui harness not on the path)');
else
c = TestColumnGui(); c.start(); fg = c.figureWindow;
tp = findall(fg,'-property','TabTitles');
state = check(state, 'sequence/results tabs', ~isempty(tp) && isequal(tp(1).TabTitles', {'Sequence','Results'}));
pops = findobj(fg,'Style','popupmenu');
modePop = [];
for hh = pops'
    if iscell(hh.String) && any(strcmp(hh.String,'Sequence builder')); modePop = hh; end
end
state = check(state, 'three modes', ~isempty(modePop) && numel(modePop.String)==3);
if ~isempty(modePop)
    okAll = true;
    for m = 1:3
        modePop.Value = m;
        try; feval(modePop.Callback, modePop, []); catch; okAll = false; end
    end
    state = check(state, 'all modes switch', okAll);
end
close(fg);
end
state = check(state, 'workspace name mangling', ...
    strcmp(ViewExperimentColumn.workspaceNameFor('ESR'),'esr') && ...
    strcmp(ViewExperimentColumn.workspaceNameFor('T1'),'t1') && ...
    isvarname(ViewExperimentColumn.workspaceNameFor('2DESR')));

%% ---------- 11. ExpUserSequence structure ----------
section('ExpUserSequence');
mc = meta.class.fromName('ExpUserSequence');
props = {mc.PropertyList.Name};
for want = {'frequency','amplitude','phase','spec'}
    state = check(state, sprintf('has %s (prepareInternal needs it)', want{1}), any(strcmp(props, want{1})));
end
mnames = {mc.MethodList.Name};
for want = {'buildSequence','getTotalNumberOfParams','resultsTable','setSpec'}
    state = check(state, sprintf('has %s', want{1}), any(strcmp(mnames, want{1})));
end
i = find(strcmp(mnames,'buildSequence'),1);
state = check(state, 'buildSequence is public', strcmp(mc.MethodList(i).Access,'public'));
for want = {'prepare','perform','wrapUp','alternateSignal'}
    j = find(strcmp(mnames, want{1}),1);
    state = check(state, sprintf('%s is protected', want{1}), ...
        ~isempty(j) && strcmp(mc.MethodList(j).Access,'protected'));
end

%% ---------- 12. refactored experiments ----------
section('Refactored experiments');
for n = {'ExpESR','ExpRabi','ExpEcho','ExpT1','ExpRamsey','ExpDEER'}
    mc = meta.class.fromName(n{1});
    idx = find(strcmp({mc.MethodList.Name},'buildSequence'),1);
    state = check(state, sprintf('%s has public buildSequence', n{1}), ...
        ~isempty(idx) && strcmp(mc.MethodList(idx).Access,'public') && ...
        strcmp(mc.MethodList(idx).DefiningClass.Name, n{1}));
end
nm = Experiment.getExperimentNames();
state = check(state, 'experiment discovery works', numel(nm(~cellfun(@isempty,nm))) > 90);
state = check(state, 'experiment path resolves', exist(Experiment.PATH_ALL_EXPERIMENTS,'dir')==7);

%% ---------- summary ----------
fprintf('\n=========================================================\n');
fprintf('  %d passed, %d FAILED\n', state.pass, state.fail);
if state.fail > 0
    fprintf('\n  failures:\n');
    fprintf('    - %s\n', state.names{:});
end
fprintf('=========================================================\n\n');
end

%% ---------------- helpers ----------------
function section(name)
fprintf('\n-- %s --\n', name);
end

function state = check(state, name, condition, detail)
if nargin < 4; detail = ''; end
if condition
    state.pass = state.pass + 1;
    fprintf('  ok    %s\n', name);
else
    state.fail = state.fail + 1;
    state.names{end+1} = name;
    if isempty(detail)
        fprintf('  FAIL  %s\n', name);
    else
        fprintf('  FAIL  %s  (%s)\n', name, detail);
    end
end
end

function state = renderCheck(state, name, factory)
try
    c = factory();
    c.start();
    f = c.figureWindow;
    okNow = ~isempty(f) && isvalid(f);
    close(f);
    state = check(state, sprintf('%s renders', name), okNow);
catch err
    state = check(state, sprintf('%s renders', name), false, err.message);
end
end

function errs = parseErrors(file)
errs = {};
r = checkcode(file, '-struct');
for j = 1:numel(r)
    if contains(r(j).message,'Parse error') || contains(r(j).message,'not terminated')
        errs{end+1} = sprintf('L%d %s', r(j).line, r(j).message); %#ok<AGROW>
    end
end
end

function n = begetPoints(s, ranges)
s.fillGrid(ranges);
n = s.numberOfParams();
end

function out = nth(k, fcn)
c = cell(1, k);
[c{:}] = fcn();
out = c{k};
end

function spec = exampleSpec()
spec = UserSequenceSpec();
spec.name = 'QaSeq';
spec.setVariable('tau', 1);
spec.setVariable('piTime', 0.05);
spec.addPulse('pi_half', 'piTime/2', {'MW'});
spec.addPulse('tau1',    'tau',      {});
spec.addPulse('pi',      'piTime',   {'MW'});
spec.addPulse('tau2',    'tau',      {});
spec.addPulse('readout', 'piTime/2', {'MW'});
spec.addPulse('detect',  '0.3',      {'greenLaser','detector'});
spec.addPulse('init',    '2',        {'greenLaser'});
spec.addPulse('ref',     '0.3',      {'greenLaser','detector'});
spec.setSwept({'tau'});
spec.combinations = (0.1:0.1:2)';
spec.xAxisName = 'tau';
spec.signalWindow = 1;
spec.referenceWindow = 2;
end
