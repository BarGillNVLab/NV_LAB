function object = getObjByName( name )
%GETOBJBYNAME calls BaseObject.getByName, so there will be an auto-complete typing for getting objects
%   will throw an error if no object was found with this name
object = BaseObject.getByName(name);
end
