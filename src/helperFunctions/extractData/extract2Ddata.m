function [x, signal, signal_1, signal_2, sterr, sterr_1, sterr_2, xName] = extract2Ddata(exp)

axisParam = exp.mCurrentXAxisParam;
if ~isempty(axisParam)
    x = axisParam.value;
    xName = axisParam.name;
else 
    N = size(exp.signal, 2);
    xName = [];
    fields = fieldnames(exp);
    for i = 1:length(fields)
        sz = size(exp.(fields{i}));
        if  (sz(1) == 1) && (sz(2) ==  N)
            x = exp.(fields{i});
            break
        end
    end
end

sig = exp.signal;
d = exp.sterr;

lastAvg = find(prod(prod((sig~=0),1),2) == 0, 1) - 1;     % finding the last average index that not contains 0
if isempty(lastAvg); lastAvg = size(sig,3); end

s1 = squeeze(sig(1, :, 1:lastAvg));
s2 = squeeze(sig(2, :, 1:lastAvg));
s3 = squeeze(sig(3, :, 1:lastAvg));
s4 = squeeze(sig(4, :, 1:lastAvg));
if lastAvg == 1
    s1 = s1'; s2 = s2'; s3 = s3'; s4 = s4';
end
signal_1 = s1./s2;
signal_2 = s3./s4;
errorDistance = 8;                                          % number of std to assume a point is error
signal_1((abs(signal_1-mean(signal_1,2)) > (errorDistance*mean(std(signal_1,1,2))))) = NaN;         % Active filtering for error results
signal_2((abs(signal_2-mean(signal_2,2)) > (errorDistance*mean(std(signal_2,1,2))))) = NaN;         % Active filtering for error results

signal_1 = nanmean(signal_1,2)';
signal_2 = nanmean(signal_2,2)';
signal = signal_2 - signal_1;

% Calculates the mean and standard error similar to the function 'Experiment.getRatioDistributionValues'
d1 = squeeze(d(1, :, 1:lastAvg));
d2 = squeeze(d(2, :, 1:lastAvg));
d3 = squeeze(d(3, :, 1:lastAvg));
d4 = squeeze(d(4, :, 1:lastAvg));
if lastAvg == 1
    d1 = d1'; d2 = d2'; d3 = d3'; d4 = d4';
end
s1mean = mean(s1, 2);
s2mean = mean(s2, 2);
s3mean = mean(s3, 2);
s4mean = mean(s4, 2);

d1 = getCombinedSterr(s1, d1, exp.repeats);
d2 = getCombinedSterr(s2, d2, exp.repeats);
d3 = getCombinedSterr(s1, d3, exp.repeats);
d4 = getCombinedSterr(s2, d4, exp.repeats);
sterr_1 = (s1mean./s2mean) .* sqrt(d1.^2./s1mean.^2 + d2.^2./s2mean.^2);
sterr_2 = (s3mean./s4mean) .* sqrt(d3.^2./s3mean.^2 + d4.^2./s4mean.^2);
sterr = sqrt(sterr_1.^2 + sterr_2.^2);

    function sterr = getCombinedSterr(means, sterrs, repeats)
        % Calculate the combined standard error similar to the function 'Experiment.getCombinedSterr'
        m = repeats;
        meanSoFar = means(:,1);
        sterrSoFar = sterrs(:,1);
        for i = 2:size(means, 2)
            n = m * (i-1);
            meanSoFar = ((i-2)*meanSoFar+means(:,i-1))/(i-1);
            sterrSoFar = sqrt(((n*(n-1)*sterrSoFar.^2)+(m*(m-1)*sterrs(:,i).^2))./((n+m)*(n+m-1)) + n*m*(meanSoFar-means(:,i)).^2 ./ ((n+m)^2*(n+m-1)));
        end
        sterr = sterrSoFar;
    end
end