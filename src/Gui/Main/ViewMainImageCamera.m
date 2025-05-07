classdef ViewMainImageCamera < ViewVBox
    %VIEWMAIN the main window
    %   is constructed from a vertical box with 2 elements: 
    %     *  top erea is for the 3 columns (via horizontal box) + dummy column, 
    %     *  bottom erea is for the error messages. 
    %
    %   notice that obj.component is a vertical box!
    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties (Constant)
        
    end
    
    methods
        % constructor - parent of a main view is the figure itself!
        function obj = ViewMainImageCamera(parent, controller)
            obj@ViewVBox(parent, controller);
            
            % create a new position for the lasers
            mainView = ViewHBox(obj, controller);
            column1 = ViewVBox(mainView, controller);
            %column1 = ViewContainerStage(mainView, controller);
            column2 = ViewCameraResult(mainView, controller);
            column3 = ViewVBox(mainView, controller);
            ViewVBox(mainView, controller);     % Dummy column, so that the third column doesn't end at the right end of the window

            %colummn 1
            viewContainerStage = ViewContainerStage(column1, controller, [4 6]);
            viewImageResult = ViewImageResult(column1, controller, [100 100], [4 6]);
            
           
%             column1.setHeights([viewROI.height]);
%             column1width = viewROI.width;
            column1.setHeights([viewContainerStage.height -1]);
            
            column1width = max(viewContainerStage.width, viewImageResult.width);
            column1height = viewContainerStage.height + viewImageResult.height + 10;
            
            
            %column 2


            %column 3
            viewLaserContainer = ViewLasersContainer(column3, controller);
            viewSaveLoad = ViewSaveLoad(column3, controller, Savable.CATEGORY_IMAGE);
            cameraoptions = ViewCameraOptions(column3, controller);
        
            
            column3.setHeights([viewLaserContainer.height, viewSaveLoad.height, cameraoptions.height]);
            column3width = max([viewLaserContainer.width, viewSaveLoad.width, cameraoptions.width]);
            dummyWidth = 3;

            columnsWidths = [column1width, column2.width, column3width, dummyWidth];
            mainView.component.Widths = [column1width, -1, column3width, dummyWidth];
            errorView = ViewError(obj, controller);
            column3height = viewSaveLoad.height + viewLaserContainer.height+cameraoptions.height + 10;
            maximumColumnsHeight = max([column1height, column2.height, column3height]);
            obj.component.Heights = [-1, errorView.height];
            
            minWidth = max([errorView.width, sum(columnsWidths)]) + 20;
            minHeight = errorView.height + maximumColumnsHeight;
            
            obj.width = minWidth;
            obj.height = minHeight;
        end      
    end
    
end

