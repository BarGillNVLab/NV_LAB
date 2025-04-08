classdef ViewSpcm < GuiComponent
    %ViewSpcm wrapper for ViewSpcmCounter for display in main image view
    
    properties (Constant)
        VIEW_HEIGHT = 100;
        VIEW_WIDTH = -1;
    end
    
    methods
        function obj = ViewSpcm(parent,controller)
            spcm = getObjByName(Spcm.NAME); 
            titleString = 'SPCM';
            if spcm.hasPhotodiode()
                titleString = 'Photodiode';
            end
            panel = ViewExpandablePanel(parent, controller, titleString, @ViewSpcm.popup);
            obj@GuiComponent(parent, controller);
            
            spcmCounerView = ViewSpcmCounter(panel, controller, ...
                'isStandalone', false, obj.VIEW_HEIGHT, obj.VIEW_WIDTH);
            obj.component = spcmCounerView.component;
        end
    end     
       
    methods (Static)
        function popup
            GuiControllerSpcmCounter().start;
        end
    end 
end