function [vCenter, vWidth] = extractVoltageSpan(Exp, toPlot)
% This function used for photodiode measurement.
% It takes experimrnt object and return the voltage center and width that
% acqired during the experiment. For using it the 'recordVoltageSpan' property should be 1.
% vWidth defined here where the value going down to almost 0
% experimentally. 'vCenter'-'vWidth' TO 'vCenter'+'vWidth'.

x = Exp.voltageHistogram.bins;
x = x(1:end-1) + 0.5*mean(diff(x));

colors = {[0 0.4470 0.7410], [0.8500 0.3250 0.0980]};

if toPlot
    figure; hold on;
end


for i = 1:size(Exp.voltageHistogram.values, 1)
    y = Exp.voltageHistogram.values(i,:);

    [maxVal, maxIdx] = max(y);
    startPoints = [maxVal, x(maxIdx), 1e-3];
    f = 'a * exp(-(x-x0)^2/s^2)';
    myfittype = fittype(f, 'coefficients', {'a', 'x0', 's'});
    fitObj = fit(x', y', myfittype, 'StartPoint', startPoints);

    coeff = coeffvalues(fitObj);
    vCenter(i) = coeff(2);
    vWidth(i) = 6 * coeff(3);

    if toPlot
        xi = x(1) : 0.0001 : x(end);
        plot(xi, fitObj(xi), 'color', colors{i});
        plot(x, y, '.', 'color', colors{i}*0.5);
        plot(vCenter(i) - vWidth(i) + [0 0], [0 maxVal], 'color', colors{i}*0.5, 'LineStyle','--');
        plot(vCenter(i) + vWidth(i) + [0 0], [0 maxVal], 'color', colors{i}*0.5, 'LineStyle','--');
    end
end