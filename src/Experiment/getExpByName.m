function expObj = getExpByName(searchedName)
%GETEXPBYNAME Returns an experiment object, whose name is the same as
%searchedName, if such might exist

msgNoExp = 'No experiment exists that is called ''%s''!';
msgNotCurrent = '"%s" is not a current experiment! Running it now.';

expObj = getObjByName(searchedName);
if ~isempty(expObj)
    % We found it, and we're done
    return
end

% We look for the experiment, in order to create it
[expNamesCell, expClassNamesCell] = Experiment.getExperimentNames();
ind = strcmp(searchedName, expNamesCell); % index of searchedName in list

if isempty(ind)
    ME = MException(Experiment.EXCEPTION_ID_NO_EXPERIMENT, msgNoExp, searchedName);
    throw(ME);
else
    warning(Experiment.EXCEPTION_ID_NOT_CURRENT, msgNotCurrent, searchedName); % todo: maybe it is unnecessary
    % (We use @str2func, which is superior to @eval, when possible)
    className = str2func(expClassNamesCell{ind}); % function handle for the class
    expObj = className();
end

end

