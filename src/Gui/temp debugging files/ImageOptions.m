classdef ImageOptions < ViewHBox
    properties
    end
    
    methods
        function obj = ImageOptions(parent, controller)
            % Create an expandable panel for the whole column
            panel = ViewExpandablePanel(parent, controller, 'Image Options');
            obj@ViewHBox(panel, controller);
            %%%% ui component init %%%%
            obj.component.Spacing = 5;
            obj.component.Padding = 5;
            
            % Create main vertical box layout
            main = ViewHBox(obj, controller, 0, 8);
            % left side           
            

            %bottom left hbox
            bottomleftHBox = ViewHBox(main, controller, 0, 0);
            startstop = StartStop(bottomleftHBox, controller);
            countsperPixel = CountsperPixel(bottomleftHBox, controller);            
            bottomleftHBox.setWidths([-1 countsperPixel.width]);
            bottomleftHBox.height = max(startstop.height, countsperPixel.height)+10;
            bottomleftHBox.width = [startstop.width, countsperPixel.width];
            
            
            left = {bottomleftHBox};  
            
            

            % plot options, cpp, start/stop
            rightVBox = ViewVBox(main, controller, 0, 0);
            plotoptions = PlotOptions(rightVBox, controller);
            microwave = ViewImageMW(rightVBox, controller);
                                    
            right = {plotoptions, microwave};
            rightVBox.setHeights([-1 microwave.height]);
            rightVBox.height = [plotoptions.height+10, microwave.height];
            rightVBox.width = max(plotoptions.width, microwave.width)+50;
            

            
            % Compute heights and widths for proper layout
            
            heights = [...
                    sum(cellfun(@(p) p.height, left)), ...
                    sum(cellfun(@(p) p.height, right))+10, ...
                    ];
                
            widths = [sum(bottomleftHBox.width) rightVBox.width];
            
            % Adjust the size of the entire layout
            main.height = max(heights)+20;
            main.width =  sum(widths)+10;
            
            obj.height = max(heights)+40;
            obj.width = sum(widths)+40;
        end
    end
end