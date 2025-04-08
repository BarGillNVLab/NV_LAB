function [w0, r0, a, d_w0, fitObj, r2, rotatingAngle] = gaussianFit2D(x, y, s, plotFit, varargin)
% This function doing a 2D Gaussian fit. Yachel Ben-Shalom, 2024
% The gaussian deninition is as we define in laser beam power: a*exp(-2*(r-r0)^2/w0^2)+c
% Input:
%   x,y: image axes vectors (1*M), (1*N)
%   s: image data matrix (N*M)
%   plotFit: Boolean. if to plot the results.
%   varargin options:
%       'rotatingAngle': rotating angle of the fit axes in degrees
%       'optimizeAngle': Boolean. If true optimize automatically rotatingAngle to maximize r square. If 'rotatingAngle' exist use it as initial points.
%       'constZero': a number to assign as zero to the fit
%       'effectiveRadius': a number in  the 'x','y' units. If exist the fit takes just the points below this radius.
%       'plotDist': add another plot - histogram of the error as function of the distance from the center.
%       'w0', 'r0', 'a', 'c': initial points for the fit parameters
%       In case of given 'r0' - the efective radius will took around it. This can be usefull for fit to specific gaussian in figure with many.
%   The idea of using 'effectiveRadius', and 'plotDist' is that: 
%   If there is another close gaussian the histogram won't be around zero, but in disribution of positive-->negative-->positive.
%   In this case you can redduce the 'effectiveRadius'.
% Output:
%   w0: gaussian waist vector [w_x, w_y] (half width of exp(-2))
%   r0: gaussian center vector [x_0, y_0]
%   a: gaussian amplitude
%   d_w0: gaussian waist error vector [dw_x, dw_y]
%   'fitObj: fit object 
%   r2: r square of the fit
%   rotatingAngle: The rotating angle of the fit

defult = {'rotatingAngle', 0, 'optimizeAngle', false, 'constZero', [], 'effectiveRadius', inf, ...
          'plotDist', false, 'w0', [], 'r0', [], 'a', [], 'c', []};
params = varargin2param(defult, varargin);

if length(x) ~= size(s, 2) || length(y) ~= size(s, 1)
    error('x and y length do not fit to the image size');
end

% Optimize rotatingAngle:
if params.optimizeAngle
    var = varargin;
    i = find(strcmp(var, 'optimizeAngle'));
    var{i+1} = false;
    i = find(strcmp(var, 'rotatingAngle'));
    var(i:i+1) = [];
    var{end+1} = 'rotatingAngle';
    fun = @(rotatingAngle) gaussianFit2Dr2(x, y, s, var{:}, rotatingAngle);
    options = optimset('TolX', 1e-3, 'TolFun', 1e-5);
    rotatingAngle = fminsearch(fun, params.rotatingAngle, options);
    params.rotatingAngle = rotatingAngle;
end

% Convert to list of coordinates:
xx = repelem(x, length(y))';
yy = repmat(y, 1, length(x))';
ss = s(:);

% Initial point for the center:
if isempty(params.r0)
    [~, maxInd] = max(ss);
    xm = xx(maxInd); ym = yy(maxInd);
else
    xm = params.r0(1); ym = params.r0(2);
end

% Remove coordinates out of the effective radius:
i = (yy-ym).^2 + (xx-xm).^2 <= params.effectiveRadius^2;
xi = xx(i); yi = yy(i); si = ss(i);

% Rotating angle:
rotatingAngle = params.rotatingAngle;
R = [cosd(rotatingAngle) sind(rotatingAngle); -sind(rotatingAngle) cosd(rotatingAngle)]';
xyCoor = [xi, yi] * R;
x0y0Coor = [xm, ym] * R;

% Initial points:
if isempty(params.c)
    params.c = min(si);
end
if isempty(params.a)
    params.a = max(si) - params.c;
end
if isempty(params.w0)
    dist = sqrt((yi-ym).^2 + (xi-xm).^2);
    [sortSdist, sortSdistIdx] = sort(si, 'descend');
    i = find(sortSdist < max(si) - params.a * (1-exp(-2)), 1, 'first');
    if isempty(i) || length(xi) < i+5
        params.w0 = params.effectiveRadius * [1 1];
    else
        params.w0 = mean(dist(sortSdistIdx(i-5:1:i+5))) * [1 1];
    end
end

% Fitting:
coefficients = {'a','x0', 'y0', 'Sx', 'Sy'};
startPoint = [params.a,     x0y0Coor(1),              x0y0Coor(2),                  params.w0(1),     params.w0(2)];
lower =      [0.5*params.a, x0y0Coor(1)-params.w0(1), x0y0Coor(2)-params.w0(2), 0.5*params.w0(1), 0.5*params.w0(2)];
upper =      [1.5*params.a, x0y0Coor(1)+params.w0(1), x0y0Coor(2)+params.w0(2),   2*params.w0(1),   2*params.w0(2)];
if isempty(params.constZero)
    coefficients{end+1} = 'c';
    startPoint(end+1) = params.c;
    lower(end+1) =      min([params.c, 0]) - 0.5*params.a;
    upper(end+1) =      params.c           + 0.5*params.a;
    c = 'c';
else
    c = num2str(params.constZero);
end
f = ['a * exp(-2*(x-x0)^2/Sx^2 -2*(y-y0)^2/Sy^2) +', c];

myfittype = fittype(f, 'coefficients', coefficients, 'independent', {'x', 'y'}, 'dependent', 'z');
[fitObj,gof,~] = fit(xyCoor, si, myfittype, 'StartPoint', startPoint, 'Lower', lower, 'Upper', upper);

alpha = 0.95;
df = gof.dfe;
ci = confint(fitObj, alpha);
t = tinv((1+alpha)/2, df);
se = (ci(2,:) - ci(1,:)) / (2*t); %Standard Error
coeff = coeffvalues(fitObj);

w0 = [coeff(4), coeff(5)];
r0 = [coeff(2), coeff(3)];
a = coeff(1);
d_w0 = [se(4), se(5)];
r2 = gof.rsquare;

% Plots:
nPlots = 2*plotFit + params.plotDist;
if nPlots; figure; end
if plotFit
    subplot(1,nPlots,1);
    imagesc(x,y,s);
    colorbar;
    hold on;
    if params.effectiveRadius < max([abs(x(end)-x(1))/2, abs(y(end)-y(1))/2])
        viscircles(r0, params.effectiveRadius, 'LineWidth', 0.5);
    end
    set(gca,'YDir','normal');
    xlabel('X'); ylabel('Y'); title('Image Plot');
    subplot(1,nPlots,2);
    plot(fitObj, xyCoor, si);
    xlabel('X');
    ylabel('Y');
    zlabel('signal');
    title('2D Gaussian Fit');
    subtitle(sprintf('\\omega_0 = [%g, %g]', w0(1), w0(2)));
end

if params.plotDist
    vError = si - fitObj(xyCoor);
    rDist = xyCoor - r0;
    rDist = sqrt(rDist(:,1).^2 + rDist(:,2).^2);
    
    numRBins = 10;                                                  % Number of bins for distance
    numVBins = 10;                                                  % Number of bins for vertical error
    rEdges = linspace(min(rDist), max(rDist), numRBins + 1);        % Radial distance bin edges
    vEdges = linspace(min(vError), max(vError), numVBins + 1);      % Vertical error bin edges
    
    % Compute 2D histogram (distance bins vs vertical error bins)
    counts = zeros(numVBins, numRBins);
    for i = 1:numRBins
        % Indices of points within the current distance bin
        binIndices = rDist >= rEdges(i) & rDist < rEdges(i+1);
        % Compute histogram for vertical errors within this distance bin
        counts(:, i) = histcounts(vError(binIndices), vEdges);
    end
    
    % Plot the histogram as a color map
    ax = subplot(1,nPlots,nPlots);
    imagesc('XData', (rEdges(1:end-1) + rEdges(2:end)) / 2, ...     % Bin centers for rDist
            'YData', (vEdges(1:end-1) + vEdges(2:end)) / 2, ...     % Bin centers for vDist
            'CData', counts);
    set(gca, 'YDir', 'normal');
    
    colorbar;
    colormap(ax, 'bone');
    xlabel('distance from center');
    ylabel('vertical error');
    title('Histogram of Vertical Errors as a Function of Distance');
end


function r2 = gaussianFit2Dr2(x, y, s, varargin)
[~, ~, ~, ~, ~, r2] = gaussianFit2D(x, y, s, 0, varargin{:});

