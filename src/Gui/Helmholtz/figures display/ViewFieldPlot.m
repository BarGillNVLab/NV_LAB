classdef ViewFieldPlot < GuiComponent & EventListener

    properties
        helm
        vAxes
        fig
    end
    
    methods
        function obj = ViewFieldPlot(parent, controller)
            expNames = Experiment.getExperimentNames();
            namesToListenTo = {expNames{:}, Helmholtz.NAME}; %#ok<CCAT>
            obj@GuiComponent(parent, controller);
            obj@EventListener(namesToListenTo);
            obj.helm = getObjByName('Helmholtz');

            obj.component.Spacing = 5;
            obj.component.Padding = 5;
            
            obj.component = uicontainer('parent', parent.component);
            obj.vAxes = axes('Parent', obj.component, 'ActivePositionProperty', 'outerposition');
            obj.helm.plotSetup(obj.vAxes);
            obj.height = 500;   % minimum
            obj.width = 500;    % minimum
        end
        
        function refresh(obj)
            obj.helm.plotSetup(obj.vAxes);
        end
        
        function refreshView(obj)
            obj.helm.setView(obj.vAxes);
        end
    end 

    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if event.isError ...
                    || isfield(event.extraInfo, Helmholtz.EVENT_MAGNETIC_FIELD_CHANGED) ...
                    || isfield(event.extraInfo, Helmholtz.EVENT_DIAMOND_PROPERTIES_CHANGED)
                obj.refresh();
            elseif  isfield(event.extraInfo, Helmholtz.EVENT_VIEW_ANGLE_CHANGED)
                obj.refreshView();
            end
        end
    end
end