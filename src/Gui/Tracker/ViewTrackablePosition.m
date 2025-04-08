classdef ViewTrackablePosition < ViewTrackable
    %VIEWTRACKABLEPOSITION View for the trackable position 
    %   
    
    properties (SetAccess = protected)
        stageAxes       % string. The axes of the stage this trackable uses
        laserPartNames	% cell. names of laser parts that can set their value (power)
        uiStageName     % text-view. Shows the name of the current stage
        tvCurPos        % text-view. Shows the current position of the stage
        lblCurPos       % label. Name of axes (Used for visibility)
    end
    
    properties
        % n is the length of stageAxes
        edtInitStepSize % nx1 edit-input. Initial step size
        edtMinStepSize  % nx1 edit-input. Minimum step size
        edtNumStep      % edit-input. Maximum number of steps before giving up
        edtPixelTime    % edit-input. Time for reading at each point.
        edtLaserPower   % edit-input. Power of green laser
    end
    
    properties (Constant)
        LEFT_LABEL1 = sprintf('%s(position) [%s]', StringHelper.DELTA, StringHelper.MICRON);
        LEFT_LABEL2 = 'kpcs'
    end
    
    methods
        function obj = ViewTrackablePosition(parent, controller)
            obj@ViewTrackable(parent, controller)
            obj.startListeningTo(TrackablePosition.NAME);
            
            % Set parameters for graphic axes
            obj.vAxes1.YLabel.String = obj.LEFT_LABEL1;
            obj.vAxes2.XLabel.String = obj.LABEL_TIME;
            obj.vAxes2.YLabel.String = obj.LEFT_LABEL2;
            
            %%%% Get objects we will work with: %%%%
            % First and foremost: the trackable experiment
            trackablePos = obj.getTrackable();
            trackablePos.addGraphicAxes(obj.vAxes1);
            % List of all available stages
            stages = ClassStage.getScannableStages;
            stagesNames = cellfun(@(x) x.name, stages, 'UniformOutput', false);
            % General stage parameters
            axesLen = ClassStage.SCAN_AXES_SIZE;
            % Green laser
            laser = getObjByName(trackablePos.mLaserName);
                if isempty(laser); throwBaseObjException(trackablePos.mLaserName); end
            obj.laserPartNames = laser.getContollableParts;
            laserPartsLen = length(obj.laserPartNames);
            laserParts = cell(1, laserPartsLen);
            for i = 1:laserPartsLen
                laserParts{i} = getObjByName(obj.laserPartNames{i});
                obj.startListeningTo(laserParts{i}.name);
            end
            
            %%%% Fill input parameter panel %%%%
            longLabelWidth = 120;
            shortLabelWidth = 80;
            lineHeight = 30;
            heights = [lineHeight*ones(1,5), lineHeight*ones(1,laserPartsLen), -1];
            
            hboxInput = uix.HBox('Parent', obj.panelInput, 'Spacing', 5, 'Padding', 5);
            
            % Label column
            vboxLabels = uix.VBox('Parent', hboxInput, 'Spacing', 5, 'Padding', 0);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', vboxLabels, ...
                'String', 'Tracked Stage');
            uicontrol(obj.PROP_LABEL{:}, 'Parent', vboxLabels, ...
                'String', 'Max # of steps');
            uicontrol(obj.PROP_LABEL{:}, 'Parent', vboxLabels, ...
                'String', 'Pixel Time');
            uicontrol(obj.PROP_LABEL{:}, 'Parent', vboxLabels, ...
                'String', 'Initial Step Size');
            uicontrol(obj.PROP_LABEL{:}, 'Parent', vboxLabels, ...
                'String', 'Min. Step Size');
            for i = 1:laserPartsLen
                label = uicontrol(obj.PROP_LABEL{:}, 'Parent', vboxLabels);
                switch class(laserParts{i})
                    case {'LaserSourceOnefiveKatana05', 'LaserSourceDummy'}
                        label.String = 'Laser Source';
                    case {'AomDoubleNiDaqControlled', 'AomDummy', 'AomNiDaqControlled'}
                        label.String = 'Laser AOM';
                end
            end
            uix.Empty('Parent', vboxLabels);
            vboxLabels.Heights = heights;
            
            % Values column
            vboxValues = uix.VBox('Parent', hboxInput, 'Spacing', 5, 'Padding', 0);
            obj.uiStageName = obj.uiTvOrPopup(vboxValues, stagesNames);     % might be a text-view or a dropdown-menu
                obj.uiStageName.Callback = @obj.uiStageNameCallback;
            obj.edtNumStep = uicontrol(obj.PROP_EDIT{:}, ...
                'Parent', vboxValues, ...
                'Callback', @obj.edtNumStepCallback);
            hboxPixelTime = uix.HBox('Parent', vboxValues, ...
                    'Spacing', 5, 'Padding', 0);
                obj.edtPixelTime = uicontrol(obj.PROP_EDIT{:}, ...
                    'Parent', hboxPixelTime, ...
                    'Callback', @obj.edtPixelTimeCallback);
                uicontrol(obj.PROP_TEXT_UNITS{:}, ...
                    'Parent', hboxPixelTime, ...
                    'String', 's');
                hboxPixelTime.Widths = [-1 15];
            
            hboxInitStepSize = uix.HBox('Parent', vboxValues, 'Spacing', 5, 'Padding', 0);
                obj.edtInitStepSize = gobjects(1, axesLen);
            hboxMinStepSize = uix.HBox('Parent', vboxValues, 'Spacing', 5, 'Padding', 0);
                obj.edtMinStepSize = gobjects(1, axesLen);
            for i = 1:axesLen
                obj.edtInitStepSize(i) = uicontrol(obj.PROP_EDIT{:}, ...
                    'Parent', hboxInitStepSize, ...
                    'Callback', @(h,e)obj.edtInitStepSizeCallback(i));
                obj.edtMinStepSize(i) = uicontrol(obj.PROP_EDIT{:}, ...
                    'Parent', hboxMinStepSize, ...
                    'Callback', @(h,e)obj.edtMinStepSizeCallback(i));
            end
                
            hboxLaserPower = gobjects(1, laserPartsLen);
            obj.edtLaserPower = gobjects(1, laserPartsLen);
            for i = 1:laserPartsLen
                hboxLaserPower(i) = uix.HBox('Parent', vboxValues, ...
                    'Spacing', 5, 'Padding', 0, ...
                    'UserData', obj.laserPartNames{i});
                obj.edtLaserPower(i) = uicontrol(obj.PROP_EDIT{:}, ...
                    'Parent', hboxLaserPower(i), ...
                    'Callback', @obj.edtLaserPowerCallback);
                uicontrol(obj.PROP_TEXT_UNITS{:}, 'Parent', hboxLaserPower(i), ...
                    'String', laserParts{i}.units);
                hboxLaserPower(i).Widths = [-1 15];
            end
            uix.Empty('Parent', vboxValues);
            vboxValues.Heights = heights;

            hboxInput.Widths = [longLabelWidth -1];
            
            %%%% Fill tracked parameter panel %%%%
            gridTracked = uix.Grid('Parent', obj.panelTracked, 'Spacing', 5, 'Padding', 5);
            obj.lblCurPos = gobjects(1, axesLen);
            obj.tvCurPos = gobjects(1, axesLen);
            % First column
            for i = 1:axesLen
                obj.lblCurPos(i) = uicontrol(obj.PROP_LABEL{:}, 'Parent', gridTracked, 'String', upper(ClassStage.SCAN_AXES(i)));
            end
            % Second column
            for i = 1:axesLen
                obj.tvCurPos(i) = uicontrol(obj.PROP_EDIT{:}, 'Parent', gridTracked, 'Enable', 'off');
            end
            set(gridTracked, 'Widths', [shortLabelWidth -1]);
            
            % Get information from all devices
            obj.totalRefresh;
        end
    end
    
    methods % Called to update GUI
        % We have several levels of refreshing\updating:
        % 1. When the tracker finishes one step. Here we only want to check
        %    that how are scanned parameters are doing, and redraw on the
        %    axes. Dubbed: update.
        % 2. When user changes other tracking parameters. We then make sure
        %    that all other tracking parameters are is in place.
        %    Dubbed: refresh.
        % 3. When stage is changed: this requires checking almost
        %    everything. This is very costly, but will rarely happen.
        %    Dubbed: totalRefresh.
        
        function update(obj) % (#1)
            trackablePos = obj.getTrackable;
            
            [history, sessEndIdx] = trackablePos.convertHistoryToStructToSave;
            
            % Get the data
            pos = cell2mat(history.position);
            if isempty(pos)
                return  % Nothing to do here
            end
            switch obj.xAxisMode
                case obj.STRING_TIME
                    xAx = cell2mat(history.time);
                case obj.STRING_STEPS
                    xAx = 0 : (length(history.time) - 1);  % vector of natural numbers
            end
            
            % Choose the relevant part, according to history mode
            switch lower(obj.historyMode)
                case 'short'
                    s = size(pos);
                    current = s(1);             % current index of history
                    lastEnd = sessEndIdx(end);  % index of the end of last session
                    if s(1) == lastEnd && lastEnd~=1
                        ind = sessEndIdx(end-1):current;
                    else
                        ind = lastEnd:current;
                    end
                case 'long'
                    ind = sessEndIdx;           % Only the indices of the final position in each session    
            end
            % Now take the relevant data
            pos = pos(ind, :);
            xAx = xAx(ind);
            
            p_1 = pos(1, :);
            dp = pos - p_1;
            plot(obj.vAxes1, xAx, dp); % plots each column (x,y,z) against the time
            axesLetters = num2cell(obj.stageAxes);     % Odd, but this usefully turns 'xyz' into {'x', 'y', 'z'}
            legend(obj.vAxes1, axesLetters, 'Location', 'northwest');
            drawnow;
            
            kcps = cell2mat(history.value);
            kcps = kcps(ind);
            kcpsSte = cell2mat(history.ste);
            kcpsSte = kcpsSte(ind);
            AxesHelper.update(obj.vAxes2, kcps, 1, xAx, [], kcpsSte);
            
            currentPos = pos(end, :);
            axesLen = length(obj.stageAxes);
            for i = 1:axesLen
                axisIndex = ClassStage.getAxis(obj.stageAxes(i));
                obj.tvCurPos(axisIndex).String = num2str(currentPos(i));
            end
        end
        
        function refresh(obj) % (#2)
            trackablePos = obj.getTrackable();
            stage = getObjByName(trackablePos.mStageName);
            
            % If tracking is currently performed, Start/Stop should be "Stop"
            % and reset should be disabled
            if trackablePos.stopFlag
                obj.btnStartStop.stopString = 'Stopping...';
            else
                obj.btnStartStop.stopString = 'Stop';
            end
            obj.btnStartStop.isRunning = trackablePos.isCurrentlyTracking;
            obj.btnReset.Enable = BooleanHelper.boolToOnOff(~trackablePos.isCurrentlyTracking);
            
            obj.cbxContinuous.Value = trackablePos.isRunningContinuously;
            obj.edtNumStep.String = trackablePos.nMaxIterations;
            obj.edtPixelTime.String = trackablePos.pixelTime;
            
            currentPos = stage.Pos(obj.stageAxes);
            axesLen = length(obj.stageAxes);
            for i = 1:axesLen
                obj.tvCurPos(i).String = StringHelper.formatNumber(currentPos(i));
                obj.edtInitStepSize(i).String = trackablePos.initialStepSize(i);
                obj.edtMinStepSize(i).String = trackablePos.minimumStepSize(i);
            end
            
            laserPartsLen = length(obj.laserPartNames);
            for i = 1:laserPartsLen
                part = getObjByName(obj.laserPartNames{i});
                val = StringHelper.formatNumber(part.value);
                obj.edtLaserPower(i).String = val;
            end
        end
        
        function totalRefresh(obj) % (#3)
            %%% "Under the hood" %%%
            trackablePos = obj.getTrackable();
            stage = getObjByName(trackablePos.mStageName);
            obj.stageAxes = stage.availableAxes;
            
            %%% On display %%%
            % Update stage name
            obj.uiStageName.String = trackablePos.mStageName;
            % Set all as visible ("init")
            axesIndex = ClassStage.getAxis(obj.stageAxes);
            obj.setAxisVisible(axesIndex, 'on')
            % Hide irrelevent ones
            unavailableAxes = setdiff(ClassStage.SCAN_AXES, obj.stageAxes);
            axesIndex = ClassStage.getAxis(unavailableAxes);
            obj.setAxisVisible(axesIndex, 'off')
            
            obj.refresh;
        end
        
        function setAxisVisible(obj, index, value)
            % Helps with setting visibility of elements related to stage
            objects = [obj.edtInitStepSize(index), obj.edtMinStepSize(index), ...
                obj.lblCurPos(index), obj.tvCurPos(index) ];
            set(objects, 'Visible', value);
        end
        
    end
    
    %% Callbacks
    methods (Access = protected)
        % From parent class
        function btnStartCallback(obj, ~, ~)
            trackablePos = obj.getTrackable();
            try
                trackablePos.startTrack;
                obj.refresh;
            catch err
                trackablePos.stopTrack;     % sets trackablePos.isCurrentlyTracking = false
                rethrow(err);
            end
        end
        function btnStopCallback(obj, ~, ~)
            trackablePos = obj.getTrackable();
            
            trackablePos.stopTrack;
            obj.refresh;
        end
        function btnResetCallback(obj, ~, ~)
            trackablePos = obj.getTrackable();
            
            trackablePos.resetTrack;
            obj.refresh;
            cla(obj.vAxes1)
            cla(obj.vAxes2)
        end
        function cbxContinuousCallback(obj, ~, ~)
            trackablePos = obj.getTrackable();
            trackablePos.isRunningContinuously = obj.cbxContinuous.Value;
        end
        function btnStartStopCallback(obj, ~, ~)
            % If tracking is being performed, Start/Stop should be "Stop"
            % and reset should be disabled, and the opposite should happen
            % otherwise
            trackablePos = obj.getTrackable();
            obj.btnStartStopChangeMode(obj.btnStartStop, trackablePos.isCurrentlyTracking);
            obj.btnReset.Enable = BooleanHelper.boolToOnOff(~trackablePos.isCurrentlyTracking);
        end
        function btnSaveCallback(obj, ~, ~)
            trackablePos = obj.getTrackable();
            sl = SaveLoad.getInstance(Savable.CATEGORY_EXPERIMENTS);
            
            trackablePos.save;
            obj.showMessage(['File was saved in ', sl.mLoadedFileFullPath]);
        end
        
        
        % Unique to class
        function uiStageNameCallback(obj)
            trackablePos = obj.getTrackable();
            newStageName = obj.uiStageName;
            trackablePos.mStageName = newStageName;
        end
        function edtInitStepSizeCallback(obj, index)
            trackablePos = obj.getTrackable();
            edt = obj.edtInitStepSize(index);   % For brevity
            if ~ValidationHelper.isStringValueInBorders(edt.String, ...
                    trackablePos.minimumStepSize(index), inf)
                edt.String = trackablePos.initialStepSize(index);
                obj.showWarning('Initial step size is smaller than minimum step size! Reveting.');
            end
            [edt.String, newVal] = StringHelper.formatNumber(str2double(edt.String));
            trackablePos.setInitialStepSize(index, newVal);
        end
        function edtMinStepSizeCallback(obj, index)
            trackablePos = obj.getTrackable();
            edt = obj.edtMinStepSize(index);   % For brevity
            if ~ValidationHelper.isStringValueInBorders(edt.String, ...
                    0, trackablePos.initialStepSize(index))
                edt.String = trackablePos.minimumStepSize(index);
                obj.showWarning('Minimum step size must be between 0 and initial step size! Reveting.');
            end
            [edt.String, newVal] = StringHelper.formatNumber(str2double(edt.String));
            trackablePos.setMinimumStepSize(index, newVal);
        end
        function edtNumStepCallback(obj, ~, ~)
            obj.showMessage('Requested action is not available yet. Reverting.');
            obj.refresh;
        end
        function edtPixelTimeCallback(obj, ~, ~)
            trackablePos = obj.getTrackable();
            if ~ValidationHelper.isValuePositive(obj.edtPixelTime.String)
                obj.edtPixelTime.String = StringHelper.formatNumber(trackablePos.pixelTime);
                obj.showWarning('Pixel time has to be a positive number! Reverting.');
            end
            trackablePos.pixelTime = str2double(obj.edtPixelTime.String);
        end
        function edtLaserPowerCallback(obj, edtHandle, ~)
            val = str2double(edtHandle.String);
            decimalDigits = 1;
            [string, numeric] = StringHelper.formatNumber(val, decimalDigits);
            
            laserPart = obj.getLaerPart(edtHandle);
            try
                laserPart.value = numeric;
            catch err
                % Laser did not accept the value. Reverting.
                numeric = laserPart.value;
                string = StringHelper.formatNumber(numeric, decimalDigits);
                EventStation.anonymousWarning(err.message);
            end
            edtHandle.String = string;
        end
    end
    
    methods (Static, Access = protected)
        % Helper function for laser parts
        function laserPart = getLaerPart(handle)
            partName = handle.Parent.UserData;
            laserPart = getObjByName(partName);
            if isempty(laserPart)
                throwBaseObjException(partName);
            end
        end
        
        function trackablePos = getTrackable()
            trackablePos = getObjByName(TrackablePosition.NAME);
            if isempty(trackablePos); throwBaseObjException(TrackablePosition.NAME); end
        end
    end
    
    %% overridden from EventListener
    methods
        % When events happens, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            
            creator = event.creator;
            
            % Maybe it is one of the laser parts:
            if isa(creator, 'LaserPartAbstract')
                obj.refresh;    % check values of all devices (level 2 refresh)
                return
            end
            
            % Besides that, we only listen to TrackablePosition
            trackablePos = creator;
            if isfield(event.extraInfo, trackablePos.EVENT_TRACKABLE_EXP_UPDATED)
                obj.refresh;
                obj.update;
            elseif isfield(event.extraInfo, trackablePos.EVENT_TRACKABLE_EXP_ENDED)
                obj.refresh;
                obj.showMessage(event.extraInfo.text);
            elseif isfield(event.extraInfo, trackablePos.EVENT_CONTINUOUS_TRACKING_CHANGED)
                obj.refresh;
            elseif isfield(event.extraInfo, trackablePos.EVENT_STAGE_CHANGED)
                obj.totalRefresh;
            elseif event.isError
                errorMsg = event.extraInfo.(Event.ERROR_MSG);
                obj.showMessage(errorMsg);
            end
        end
    end
    
end