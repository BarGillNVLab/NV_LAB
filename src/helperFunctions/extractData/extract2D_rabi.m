function [tau, value, sterr, dbm] = extract2D_rabi(exp)
% THIS IS DIFFERENT THAN EXTRACT 2Ddata
% tau is matrix where each row is the relevant time vector signal is matrix
% with signal ; sterr - standard error; dbm - vector with dbm powers
     
    repeats = exp.repeats;
    tau = exp.tau;
    tauSize = size(tau);
    iter = exp.currIter -1; %choose the last iteration 
    S1 = reshape(squeeze(exp.signal(1, :, 1:iter)), length(exp.amplitude), tauSize(2), []);
    S1sterr = reshape(squeeze(exp.sterr(1, :, 1:iter)), length(exp.amplitude), tauSize(2), []);
    S2 = reshape(squeeze(exp.signal(2, :, 1:iter)), length(exp.amplitude), tauSize(2), []);
    S2sterr = reshape(squeeze(exp.sterr(2, :, 1:iter)), length(exp.amplitude), tauSize(2), []);
    dbm = exp.amplitude;


dataSize = size(S1);
dim = length(dataSize);
if dim > 2
    S1 = reshape(S1, [], dataSize(end));
    S2 = reshape(S2, [], dataSize(end));
    S1sterr = reshape(S1sterr, [], dataSize(end));
    S2sterr = reshape(S2sterr, [], dataSize(end));
end
value = mean(S1./S2, 2);
S1mean = mean(S1, 2);
S2mean = mean(S2, 2);

S1sterr = getCombinedSterr(S1, S1sterr);
S2sterr = getCombinedSterr(S2, S2sterr);
if dim > 2
    dataSize = dataSize(1:end-1);
    value = reshape(value, dataSize);
    S1mean = reshape(S1mean, dataSize);
    S2mean = reshape(S2mean, dataSize);
    S1sterr = reshape(S1sterr, dataSize);
    S2sterr = reshape(S2sterr, dataSize);
end

sterr = (S1mean./S2mean).*sqrt(S1sterr.^2./S1mean.^2 + S2sterr.^2./S2mean.^2);

        function sterr = getCombinedSterr( means, sterrs)
            % Calculate the combined standard error when combining the data
            % coming from several normal distribution. Formula taken from:
            % https://math.stackexchange.com/questions/2971315/how-do-i-combine-standard-deviations-of-two-groups
            % Note that it was adjusted for standard error (and not
            % deviation), and runs iteratively.
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