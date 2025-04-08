function s = ste( varargin )
%STE returns the standard error of the data
% Works exactly like VAR or STD, but equals std(x)/sqrt(n), where n is the
% number of elements in the selected axis

x = varargin{1};
if nargin > 2
    dim = varargin{3};
else
    dim = find(size(x) ~= 1, 1);
    if isempty(dim)
        dim = 1;
    end
end
n = size(x, dim);
v = var(varargin{:}, "omitnan");        % "omitnan" added by yachel 23.07.23
s = sqrt(v/n);
end

