classdef ViewStagePanelScanParams < GuiComponent & EventListener & EventSender
    %VIEWSTAGESCANSCANPARAMS Summary of this class goes here
    %   Detailed explanation goes here
    
    %   todo: possible bug? If someone changes properties of the "scan params" property of
    %   the stage, the stage will not send event and the GUI won't know
    %   about it. How often do people use matlab programatically?
    
    properties
        edtFrom             % 1x3 input text
        edtTo               % 1x3 input text
        edtNumPoints        % 1x3 input text
        cbxFixed            % 1x3 checkbox
        edtFixedPos         % 1x3 input text
        edtScanAround       % 1x3 input text
        btnScanAroundSet    % 1x3 "Set" button
                                
        stageName   % string. the name of the relevant stage
        stageAxes   % string. valid axes of the stage. example: "zx"
    end
    
    properties (Constant)
        SCAN_AROUND_DEFAULT_STRING = '5';
    end
    
    methods
        function obj = ViewStagePanelScanParams(parent, controller, stage)
            obj@GuiComponent(parent, controller);
            obj@EventListener(stage.name);
            obj@EventSender(sprintf('%s%s', stage.name, ' _ panel Scan params'));
            obj.stageName = stage.name;
            obj.stageAxes = stage.availableAxes;
            axesLength = length(stage.availableAxes);
            
            %%%% Scan parameters panel init %%%%
            panelScanParams = uix.Panel('Parent', parent.component,'Title','Scan Paramters', 'Padding', 5);
            gridScanParams = uix.Grid('Parent', panelScanParams, 'Spacing', 5);
            
            % 1st Column - x\y\z labels
            uix.Empty('Parent', gridScanParams);
            for i = 1: axesLength
                uicontrol(obj.PROP_LABEL{:}, 'Parent', gridScanParams, 'String', upper(stage.availableAxes(i)));
            end
            
            
            % 2nd Column - "from"
            uicontrol(obj.PROP_LABEL{:}, 'Parent', gridScanParams, 'String', 'From');  % label
            obj.edtFrom = gobjects(1,axesLength);
            for i = 1: axesLength 
                obj.edtFrom(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', gridScanParams);
            end
            
            % 3rd Column - "to"
            uicontrol(obj.PROP_LABEL{:}, 'Parent', gridScanParams, 'String', 'To');  % label
            obj.edtTo = gobjects(1,axesLength);
            for i = 1: axesLength
                obj.edtTo(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', gridScanParams);
            end
            
            % 4th Column - amount of points
            uicontrol(obj.PROP_LABEL{:}, 'Parent', gridScanParams, 'String', '# Pts');  % label
            obj.edtNumPoints = gobjects(1,axesLength);
            for i = 1: axesLength
                obj.edtNumPoints(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', gridScanParams);
            end
            
            % 5th Column - "Fix" checkboxes
            uicontrol(obj.PROP_LABEL{:}, 'Parent', gridScanParams, 'String', 'Fix');  % label
            obj.cbxFixed = gobjects(1,axesLength);
            for i = 1: axesLength
                obj.cbxFixed(i) = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', gridScanParams);
            end
            
            % 6th Column - "fixed position"
            uicontrol(obj.PROP_LABEL{:}, 'Parent', gridScanParams, 'String', 'Fixed');  % label
            obj.edtFixedPos = gobjects(1,axesLength);
            for i = 1: axesLength
                obj.edtFixedPos(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', gridScanParams);
            end
            
            % 7th Column - "scan around"
            uicontrol(obj.PROP_LABEL{:}, 'Parent', gridScanParams, 'String', 'Scan Around');  % label
            obj.edtScanAround = gobjects(1,axesLength);
            obj.btnScanAroundSet = gobjects(1,axesLength);
            for i = 1: axesLength
                hboxScanAround = uix.HBox('Parent', gridScanParams, 'Spacing', 5, 'Padding', 0);
                obj.edtScanAround(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', hboxScanAround, 'String', obj.SCAN_AROUND_DEFAULT_STRING);
                obj.btnScanAroundSet(i) = uicontrol(obj.PROP_BUTTON{:}, 'Parent', hboxScanAround, 'String', 'Set');
                hboxScanAround.Widths = [40 40];
            end
            
            wftf = 60;  % Width for From, To & Fixed-position
            widthsPanelScanParams = [20 wftf wftf 40 25 wftf 90];
            heightsPanelScanParams = 20;
            for i = 1 : axesLength
                heightsPanelScanParams(end + 1) = 25; %#ok<AGROW>
            end
            panelScanParamsHeight = sum(heightsPanelScanParams) + length(heightsPanelScanParams) * 5 + 25;
            set(gridScanParams, 'Widths', widthsPanelScanParams, 'Heights', heightsPanelScanParams);
            
            
            obj.height = panelScanParamsHeight;
            obj.width = sum(widthsPanelScanParams)+5*length(widthsPanelScanParams) + 10;
            
            
            
            %%%% Set callbacks %%%%
            for i=1 : length(obj.stageAxes)
                set(obj.edtFrom(i), 'Callback', @(h,e)obj.edtFromChangedCallback(i));
                set(obj.edtTo(i), 'Callback', @(h,e)obj.edtToChangedCallback(i));
                set(obj.edtNumPoints(i), 'Callback',@(h,e)obj.edtNumPointsChangedCallback(i));
                set(obj.cbxFixed(i), 'Callback',@(h,e)obj.cbxFixedChangedCallback(i));
                set(obj.edtFixedPos(i), 'Callback', @(h,e)obj.edtFixedChangedCallback(i));
                set(obj.edtScanAround(i), 'Callback', @(h,e)obj.scanAroundCallback(i));
                set(obj.btnScanAroundSet(i), 'Callback', @(h,e)obj.setAroundCallback(i));
            end
            
            %%%% init values into fields %%%%
            obj.refresh();
        end
        
        function edtNumPointsChangedCallback(obj, index)
            % index - int. [1 to length(obj.stageAxes)] which view was changed
            stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
            scanParams = stage.scanParams;
            phAxis = ClassStage.getAxis(obj.stageAxes(index));
            
            edtNumPointsI = obj.edtNumPoints(index);
            if ValidationHelper.isValuePositiveInteger(edtNumPointsI.String)
                scanParams.numPoints(phAxis) = str2double(edtNumPointsI.String);
            else
                edtNumPointsI.String = scanParams.numPoints(phAxis);
                obj.sendError('Number of points isn''t a positive integer! reverting');
            end
            
        end
        
        function cbxFixedChangedCallback(obj, index)
            % index - int. [1 to length(obj.stageAxes)] which view was changed
            stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
            scanParams = stage.scanParams;
            phAxis = ClassStage.getAxis(obj.stageAxes(index));
            
            cbx = obj.cbxFixed(index);
            scanParams.isFixed(phAxis) = cbx.Value;
            obj.colorifyFixed(index);
        end
        
        function scanAroundCallback(obj, index)
            edtScan = obj.edtScanAround(index);
            valueLimStr = edtScan.String;
            if ~ValidationHelper.isValueNonNegative(valueLimStr)
                edtScan.String = obj.SCAN_AROUND_DEFAULT_STRING;
                obj.sendError(sprintf('"Scan Around" (axis %s) value should be non-negative! Reverting to default', obj.stageAxes(index)));
            end
            val = str2double(valueLimStr);
            signifDigits = 1;
            edtScan.String = StringHelper.formatNumber(val, signifDigits);
        end
        
        function setAroundCallback(obj, index)
            % Change the values in the GUI, and call their callbacks that
            % will change it in the stage
            %
            % index - int. [1 to length(obj.stageAxes)] which button was pressed
            
            edtScan = obj.edtScanAround(index);
            valueLimStr = edtScan.String;
            
            signifDigits = 1;
            valueLimHalf = round(str2double(valueLimStr)/2, signifDigits);
            
            stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
            scanParams = stage.scanParams;
            phAxis = ClassStage.getAxis(obj.stageAxes(index));
            
            from = scanParams.fixedPos(phAxis) - valueLimHalf;
            to = scanParams.fixedPos(phAxis) + valueLimHalf;
            obj.edtFrom(index).String = from;
            obj.edtTo(index).String = to;
            obj.edtFromChangedCallback(index);
            obj.edtToChangedCallback(index);
        end
        
        function edtFromChangedCallback(obj, index)
            % index - int. [1 to length(obj.stageAxes)] which view was changed
            stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
            scanParams = stage.scanParams;
            phAxis = ClassStage.getAxis(obj.stageAxes(index));
            
            viewFrom = obj.edtFrom(index);
            if ~ValidationHelper.isStringValueANumber(viewFrom.String)
                viewFrom.String = scanParams.from(phAxis);
                obj.sendError('Only numbers can be accepted! Reverting.');
            end
            from = str2double(viewFrom.String);
            [lowerBound, upperBound] = stage.ReturnLimits(phAxis);
            if ~ValidationHelper.isInBorders(from, lowerBound, upperBound)
                warningMsg = sprintf( ...
                    '"from" (index: %s) is not in bounds! Reverting.\n(bounds: [%d, %d])', ...
                    obj.stageAxes(index), ...
                    lowerBound, ...
                    upperBound);
                from = scanParams.from(phAxis);
                obj.sendWarning(warningMsg);
            elseif from == scanParams.to(phAxis)
                warningMsg = sprintf( ...
                    'Scan over the %s axis starts and ends at the same point!', ...
                    obj.stageAxes(index));
                obj.sendWarning(warningMsg)
            end

            [viewFrom.String, scanParams.from(phAxis)] = StringHelper.formatNumber(from);
        end
        
        function edtToChangedCallback(obj, index)
            % index - int. [1 to length(obj.stageAxes)] which view was changed
            stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
            scanParams = stage.scanParams;
            phAxis = ClassStage.getAxis(obj.stageAxes(index));
            
            viewTo = obj.edtTo(index);
            if ~ValidationHelper.isStringValueANumber(viewTo.String)
                viewTo.String = scanParams.to(phAxis);
                obj.sendError('Only numbers can be accepted! Reverting.');
            end
            to = str2double(viewTo.String);
            [lowerBound, upperBound] = stage.ReturnLimits(phAxis);
            if ~ValidationHelper.isInBorders(to, lowerBound, upperBound)
                warningMsg = sprintf( ...
                    '"to" (index: %s) is not in bounds! Reverting.\n(bounds: [%d, %d])', ...
                    obj.stageAxes(index), ...
                    lowerBound, ...
                    upperBound);
                to = scanParams.to(phAxis);                
                obj.sendWarning(warningMsg);
            elseif to == scanParams.from(phAxis)
                warningMsg = sprintf( ...
                    'Scan over the %s axis starts and ends at the same point!', ...
                    obj.stageAxes(index));
                obj.sendWarning(warningMsg)
            end
            
            [viewTo.String, scanParams.to(phAxis)] = StringHelper.formatNumber(to);
            
        end
        
        function edtFixedChangedCallback(obj, index)
            % index - int. [1 to length(obj.stageAxes)] which view was changed
            stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
            scanParams = stage.scanParams;
            phAxis = ClassStage.getAxis(obj.stageAxes(index));
            
            viewFixed = obj.edtFixedPos(index);
            if ~ValidationHelper.isStringValueANumber(viewFixed.String)
                viewFixed.String = StringHelper.formatNumber(scanParams.fixedPos(phAxis));
                obj.sendError('Only numbers can be accepted! reverting.');
            end
            fixedPos = str2double(viewFixed.String);
            [lowerBound, upperBound] = stage.ReturnLimits(phAxis);
            if ~ValidationHelper.isInBorders(fixedPos, lowerBound, upperBound)
                warningMsg = sprintf( ...
                    '"fixedPos" (index: %s) is not in bounds! Setting it to the bound...\n(bounds: [%d, %d])', ...
                    obj.stageAxes(index), ...
                    lowerBound, ...
                    upperBound);
                obj.sendWarning(warningMsg);
                if fixedPos > upperBound
                    fixedPos = upperBound;
                else
                    fixedPos = lowerBound;
                end
            end
            
            [viewFixed.String, scanParams.fixedPos(phAxis)] = StringHelper.formatNumber(fixedPos);
        end
        
        function colorifyFixed(obj, index)
           % index - int. [1 to length(obj.stageAxes)] which view was changed
           stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
           scanParams = stage.scanParams;
           phAxis = ClassStage.getAxis(obj.stageAxes(index));
           axisIsFixed = scanParams.isFixed(phAxis);
           
           obj.recolor( ...     % Grays out if second parameter is true, reverts -- if false
               [obj.edtFrom(index), obj.edtTo(index), obj.edtNumPoints(index)], ...
               axisIsFixed);
           obj.recolor(obj.edtFixedPos(index), ~axisIsFixed);
        end
        
        function refresh(obj)
            stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
            scanParams = stage.scanParams;
            
            for i = 1 : length(obj.stageAxes)
                phAxis = obj.stageAxes(i);
                axisIndex = ClassStage.getAxis(phAxis);
                
                % Notice the difference:
                % i - index for the views
                % axisIndex - index in scan params
                %
                % For example, in a stage supporting only 'zy' scans,
                % in the first iteration:   i --> 1 , axisIndex --> 3
                % in the second iteration:  i --> 2 , axisIndex --> 2
                
                obj.edtFrom(i).String = scanParams.from(axisIndex);
                obj.edtTo(i).String = scanParams.to(axisIndex);
                obj.edtNumPoints(i).String = scanParams.numPoints(axisIndex);
                obj.cbxFixed(i).Value = scanParams.isFixed(axisIndex);
                obj.edtFixedPos(i).String = StringHelper.formatNumber(scanParams.fixedPos(axisIndex));
                
                obj.colorifyFixed(i);
            end
        end
    end
    
    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if event.isError || isfield(event.extraInfo, ClassStage.EVENT_SCAN_PARAMS_CHANGED)
                obj.refresh()
            end
        end
    end
    
end

