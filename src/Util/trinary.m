function tri = trinary(x, I)
%TRINARY returns whether x is in I (1), to its right (0) or to its left(2)
% receives:
%       x, scalar
%       I, vector representing interval
% returns:
%       0, if x < I,
%       1, if x in I (including edges)
%       2, if x > I

a = min(I);
b = max(I);

if x < a
    tri = 0;
elseif x > b
    tri = 2;
else
    tri = 1;
    
% or, more compactly, but less intuitively
%   tri = 1 + (x>b) - (x<a);

end

