function [T2, coeff, coeffError, fitObj] = EchoFit(Exp, toSave, path, toPlot, expDecayOrder, varargin)
% Amir Abramovich 11.07.23 (Edited Yachel 18.06.23)
% The function receives an Echo experiment and returns the T2 time and fit object
% 'Exp': experiment object
% 'toSave': If to save the fit results
% 'path': Location to save the files
% 'toPlot': If to plot the graph (and to save the ploted graph)
% 'expDecayOrder': The exponential decay order of the Echo - number between 0.5 to 3. Keep empty or not number to optimize it with the fit. 
% 'varargin': An option to define start point to the parameters, Synteax: "T", 500, "a", 0.04, etc. Options: 'a','x0', 'T' ,'g_m', 'c'.

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
[t, signal, ~, ~, sterr, ~, ~, ~] = extract2Ddata(Exp);
signal = reshape(signal,[length(signal) 1]);
sterr = reshape(sterr,[length(sterr) 1]);
t = reshape(t,[length(t) 1]);
if abs(signal(2)/signal(1)) > 2;  signal = signal(2:end);  sterr = sterr(2:end);  t = t(2:end); end

% Calculates start points:
contrast = max(signal) - min(signal);
meanLine = mean(signal);
[pks,locs] = findpeaks(signal, 'MinPeakDistance', 10, 'MinPeakHeight', meanLine, 'MinPeakWidth', 4);
pks = [signal(1); pks]; locs = [1; locs];
i = find(pks/pks(1) < exp(-1), 1, 'first');
if isempty(i); i = length(locs); end
T2_approx = t(locs(i));
displacment = 0;
baseLine = 0;
decayOrder = 1;

% Calculates the mean width of the Lorenzian
[~,locs_max] = findpeaks(diff(signal), 'MinPeakDistance', 8, 'MinPeakHeight', 0);
[~,locs_min] = findpeaks(-diff(signal), 'MinPeakDistance', 8, 'MinPeakHeight', 0);
mean_std = mean(t(locs_min(2:i)) - t(locs_max(1:i-1))) / 2;
if isnan(mean_std); mean_std = 10; end

% Calculates the diffrences between peaks
B0 = (2870 - Exp.frequency) / 2.8;
f_C13 = B0 * 10.7084*1e-4;
dT = 2/f_C13;

while ~isempty(varargin)
    switch varargin{1}
        case 'a'
            contrast = varargin{2};
        case 'x0'
            displacment = varargin{2};
        case 'T'
            T2_approx = varargin{2};
        case 'g_m'
            mean_std = varargin{2};
        case 'c'
            baseLine = varargin{2};
        case 'q'
            decayOrder = varargin{2};
        otherwise
            error('no field "%s" in rabi fit', varargin{1})
    end
    varargin(1:2) = [];
end


% Fit to Echo curve:
coefficients = {'a','x0', 'T' ,'g_m', 'c'};
startPoint = [contrast,     displacment,          T2_approx,  abs(    mean_std),  baseLine];
lower =      [0.5*contrast, displacment-dT/2, 0.5*T2_approx,  abs(0.5*mean_std),  baseLine-contrast/10];
upper =      [1.5*contrast, displacment+dT/2, 5  *T2_approx,  abs(3  *mean_std),  baseLine+contrast/10];
order = expDecayOrder;

if ~isnumeric(expDecayOrder)
    coefficients = [coefficients(:)', {'q'}];
    startPoint = [startPoint, decayOrder];
    lower =      [lower, 0.5];
    upper =      [upper, 3];
    order = 'q'; 
end

f = sprintf('c + a * exp(-(((x-x0)/T)^%s)) * (0', num2str(order));
for m = 0:floor(t(end)/dT)
    f = [f sprintf(' + exp(-(((x-x0-%s)/g_m)^2))', num2str(m*dT))];
end
f = [f ')'];
myfittype = fittype(f, 'coefficients', coefficients);
[fitObj, gof, ~] = fit(t, signal, myfittype, 'Weights', 1./sterr.^2, 'StartPoint', startPoint, 'Lower', lower, 'Upper', upper);

coeff = coeffvalues(fitObj);
coeffError = fitStd(fitObj, gof);
a = coeff(1); x0 = coeff(2); T2 = coeff(3); g_m = coeff(4); c = coeff(5); dT = coeffError(3);
if ~isnumeric(expDecayOrder)
    order = coeff(6);
else
    order = expDecayOrder;
end
SNR = a / (mean(sterr) * sqrt(Exp.averages*Exp.repeats));


% Plot:
if toPlot
    figure; hold on;
    ti = 0:0.001:t(end);
    plot(ti, fitObj(ti), 'color', [0, 0.4470, 0.7410], 'LineWidth', 2); hold on;
    plot(ti, real(c + a * exp(-(((ti-x0)/T2).^order))), 'LineWidth', 2);
    errorbar(t, signal, sterr, '.', 'color', 'k', 'MarkerSize', 10);
    dispData = sprintf('\n$Contrast=%.2f\\%%$ \n$\\mathcal{T}_2=%.1f \\pm %.1f\\, \\mu s$ \n$SNR/\\sqrt{n}=%.3f$', a*100, T2, dT, SNR);
    annotation('textbox', [0.46,0.65,0.44,0.27], 'String', dispData, 'Interpreter', 'Latex', 'FontSize', 14, 'BackgroundColor', [1 1 1]);
    set(gca,'FontSize',14);
    grid on
    box on
end

% Save:
if toSave
    format shortg
    fileName = [path,'\EchoFit_', datestr(now,'yyyymmdd_HHMMSS')];
    if toPlot
        savefig([fileName,'.fig']);
        saveas(gcf, [fileName,'.png']);
    end
    save([fileName,'.mat'], 'T2', 'g_m', 'fitObj');
end




