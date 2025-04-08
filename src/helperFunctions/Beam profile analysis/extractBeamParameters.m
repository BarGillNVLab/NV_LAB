function [w0, z0, zR] = extractBeamParameters(points, diameters, toPlot, lambda)
% function that extract to beam parameters from diameter points data.
% All input and output parameters in the same units.
% points: vector of spatial points
% diameters: vector of diameters points
% lambda: beam wavelength
% toPlot: boolean. If to plot the fit function
% [w0, z0, zR]: gaussian beam parameters (same units as input

if ~exist('toPlot', 'var')
    toPlot = 0;
end

if ~exist('lambda', 'var')
    lambda = 0.532 * 1e-3;
end

% Start points calculation:
[min_D, min_ind] = min(diameters);
myfittype = fittype(@(w0, z0, z) w0 * sqrt(1 + ((z-z0) / (pi*w0^2/lambda)) .^ 2), 'independent', 'z', 'coefficients',{'w0', 'z0'});
myfit = fit(points', (diameters/2)', myfittype, 'StartPoint', [min_D/2, points(min_ind)]);
coeff = coeffvalues(myfit);
w0 = coeff(1);
z0 = coeff(2);
zR = pi*w0^2/lambda;

if toPlot
    figure; hold on;
    dx = mean(diff(points)) / 100;
    xi = points(1):dx:points(end);
    plot(xi, myfit(xi), 'color', 'red');
    plot(xi, -myfit(xi), 'color', 'red');
    plot(points, diameters/2, '*', 'color', 'k');
    title('Beam Profile');
    xlabel('position');
    ylabel('radius');
    annotation('TextBox', [0.3, 0.15, 0.5, 0.2], 'String', sprintf('w_{0}=%.3f\nz_{0}=%.1f\nz_{R}=%.1f', w0, z0, zR), 'FontSize', 12,  'HorizontalAlignment', 'center', 'LineStyle', 'None');
    box on;
end
