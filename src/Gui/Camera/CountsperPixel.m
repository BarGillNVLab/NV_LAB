classdef CountsperPixel < GuiComponent
    properties
        ccpbtn         % ccp button
        runccp         % run ccp button
        ccpboxbtn      % ccpbox button
        stpccp         % stop ccp button
    end
    methods
        function obj = CountsperPixel(parent, controller)
            % Call the superclass constructor
            obj@GuiComponent(parent, controller);

            % Create the main vertical box container
            panel = uix.Panel('Parent', parent.component, 'Title', 'Counts Per Pixel', 'Padding', 5);
            mainVBox = uix.VBox('Parent',panel, 'Spacing', 0, 'Padding', 0);

            % Add a text box for the "CPP" display at the top
            obj.ccpbtn = uicontrol(obj.PROP_BUTTON{:}, ...
                                    'Parent', mainVBox, ...
                                    'String', 'CPP', ...
                                    'FontSize', 10, ...
                                    'HorizontalAlignment', 'center');

            uix.Empty('parent', mainVBox);

            
            

            % Add the "Run CPP" button to the horizontal box
            obj.runccp = uicontrol(obj.PROP_BUTTON{:}, ...
                                   'Parent', mainVBox, ...
                                   'String', 'Run CPP');
            uix.Empty('parent', mainVBox);

            % Add the "CPP Box" button to the horizontal box
            obj.ccpboxbtn = uicontrol(obj.PROP_BUTTON{:}, ...
                                      'Parent', mainVBox, ...
                                      'String', 'CPP Box');
            uix.Empty('parent', mainVBox);

            % Add the "Stop CPP" button to the horizontal box
            obj.stpccp = uicontrol(obj.PROP_BUTTON{:}, ...
                                   'Parent', mainVBox, ...
                                   'String', 'Stop CPP');

            
            mainVBox.Heights = [30 10 25 5 25 5 25];
            
            obj.height = sum(mainVBox.Heights) + 5;
            obj.width = 130;
        end
    end
    % Callback functions can be implemented here as needed
end
