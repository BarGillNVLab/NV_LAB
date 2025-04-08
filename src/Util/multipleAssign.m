function [varargout] = multipleAssign( cellArray )
%MULTIPLEASSIGN support multiple assignments!
%   Takes the elements of a cell or numeric array and assigns them to separate varargout
%  [argout1,argout2,...]= multipleAssign(X)
if isnumeric(cellArray), cellArray=num2cell(cellArray); end

[varargout] = cellArray;

end

