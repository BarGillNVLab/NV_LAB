classdef ViewMainExperiment < ViewVBox
    %VIEWMAINEXPERIMENT The main window, with an experiment column
    %   Columns: 1 stages (scan + Kinesis/focus), 2 image, 3 lasers / MW /
    %   save-load / SPCM, 4 experiments. Every block is a collapsible panel.
    %   Like ViewMainImage - stage, image result, and the third column of
    %   lasers/save-load/SPCM - with microwave controls added to the third
    %   column, and a fourth column on the right for running experiments.
    %
    %   notice that obj.component is a vertical box!

    properties (Constant)
        EXPERIMENT_COLUMN_WIDTH = 420   % in px
        PANEL_HEADER = 25               % title bar of a collapsible panel
    end

    properties (SetAccess = private)
        viewExperiment      % ViewExperimentColumn
        viewMw              % ViewMwContainer
        viewStages          % ViewKinesisStages
    end

    methods
        % constructor - parent of a main view is the figure itself!
        function obj = ViewMainExperiment(parent, controller, dummyMode)
            obj@ViewVBox(parent, controller);
            if ~exist('dummyMode', 'var'); dummyMode = false; end

            mainView = ViewHBox(obj, controller);

            % Column 1 - everything that moves the sample: scan stages, then
            % the Kinesis stages with the focus search
            column1 = ViewVBox(mainView, controller, 0, 3);
            viewScanStages = ViewContainerStage(column1, controller);
            panelKinesis = ViewExpandablePanel(column1, controller, 'Kinesis stages & focus');
            obj.viewStages = ViewKinesisStages(panelKinesis, controller);
            column1.setHeights([viewScanStages.height, obj.viewStages.height + obj.PANEL_HEADER]);
            column1.width = max(viewScanStages.width, obj.viewStages.width);
            column1.height = viewScanStages.height + obj.viewStages.height + obj.PANEL_HEADER + 3;

            if dummyMode
                column2 = ViewCameraResult(mainView, controller);
            else
                column2 = ViewImageResult(mainView, controller);
            end
            column3 = ViewVBox(mainView, controller, 0, 3);
            column4 = ViewVBox(mainView, controller);

            % Column 3 - excitation (lasers, then microwaves), then the
            % save/load and counting controls. Every block collapses.
            viewLaserContainer = ViewLasersContainer(column3, controller);
            panelMw = ViewExpandablePanel(column3, controller, 'Microwave');
            obj.viewMw = ViewMwContainer(panelMw, controller);
            viewSaveLoad = ViewSaveLoad(column3, controller, Savable.CATEGORY_IMAGE);
            viewSpcm = ViewSpcm(column3, controller);
            column3heights = [viewLaserContainer.height, obj.viewMw.height + obj.PANEL_HEADER, ...
                viewSaveLoad.height, viewSpcm.height];
            column3.setHeights(column3heights);
            column3width = max([viewLaserContainer.width, obj.viewMw.width, viewSaveLoad.width]);

            obj.viewExperiment = ViewExperimentColumn(column4, controller);
            column4.setHeights(-1);
            column4width = obj.EXPERIMENT_COLUMN_WIDTH;

            % The image column takes whatever is left over (-1)
            mainView.component.Widths = [column1.width, -1, column3width, column4width];

            errorView = ViewError(obj, controller);
            obj.component.Heights = [-1, errorView.height];

            column3height = sum(column3heights) + 3 * numel(column3heights);
            maximumColumnsHeight = max([column1.height, column2.height, column3height, obj.viewExperiment.height]);

            columnsWidths = [column1.width, column2.width, column3width, column4width];
            obj.width = max([errorView.width, sum(columnsWidths)]) + 20;
            obj.height = errorView.height + maximumColumnsHeight;
        end
    end

end
