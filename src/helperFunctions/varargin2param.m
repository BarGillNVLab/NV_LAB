function params = varargin2param(defult, vars)
% This function get list of defult fields and parameters, and varargin, 
% and return a struct with defult parameters in empty varargin fields.
% example:
% Input: varargin2param({'name', 'Boris', 'age', 120}, {'name', 'Dafna'})
% Output: params = struct('name', 'Dafna', 'age', 120)

if mod(length(defult), 2)
    error('''defult'' must contains pairs of field and value')
end

params = struct;
for i = 1 : 2 : length(defult)-1
    params.(defult{i}) = defult{i+1};
end

 if ~exist('vars', 'var')
     vars = [];
 end
 
 while ~isempty(vars)
     i = find(strcmp(vars{1}, defult(1:2:end)));
     if ~isempty(i)
        params.(defult{i*2-1}) = vars{2};
     else
        error('There is no optional field "%s"', vars{1});
     end
     vars(1:2) = [];
 end

