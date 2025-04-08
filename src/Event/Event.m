classdef Event < handle
    %EVENT events are sent from EventSenders to EventListeners
    
    properties
        creator         % handle to the object that sent the event
        extraInfo       % struct. Both sender (physics-object) and listener should know what's inside
        isError         % logical. Is this an error event?
        isWarning       % logical. Is this a warning event?
    end
    
    properties (Constant, Hidden)
       ERROR_MSG = 'event_error_msg'; 
    end
    
    methods
        %% Constructor for normal events
        function obj = Event(creator, extraInfoIfNeeded)
            % creator - object
            % extraInfoIfNeeded - struct. Additional details about the event
            obj@handle();
            obj.creator = creator;
            obj.isError = false;
            obj.isWarning = false;
            if exist('extraInfoIfNeeded', 'var')
                obj.extraInfo = extraInfoIfNeeded;
            else
                obj.extraInfo = struct();
            end
        end
    end
    
    methods (Static)
        %% Constructor for error events
        function errorEvent = createErrorEvent(creator, errorMsgStr, extraInfoIfNeeded)
            % creator - the object that want to create an error event
            % errorMsgStr - the error message to be displayed            
            % extraInfoIfNeeded - optional struct
            
            if ~exist('extraInfoIfNeeded', 'var')
                extraInfoIfNeeded = struct(Event.ERROR_MSG, errorMsgStr);
            else
                extraInfoIfNeeded.(Event.ERROR_MSG) = errorMsgStr;
            end
                
           errorEvent = Event(creator, extraInfoIfNeeded);
           errorEvent.isError = true;
        end
        
        function warningEvent = createWarningEvent(creator, errorMsgStr, extraInfoIfNeeded)
            % creator - the object that want to create an warning event
            % errorMsgStr - the error message to be displayed            
            % extraInfoIfNeeded - optional struct
            
            if ~exist('extraInfoIfNeeded', 'var')
                extraInfoIfNeeded = struct(Event.ERROR_MSG, errorMsgStr);
            else
                extraInfoIfNeeded.(Event.ERROR_MSG) = errorMsgStr;
            end
                
           warningEvent = Event(creator, extraInfoIfNeeded);
           warningEvent.isWarning = true;
        end
    end
    
end