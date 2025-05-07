classdef ImageScanResult < Savable & EventSender & EventListener
    %IMAGESCANRESULT stores the last scan-image
    %   it is savable, so the last image can be saved and opened
    
    % Hopefully, no other figure will need such functionality. Otherwise,
    % this class should be abstracted, and a child class will need to
    % implement it for scan result.
    
    properties (GetAccess = public, SetAccess = private)
        mData = [];     % double. Scan results
        mDimNumber = 2; % intgeger. Number of dimensions of scan. Has default value;
        mFirstAxis      % vector
        mSecondAxis     % vector or point
        mStageName      % string
        mAxesString     % string
        mLabelBot       % string
        mLabelLeft      % string
        mHist = []      % double. Scan lifetime results.
        mFocusGrade
    end
    
    properties (Access = private) % For plotting over Image
        gAxes
        gLimits = [];           % graphic handle; stores limits drawn onto image (for zoom)
        crosshairs = struct;    % struct of graphic handles, for the elements of the crosshairs\arrow for current position
        cursor                  % datacursor handle. Stores the information about recent mouse actions
    end
    
    properties
        plotStyle               % integer. Index for value in obj.PLOT_STYLE_OPTIONS (either _1D or _2D)
        colormapType            % integer. Index for value in COLORMAP_OPTIONS
        colormapLimits = [0 1]; % 2x1 double
        colormapAuto = true;    % logical
        cursorType              % integer. Index for value in CURSOR_OPTIONS
        contrastType            % integer. Index for value in CONTRAST_OPTIONS
        imageType               % integer. Index for value in IMAGE_OPTIONS
        scanType                % integer. for widefield scans
    end
    
    properties (Constant)
        NAME = 'imageScanResult'
        IMAGE_FILE_SUFFIX = 'png'
        FIGURE_FILE_SUFFIX = 'fig'
        
        % Events
        EVENT_IMAGE_UPDATED = 'imageUpdated';

        % Figure Options
        PLOT_STYLE_OPTIONS_1D = {'Normal', 'Square'};
        PLOT_STYLE_OPTIONS_2D = {'Normal', 'Equal', 'Square'};
        COLORMAP_OPTIONS = {'Pink', 'Parula', 'HSV', 'Hot', 'Cool', ...
            'Spring', 'Summer', 'Autumn', 'Winter', ...
            'Gray', 'Bone', 'Copper', 'Lines'};
        CURSOR_OPTIONS = {'Marker', 'Zoom', 'Location'};
        CONTRAST_OPTIONS = {'Difference', 'Ratio', 'Without MW', 'With MW'};
        SCAN_OPTIONS = {'Average counts', 'Focus Grade'}
        IMAGE_OPTIONS = {'kcps', 'Lifetime'};
    end
    
    methods
        function obj = ImageScanResult
            obj@Savable(ImageScanResult.NAME);
            obj@EventSender(ImageScanResult.NAME);
            obj@EventListener({SaveLoadCatImage.NAME, StageScanner.NAME});
            
            obj.plotStyle = 2;      % Equal
            obj.colormapType = 2;   % Parula
            obj.cursorType = 1;     % Marker
            obj.contrastType = 1;   % Difference
            obj.imageType = 1;      % kcps
            obj.scanType = 1;       % widefield scan
        end
        
        %% Updating Image
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
                obj.mDimNumber = newStruct.mDimNumber;
                obj.mFirstAxis = newStruct.mFirstAxis;
                obj.mSecondAxis = newStruct.mSecondAxis;
                obj.mLabelBot = newStruct.mLabelBot;
                obj.mLabelLeft = newStruct.mLabelLeft;
                
                if isfield(newStruct, 'mHist') % Only available in new scans in setup 4 (29.9.20)
                    obj.mHist = newStruct.mHist;
                else
                    obj.mHist = [];
                end
                
                if isfield(newStruct, 'mFocusGrade') % Only available for widefield images
                    obj.mFocusGrade = newStruct.mFocusGrade;
                else
                    obj.mFocusGrade = [];
                end
                

                % In a previous version we did not save mStageName and
                % mAxesString. For compatability, we need:
                if isfield(newStruct, 'mStageName')
                    obj.mStageName = newStruct.mStageName;
                    if isfield(newStruct, 'mAxesString')
                        obj.mAxesString = newStruct.mAxesString;
                    else
                        obj.sendWarning('This should not have happenned...')
                    end
                else
                    % We are loading an old version, so maybe we can get
                    % missing parameters from current system
                    obj.sendWarning(['Save file does not contain stage name.\n', ...
                        'We keep using the old stage, and hope for the best.'])
                end
            elseif ~obj.isDataAvailable
                % No data is available, neither externally nor internally.
                return
            end
            
            [data, label] = obj.getDataForPlotting;
            
            % We need to calculate this before sending event (so as to update the header):
            if obj.colormapAuto
                obj.colormapLimits = obj.calcColormapLimits(data);
            end
            
            switch obj.mDimNumber
                case 2
                    AxesHelper.fill(obj.gAxes, data, obj.mDimNumber, obj.mFirstAxis, obj.mSecondAxis, obj.mLabelBot, obj.mLabelLeft, [], label);
                case 1
                    AxesHelper.fill(obj.gAxes, data, obj.mDimNumber, obj.mFirstAxis, obj.mSecondAxis, obj.mLabelBot, label);
            end
            obj.sendEventImageUpdated();
            obj.imagePostProcessing;
        end
        
        function imagePostProcessing(obj)
            %%%% After plotting is done, we can make some slight changes
            
            % Plot style
            switch obj.mDimNumber
                case 1
                    styleOptions = obj.PLOT_STYLE_OPTIONS_1D;
                    if obj.plotStyle == 3
                        % Not available anymore
                        obj.plotStyle = 2;
                    end
                case 2
                    styleOptions = obj.PLOT_STYLE_OPTIONS_2D;
                    % Switching from 1D to 2D will get us in Equal axes.
                    % Not great, but to worth fixing, for now.
            end
            
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
            try     % This will not happen without an operating stage
                stage = getObjByName(obj.mStageName);
                    if isempty(stage); throwBaseObjException(obj.mStageName); end
                pos = stage.Pos(obj.mAxesString);
                % Draw
                if isempty(obj.cursor)
                    % If current cursor does not exist (for some reason)
                    warning('This shouldn''t have happenned')
                    fig = ancestor(obj.gAxes, 'figure');
                    obj.cursor = datacursormode(fig);
                    set(obj.cursor, 'UpdateFcn', @obj.cursorMarkerDisplay);
                end
                gLimitsVector = axis(obj.gAxes);   % vector of [x_min x_max y_min y_max]
                obj.drawCrosshairs(gLimitsVector, pos)
            catch err
                obj.sendWarning('Unable to set crosshairs');
                err2warning(err)
            end
            
            obj.clearCursorData;    % left outside of updateDataCursor(obj), so that zoom bar is not deleted
            obj.updateDataCursor;
        end
        
        function [data, label] = getDataForPlotting(obj)
            switch obj.imageType
                case 1 % Normal kcps image
                    label = 'kcps';
                    if size(obj.mData, obj.mDimNumber + 1) == 2 % Contrast Image
                        switch obj.mDimNumber
                            case 2
                                withoutMW = obj.mData(:,:,1);
                                withMW = obj.mData(:,:,2);
                            case 1
                                withoutMW = obj.mData(:,1);
                                withMW = obj.mData(:,2);
                        end
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
                    if obj.scanType == 2
                        data = obj.mFocusGrade;
                    end
                case 2 % Lifetime image
                    label = 'ns';
                    if isempty(obj.mHist) % Just incase it is some leftover, switch back to normal kcps image.
                        obj.imageType = 1;
                        [data, label] = getDataForPlotting(obj);
                        return
                    end
                    % Uses RLD method from https://en.wikipedia.org/wiki/Fluorescence-lifetime_imaging_microscopy#Analysis                    
                    
                    % Find maximum and get rid of the data before it (get
                    % rid of IRF)
                    switch obj.mDimNumber
                        case 2
                            [~, maxI] = max(obj.mHist(:,:,:), [], 3);
                            maxI = round(mean(mean(maxI)));
                        case 1
                            [~, maxI] = max(obj.mHist(:,:), [], 2);
                            maxI = round(mean(maxI));
                    end
                    
                    spcm = getObjByName(Spcm.NAME);
                    % Total time in ps:
                    T = spcm.binWidth*(spcm.nBins - maxI);
                    
                    dt = (T/2) / 1000; % Half of the time, in ns.
                    midI = round((spcm.nBins + maxI)/2);
                    
                    switch obj.mDimNumber
                        case 2
                            D0 = sum(obj.mHist(:,:,1:midI), 3) * dt;
                            D1 = sum(obj.mHist(:,:,midI+1:end), 3) * dt;
                        case 1
                            D0 = sum(obj.mHist(:,1:midI), 2) * dt;
                            D1 = sum(obj.mHist(:,midI+1:end), 2) * dt;
                    end
                    data = dt ./ log(D0./D1);
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
        
        function drawLimitBar(obj,pos)
            % Draw limit bar
            if ~isempty(obj.gLimits)
                delete(obj.gLimits);
            end
            dx = pos(3)/2;
            xPos = pos(1) + dx;         % the center of the bar
            yPos = pos(2) + pos(4)/2;	% position of bar in the middle of selected rectangle
            
            hold(obj.gAxes,'on');
            obj.gLimits = errorbar(obj.gAxes, ...
                xPos,yPos, ...
                dx, 'horizontal', ...
                'Color', 'r', ...
                'LineWidth', 1);
            hold(obj.gAxes,'off');
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
            
            imageScanResult = getObjByName(ImageScanResult.NAME);
            if isempty(imageScanResult); throwBaseObjException(ImageScanResult.NAME); end
            
            if ~imageScanResult.isDataAvailable
                txt = '';
                EventStation.anonymousWarning('Image is empty');
                return
            end
            
            % Get scanning parameters
            dim = imageScanResult.mDimNumber;
            scanAxes = imageScanResult.mAxesString;
            firstAxis = scanAxes(1);	% char (either 'x', 'y' or 'z')
            secondAxis = scanAxes(end); % char (either 'x', 'y' or 'z')
            
            % Customizes text of data tips
            data = getimage(obj.gAxes);
            [~, label] = imageScanResult.getDataForPlotting;
            pos = event_obj.Position;
            
            if dim == 1
                txt = sprintf('%s = %.3f\n%.1f %s', firstAxis, pos(1), pos(2), label);
            else
                dataIndex = get(event_obj, 'DataIndex');
                level = data(dataIndex);
                txt = {sprintf('(%s,%s) = (%.3f, %.3f)\n%.1f %s', ...
                    firstAxis, secondAxis,...
                    pos(1), pos(2), level, label)};
            end
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
            dim = obj.mDimNumber;
            switch dim
                case 1
                    obj.drawLimitBar(rect);
                case 2
                    if rect(4) == 0     % Selection has no height
                        return
                    end
                    obj.drawRectangle(rect);
                otherwise
                    EventStation.anonymousError('Can''t fetch limits in higher dimensions');
            end
            
            stage = getObjByName(obj.mStageName);
            if isempty(stage)
                EventStation.anonymousError('Can''t set new scan parameters, since there is no relevant stage');
            end
            assert(stage.isScannable)
            
            for i = 1:dim
                axisIndex = stage.getAxis(obj.mAxesString(i));
                
                stage.scanParams.from(axisIndex) = rect(i);            % rect(1)==horizontal position, rect(2)==vertical position
                stage.scanParams.to(axisIndex) = rect(i)+rect(i+2);    % rect(3)==width;	rect(4)==height
            end
            stage.sendEventScanParamsChanged;
        end
        
        function drawCrosshairs(obj, limits, pos)
            % Draws an arrow or a cross on the plot on a selected position
            %       limits: limits of the view in the axes,
            %               [x_min x_max y_min y_max]
            %       pos:    current stage position, [x] or [x y]
            %
            %       Note: this function assumes the input arguments have
            %       been validated.
            
            % Get properties of axes
            xLimits = limits(1:2);
            yLimits = limits(3:4);
            dim = length(pos);
            
            % If 1D, arbitrarily set the position in the middle
            if dim == 1
                pos(2) = (yLimits(2) + yLimits(1))/2;
            end
            
            %%%% Deciding on which area the position is located %%%%
            % Trinary encoding of the position yields:
            %-----------------------%
            %  2,0  |  2,1  |  2,2  |
            %-----------------------|
            %  1,0  |  1,1  |  1,2  |
            %-----------------------|
            %  0,0  |  0,1  |  0,2  |
            %-----------------------%
            % trinary receives:
            %       x, scalar
            %       I, vector representing interval
            % returns:
            %   0, if x < I,
            %   1, if x in I (including edges)
            %   2, if x > I
            quadrant = [trinary(pos(1),xLimits) , trinary(pos(2),yLimits)];
            
            % Delete previous and recreate correct handles
            hold(obj.gAxes,'on'); % Keep image while creating crosshair/arrow
            
            if all(quadrant == [1 1]) % Inside
                if isfield(obj.crosshairs, 'arrowHandle')
                    delete(obj.crosshairs.arrowHandle);
                end
                if ~isfield(obj.crosshairs, 'xLineHandle') || ~isvalid(obj.crosshairs.xLineHandle)
                    obj.crosshairs.xLineHandle = line(obj.gAxes, ...
                        [0 0], [0 0], 'Color', 'b', 'LineWidth', 0.5, 'HitTest', 'Off');
                end
                if ~isfield(obj.crosshairs, 'yLineHandle') || ~isvalid(obj.crosshairs.yLineHandle)
                    obj.crosshairs.yLineHandle = line(obj.gAxes, ...
                        [0 0], [0 0], 'Color', 'b', 'LineWidth', 0.5, 'HitTest', 'Off');
                end
                
                hold(obj.gAxes,'off'); % Allow picture to change when needed
                
                set(obj.crosshairs.xLineHandle, 'XData', xLimits);
                set(obj.crosshairs.xLineHandle, 'YData', [pos(2) pos(2)]);
                set(obj.crosshairs.yLineHandle, 'XData', [pos(1) pos(1)]);
                set(obj.crosshairs.yLineHandle, 'YData', yLimits);
                
                % If 1D, don't draw horizontal line and change color to black
                if dim == 1
                    delete(obj.crosshairs.xLineHandle);
                    set(obj.crosshairs.yLineHandle, 'Color', 'k') 
                end
                
            else % Outside
                if isfield(obj.crosshairs, 'xLineHandle')
                    delete(obj.crosshairs.xLineHandle);
                end
                if isfield(obj.crosshairs,'yLineHandle')
                    delete(obj.crosshairs.yLineHandle);
                end
                if isfield(obj.crosshairs, 'arrowHandle')
                    if (dim == 1 && ~isa(obj.crosshairs.arrowHandle,'matlab.graphics.primitive.Line')) ...
                            || (dim == 2 && ~isa(obj.crosshairs.arrowHandle,'matlab.graphics.chart.primitive.Quiver'))
                        delete(obj.crosshairs.arrowHandle);
                    end
                end
                if ~isfield(obj.crosshairs, 'arrowHandle') || ~ishandle(obj.crosshairs.arrowHandle)
                    if dim == 1
                        obj.crosshairs.arrowHandle = line(obj.gAxes, ...
                        [0 0], [0 0], 'Color', 'k', 'LineWidth', 1, 'HitTest', 'Off', 'MarkerSize', 10);
                    else
                        obj.crosshairs.arrowHandle = quiver(obj.gAxes, 0, 0, 0, 0, 'Color', 'b', ...
                        'LineWidth', 1, 'MaxHeadSize', 10, 'HitTest', 'Off');
                    end
                end
                
                hold(obj.gAxes,'off'); % Allow picture to change when needed
                
                % Draw arrow according to position
                if dim == 1
                    switch quadrant(1)
                        case 0 % left column
                            set(obj.crosshairs.arrowHandle, 'XData', [xLimits(1), xLimits(1)]);
                            set(obj.crosshairs.arrowHandle, 'YData', [pos(2), pos(2)]);
                            set(obj.crosshairs.arrowHandle, 'Marker', '<')
                        case 2 % right column
                            set(obj.crosshairs.arrowHandle, 'XData', [xLimits(2), xLimits(2)]);
                            set(obj.crosshairs.arrowHandle, 'YData', [pos(2), pos(2)]);
                            set(obj.crosshairs.arrowHandle, 'Marker', '>')
                    end
                else
                    row = quadrant(1);
                    switch row
                        case 0 % left column
                            set(obj.crosshairs.arrowHandle, 'XData', xLimits(1)+(xLimits(2)-xLimits(1))/10);
                            set(obj.crosshairs.arrowHandle, 'UData', (xLimits(1)-xLimits(2))/10);
                        case 1 % middle column
                            set(obj.crosshairs.arrowHandle, 'XData', pos(1));
                            set(obj.crosshairs.arrowHandle, 'UData', 0);
                        case 2 % right column
                            set(obj.crosshairs.arrowHandle, 'XData', xLimits(2)+(xLimits(1)-xLimits(2))/10);
                            set(obj.crosshairs.arrowHandle, 'UData', (xLimits(2)-xLimits(1))/10);
                    end
                    
                    column = quadrant(2);
                    switch column
                        case 0 % in bottom row
                            set(obj.crosshairs.arrowHandle, 'YData', yLimits(1)+(yLimits(2)-yLimits(1))/10);
                            set(obj.crosshairs.arrowHandle, 'VData', (yLimits(1)-yLimits(2))/10);
                        case 1 % middle row
                            set(obj.crosshairs.arrowHandle, 'YData', pos(2));
                            set(obj.crosshairs.arrowHandle, 'VData', 0);
                        case 2 % top row
                            set(obj.crosshairs.arrowHandle, 'YData', yLimits(2)+(yLimits(1)-yLimits(2))/10);
                            set(obj.crosshairs.arrowHandle, 'VData', (yLimits(2)-yLimits(1))/10);
                    end
                end
            end
        end
        
        function setLocationFromCursor(obj, ~, ~)
            if isempty(obj.gAxes.Children)
                EventStation.anonymousWarning('Image is empty');
                return
            end
            
            % Get everything we need
            stage = getObjByName(obj.mStageName);
            if isempty(stage); throwBaseObjException(obj.mStageName); end
            pos = obj.gAxes.CurrentPoint(1, 1:obj.mDimNumber);

            % Now move to the corresponding location
            stage.move(obj.mAxesString, pos);    % This should update the datacursor, by relevant event
        end
        
        %% Helper methods
        function sendEventImageUpdated(obj)
            obj.sendQueuedEvent(struct(obj.EVENT_IMAGE_UPDATED, true));
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
            if obj.mDimNumber == 2
                c = colorbar(newAxes);
                xlabel(c, 'kcps')
            end
            
            try
                notes = SaveLoad.getInstance(Savable.CATEGORY_IMAGE).mNotes;
                title(notes); % Set the notes as the figure title
            catch err
                EventStation.anonymousWarning(err.message)
            end
        end
        
        function [stageName, axesString] = compatibilityHelper1(obj, struct) %#ok<INUSL>
            % Because of changes in saved struct, we need to [try to]
            % recover these variables
            scanner = getObjByName(StageScanner.NAME);
            stageName = scanner.mStageName;
            switch struct.mDimNumber
                case 1
                    axesString = struct.mLabelBot(1);
                case 2
                    axesString = [struct.mLabelBot(1), struct.mLabelLeft(1)];
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
            fullPathImage = [fullpath '.' ImageScanResult.IMAGE_FILE_SUFFIX];
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
            replaceBaseObject(ImageScanResult);  % in base object map
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
            % Converts a struct, as output by StageScanner to the way it is
            % represented within this class (ImageScanResult)
            newStruct.mData = scanStruct.scan;
            newStruct.mDimNumber = scanStruct.dimNumber;
            newStruct.mFirstAxis = scanStruct.getFirstAxis;
            newStruct.mSecondAxis = scanStruct.getSecondAxis;
            newStruct.mStageName = scanStruct.stageName;
            newStruct.mAxesString = scanStruct.axesString;
            newStruct.mLabelBot = scanStruct.botLabel;
            newStruct.mLabelLeft = scanStruct.leftLabel;
            if isprop(scanStruct, 'scanExtraInfo')
                if isfield(scanStruct.scanExtraInfo, 'hist')
                    newStruct.mHist = scanStruct.scanExtraInfo.hist;
                end
                if isfield(scanStruct.scanExtraInfo, 'FocusGrade')
                    newStruct.mFocusGrade = scanStruct.scanExtraInfo.FocusGrade;
                end
            end
        end
    end
    
    %% Setters
    methods
        function set.mStageName(obj, stageName)
            % The stage might have changed, and we need to start listening to it
            
            % We might not need to do anything, since we are using
            % the same stage.
            if strcmp(stageName, obj.mStageName)
                return
            end
            
            % Check that required stage is available
            newStage = getObjByName(stageName);
            if isempty(newStage)
                obj.sendWarning('New stage is not available. Some things might not work properly.');
            else
                % Switch to new stage
                obj.stopListeningTo(obj.mStageName);
                obj.mStageName = stageName;
                obj.startListeningTo(obj.mStageName);
            end 
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
            
            % Check if event is "scanner started a new scan"
            if strcmp(event.creator.name, StageScanner.NAME) ...
                    && isfield(event.extraInfo, StageScanner.EVENT_SCAN_STARTED)
                % We might need to change our reference stage
                obj.mStageName = event.creator.mStageName;
                % Make sure the cursor is in marker mode
                obj.updateDataCursor;
            end
                    
            
            % Check if event is "scanner has a new line scanned" and need
            % to updated the image
            if strcmp(event.creator.name, StageScanner.NAME) ...
                    && isfield(event.extraInfo, StageScanner.EVENT_SCAN_UPDATED)
                
                extra = event.extraInfo.(StageScanner.EVENT_SCAN_UPDATED);
                % "extra" now points to an object of class EventExtraScanUpdated,
                % but we want it in the in-house format
                extraInternal = obj.ScanStructToInternal(extra);
                obj.update(extraInternal);
                drawnow
                return % To avoid drawing crosshairs twice
            end
            
            % Check if event is "Stage moved" (not by scanning,
            % which would have been caught by previous condition),
            % and redraw crosshairs
            if isfield(event.extraInfo, ClassStage.EVENT_POSITION_CHANGED) ...
                    && strcmp(event.creator.name, obj.mStageName)
                
                % If scanner is running, and there is no point in updating.
                % Crosshairs would really delay it
                scanner = getObjByName(StageScanner.NAME);
                if scanner.mCurrentlyScanning; return; end
                
                stage = getObjByName(obj.mStageName);
                if isempty(stage)
                    % Probably, there is nothing to draw on. Moving on!
                else
                    physAxes = obj.mAxesString;
                    pos = stage.Pos(physAxes);
                    limits = axis(obj.gAxes);   % vector of [x_min x_max y_min y_max]
                    obj.drawCrosshairs(limits, pos)
                end
            end
        end
    end

end