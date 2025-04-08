classdef viewHelmholtz < ViewVBox
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
        function obj = viewHelmholtz(parent, controller)
            obj@ViewVBox(parent, controller);
            
            mainView = ViewHBox(obj, controller);
            column1 = ViewHelmholtzControl(mainView, controller);
            column2 = ViewVBox(mainView, controller);
            column3 = ViewVBox(mainView, controller);
            ViewVBox(mainView, controller);     % Dummy column, so that the third column doesn't end at the right end of the window
            
            % column 2:
            viewMagneticField = ViewMagneticField(column2, controller);
            viewExpectedESR = ViewExpectedESR(column2, controller);
            column2.setHeights([viewMagneticField.height, viewExpectedESR.height]);
            column2width = max(viewMagneticField.width, viewExpectedESR.width);
            column2height = viewMagneticField.height + viewExpectedESR.height + 10;
            
            % column 3:
            viewDiamondPlacement = ViewDiamondPlacement(column3, controller);
            viewHelmholtzSaveLoad = ViewHelmholtzSaveLoad(column3, controller);
            column3.setHeights([viewDiamondPlacement.height, viewHelmholtzSaveLoad.height]);
            column3width = max(viewHelmholtzSaveLoad.width, viewDiamondPlacement.width);
            column3height = viewHelmholtzSaveLoad.height + viewDiamondPlacement.height + 10;

            % window pararmeters:
            dummyWidth = 3;
            columnsWidths = [column1.width, column2width, column3width, dummyWidth];
            mainView.component.Widths = [column1.width, -1, column3width, dummyWidth];
            errorView = ViewError(obj, controller);
            maximumColumnsHeight = max([column1.height, column2height, column3height]);
            obj.component.Heights = [-1, errorView.height];
            
            minWidth = max([errorView.width, sum(columnsWidths)]) + 20;
            minHeight = errorView.height + maximumColumnsHeight;
            
            obj.width = minWidth;
            obj.height = minHeight;
        end      
    end
    
end

