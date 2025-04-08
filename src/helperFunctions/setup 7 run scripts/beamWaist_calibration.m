load('G:\My Drive\NV Lab\Control code\prod\helperFunctions\setup 7 run scripts\setup calibration\2024_02_19\beam waist\Aluminum knife\XY scan 4 - wide.mat');
data = myStruct.imageScanResult.mData;

knifeEdgeAxis = 1;      % 1 or 2, according to the scan

if knifeEdgeAxis == 1
    axis1 = myStruct.imageScanResult.mFirstAxis;
    axis2 = myStruct.imageScanResult.mSecondAxis;
else
    axis1 = myStruct.imageScanResult.mSecondAxis;
    axis2 = myStruct.imageScanResult.mFirstAxis;
    data = data';
end

axis1limits = [3, length(axis1)];     % The first and last pixel take in account
data = data(:, axis1limits(1):axis1limits(end));
axis1 = axis1(axis1limits(1):axis1limits(end));
%%
width = zeros(1, length(axis2));
for i = 1:length(width)
    figure(10);
    width(i)  = extractKnifeEdge(axis1, data(i, :), 1);
    close(figure(10));
end

% figure;
% plot(axis2, width);

figure;
extractBeamParameters(axis2, width, 1, 0.532);