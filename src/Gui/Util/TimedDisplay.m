classdef TimedDisplay < handle
    %TIMEDDISPLAY Hides input object after set time
    %   Recieves graphic object, and handles displaying it and hiding it
    %   after set time, with proper consructor and destructor
    
    properties
        DEFAULT_DELAY_SHOW_MESSAGE_SEC = 10;
        DEFAULT_DELAY_BLINK_END_SEC = 0.5;
    end
    
    properties (Access = protected)
        grahpicObj          % handle to graphics object to be hidden
        
        mTimer
        delayHideTime   % for hiding once
        blinkTime       % for blinking ("on, off, then on")
    end
    
    methods
        function obj = TimedDisplay(gObj, delayHideTimeOptional, blinkTimeOptional)
            obj@handle;
            
            if ~isgraphics(gObj)
                EventStation.anonymousError('Can''t hide and show non-graphic objects');
            end
            obj.grahpicObj = gObj;
            
            if exist('delayHideTimeOptional','var'); obj.delayHideTime = delayHideTimeOptional;
            else; obj.delayHideTime = obj.DEFAULT_DELAY_SHOW_MESSAGE_SEC; end
            
            if exist('blinkTimeOptional','var'); obj.blinkTime = blinkTimeOptional;
            else; obj.blinkTime = obj.DEFAULT_DELAY_BLINK_END_SEC; end
        end
        
        % destructor
        function delete(obj)
            obj.exitTimersIfNeeded();
        end
    end
    
    methods
        function hideAfterTime(obj)
            % Initialize timer
            obj.exitTimersIfNeeded();
            obj.mTimer = timer('TimerFcn', @(x,y)obj.hide, 'StartDelay', obj.delayHideTime);
            % Start
            obj.show;
            start(obj.mTimer);
        end
        
        function blinkAndHideAfterTime(obj)
            % We want 3 timed actions:
            % 1. Hide (to raise the user attention) - at timer.start
            % 2. Show (so the user can read) - after blinkTime
            % 3. Hide (We don't want the message visible forever) - after
            %       delayHideTime
            % This is implemented by executing "show" twice, and then the
            %   timer will stop and hide the graphic object
            obj.exitTimersIfNeeded();
            
            T = timer;
            T.StartFcn = @(x,y)obj.hide;
            T.TimerFcn = @(x,y)obj.show;
            T.StopFcn = @(x,y)obj.hide;
            T.ExecutionMode = 'fixedRate';
            T.TasksToExecute = 2;
            T.Period = obj.delayHideTime;
            T.StartDelay = obj.blinkTime;
            
            obj.mTimer = T;
            
            obj.show;
            start(obj.mTimer);
        end
    end
    
    methods (Access = protected)
        function hide(obj)
            if isgraphics(obj.grahpicObj) % Maybe it was deleted in the meantime
                set(obj.grahpicObj, 'Visible', 'off');
            end
        end
        
        function show(obj)
            if isgraphics(obj.grahpicObj) % Maybe it was deleted in the meantime
                set(obj.grahpicObj, 'Visible', 'on');
            end
        end
        
		function exitTimersIfNeeded(obj)
            % Clears the timer (if it exists)
            try
                if (isobject(obj.mTimer))
                    % if it was running from a previous error
                    stop(obj.mTimer);
                    delete(obj.mTimer);
                end
            catch err
                % We don't want an error within error.
                % 
                err2warning(err)
            end
        end
    end
    
end

