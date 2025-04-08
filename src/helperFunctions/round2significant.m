function [value ,err] = round2significant(a,b)
% get a value and his error and round him to the significant digits
    err = round(b,1,'significant');
    dig = -floor(log10(err));
    if dig <= 0;dig = dig-1 ;end
    value = round(a, dig+1);
end
