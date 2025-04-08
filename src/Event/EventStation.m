classdef EventStation < handle
    %EVENTSTATION implements a station through which all the events go
    %   When an EventSender wants to send an event, it sends it to the
    %   station. Then, the station iterates through all of the listeners
    %   and checks - if a listener listens to the event's name, it will
    %   receive a call to its onEvent() method with the event as parameter
    
    properties (Access = private)
        eventListenersMap       % containers.map of {event-sender-name ---> event-listeners}
        listenersForAllEvents   % 1D cell-array of event listeners
        shouldShowEvents        % boolean. If true, events will be shown in the command-line
        
        % Queue
        queue = cell(0);	% cell of Events. Holds queued events until completion of stack.
        stackDepth = 0;     % int. Counts the number of times the event station was called/invoked without completion
    end
    
    methods (Static, Sealed)
        function obj = getInstance()
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = EventStation;
            end
            obj = localObj;
        end
        
        function anonymousError(errorMsg, varargin)
            % errorMsg - error message to show
            % varargin - so that we can pass multiple arguments (like sprintf)
            errorMsg = sprintf(errorMsg, varargin{:});
            EventStation.getInstance.newEvent(Event.createWarningEvent(struct('name', 'anonymous'), errorMsg));
            ME = MException('',errorMsg);
            throwAsCaller(ME);
        end
        
        function anonymousWarning(errorMsg, varargin)
            % errorMsg - error message to show
            % varargin - so that we can pass multiple arguments (like sprintf)
            errorMsg = sprintf(errorMsg, varargin{:});
            EventStation.getInstance.newEvent(Event.createErrorEvent(struct('name', 'anonymous'), errorMsg));
            warning(errorMsg); %#ok<SPWRN>
        end
    end
    
    methods (Access = private)
        function obj = EventStation()
            obj@handle;
            obj.eventListenersMap = containers.Map;
            obj.listenersForAllEvents = {};
            obj.shouldShowEvents = JsonInfoReader.getJson.showEvents;
        end
        
        function callQueuedEvents(obj)
            % When all other non-queued events have finished their
            % business, we send the queued events (if exist)
            %
            % The events are called FIFO (first in - first out)
            
            if obj.stackDepth == 0 && ~isempty(obj.queue)
                while ~isempty(obj.queue)
                    event = obj.queue{1};
                    obj.queue = {obj.queue{2:end}};
                    obj.newEvent(event);
                end
            end
        end
    end
    
    methods
        function registerListener(obj, eventListener, eventSenderName)
            % Registers a new listener to the station
            %
            % eventListener - the listener to register
            % eventSenderName - string. The name to listen to
            if ~obj.eventListenersMap.isKey(eventSenderName)
                obj.eventListenersMap(eventSenderName) = {eventListener};
            else
                cells = obj.eventListenersMap(eventSenderName);
                if ~any(cellfun(@(x)  x == eventListener, cells)) 
                    % ^ This condition is to make sure this listener isn't here
                    cells{end + 1} = eventListener;
                    obj.eventListenersMap(eventSenderName) = cells;
                end
            end
        end
        
        function registerListenerForAll(obj, eventListener)
            % Registers a new listener to the station to listen for all the
            % events
            %
            % eventListener - the listener to register
            if ~any(cellfun(@(x)  x == eventListener, obj.listenersForAllEvents))
                % only add if it's not in already
                obj.listenersForAllEvents{end + 1} = eventListener;
            end
        end
        
        function removeListener(obj, listenerToRemove, eventSenderName)
            % Removes a listener from listening for this eventSenderName
            %
            % listenerToRemove - the listener to remove
            % eventSenderName - string. The name that this listener was registered with
            if ~obj.eventListenersMap.isKey(eventSenderName)
                return
            end
            
            
            cells = obj.eventListenersMap(eventSenderName);
            allExceptToRemove = cellfun(@(x)  x ~= listenerToRemove, cells);
            newCells = cells(allExceptToRemove);
            if isempty(newCells)
                obj.eventListenersMap.remove(eventSenderName);
            else
                obj.eventListenersMap(eventSenderName) = newCells;
            end
            
            if obj.shouldShowEvents && length(newCells) ~= length(cells)
                obj.printRemove(listenerToRemove, eventSenderName)
            end
                
        end
        

        function removeListenerForAll(obj, listenerToRemove)
            % Removes a listener from the station that listened for all the
            % events
            %
            % eventListener - the listener to remove
            cells = obj.listenersForAllEvents;
            allExceptToRemove = cellfun(@(x)  x ~= listenerToRemove, cells);
            newCells = cells(allExceptToRemove);
            if obj.shouldShowEvents && length(cells) ~= length(newCells)
                obj.printRemove(listenerToRemove, 'ALL EVENTS');
            end
            obj.listenersForAllEvents = newCells;
        end
        
        function printRemove(~, listenerToRemove, eventSenderName)
            fprintf( ...
                'deleting EventListener of type %s (listened to %s)\n', ...
                class(listenerToRemove), ...
                eventSenderName);
        end
        
        function out = newEvent(obj, event)
            if obj.shouldShowEvents
                disp(event);
                disp(event.extraInfo);
            end
            
            obj.stackDepth = obj.stackDepth + 1;
            
            eventSender = event.creator.name;
            listenersForSender = {};
            if obj.eventListenersMap.isKey(eventSender) 
                listenersForSender = obj.eventListenersMap(eventSender);
            end
            for k = 1 : length(listenersForSender)
                listener = listenersForSender{k};
                if ~isvalid(listener) % listener might not have been deleted properly, and not removed as a listener.
                    removeListener(obj, listener, eventSender)
                    if JsonInfoReader.getJson.debugMode; fprintf('Deleting EventListener of type %s\n', class(listener)); end
                    continue
                end
                try
                    listener.onEvent(event);
                catch err
                    obj.anonymousWarning('%s could not perform onEventTask! Skipping.', class(listener))
                    err2warning(err);
                end
            end
            
            for i = 1 : length(obj.listenersForAllEvents)
                listenerForAll = obj.listenersForAllEvents{i};
                if ~any(cellfun(@(x)  x == listenerForAll, listenersForSender))
                    % Call only if this listener was not invoked earlier
                    listenerForAll.onEvent(event);
                end
            end
            
            obj.stackDepth = obj.stackDepth - 1;
            obj.callQueuedEvents;
            
            out = true;
        end
        
        function newQueuedEvent(obj, event)
            if obj.stackDepth == 0
                obj.newEvent(event);
            else
                obj.queue{end +1} = event;
            end
        end
    end
end

