function [pulses, f, T, coeff, coeffError, fitObj] = rabiFit(Exp, toSave, path, toPlot, expDecayOrder, varargin)
% ofir hacker 31.31.22 (Edited Yachel 18.06.23)
% The function receives an Rabi experiment and returns the fit parameters.
% 'Exp': experiment object
% 'toSave': If to save the fit results
% 'path': Location to save the files
% 'toPlot': If to plot the graph (and to save the ploted graph)
% 'expDecayOrder': The exponential decay order of the Rabi - number between 0.5 to 3. Keep empty or not number to optimize it with the fit.
% 'baseLine': A vector that defines a base line that the Rabi oscilation ride on. Keep empty to not use it.
% 'varargin': An option to define start point to the parameters, Synteax: "f", 3, "a", 0.04, etc. Options: "a", "x0", "f", "T", "c", "q".
% Return:
% pulses: [halfPiTime,piTime,threeHalfPiTime]
% f: Rabi frequency
% T: decay time
% coeff: Vector of all the coefficients: ['a' - amplitude, 'x0' - displacment, 'T' - coherency, 'f' - Rabi frequency, 'c' - center line]
% coeffError: Vector of coefficients standard error (not 95%!)
% fitObj: the original fit object


if ~exist('toSave', 'var')
    toSave = false;
end
if ~exist('path', 'var')
    path = pwd;
end
if ~exist('toPlot', 'var')
    toPlot = 0;
end
if ~exist('expDecayOrder', 'var')
    expDecayOrder = '';
end

% Extract data:
if size(Exp.signal, 1) == 2
    [t, signal, sterr, ~] = extract1Ddata(Exp);
else
    [t, signal, ~, ~, sterr, ~] = extract2Ddata(Exp);
end
signal = reshape(signal,[length(signal) 1]);
sterr = reshape(sterr,[length(sterr) 1]);
t = reshape(t,[length(t) 1]);

i = find(strcmp(varargin, 'baseLine'), 1);
if ~isempty(i)
    baseLine = varargin{i+1};
    varargin(i:i+1) = [];
    baseLine = reshape(baseLine,[length(baseLine) 1]);
    signal = signal - baseLine + 1;
end

t(isnan(signal)) = []; sterr(isnan(signal)) = []; signal(isnan(signal)) = [];

% Calculates start points:
contrast = max(signal) - min(signal);
centerLine = mean(signal);
[pks,locs] = findpeaks(signal, 'MinPeakDistance', 3, 'MinPeakHeight', centerLine);
pks = [signal(1); pks]; locs = [1; locs];
freq = 1 / mean(diff(t(locs)));
pks = pks - centerLine;
i = find(pks/pks(1) < exp(-1), 1, 'first');
if isempty(i); i = length(locs); end
tau = t(locs(i));
displacment = 0;
decayOrder = 1;
throwGlitches = true;
excludeValuesTau = t(1) + [-2 -1];
excludeValuesSignal = [min(signal), max(signal)];

while ~isempty(varargin)
    switch varargin{1}
        case 'a'
            contrast = varargin{2};
        case 'x0'
            displacment = varargin{2};
        case 'T'
            tau = varargin{2};
        case 'f'
            freq = varargin{2};
        case 'c'
            centerLine = varargin{2};
        case 'q'
            decayOrder = varargin{2};
        case 'throwGlitches'
            throwGlitches = varargin{2};
        case 'excludeValuesTau'
            excludeValuesTau = varargin{2};
        case 'excludeValuesSignal'
            excludeValuesSignal = varargin{2};
        otherwise
            error('no field "%s" in rabi fit', varargin{1})
    end
    varargin(1:2) = [];
end

% Fit to Rabi curve:
coefficients = {'a','x0', 'T', 'f', 'c'};
startPoint = [contrast,     displacment,            tau,      freq,     centerLine];
lower =      [0.5*contrast, displacment-freq/2, 0.1*tau,  0.5*freq, 0.7*centerLine];
upper =      [1.5*contrast, displacment+freq/2, 10 *tau,  1.5*freq, 1.3*centerLine];
order = expDecayOrder;
if ~isnumeric(expDecayOrder)
    coefficients = [coefficients(:)', {'q'}];
    startPoint = [startPoint, decayOrder];
    lower =      [lower, 0.3];
    upper =      [upper, 3];
    order = 'q'; 
end
include = ~((excludeValuesTau(1) <= t) & (t <= excludeValuesTau(2)) & (excludeValuesSignal(1) <= signal) & (signal <= excludeValuesSignal(2)));

f = sprintf('a * exp(-(x/T)^%s) * cos(2*pi*f*(x-x0)) + c', num2str(order));
myfittype = fittype(f, 'coefficients', coefficients);
[fitObj, gof, ~] = fit(t(include), signal(include), myfittype, 'Weights', 1./sterr(include).^2, 'StartPoint', startPoint, 'Lower', lower, 'Upper', upper);

if throwGlitches
    dist = abs(signal - fitObj(t));
    include = include & (dist < 4*mean(dist));
    [fitObj, gof, ~] = fit(t(include), signal(include), myfittype, 'Weights', 1./sterr(include).^2, 'StartPoint', startPoint, 'Lower', lower, 'Upper', upper);
end

coeff = coeffvalues(fitObj);
a = coeff(1);
x0 = coeff(2);
T = coeff(3);
f = coeff(4);
halfPiTime = 0.25 * 1/f + x0;
piTime = 0.5 * 1/f + x0;
threeHalvesPiTime = 0.75 * 1/f + x0;
SNR = 2*a / (mean(sterr)*sqrt(Exp.averages*Exp.repeats));
pulses = [halfPiTime, piTime, threeHalvesPiTime];
coeffError = fitStd(fitObj, gof);

% Plot:
if toPlot
    figure; hold on;
    ti = 0:0.001:t(end);
    plot(ti, fitObj(ti), 'color', [0, 0.4470, 0.7410], 'LineWidth', 2);
    errorbar(t, signal, sterr, '.', 'color', 'k', 'MarkerSize', 10);
    errorbar(t(~include), signal(~include), sterr(~include), '.', 'color', 'r', 'MarkerSize', 10);
    dispData = sprintf('$f_{Rabi}=%.2f \\, MHz$ \n$Contrast=%.2f\\%%$ \n$\\mathcal{T}=%.2f\\, \\mu s$ \n$[\\frac{\\pi}{2}, \\pi, \\frac{3\\pi}{2}] = [%.0f,%.0f,%.0f]\\, ns$ \n$SNR/\\sqrt{n}=%.3f$', ...
                       f, 2*a*100, T, halfPiTime*1e3, piTime*1e3, threeHalvesPiTime*1e3, SNR);
    annotation('textbox', [0.76,0.75,0.14,0.17], 'String', dispData, 'Interpreter', 'Latex', 'FontSize', 14, 'BackgroundColor', [1 1 1]);
    set(gca,'FontSize',14);
    grid on
    box on
end

% Save:
if toSave
    format shortg
    fileName = [path,'\RabiFit_', datestr(now,'yyyymmdd_HHMMSS')];
    if toPlot
        savefig([fileName,'.fig']);
        saveas(gcf, [fileName,'.png']);
    end
    save([fileName,'.mat'], 'pulses', 'f', 'T', 'fitObj');
end




