function [avg_num, meanErr] = GetErrorbarPerAverage(exp)

%plot mean of the the errobars of the final signel per average (to find
%noise floor in rabi experimetns

currIter = exp.currIter;
signal = exp.signal;
m = exp.repeats;
meanErr = [];
for i = 2:currIter
S1 = squeeze(exp.signal(1,:,1:i)); 
S1mean = mean(S1,2);
S2 = squeeze(exp.signal(2,:,1:i)); 
S2mean = mean(S2,2);

S1sterr = squeeze(exp.sterr(1,:,1:i));
S2sterr = squeeze(exp.sterr(2,:,1:i));

combinedS1sterr = getCombinedSterr(m, S1, S1sterr);
combinedS2sterr = getCombinedSterr(m, S2, S2sterr);

sterr = (S1mean./S2mean).*sqrt(combinedS1sterr.^2./S1mean.^2 + combinedS2sterr.^2./S2mean.^2)
meanErr = [meanErr,mean(sterr)];


end
avg_num = [2:currIter];
figure; plot(avg_num,meanErr)


function sterr = getCombinedSterr(m, S, sterrs)
            % Calculate the combined standard error when combining the data
            % coming from several normal distribution. Formula taken from:
            % https://math.stackexchange.com/questions/2971315/how-do-i-combine-standard-deviations-of-two-groups
            % Note that it was adjusted for standard error (and not
            % deviation), and runs iteratively.
            meanSoFar = S(:,1);
            sterrSoFar = sterrs(:,1);
            for i = 2:size(S, 2)
                n = m * (i-1);
                meanSoFar = ((i-2)*meanSoFar+S(:,i-1))/(i-1);
                sterrSoFar = sqrt(((n*(n-1)*sterrSoFar.^2)+(m*(m-1)*sterrs(:,i).^2))./((n+m)*(n+m-1)) + n*m*(meanSoFar-S(:,i)).^2 ./ ((n+m)^2*(n+m-1)));
            end
            sterr = sterrSoFar;
end

end