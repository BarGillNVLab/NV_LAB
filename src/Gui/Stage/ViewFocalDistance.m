classdef ViewFocalDistance < GuiComponent 
    % FocalDistance is a class for setups whom excitation focal length is
    % different than the collection focal length
    
    properties
        dist                % 1x3 edit-text
        up                  % button
        down                % 1x3 button
        default             % set to default value
    end
    
    properties (Constant)
        DEFAULT_DISTANCE = '10';  % need to fix so the default distance will be recieved from the jason
       
    end
    
    methods
        function obj = ViewFocalDistance(parent, controller)
            obj@GuiComponent(parent, controller);
            panelLimits = uix.Panel('Parent', parent.component, 'Title', 'Distance Between Focal Planes', 'Padding', 5);
            hboxmain = uix.HBox('Parent', panelLimits, 'Spacing', 10, 'Padding', 0);
            vboxleft = uix.VBox('Parent', hboxmain,'Spacing', 5, 'Padding', 0);
            hboxtopleft = uix.HBox('Parent', vboxleft, 'Spacing', 0, 'Padding', 0);
            uicontrol(obj.PROP_LABEL{:},'parent', hboxtopleft, 'string', 'Distance =');
            obj.dist = uicontrol(obj.PROP_EDIT{:}, 'parent', hboxtopleft);
            hboxtopleft.Widths = [-2 -1];
            uicontrol(obj.PROP_BUTTON{:},'parent', vboxleft, 'string', 'Set to Default');
            vboxleft.Heights = [-1 -1];
            vboxRight = uix.VBox('Parent', hboxmain, 'Spacing', 5, 'Padding', 0);
            obj.up = uicontrol(obj.PROP_BUTTON{:}, 'Parent',vboxRight, 'String', 'jump up');
            obj.down = uicontrol(obj.PROP_BUTTON{:}, 'Parent',vboxRight, 'String', 'jump down');
            vboxRight.Heights = [-1 -1];
            hboxmain.Widths = [-3 -2];

            obj.height = 80;
            obj.width = 90;
            
        end
        % callback functions
    end
end
        