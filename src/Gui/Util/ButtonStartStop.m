classdef ButtonStartStop < GuiComponent
    %BUTTONSTARTSTOP Start/Stop button, colored green/red, accordingly
    
    properties (Constant)
        COLOR_START = 'green'
        COLOR_STOP = 'red'
    end
    
    properties
        startCallback
        stopCallback
        
        % These two have default values
        startString = 'Start';
        stopString = 'Stop';
        
    end
    
    properties (Access = private)
        isRunningPrivate
    end
    
    properties (Dependent)
        isRunning
        Enable % "inherited" from the component
    end
    
    methods
        function obj = ButtonStartStop(parent, startString, stopString)
            obj@GuiComponent;
            obj.component = uicontrol(obj.PROP_BUTTON_BIG_GREEN{:}, 'Parent', parent);
            switch nargin
                case 1
                case 3
                    obj.startString = startString;
                    obj.stopString = stopString;
                otherwise
                    EventStation.anonymousError('Could not create Stop/Start button!')
            end
            obj.component.String = obj.startString;
            obj.isRunning = false;
            obj.component.Callback = @obj.buttonCallback;
        end
        
        function buttonCallback(obj, h, e)
            obj.isRunning = ~obj.isRunning;     % invert
            if obj.isRunning
                obj.startCallback(h, e);      % We just started, so let's go
            else
                obj.stopCallback(h, e);
            end
        end
        
    end
    
    methods
        % Setters
        function set.startCallback(obj, fun)
            if ~isa(fun, 'function_handle')
                error('startCallback must be a function handle!')
            end
            obj.startCallback = fun;
        end
        
        function set.stopCallback(obj, fun)
            if ~isa(fun, 'function_handle')
                error('stopCallback must be a function handle!')
            end
            obj.stopCallback = fun;
        end
        
        function set.isRunning(obj, newVal)
            % Might be called not by using the button, so we want this
            % function independent of callback
            if ~ValidationHelper.isTrueOrFalse(newVal)
                error('New value for button must be convertible to true or false')
            end
            obj.isRunningPrivate = newVal;
            if newVal
                % We want to be able to stop
                obj.component.BackgroundColor = obj.COLOR_STOP;
                obj.component.String = obj.stopString;
            else
                % We want to be able to start
                obj.component.BackgroundColor = obj.COLOR_START;
                obj.component.String = obj.startString;
            end
        end
        
        function set.Enable(obj, newVal)
            obj.component.Enable = newVal;
        end
        
        
        
        % Getter(s)
        function val = get.isRunning(obj)
            val = obj.isRunningPrivate;
        end
        
        function val = get.Enable(obj)
            val = obj.component.Enable;
        end
    end
    
end

