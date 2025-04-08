classdef EventSender < BaseObject
    %EVENTSENDER a member of this class can send events     
    %   Events sent by an object can be captured by various listeners   
    %                                                       %
    %   child classes can use                               %
    %       @ sendEvent(struct)                             %
    %       @ sendWarning(msgString, optionalStruct)        %
    %       @ sendError(msgString, optionalStruct)          %
    %                                                       %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    methods (Access = protected)
        function obj = EventSender(name)
            % name - string. Object name for future reference
            obj@BaseObject(name);
        end
        
        function sendEvent(obj, varargin)
            % Sends an event to the EventStation
            % optionalStructToSend - struct (optional). If not supplied,
            %                           the Event class will supplement it.
            creator = obj;
            optionalStructToSend = varargin;
            
            eventToSend = Event(creator, optionalStructToSend{:});
            station = EventStation.getInstance;
            station.newEvent(eventToSend);
        end
        
        function sendQueuedEvent(obj, varargin)
            % Sends a queued event to the EventStation, to be sent only
            % after all other events have been sent
            % optionalStructToSend - struct (optional). If not supplied,
            %                           the Event class will supplement it.
            creator = obj;
            optionalStructToSend = varargin;
            
            eventToSend = Event(creator, optionalStructToSend{:});
            station = EventStation.getInstance;
            station.newQueuedEvent(eventToSend);
        end
        
        function sendWarning(obj, errorString, extraInfoStructIfNeeded)
            % Sends an error event to the controller
            % errorString - string. Warning message to display
            % extraInfoStructIfNeeded - if you want to send the event with
            %       some extra info to be received by your listeners
            if exist('extraInfoIfNeeded', 'var')
                errorEvent = Event.createWarningEvent(obj, errorString, extraInfoStructIfNeeded);
            else
                errorEvent = Event.createWarningEvent(obj, errorString);
            end
            EventStation.getInstance.newEvent(errorEvent);
            warning(errorString);
        end
                
        function sendError(obj, errorString, extraInfoStructIfNeeded)
            % Sends an error event to the controller
            % errorString - string. Error message to display
            % extraInfoStructIfNeeded - if you want to send the event with
            %       some extra info to be received by your listeners
            if exist('extraInfoIfNeeded', 'var')
                errorEvent = Event.createErrorEvent(obj, errorString, extraInfoStructIfNeeded);
            else
                errorEvent = Event.createErrorEvent(obj, errorString);
            end
            EventStation.getInstance.newEvent(errorEvent);
            error(errorString);
        end
    end
end