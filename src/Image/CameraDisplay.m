classdef CameraDisplay < Savable & EventSender & EventListener
    %   CameraImage class for handling camera plot

    properties (Constant)
        NAME = 'cameraDisplay';                   % Name of the class
        COLORMAP_OPTIONS = {'jet', 'gray'};     % Available colormap options
        IMAGE_OPTIONS = {'kcps'};
        IMAGE_FILE_SUFFIX = 'png'
        FIGURE_FILE_SUFFIX = 'fig'
        
        % Events
        EVENT_IMAGE_UPDATED = 'imageUpdated';
        EVENT_CPP_UPDATED = 'cppUpdated'

        % Figure Options
        PLOT_STYLE_OPTIONS_2D = {'Normal', 'Equal', 'Square'};
        BINNING_OPTIONS = [1 2 3 4 8];
        CURSOR_OPTIONS = {'Marker', 'Zoom', 'Location'};
        CONTRAST_OPTIONS = {'Difference', 'Ratio', 'Without MW', 'With MW'};
 
    end
    
    properties (GetAccess = public, SetAccess = private)
        mData = [];     % double. Image data from the camera
        mFirstAxis      % vector
        mSecondAxis     % vector or point
        mStageName      % string
        mAxesString     % string
        mLabelBot       % string
        mLabelLeft      % string
    end
%     properties (GetAccess = public, SetAccess = private)
%         imageData = [];     % Image data from the camera
%         axesHandle = [];    % Handle to the axes where the image is displayed
%         currentCameraName = ''; % Name of the current camera
%         currentCamera = []; % Handle to the current camera object
%     end

    properties (Access = private) % For plotting over Image
        gAxes
        gLimits = [];           % graphic handle; stores limits drawn onto image (for zoom)
        crosshairs = struct;    % struct of graphic handles, for the elements of the crosshairs\arrow for current position
        cursor                  % datacursor handle. Stores the information about recent mouse actions
    end

    properties
        plotStyle               % integer. Index for value in obj.PLOT_STYLE_OPTIONS 
        colormapType            % Colormap type
        colormapLimits = [0 1]; % Colormap limits
        colormapAuto = true;    % Auto colormap limits
        zoomFactor = 1;      % Current zoom factor
        zoomCenter = [0 0];   % Center of the zoom
        dataCursorMode = 'off'; % Data cursor mode ('off' or 'on')
        dataCursorHandle = []; % Handle to the data cursor object
        cursorType              % integer. Index for value in CURSOR_OPTIONS
        contrastType            % integer. Index for value in CONTRAST_OPTIONS
        imageType               % integer. Index for value in IMAGE_OPTIONS
        runCPP                  % boolean checks if the runcpp button was pressed

        roi
        initialroi
        initialdata
        cpproi
        CPP
    end
    
    methods
        function obj = CameraDisplay
            obj@Savable(CameraDisplay.NAME);
            obj@EventSender(CameraDisplay.NAME);
            obj@EventListener({SaveLoadCatImage.NAME, CameraCapture.NAME}); % Listen to all camera types
            
            obj.plotStyle = 2;      % Equal
            obj.colormapType = 2;   % Parula
            obj.cursorType = 1;     % Marker
            obj.contrastType = 1;   % Difference
            obj.imageType = 1;      % kcps
            obj.runCPP = 0;         % counts per pixel flag
            obj.CPP = 0;            % counts per pixel
            
        end
        %%      

        function update(obj, newStruct)
            % This function could be called in two cases:
            % 1. When new data arrives. We then have newStruct.
            % 2. When ViewImageResultImage starts, and wants data to plot.
            %    Then, no structExtra will be available, but if there is
            %    available data, we still want to plot it.
            if isempty(obj.gAxes) || ~ishandle(obj.gAxes)
                return
            end
            if exist('newStruct', 'var')
                % Get EVERYTHING from the struct
                obj.mData = newStruct.mData;
                obj.mFirstAxis = newStruct.mFirstAxis;
                obj.mSecondAxis = newStruct.mSecondAxis;
                obj.mLabelBot = newStruct.mLabelBot;
                obj.mLabelLeft = newStruct.mLabelLeft;
                obj.initialroi = newStruct.initialroi;
                obj.roi = [obj.mFirstAxis(1) obj.mSecondAxis(1) obj.mFirstAxis(end)-obj.mFirstAxis(1) obj.mSecondAxis(end)-obj.mSecondAxis(1)];
                
                

                
            elseif ~obj.isDataAvailable
                % No data is available, neither externally nor internally.
                return
            end
            
            [data, label] = obj.getDataForPlotting;

            
            
            % We need to calculate this before sending event (so as to update the header):
            if obj.colormapAuto
                obj.colormapLimits = obj.calcColormapLimits(data);
            end
            
            AxesHelper.fill(obj.gAxes, data, 2, obj.mFirstAxis, obj.mSecondAxis, obj.mLabelBot, obj.mLabelLeft, [], label);
            obj.sendEventImageUpdated();
            obj.imagePostProcessing;
            % zoom will be done in updateDataByZoom
        end

        function imagePostProcessing(obj)
            %%%% After plotting is done, we can make some slight changes
            
            % Plot style
            styleOptions = obj.PLOT_STYLE_OPTIONS_2D;
            
            styleName = lower(styleOptions{obj.plotStyle});
            axis(obj.gAxes, styleName)
            
            % Colormap
            colormapName = obj.COLORMAP_OPTIONS{obj.colormapType};
            colormap(obj.gAxes, colormapName)
            
            data = obj.getDataForPlotting;
            
            if obj.colormapAuto
                obj.colormapLimits = obj.calcColormapLimits(data);
            end
            
            try
                caxis(obj.gAxes, obj.colormapLimits);
            catch % There is a problem with the limits we tried to enforce
                caxis(obj.gAxes, 'auto');
                obj.sendWarning(['Assigned colorbar limits were problematic.\n' ...
                    'Limits were set automatically, instead.']);
            end
            
            % Get current stage position
           if isempty(obj.cursor)
                % If current cursor does not exist (for some reason)
                warning('This shouldn''t have happenned')
                fig = ancestor(obj.gAxes, 'figure');
                obj.cursor = datacursormode(fig);
                set(obj.cursor, 'UpdateFcn', @obj.cursorMarkerDisplay);
            end
            
            obj.clearCursorData;    % left outside of updateDataCursor(obj), so that zoom bar is not deleted
            obj.updateDataCursor;
            if obj.runCPP
                % leave the previous ccp box
                % update the ccp
                obj.drawRectangle(obj.cpproi);
                obj.RunCPP;
            else
                delete(findall(gca, 'Type','rectangle'));
            end
            obj.sendEventCPPUpdated();
        end

        function [data, label] = getDataForPlotting(obj)
            label = 'power';
            if size(obj.mData, 3) == 2 % Contrast Image
                    withoutMW = obj.mData(:,:,1);
                    withMW = obj.mData(:,:,2);
                switch obj.contrastType
                    case 1 % Difference
                        data = withoutMW - withMW;
                        label = 'kcps difference';
                    case 2 % Ratio
                        data = withMW./withoutMW;
                        label = 'kcps ratio';
                    case 3 % Without MW
                        data = withoutMW;
                    case 4 % With MW
                        data = withMW;
                end
            else
                data = obj.mData;
            end
        end

        %%%% Data Cursor methods %%%%
        function clearCursorData(obj)
            % Clear the cursor data between passing from one cursor type to
            % another. To avoid collision.
            
            % Stop zoom if active
            % (uses undocumented feature)
            global GETRECT_H1
            if ~isempty(GETRECT_H1) && ishghandle(GETRECT_H1)
                set(GETRECT_H1, 'UserData', 'Completed');
            end
            
            if isempty(obj.cursor)
                % If current cursor does not exist (for some reason)
                warning('This shouldn''t have happenned')
                fig = ancestor(obj.gAxes, 'figure');
                obj.cursor = datacursormode(fig);
            end
            obj.cursor.removeAllDataCursors;
            set(obj.cursor, 'Enable', 'off');
            
            % Remove drawn limits, if exists
            if ~isempty(obj.gLimits)
                delete(obj.gLimits);
            end
            
            % Disable button press
            set([obj.gAxes; obj.gAxes.Children], 'ButtonDownFcn', '');
        end
        
        function drawRectangle(obj, pos)
            % Draw rectangle
            if HandleHelper.isType(obj.gLimits, 'rectangle')
                obj.gLimits.Position = pos;
            else
                obj.gLimits = rectangle(obj.gAxes, ...
                    'Position', pos, ...
                    'EdgeColor', 'g', ...
                    'LineWidth', 1, ...
                    'LineStyle', '-.', ...
                    'HitTest', 'Off');
            end
        end

        function updateDataCursor(obj, action)
            % Needs to happen only when everything else finished, whether
            % by scanning or loading
            %
            % action - string. One of obj.CURSOR_OPTIONS

            if isempty(obj.cursor)
                % Nothing to do here
                return
            end
            
            if ~exist('action', 'var')
                actionIndex = 1;    % Marker is default
            else
                actionIndex = find(strcmp(action, obj.CURSOR_OPTIONS));
            end
            switch actionIndex
                case 1      % Display cursor with specific data tip
                    set(obj.cursor, 'Enable', 'on')
                    obj.cursor.UpdateFcn = @obj.cursorMarkerDisplay;
                case 2      % Create a rectangle on the selected area, and update the GUI scanParams's min and max values accordingly
                    obj.clearCursorData;
                    obj.updataDataByZoom;
                case 3      % Move the stage to selected location
                    set(obj.cursor, 'Enable', 'off')
                    set([obj.gAxes; obj.gAxes.Children], 'ButtonDownFcn', @obj.setLocationFromCursor);
            end
        end

        function txt = cursorMarkerDisplay(obj, ~, event_obj)
            % Displays the location of the cursor on the plot and the kcps
            % (the color level from the colormap)
            
            % Displays the location of the cursor on the plot and the kcps
            % (the color level from the colormap)
            
            cameradisplay = getObjByName(CameraDisplay.NAME);
            if isempty(cameradisplay); throwBaseObjException(CameraDisplay.NAME); end
            
            if ~cameradisplay.isDataAvailable
                txt = '';
                EventStation.anonymousWarning('Image is empty');
                return
            end
            
           
            firstAxis = 'x';	
            secondAxis = 'y';
            
            % Customizes text of data tips
            data = getimage(obj.gAxes);
            [~, label] = cameradisplay.getDataForPlotting;
            pos = event_obj.Position;
            
            
            dataIndex = get(event_obj, 'DataIndex');
            level = data(dataIndex);
            txt = {sprintf('(%s,%s) = (%.3f, %.3f)\n%.1f %s', ...
                firstAxis, secondAxis,...
                pos(1), pos(2), level, label)};
            
        end
        
        function updataDataByZoom(obj)
            % Draw the rectangle on the selected area on the plot,
            % and update the GUI with the max and min values
            
            if ~obj.isDataAvailable      % nothing to zoom to
                EventStation.anonymousWarning('Image is empty');
                return
            end
            
            % "try" getting user input
            warning('off','all');
            rect = getrect(obj.gAxes);
            warning('on','all');
            if rect(3) == 0; return; end  % Selection has no width. No use in continuing
            
            % Draw, according to the dimensions of the image
            if rect(4) == 0     % Selection has no height
                return
            end
            obj.drawRectangle(rect);
            % rect(1)==horizontal position, rect(2)==vertical position
            % rect(3)==width;	rect(4)==height
            rect = round(rect);
            obj.cpproi = rect;
            xstart = rect(1) - obj.roi(1);
            ystart = rect(2) - obj.roi(2);
%             obj.roi = [rect(1) rect(2) rect(3) rect(4)];
            data = getimage(obj.gAxes);
            zoomdata = data(ystart:ystart+rect(4), xstart:xstart+rect(3));
            axis1 = rect(1):(rect(1)+rect(3));
            axis2 = rect(2):(rect(2)+rect(4));
            botLabel = obj.mLabelBot;
            leftLabel = obj.mLabelLeft;
            phAxes = {axis1, axis2};
            extra = EventExtraImageUpdated(zoomdata, phAxes, botLabel, leftLabel, obj.initialroi);
%             extra = struct(scanResults, zoomdata, getFirstAxis, axis1,getSecondAxis, axis2, botLabel, botLabel, leftLabel, leftLabel);
            newstruct = obj.ScanStructToInternal(extra);
            obj.update(newstruct);
        end


        function ZoomOut(obj)
            ROI = obj.initialroi;
            Data = obj.initialdata;
            axis1 = ROI(1):(ROI(1)+ROI(3));
            axis2 = ROI(2):(ROI(2)+ROI(4));
            phAxes = {axis1, axis2};
            botLabel = obj.mLabelBot;
            leftLabel = obj.mLabelLeft;
            extra = EventExtraImageUpdated(Data, phAxes, botLabel, leftLabel, obj.initialroi);
%             extra = struct(scanResults, Data, getFirstAxis, axis1,getSecondAxis, axis2, botLabel, botLabel, leftLabel, leftLabel);
            newstruct = obj.ScanStructToInternal(extra);
            obj.update(newstruct);
        end

        % for cpp calculation for each acquisition need to specify a
        % conversion factor of digital power to physical power

        function CPPBox(obj)
            % draws a box on the image for counts per pixel calculation
            if ~obj.isDataAvailable      % nothing to zoom to
                EventStation.anonymousWarning('Image is empty');
                return
            end
            
            % "try" getting user input
            warning('off','all');
            delete(findall(gca, 'Type','rectangle'));
            rect = getrect(obj.gAxes);
            warning('on','all');
            if rect(3) == 0; return; end  % Selection has no width. No use in continuing
            
            % Draw, according to the dimensions of the image
            if rect(4) == 0     % Selection has no height
                return
            end
            obj.drawRectangle(rect);
            obj.cpproi = round(rect);
        end

        function RunCPP(obj)
            data = obj.getDataForPlotting;
            if isempty(obj.cpproi)|| ~compareVectors(obj.cpproi, obj.roi)
                obj.cpproi = obj.roi;
            end
           function isInside = compareVectors(roi1, roi2)
                % Check that both are 1x4 vectors
                if numel(roi1) ~= 4 || numel(roi2) ~= 4
                    error('Both input vectors must be of size 1x4.');
                end
            
                % Extract coordinates and dimensions
                x1 = roi1(1); y1 = roi1(2); w1 = roi1(3); h1 = roi1(4);
                x2 = roi2(1); y2 = roi2(2); w2 = roi2(3); h2 = roi2(4);
            
                % Check if ROI1 is fully within ROI2
                isInside = (x1 >= x2) && ...
                           (y1 >= y2) && ...
                           (x1 + w1 <= x2 + w2) && ...
                           (y1 + h1 <= y2 + h2);
            end

            reldata = data(obj.cpproi(2):obj.cpproi(2)+obj.cpproi(4), obj.cpproi(1):obj.cpproi(1)+obj.cpproi(3));
            obj.CPP = mean(reldata, "all");
        end


        

         %% Helper methods
        function sendEventImageUpdated(obj)
            obj.sendQueuedEvent(struct(obj.EVENT_IMAGE_UPDATED, true));
        end

        function sendEventCPPUpdated(obj)
            obj.sendEvent(struct(obj.EVENT_CPP_UPDATED, true));
        end
        
        function tf = isDataAvailable(obj)
            tf = ~isempty(obj.mData);
        end
        
        function addGraphicAxes(obj, gAxes)
            % "Setter" for the axes, when they are created in the GUI
            if ~(isgraphics(gAxes) && isvalid(gAxes))
                obj.sendWarning('Graphic Axes were not created. Plotting is unavailable');
                return
            end
            
            obj.gAxes = gAxes;
            fig = ancestor(obj.gAxes,'figure');
            obj.cursor = datacursormode(fig);
            set(obj.cursor,'UpdateFcn',@obj.cursorMarkerDisplay);
        end

        function checkGraphicAxes(obj)
            if exist('obj.gAxes', 'var') && ~(isgraphics(obj.gAxes) && isvalid(obj.gAxes))
                % gAxes are no longer available, so we discard them
                obj.gAxes = [];
                obj.cursor = [];
            end
        end
        
        function fig = copyToFigure(obj, isVisible)
            % isVisible - logical. Should we create the figure as visible,
            % to begin with
            if ~exist('isVisible', 'var') || isVisible
                fig = figure;
            else
                fig = figure('Visible', 'off');
            end

            newAxes = copyobj(obj.gAxes, fig);

            c = colorbar(newAxes);
            xlabel(c, 'power')            
            try
                notes = SaveLoad.getInstance(Savable.CATEGORY_IMAGE).mNotes;
                title(notes); % Set the notes as the figure title
            catch err
                EventStation.anonymousWarning(err.message)
            end
        end

        %% Saving
        function fullpath = savePlottingImage(obj, folder, filename)
            % Create a new invisible figure, and than save it with a same
            % filename.
            %
            % Input:
            %   folder - string. the path.
            %   filename - string. the file that was saved by the SaveLoad
            %
            % Output:
            % fullpath - the fullpath of the image file that was saved
            
            if isempty(obj.mData); return; end
            
            isVisible = false;
            figureInvis = obj.copyToFigure(isVisible);
            
            filename = PathHelper.removeDotSuffix(filename);
            fullpath = PathHelper.joinToFullPath(folder, filename);
            
            %%% Save image (.png)
            fullPathImage = [fullpath '.' CameraDisplay.IMAGE_FILE_SUFFIX];
            saveas(figureInvis, fullPathImage);
            
            %%% Save figure (.fig)
            % The figure is saved as invisible, but we set its creation
            % function to set it as visible
            set(figureInvis, 'CreateFcn', 'set(gcbo, ''Visible'', ''on'')'); % No other methods of specifying the function seemed to work...
            savefig(figureInvis, fullpath)
            
            %%% close the figure
            close(figureInvis);
        end
    end
    methods (Static)
        function init
            replaceBaseObject(CameraDisplay);  % in base object map
        end
        
        function limits = calcColormapLimits(data)
            % Calculate auto-limits from data.
            if all(isinf(data(:))) || all(data(:) == 0)
                limits = [0 0];     % No information.
                return
            end
            
            maxValue = max(max(data(~isinf(data))));
            minValue = min(min(data(data ~= 0)));
            limits = [minValue maxValue];
        end
        
        function newStruct = ScanStructToInternal(scanStruct)
            % Converts a struct, as output by CameraCapture to the way it is
            % represented within this class (CameraDisplay)
            newStruct.mData = scanStruct.image;
            newStruct.mFirstAxis = scanStruct.getFirstAxis;
            newStruct.mSecondAxis = scanStruct.getSecondAxis;
            newStruct.mLabelBot = scanStruct.botLabel;
            newStruct.mLabelLeft = scanStruct.leftLabel;
            newStruct.initialroi = scanStruct.initialroi;
        end
    end


        

   
    
    %% Getters (for backward compatibility)
    methods 
        function limits = get.colormapLimits(obj)
            if isnumeric(obj.colormapLimits) && (length(obj.colormapLimits) == 2)
                limits = obj.colormapLimits;
            elseif obj.isDataAvailable
                limits = obj.calcColormapLimits(obj.mData);
            else
                limits = [0 1];
            end
        end
        
        function tf = get.colormapAuto(obj)
            % The second condition in this 'if' statement is needed since
            % true ~= 1, but we do want it to be accepted.
            if islogical(obj.colormapAuto) || obj.colormapAuto == 1
                tf = obj.colormapAuto;
            else
                tf = false;
            end
        end
    end

     %% overriding from Savable
    methods (Access = protected)
        function outStruct = saveStateAsStruct(obj, category, type)
            % Saves the state as struct. if you want to save stuff, make
            % (outStruct = struct;) and put stuff inside. If you dont
            % want to save, make (outStruct = NaN;)
            %
            % category - string. Some objects saves themself only with
            %                    specific category (image/experiments/etc.)
            % type - string.     Whether the objects saves at the beginning
            %                    of the run (parameter) or at its end (result)
            if ~strcmp(category, Savable.CATEGORY_IMAGE) || ~strcmp(type, Savable.TYPE_RESULTS)
                outStruct = NaN;
                return
            end
            
            if isempty(obj.mData)
                outStruct = NaN;
                return
            end
            
            outStruct = struct();
            propNameCell = obj.getAllNonConstProperties();
            for i = 1: length(propNameCell)
                propName = propNameCell{i};
                outStruct.(propName) = obj.(propName);
            end
            
        end
        
        function loadStateFromStruct(obj, savedStruct, category, subCategory)
            % Loads the state from a struct.
            % To support older versoins, always check for a value in the
            % struct before using it. view example in the first line.
            % subCategory - string. could be empty string

            if ~strcmp(category, Savable.CATEGORY_IMAGE); return; end
            if ~any(strcmp(subCategory, {Savable.SUB_CATEGORY_DEFAULT})); return; end
            
            hasChanged = false;     % initialize
            for propNameCell = obj.getAllPropertiesThisClassDefined()
                propName = propNameCell{:};
                if isfield(savedStruct, propName)
                    obj.(propName) = savedStruct.(propName);
                    hasChanged = true;
                    break       % If even one has changed, that's enough
                end
            end
            if hasChanged
                obj.update(savedStruct);
            end
        end
        
        function string = returnReadableString(obj, savedStruct) %#ok<INUSD>
            % Return a readable string to be shown. If this object
            % doesn't need a readable string, make (string = NaN;) or
            % (string = '');
            string = NaN;
        end
    end
    
    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            % Check if event is "loaded file to SaveLoad" and need to show the image
            if strcmp(event.creator.name, SaveLoadCatImage.NAME) ...
                    && isfield(event.extraInfo, SaveLoad.EVENT_LOAD_SUCCESS_FILE_TO_LOCAL)
                % Need to load the image!
                category = Savable.CATEGORY_IMAGE;
                subcat = Savable.SUB_CATEGORY_DEFAULT;
                saveLoad = event.creator;
                struct = saveLoad.getStructToSavable(obj);
                if ~isempty(struct)
                    obj.loadStateFromStruct(struct, category, subcat);
                end
            end
            
            % Check if event is "SaveLoad wants to save a file" and need to
            % save an image file of the figure
            if strcmp(event.creator.name, SaveLoadCatImage.NAME) ...
                    && isfield(event.extraInfo, SaveLoad.EVENT_SAVE_SUCCESS_LOCAL_TO_FILE) ...
                    && ~isempty(obj.mData)
                
                folder = event.extraInfo.(SaveLoad.EVENT_FOLDER);
                filename = event.extraInfo.(SaveLoad.EVENT_FILENAME);
                obj.savePlottingImage(folder, filename);
            end
            % add camera related events
            % Check if event is "image acquisition"
            if strcmp(event.creator.name, CameraCapture.NAME) ...
                    && isfield(event.extraInfo, CameraCapture.EVENT_ACQUIRE_STARTED)
                % Make sure the cursor is in marker mode
                obj.updateDataCursor;
            end

            %check if event is new image acquired
            if strcmp(event.creator.name, CameraCapture.NAME) ...
                    && isfield(event.extraInfo, CameraCapture.EVENT_IMAGE_UPDATED)
                
                extra = event.extraInfo.(CameraCapture.EVENT_IMAGE_UPDATED);
                obj.initialdata = extra.image;
                % "extra" now points to an object of class EventExtraImageUpdated,
                % but we want it in the in-house format
                extraInternal = obj.ScanStructToInternal(extra);
                obj.update(extraInternal);
                drawnow
                return % To avoid drawing crosshairs twice
            end
        end
    end

end

    




