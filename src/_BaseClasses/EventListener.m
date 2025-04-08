classdef (Abstract) EventListener < handle
    % EventListener every object who wants to listen to events should inherit from this class. 
    %
    %
    % subclasses need to override onEvent()
    % subclasses can also use those 3 methods:
    %   @ startListeningTo(senderNameStringOrCellString), 
    %   @ stopListeningTo(senderNameStringOrCellString), 
    %   @ setListeningForAll(booleanValue)

    
    
    
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Override this in child classes to get notified about the event!    %
% Copy & paste the lines below:                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%     %% overridden from EventListener
%     methods
%         % When events happen, this function jumps.
%         % event is the event sent from the EventSender
%         function onEvent(obj, event)
%         end
%     end

    
    
    
    properties (SetAccess = private)
        namesToListenTo = {};
        % cell-array of strings
    end
    
    properties (SetAccess = protected)
        listensToEveryone = false;
        % Self explanatory. Can be used be someone who wants to listen to
        % all the events, and then check in onEvent() if the event is an
        % error event, and display it. For example - a view to show errors
        % in the GUI
        
    end
    
    methods (Abstract)
        onEvent(obj, event)
    end
    
    
    % setters
    methods
        function set.listensToEveryone(obj, newBoolValue)
            if ~ValidationHelper.isTrueOrFalse(newBoolValue);EventStation.anonymousError('Can only be set to logical value!');end            
            
            if newBoolValue
                EventStation.getInstance.registerListenerForAll(obj);
                obj.listensToEveryone = true;
            else
                EventStation.getInstance.removeListenerForAll(obj);
                obj.listensToEveryone = false;
            end
        end
        
        % determine if this listener will listen to all the events being sent (default: false)
        function setListeningForAll(obj, newBoolValue)
            % newValue - can be eighter true or false
            obj.listensToEveryone = newBoolValue;
        end
    end
    
    methods
        %% constructor
        function obj = EventListener(namesToListenTo)
            % namesToListenTo - can be either empty, a string or cell of strings
            obj@handle();
            if exist('namesToListenTo', 'var')
                obj.startListeningTo(namesToListenTo);
            end
        end
                
        %% add a name to listen to
        function startListeningTo(obj, newName)
            % newName - can be a string or cell of strings 
            es = EventStation.getInstance;
            if ischar(newName)
                % add only one
                senderName = newName;
                obj.namesToListenTo{end + 1} = senderName;
                es.registerListener(obj, senderName);
            else
                % iterate and add them all
                for k = 1 : length(newName)
                    senderName = newName{k};
                    if isempty(senderName)
                        continue;
                    end
                    obj.namesToListenTo{end + 1} = senderName;
                    es.registerListener(obj, senderName);
                end
            end
        end
        
        %% remove a name to listen to
        function stopListeningTo(obj, oldName)
            % oldName - can be a string or cell of strings
            es = EventStation.getInstance;
            if ischar(oldName)
                % Remove this name
                senderName = oldName;
                allOther = cellfun(@(x) ~strcmp(x, senderName), obj.namesToListenTo);
                obj.namesToListenTo = obj.namesToListenTo(allOther);
                es.removeListener(obj, senderName);
            else
                % This is a cell array of names;
                % Iterate and remove
                for i = 1 : length(oldName)
                    senderName = oldName{i};
                    allOther = cellfun(@(x) ~strcmp(x, senderName), obj.namesToListenTo);
                    obj.namesToListenTo = obj.namesToListenTo(allOther);
                    es.removeListener(obj, senderName);
                end
            end
        end
        
        % destrcutor
        function delete(obj)
            obj.stopListeningTo(obj.namesToListenTo);
            obj.setListeningForAll(false);
        end
    end
end