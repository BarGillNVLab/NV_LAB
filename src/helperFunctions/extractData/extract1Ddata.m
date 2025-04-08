function [x, signal, sterr, xName] = extract1Ddata(exp)

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

lastAvg = find(prod(prod((sig~=0),1),2) == 0, 1) - 1;       % finding the last average index that not contains 0
if isempty(lastAvg); lastAvg = size(sig,3); end

s1 = squeeze(sig(1, :, 1:lastAvg));
s2 = squeeze(sig(2, :, 1:lastAvg));
if lastAvg == 1
    s1 = s1'; s2 = s2';
end
s = s1./s2;

errorDistance = 8;                                          % number of std to assume a point is error
s((abs(s-mean(s,2)) > (errorDistance*mean(std(s,1,2))))) = NaN;         % Active filtering for error results
signal = nanmean(s,2)';


% Calculates the mean and standard error similar to the function 'Experiment.getRatioDistributionValues'
d1 = squeeze(d(1, :, 1:lastAvg));
d2 = squeeze(d(2, :, 1:lastAvg));
if lastAvg == 1
    d1 = d1'; d2 = d2';
end
s1mean = mean(s1, 2);
s2mean = mean(s2, 2);
d1 = getCombinedSterr(s1, d1, exp.repeats);
d2 = getCombinedSterr(s2, d2, exp.repeats);
sterr = (s1mean./s2mean) .* sqrt(d1.^2./s1mean.^2 + d2.^2./s2mean.^2);


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