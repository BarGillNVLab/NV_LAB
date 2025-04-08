classdef ViewMessage < ViewHBox
    %VIEWMESSAGE Gui Component to show messages for a brief period of time
    % Similar to ViewError
    % Warning: This view was not put into use, and was not tested!
    
    properties (Constant)
        DELAY_SHOW_MESSAGE_SEC = 12;
    end
    
    properties (Access = protected)
        timerHideMessage
    end
    
    methods
        function obj = ViewMessage(parent, controller)
            obj@ViewHBox(parent, controller);
            uix.Empty('Parent', obj.component);
            obj.tvMsg = uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', obj.component);
            uix.Empty('Parent', obj.component);
            obj.component.Widths = [-1 -10 -1];
        end
        
        % Destructor
        function delete(obj)
            obj.exitTimersIfNeeded();
        end
    end
    
    methods (Access = protected)
        function cleanErrorAfterTime(obj)
            obj.exitTimersIfNeeded();
            
            obj.timerHideMessage = timer('TimerFcn',@(x,y)obj.displayOff,'StartDelay',obj.DELAY_SHOW_MESSAGE_SEC);
            start(obj.timerHideMessage);
        end
        
        function displayOff(obj)
            set(obj.component, 'Visible', 'off');
        end
        
        % clears the timer (if it exist)
        function exitTimersIfNeeded(obj)
            try
                if (isobject(obj.timerHideMessage))
                    % if it was running from a previous error
                    stop(obj.timerHideMessage);
                    delete(obj.timerHideMessage);
                end
            catch err
                disp(err)
            end
        end
    end
    
end

