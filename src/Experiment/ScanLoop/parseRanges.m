function v = parseRanges(str, what)
%PARSERANGES Values from text like "0:5:25, 0:100:400" - sorted, no duplicates
%   Items are separated by commas, semicolons or spaces; each is a number or
%   from:step:to. No eval: only numbers and colons are accepted.
%   what names the field in error messages.
if nargin < 2; what = 'Values'; end
str = regexprep(char(str), '\s*:\s*', ':');     % "0 : 5 : 25" -> "0:5:25"
items = strsplit(strtrim(regexprep(str, '[,;]', ' ')));
items = items(~cellfun(@isempty, items));
assert(~isempty(items), '%s: empty - type e.g. 0:5:25, 0:100:400', what);
v = [];
for k = 1:numel(items)
    p = str2double(strsplit(items{k}, ':'));
    assert(all(isfinite(p)), '%s: "%s" is not a number or from:step:to', what, items{k});
    switch numel(p)
        case 1
            v = [v, p]; %#ok<AGROW>
        case 3
            assert(p(2) ~= 0, '%s: step 0 in "%s"', what, items{k});
            r = p(1):p(2):p(3);
            assert(~isempty(r), '%s: "%s" gives no values (check the sign of the step)', what, items{k});
            v = [v, r]; %#ok<AGROW>
        otherwise
            error('%s: "%s" - use from:step:to (three numbers)', what, items{k});
    end
end
v = unique(round(v * 1e9) / 1e9);   % rounding: 0.1 steps must not leave near-duplicates
end
