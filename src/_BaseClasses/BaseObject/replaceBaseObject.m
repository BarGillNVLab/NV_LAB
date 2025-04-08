function oldObjOrNan = replaceBaseObject(newObj)
%REPLACEOBJECT Finds and replaces old object of same type as new object
%   Recieves object to be "pushed" into the base object map
%   (BaseObject.allObjects). If such an object already exists, it "pops" it
%   out; otherwise, it returns NaN.
%
%   This function unifies the function of "removeObjIfExists" and
%   "addBaseObject".

% Find and remove previous object
name = newObj.name;
baseObj = getObjByName(name);

if isempty(baseObj)
    % Don't remove anything: there was nothing there in the first place
    oldObjOrNan = nan;
else
    BaseObject.removeObject(baseObj);
    oldObjOrNan = baseObj;
end

BaseObject.addObject(newObj);

end

