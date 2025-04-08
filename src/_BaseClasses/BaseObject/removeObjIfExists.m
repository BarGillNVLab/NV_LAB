function baseObjOrNan = removeObjIfExists(baseObjName)
%REMOVEOBJIFEXISTS Removes a base object if it exists
    baseObj = getObjByName(baseObjName);
    if isempty(baseObj)
        % Don't remove anything: nothing was there in the first place
        baseObjOrNan = nan;
    else
        BaseObject.removeObject(baseObj);
        baseObjOrNan = baseObj;
    end
end

