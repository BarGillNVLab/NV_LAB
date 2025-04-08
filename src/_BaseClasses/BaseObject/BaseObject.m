classdef BaseObject < HiddenMethodsHandle & PropertiesDisplaySorted
    %BASEOBJECT an object which has a name
    %   Objects of type BaseObject are singletons that can be identified by
    %   their name, so they would be able to perform well when book-keeping
    %   is needed. Because of that, all the "interesting" classes (like
    %   e.g. EventSender or Savable) derive from BaseObject.
    %   
    %   This class has a static map of BaseObjects that someone thought
    %   they would be nice to have around. Adding an object to this map
    %   would be via calling addBaseObject() --> an Exception will be
    %   thrown if an object is in with the same name.
    %   Removing a BaseObject from the map is done via removeObjIfExists().
    %   Querying (getting) objects from the map is done via
    %   getObjByName(string), which will return either the BaseObject if it
    %   was found, or an empty variable if no BaseObject was found.
    %
    %   This class extends CustomDisplay so that properties could look
    %   better and readable.
    
    properties
        name  % An object is recognized in the event system by its name only! vector of chars
    end
    
    methods
        function obj = BaseObject(name)
            % name - the object name
            obj@HiddenMethodsHandle;
            obj@PropertiesDisplaySorted;
            obj.name = name; 
        end
        
        function set.name(obj, newName)
            if isempty(obj.name)
                obj.name = newName;
                return
            end
            
            if ~strcmp(obj.name, newName)
                error('Can''t set BaseObject with different names! That will cause TROUBLE!\nPrevious name: "%s", current name: "%s"',...
                    obj.name, ...
                    newName);
            end
        end
                
        function delete(obj)
            BaseObject.removeObject(obj);
        end
        
    end
    
    methods (Static, Access = {?DeveloperFunctions})
        % We don't want people messing around with this.
        % But there's a class in dev\DevOnly\ ...
        function objectMap = allObjects
            persistent allObjectsMap
            if isempty(allObjectsMap) || ~isvalid(allObjectsMap)
                temp = containers.Map('UniformValues', false);
                allObjectsMap = HandleWrapper(temp); 
            end
            objectMap = allObjectsMap;
        end
    end
       
    methods (Static, Hidden)
        function baseObject = getByName(objName)
            % Searches and returns an object based on its "name" property;
            % returns an empty variable if no such object was found.
            %
            % Although this function is accessable from anywhere in the
            % code, it is hidden so that it won't auto-complete in every
            % object inheriting from BaseObject.
            % Instead, call "getObjByName(name)", which is a wrapper
            % function for "BaseObject.getByName(name)"
            allBaseObjects = BaseObject.allObjects.wrapped;

            if ~ischar(objName) && ~isstring(objName)
                baseObject = [];
%                 error('Requested object name, %s, is invalid!', objName)
            elseif ~allBaseObjects.isKey(objName)
                baseObject = [];
%                 error('No object named "%s" exists!', objName)
            else
                baseObject = allBaseObjects(objName);
                assert(isscalar(baseObject)); % found only one object
            end
        end
        
        function addObject(baseObject)
            allBaseObjects = BaseObject.allObjects.wrapped;
            objName = baseObject.name;
            if allBaseObjects.isKey(objName)
                % => Apparently an object with this name already exists.
                % It's probably an error, but maybe it's the same object
                % being constructed twice (it can happen with diamond
                % inheritance. For example if something inherits both
                % "Savable" and "EventSender", both inherit from
                % "BaseObject". We need to check this
                if allBaseObjects(objName) == baseObject
                    % Dismiss - same object constructed twice. Not an error
                    return
                end
                EventStation.anonymousError('Another object named "%s" already exists!', objName)
            end
            
            allBaseObjects(objName) = baseObject; %#ok<NASGU>
        end
        
        function removeObject(baseObjectOrObjName)
            allBaseObjects = BaseObject.allObjects.wrapped;
            
            if ischar(baseObjectOrObjName)
                nameToRemove = baseObjectOrObjName;
            else
                % We have the actual object at hand. Since this function
                % is sometimes incorrectly invoked, we want to make sure
                % that we are not deleting the new object, but only the old
                % one.
                nameToRemove = baseObjectOrObjName.name;
                if ~isKey(allBaseObjects, nameToRemove) || ...
                        allBaseObjects(nameToRemove) ~= baseObjectOrObjName
                    % ^ Logic for this condition: This name might:
                    % (1) not exist in the system - and then there's no
                    %     point in further checking;
                    % (2) exist in the system (condition was not
                    %     short-circuited), but it does not refer to the
                    %     object that we wanted to delete (but to an older
                    %     version of it).
                    % Either way, nothing more to do here.
                    return
                end
            end
            
            if allBaseObjects.isKey(nameToRemove)
                allBaseObjects.remove(nameToRemove);
            end
        end
    end
    
%     methods (Static, Access = public)         % why public?
%         function objectMap = allObjects
%             persistent allObjectsMap
%             if isempty(allObjectsMap) || ~isvalid(allObjectsMap)
%                 allObjectsMap = containers.Map;
%             end
%             objectMap = HandleWrapper(allObjectsMap);
%         end
%     end
end
