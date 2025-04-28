function viewAllBaseObjects()
    objMap = BaseObject.allObjects.wrapped;
    disp('Current objects in BaseObject map:');
    disp(objMap.keys());
end