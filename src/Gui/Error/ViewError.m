classdef ViewError < GuiComponent & EventListener
    %VIEWERROR showing the errors
    %   this view listens for all the event, and shows the error events. it uses a timer to remove the display from the event
    
    properties (Access = protected, Constant)
        PROP_ERROR_TEXT = {'Style', 'text', 'ForegroundColor', 'red', 'BackgroundColor', 'white', 'HorizontalAlignment', 'center'};
        PROP_ERROR_MSG = {'FontSize', 14, 'String', 'Errors will be displayed here!'};
        PROP_ERROR_FROM = {'FontSize', 12, 'String', ''};
        PROP_ERROR_MAIN = {'BackgroundColor', 'white', 'Spacing', 20, 'Padding', 5};
    end
    
    properties (Access = protected)
        tvFrom
        tvMsg
        
        timer   % object of class TimedDisplay
    end
    
    methods
        function obj = ViewError(parent, controller)
            %%%% parent constructors %%%%
            obj@GuiComponent(parent, controller);
            obj@EventListener();
            obj.setListeningForAll(true);
            
            %%%% UI initialization %%%%
            obj.width = 800;   % for the screen
            obj.height = 60;   % for the screen
            
            obj.component = uix.HBox(obj.PROP_ERROR_MAIN{:}, 'Parent', parent.component);
            obj.tvFrom = uicontrol(obj.PROP_ERROR_TEXT{:}, obj.PROP_ERROR_FROM{:}, 'Parent', obj.component);
            obj.tvMsg = uicontrol(obj.PROP_ERROR_TEXT{:}, obj.PROP_ERROR_MSG{:}, 'Parent', obj.component);
            obj.component.Widths = [-3 -10];
            
            obj.timer = TimedDisplay(obj.component);
            obj.timer.hideAfterTime;
        end
        
        % destructor
        function delete(obj)
            delete(obj.timer);
        end
    end
    
    methods
        %% When error event happens, this function jumps.
        % extraInfo is a struct sent from the physics
        function out = onEvent(obj, event)
            if ~(event.isError || event.isWarning)
                out = false;
                return
            end
            eventSender = event.creator.name;
            errorMsg = event.extraInfo.(Event.ERROR_MSG);
            obj.tvFrom.String = sprintf('From %s', eventSender);
            obj.tvMsg.String = errorMsg;
            set(obj.component, 'Visible', 'on');
            
            out = true;
            blinkAndHideAfterTime(obj.timer);
        end
    end
end