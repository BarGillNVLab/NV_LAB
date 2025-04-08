function [T1, fitObj] = T1Fit(Exp, toSave, path, toPlot, expDecayOrder)
% Yachel 02.24
% The function receives an T1 experiment and returns the fit parameters.
% 'Exp': experiment object
% 'toSave': If to save the fit results
% 'path': Location to save the files
% 'toPlot': If to plot the graph (and to save the ploted graph)
% 'expDecayOrder': The exponential decay order of the Rabi - number between 0.5 to 3. Keep empty or not number to optimize it with the fit. 
% Return:
% T1: T1 time
% fitObj: the fit object


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
[t, signal, ~, ~, sterr] = extract2Ddata(Exp);
signal = reshape(signal,[length(signal) 1]);
sterr = reshape(sterr,[length(sterr) 1]);
t = reshape(t,[length(t) 1]);

% Calculates start points:
contrast = max(signal);
i = find(signal/signal(1) < exp(-1), 1, 'first');
if isempty(i); i = length(signal); end
tau = t(i);

% Fit to T1 curve:
coefficients = {'a','T', 'c'};
startPoint = [contrast,         tau,   0];
lower =      [0.5*contrast, 0.5*tau,  -contrast/10];
upper =      [1.5*contrast, 10 *tau,   contrast/10];
order = expDecayOrder;
if ~isnumeric(expDecayOrder)
    coefficients = [coefficients(:)', {'q'}];
    startPoint = [startPoint, 1];
    lower =      [lower, 0.5];
    upper =      [upper, 3];
    order = 'q'; 
end
f = sprintf('a * exp(-(x/T)^%s) + c', num2str(order));
myfittype = fittype(f, 'coefficients', coefficients);
fitObj = fit(t, signal, myfittype, 'Weights', 1./sterr.^2, 'StartPoint', startPoint, 'Lower', lower, 'Upper', upper);

coeff = coeffvalues(fitObj);
a = coeff(1);
T1 = coeff(2);
SNR = a / (mean(sterr)*sqrt(Exp.averages*Exp.repeats));

% Plot:
if toPlot
    figure; hold on;
    ti = 0:0.001:t(end);
    plot(ti, fitObj(ti), 'color', [0, 0.4470, 0.7410], 'LineWidth', 2);
    errorbar(t, signal, sterr, '.', 'color', 'k', 'MarkerSize', 10);
    dispData = sprintf('$Contrast=%.2f\\%%$ \n$\\mathcal{T}=%.2f\\, \\mu s$ \n$SNR/\\sqrt{n}=%.3f$', a*100, T1, SNR);
%     annotation('textbox', [0.76,0.75,0.14,0.17], 'String', dispData, 'Interpreter', 'Latex', 'FontSize', 14, 'BackgroundColor', [1 1 1]);
    annotation('textbox', [0.46,0.7,0.44,0.22], 'String', dispData, 'Interpreter', 'Latex', 'FontSize', 14, 'BackgroundColor', [1 1 1]);
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
    save([fileName,'.mat'], 'T1', 'fitObj');
end




