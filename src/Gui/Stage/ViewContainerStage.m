classdef ViewContainerStage < ViewVBox
    %VIEWSTAGECONTAINER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function obj = ViewContainerStage(parent, controller, camera)
            if ~exist('camera', 'var'); camera = [];end
            obj@ViewVBox(parent, controller);
            obj.component.Spacing = 0;
            stages = ClassStage.getStages;
            
            heights = -1 * ones(1, length(stages));
            width = 0;
            
            for k = 1 : length(stages)
                stage = stages{k};
                stageView = ViewStage(obj, controller, stage, camera);
                heights(k) = stageView.height;
                width = max(width, stageView.width);
            end
            
            obj.component.Heights = heights;
            obj.height = sum(heights);
            obj.width = width;
        end
    end 
end

