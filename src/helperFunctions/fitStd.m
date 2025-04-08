function coeffError = fitStd(fitObj, gof)
% This function caculate the standard error of a fit object
% When you doing fit get also the 'goodness of fit' parameter: [fitObj, gof, ~] = fit
% Use 'gof' as an input to this function
% coeffError: Output vector of the standard error for tit coefficients

alpha = 0.95;
df = gof.dfe;
ci = confint(fitObj, alpha);
t = tinv((1+alpha)/2, df);
coeffError = (ci(2,:) - ci(1,:)) / (2*t); %Standard Error
