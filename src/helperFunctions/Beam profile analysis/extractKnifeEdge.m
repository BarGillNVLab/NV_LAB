function [diameter, diameter_std]  = extractKnifeEdge(points, power, toPlot)
% function that extract to beam diameter from knife edge method data.
% This function can work with data from dark to bright and vice-versa
% points: vector of spatial points
% power: vector of power points
% toPlot: boolean. If to plot the erf fit
% diameter: output of the beam diameter

if ~exist('toPlot', 'var')
    toPlot = 0;
end

% Padding:
s = [ones(1,10)*power(1), power, ones(1,10)*power(end)];
dx = mean(diff(points));
x = [points(1) + dx*(-10:1:-1), points, points(end) + dx*(1:1:10)];
N = length(s);

% Start points calculation:
contrast = max(s)-min(s);
[~, center] = min(abs(s - min(s) - contrast/2));

if mean(s(1:floor(N/2))) < mean(s(ceil(N/2):end))
    myfittype = fittype('a*(  erf(sqrt(2)*(x-x0)/w))+c', 'coefficients',{'a', 'x0', 'w', 'c'});
else
    myfittype = fittype('a*(1-erf(sqrt(2)*(x-x0)/w))+c', 'coefficients',{'a', 'x0', 'w', 'c'});
end
[fitObj, gof, ~] = fit(x', s', myfittype, 'StartPoint', [contrast, x(center), dx, min(s)]);
coeff = coeffvalues(fitObj);
diameter = 2 * coeff(3);
coeffError = fitStd(fitObj, gof);
diameter_std = 2 * coeffError(3);

if toPlot
    figure;
    hold on;
    xi = x(1):dx/100:x(end);
    plot(xi, fitObj(xi), 'color', 'red');
    plot(x, s, '*', 'color', 'k');
    xlabel('position');
    ylabel('power');
    title('Laser Beam - Knife Edge Profile');
    annotation('TextBox', [0.2, 0.45, 0.2, 0.1], 'String', sprintf('2\\omega_0=%.2f\\pm%.2f', diameter, diameter_std), 'LineStyle', 'none', 'FontSize', 14);
end
