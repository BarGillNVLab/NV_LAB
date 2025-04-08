classdef ViewESRPlot < GuiComponent & EventListener

    properties
        helm
        vAxes
        fig
    end
    
    methods
        function obj = ViewESRPlot(parent, controller)
            expNames = Experiment.getExperimentNames();
            namesToListenTo = {expNames{:}, Helmholtz.NAME}; %#ok<CCAT>
            obj@GuiComponent(parent, controller);
            obj@EventListener(namesToListenTo);
            obj.helm = getObjByName('Helmholtz');

            obj.component.Spacing = 5;
            obj.component.Padding = 5;
            
            obj.component = uicontainer('parent', parent.component);
            obj.vAxes = axes('Parent', obj.component, 'ActivePositionProperty', 'outerposition');
            obj.helm.plotExpectedESR(obj.vAxes);
            obj.height = 250;   % minimum
            obj.width = 500;    % minimum
        end
        
        function refresh(obj)
            obj.helm.plotExpectedESR(obj.vAxes);
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
            end
        end
    end
end