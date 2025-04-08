classdef ViewBooleanSwitch < EventListener & GuiComponent
    % VIEWBOOLEANSWITCH a GUI component that handles a switch which
    % controls a physical switch
    
    properties
        % Ui related
        cbxEnabled             % Checkbox
        
        %%%% the laser aom to send requests to %%%%
        physicsBooleanSwitch
    end
    
    methods
        
        % constructor
        function obj = ViewBooleanSwitch(parent, controller, booleanPhysical, stringToDisplay)
            % parent - gui component
            % controller - the main GUI controller
            
            % init variables
            switchNameToListen = booleanPhysical.name;
            
            % Constructors
            obj@EventListener(switchNameToListen);
            obj@GuiComponent(parent, controller);
            
            % the boolean switch physics object
            obj.physicsBooleanSwitch = booleanPhysical;
                        
            % UI components init
            parentBox = parent.component;
            obj.cbxEnabled = uicontrol(obj.PROP_CHECKBOX{:}, ...
                'Parent', parentBox, 'string', stringToDisplay, ...
                'Callback', @obj.cbxEnabledCallback);
            obj.component = obj.cbxEnabled;
            obj.refresh();
            obj.height = 30;
            obj.width = 40;
            
        end
        
        function cbxEnabledCallback(obj, ~, ~)
            obj.requestSwitchEnabled(obj.cbxEnabled.Value);
        end
        
    end
    
    %% 
    methods (Access = protected)
        
        function refresh(obj)
            obj.setSwitchEnabledInternally(obj.physicsBooleanSwitch.isEnabled);
        end
        
        %%%% Internal function for changing the checkbox "enabled" %%%%
        function setSwitchEnabledInternally(obj, newBoolValue)
            obj.cbxEnabled.Value = newBoolValue;
        end

        
        %%%% This method actually requests stuff from the physics. Carefull! %%%%
        function requestSwitchEnabled(obj, newBoolValue)
            obj.physicsBooleanSwitch.isEnabled = newBoolValue;
            % If the physics got our change - it will send an event to notify us
            % If not, it will send an error Event to notify us
        end
        
    end  % methods
    
    %% Overriding methods!
    methods
        function out = onEvent(obj, event)
            info = event.extraInfo;
            if event.isError
                obj.refresh;
            elseif isfield(info, 'isEnabled')
                obj.setSwitchEnabledInternally(info.isEnabled);
            else
                f = fields(info);
                errMsg = sprintf('%s ', f{:});
                EventStation.anonymousWarning(['Unknown field(s):', errMsg])
            end

            out = true;
        end
    end
    
end

