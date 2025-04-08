function [w0, r0, a, d_w0, fitObj, r2, rotatingAngle] = gaussianFitImage(imageStruct, plotFit, varargin)
% This function working as 'gaussianFit2D', but instead of getting the full data, it works with the saved matlab file of the main GUI
% Input:
%   'imageStruct': .mat file as saved from our main GUI.
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

x = imageStruct.imageScanResult.mFirstAxis;
y = imageStruct.imageScanResult.mSecondAxis;
s = imageStruct.imageScanResult.mData;
[w0, r0, a, d_w0, fitObj, r2, rotatingAngle] = gaussianFit2D(x, y, s, plotFit, varargin{:});