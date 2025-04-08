function [f0, width, contrast, SNR, coeffError, fitObj] = ESRfit(Exp, toSave, path, toPlot)
% ofir hacker 31.31.22 (Edited Yachel 18.06.23)
% The function receives an ESR experiment and returns the center frequency, width, contrast and fit object.
% In case of mirrored frequency all of the output variable are vectors [1, 2]
% Working now for single resonance
% 'Exp': experiment object
% 'toSave': If to save the fit results
% 'path': Location to save the files
% 'toPlot': If to plot the graph (and to save the ploted graph)
% 'expDecayOrder': The exponential decay order of the Rabi - number between 0.5 to 3. Keep empty or not number to optimize it with the fit. 
% coefficient order: [contrast, dc, frequency, width]

if ~exist('toSave', 'var')
    toSave = false;
end
if ~exist('path', 'var')
    path = pwd;
end
if ~exist('toPlot', 'var')
    toPlot = 0;
end
mirrored = ~isempty(Exp.mirrorSweepAround);

% Extract data:
[freq, signal, sterr, signal_2, sterr_2] = extractESRdata(Exp);
signal = reshape(signal,[length(signal) 1]);
sterr = reshape(sterr,[length(sterr) 1]);
signal_2 = reshape(signal_2,[length(signal_2) 1]);
sterr_2 = reshape(sterr_2,[length(sterr_2) 1]);
freq = reshape(freq,[length(freq) 1]);

% Fit:
[fitObj, gof] = ESRfitInternal(freq, signal, sterr);
coeff = coeffvalues(fitObj);
contrast = coeff(1);
f0 = coeff(2);
width = 2 * coeff(3);
SNR = contrast / (mean(sterr)*sqrt(Exp.averages*Exp.repeats));

if mirrored
    fitObj2 = ESRfitInternal(freq, signal_2, sterr_2);
    coeff = coeffvalues(fitObj2);
    contrast(2) = coeff(1);
    f0(2) = coeff(2);
    width(2) = 2 * coeff(3);
    SNR(2) = contrast(2) / (mean(sterr_2)*sqrt(Exp.averages*Exp.repeats));
end

coeffError = fitStd(fitObj, gof);

% Plot:
if toPlot
    figure; hold on;
    fi = freq(1):0.01:freq(end);
    fitLine = plot(fi, fitObj(fi), 'color', [0, 0.4470, 0.7410], 'LineWidth', 2, 'DisplayName', 'Normal');
    dataPoints = errorbar(freq, signal, sterr, '.', 'color', 'b', 'MarkerSize', 7);
    dispData = sprintf('$f_0=%.1f \\, MHz$ \n$Contrast=%.2f\\%%$ \n$FWHM(2\\gamma)=%.2f\\, MHz$ \n$SNR/\\sqrt{n}=%.3f$', f0, contrast*100, width, SNR);
   if mirrored
        fitLine2 = plot(fi, fitObj2(fi), 'color', [0.8500, 0.3250, 0.0980], 'LineWidth', 2, 'DisplayName', 'Mirrored');
        dataPoints2 = errorbar(freq, signal_2, sterr_2, '.', 'color', 'r', 'MarkerSize', 7);
        dispData = sprintf('$f_0=%.1f/%.1f \\, MHz$ \n$Contrast=%.2f/%.2f\\%%$ \n$FWHM(2\\gamma)=%.2f/%.2f\\, MHz$ \n$SNR/\\sqrt{n}=%.3f$', f0, contrast*100, width, mean(SNR));
        legend([fitLine, fitLine2], 'Location', 'southeast');
    end
    annotation('textbox', [0.4,0.7,0.5,0.22], 'String', dispData, 'Interpreter', 'Latex', 'FontSize', 14, 'BackgroundColor', [1 1 1]);
    set(gca,'FontSize',14);
    ylim([min([signal; signal_2]) - max(sterr), max([signal; signal_2]) + max(sterr) + contrast(1)/2]);
    grid on
    box on
end
if mirrored; fitObj = {fitObj, fitObj2}; end

% Save:
if toSave
    format shortg
    fileName = [path,'\ESRfit_', datestr(now,'yyyymmdd_HHMMSS')];
    if toPlot
        savefig([fileName,'.fig']);
        saveas(gcf, [fileName,'.png']);
    end
    save([fileName,'.mat'], 'f0', 'width', 'contrast', 'SNR', 'fitObj');
end


    function [fitObj, gof] = ESRfitInternal(freq, signal, sterr)
        % Calculates start points:
        cont = max(signal) - min(signal);
        baseLine = mean(signal([1:5, end-5:end]));
        [~, i] = min(signal);
        center = freq(i);
        df = mean(diff(freq));
        g = df * sum(signal < baseLine - cont/2) / 2;
        
        % Fit to Rabi curve:
        coefficients = {'a','f0', 'g', 'c'};
        startPoint = [cont,      center,       g,        baseLine];
        lower =      [0.5*cont,  center-4*g, 0.1*g,  0.7*baseLine];
        upper =      [1.5*cont,  center+4*g, 5  *g,  1.3*baseLine];
        f = 'c - a * g^2 / ((x-f0)^2 + g^2)';
        myfittype = fittype(f, 'coefficients', coefficients);
        [fitObj, gof, ~] = fit(freq, signal, myfittype, 'Weights', 1./sterr.^2, 'StartPoint', startPoint, 'Lower', lower, 'Upper', upper);
    end
end



