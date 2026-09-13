classdef ViewMainExperiment < ViewVBox
    %VIEWMAINEXPERIMENT The main window, with an experiment column
    %   Like ViewMainImage - stage, image result, and the third column of
    %   lasers/save-load/SPCM - with microwave controls added to the third
    %   column, and a fourth column on the right for running experiments.
    %
    %   notice that obj.component is a vertical box!

    properties (Constant)
        EXPERIMENT_COLUMN_WIDTH = 420   % in px
    end

    properties (SetAccess = private)
        viewExperiment      % ViewExperimentColumn
        viewMw              % ViewMwContainer
    end

    methods
        % constructor - parent of a main view is the figure itself!
        function obj = ViewMainExperiment(parent, controller, dummyMode)
            obj@ViewVBox(parent, controller);
            if ~exist('dummyMode', 'var'); dummyMode = false; end

            mainView = ViewHBox(obj, controller);
            column1 = ViewContainerStage(mainView, controller);
            if dummyMode
                column2 = ViewCameraResult(mainView, controller);
            else
                column2 = ViewImageResult(mainView, controller);
            end
            column3 = ViewVBox(mainView, controller);
            column4 = ViewVBox(mainView, controller);

            % Excitation sources first - lasers, then microwaves - then the
            % save/load and counting controls.
            viewLaserContainer = ViewLasersContainer(column3, controller);
            obj.viewMw = ViewMwContainer(column3, controller);
            viewSaveLoad = ViewSaveLoad(column3, controller, Savable.CATEGORY_IMAGE);
            viewSpcm = ViewSpcm(column3, controller);
            column3.setHeights([viewLaserContainer.height, obj.viewMw.height, ...
                viewSaveLoad.height, viewSpcm.height]);
            column3width = max([viewLaserContainer.width, obj.viewMw.width, viewSaveLoad.width]);

            obj.viewExperiment = ViewExperimentColumn(column4, controller);
            column4.setHeights(-1);
            column4width = obj.EXPERIMENT_COLUMN_WIDTH;

            % The image column takes whatever is left over (-1)
            mainView.component.Widths = [column1.width, -1, column3width, column4width];

            errorView = ViewError(obj, controller);
            obj.component.Heights = [-1, errorView.height];

            column3height = viewLaserContainer.height + obj.viewMw.height + ...
                viewSaveLoad.height + viewSpcm.height + 10;
            maximumColumnsHeight = max([column1.height, column2.height, column3height, obj.viewExperiment.height]);

            columnsWidths = [column1.width, column2.width, column3width, column4width];
            obj.width = max([errorView.width, sum(columnsWidths)]) + 20;
            obj.height = errorView.height + maximumColumnsHeight;
        end
    end

end
