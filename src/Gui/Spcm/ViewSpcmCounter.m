classdef ViewSpcmCounter < ViewVBox & EventListener
    %ViewSpcmCounter view for the SPCM counter
    % This view receives data from the SPCM counter, and displays it
    % according to the requirement of the user (especially, determinines
    % value for wrap (maximum number of data points presented). It can also
    % turn the the SPCM on and off.
    
    properties
        vAxes           % axes view, to use for the plotting
        btnPopout
        
        btnStartStop
        btnReset
        btnSave
        edtIntegrationTime
        
        wrap            % positive integer, how many records in plot
        cbxUsingWrap
        edtWrap
        
        leftLabel
        
        isStandalone = false;
    end
    
    properties (Constant)
        BOTTOM_LABEL = 'time [sec]'; % Text for horiz. axis
        
        DEFAULT_WRAP_VALUE = 50;    % Value of wrap set in initiation
        DEFAULT_USING_WRAP = true;  % boolean, does this window uses wrap
    end
    
    methods
        function obj = ViewSpcmCounter(parent, controller, varargin)
            padding = 5;
            obj@ViewVBox(parent, controller, padding);
            obj@EventListener(SpcmCounter.NAME);
            
            obj.wrap = obj.DEFAULT_WRAP_VALUE;
            
            spcm = getObjByName('spcm');
            if strcmp(varargin{1}, 'isStandalone')
                % This is the value for obj.isStandalone
                obj.isStandalone = varargin{2};
            end
            
            obj.leftLabel = 'kcps';
            if spcm.hasPhotodiode()
                obj.leftLabel = 'volt';
            end
            
            %% Plot Area %%%
            % Set initial values for properties of axes 
            obj.vAxes = axes('Parent', obj.component, ...
                'ActivePositionProperty', 'outerposition');
            AxesHelper.fill(obj.vAxes, AxesHelper.DEFAULT_Y, 1, AxesHelper.DEFAULT_X, [], obj.BOTTOM_LABEL, obj.leftLabel);
            if obj.isStandalone
                obj.vAxes.FontSize = 20;
            end
            axes()
            
            %%% Buttons / Controls %%%
            hboxButtons = uix.HBox('Parent', obj.component, ...
                'Spacing', 3);
            
            % Counter Controls Panel
            panelControlsTitle = 'Counter Controls';
            if spcm.hasPhotodiode()
                panelControlsTitle = 'Digitizer Controls';
            end                
            panelControls = uix.Panel('Parent', hboxButtons, ...
                'Title', panelControlsTitle);
            hboxControls = uix.HBox('Parent', panelControls, ...
                'Spacing', 3);
            
            obj.btnStartStop = ButtonStartStop(hboxControls);
                obj.btnStartStop.startCallback = @obj.btnStartCallback;
                obj.btnStartStop.stopCallback = @obj.btnStopCallback;
            obj.btnReset = uicontrol(obj.PROP_BUTTON{:}, ...
                'Parent', hboxControls, ...
                'String', 'Reset', ...
                'Callback', @obj.btnResetCallback);
            obj.btnSave = uicontrol(obj.PROP_BUTTON{:}, ...
                'Parent', hboxControls, ...
                'String', 'Save', ...
                'Callback', @obj.btnSaveCallback);
            
            % Integration time column %
            defaultTime = SpcmCounter.INTEGRATION_TIME_DEFAULT_MILLISEC;
            vboxIntegrationTime =  uix.VBox('Parent', hboxControls, ...
                'Spacing', 1, 'Padding', 1);
            uicontrol(obj.PROP_LABEL{:}, ...
                'Parent', vboxIntegrationTime, ...
                'String', 'Integration (ms)');
            obj.edtIntegrationTime = uicontrol(obj.PROP_EDIT{:}, ...
                'Parent', vboxIntegrationTime, ...
                'String', num2str(defaultTime), ...
                'Callback', @obj.edtIntegrationTimeCallback);
            vboxIntegrationTime.Heights = [-1 -1];
            
            hboxControls.Widths = [-1, 50, 50, 110];
            
            % Wrap Panel %
            panelWrap = uix.Panel('Parent', hboxButtons, ...
                'Title', 'Wrap');
            hboxWrapMain = uix.HBox('Parent', panelWrap, ...
                'Spacing', 1, 'Padding', 1);
            obj.cbxUsingWrap = uicontrol(obj.PROP_CHECKBOX{:}, ...
                'Parent', hboxWrapMain, ...
                'Value', obj.DEFAULT_USING_WRAP, ...
                'Callback', @obj.cbxUsingWrapCallback);
            vboxWrapNumber = uix.VBox('Parent', hboxWrapMain);
                uicontrol(obj.PROP_LABEL{:}, 'Parent', vboxWrapNumber, ...
                    'String', '# of Pts');
                obj.edtWrap = uicontrol(obj.PROP_EDIT{:}, ...
                    'Parent', vboxWrapNumber, ...
                    'String', obj.DEFAULT_WRAP_VALUE, ...
                    'Callback', @obj.edtWrapCallback);
                vboxWrapNumber.Heights = [-1, -1];
            hboxWrapMain.Widths = [15, -1];
            
            hboxButtons.Widths = [-1, 75];

            obj.update;     % There might already be records in the counter
            
            % SPCM Control
            spcm = getObjByName(Spcm.NAME);
            shouldHaveControl = (spcm.hasAltCount() || spcm.hasG2() || spcm.hasLifetime()) ...
                    && (~strcmp(varargin{1}, 'isStandalone') || ~varargin{2});
            if shouldHaveControl
                spcmControlView = ViewSpcmControl(obj.component, controller);
            end
            shouldHavePhotodiodeControl = spcm.hasPhotodiode();
            if shouldHavePhotodiodeControl
                spcmControlView = ViewPhotodiodeControl(obj.component, controller);
            end
            
            %%% Define size %%%
            % Default values
            obj.height = 500;
            obj.width = 850;
            
            switch length(varargin)
                case {2, 3}
                    if ~strcmp(varargin{1}, 'isStandalone')
                        % not a standalone
                        obj.height = varargin{1};
                        obj.width = varargin{2};
                    end
                case {4, 5}
                    if strcmp(varargin{1}, 'isStandalone')
                        heightArgIndex = 3;
                    else
                        heightArgIndex = 1;
                    end
                    obj.height = varargin{heightArgIndex};
                    obj.width = varargin{heightArgIndex+1};
            end
            
            controlsHeight = 80;
            if shouldHaveControl || shouldHavePhotodiodeControl
                obj.setHeights([-1, controlsHeight, spcmControlView.height]);
            else
                obj.setHeights([-1, controlsHeight]);
            end
            
            SpcmCounter.init();
            counter = getObjByName(SpcmCounter.NAME);
            counter.addGraphicAxes(obj.vAxes); % So that experiment could plot on it
        end

        function tf = isUsingWrap(obj)
            tf = obj.cbxUsingWrap.Value;
        end
        
        function refresh(obj)
            % Just uicontrols, not axes
            spcmCount = getObjByName(SpcmCounter.NAME);
            if isempty(spcmCount)
                % The counter is unavailable
                obj.btnStartStop.isRunning = false;
            else
                obj.edtIntegrationTime.String = spcmCount.integrationTimeMillisec;
                obj.btnStartStop.isRunning = spcmCount.isRunning;
            end
        end
        
        function update(obj)
            % Axes AND uicontrols

            counter = getObjByName(SpcmCounter.NAME);
            if isempty(counter)
                % Nothing to do here
                return
            end
            counter.addGraphicAxes(obj.vAxes); % So that experiment could plot on it
            
            switch counter.currentType
                case 1 % Counter
                    % Get plot data
                    spcm = getObjByName(Spcm.NAME);
                    if obj.isUsingWrap
                        [time, kcps, std, realTime] = counter.getRecords(obj.wrap);
                    else
                        [time, kcps, std, realTime] = counter.getRecords;
                    end
                    dimNum = 1;
                    AxesHelper.fill(obj.vAxes, kcps(1,:), dimNum, time, NaN, obj.BOTTOM_LABEL, obj.leftLabel, std(1,:));
                    %             xticklabels(obj.vAxes, 'auto')
                    %             [~,ind] = ismember(round(str2num(cell2mat(xticklabels(obj.vAxes)))), round(time));
                    %             xticklabels(obj.vAxes, sprintfc('%d',round(realTime(ind))))
                    obj.vAxes.Children(1).HitTest = 'off'; % So as not to be interacted by "marker" cursor
                    if size(kcps, 1) == 2 && any((kcps(2,:) ~= 0) & ~isnan(kcps(2,:))) %% Has 2nd spcm to plot
                        AxesHelper.add(obj.vAxes, kcps(2,:), time, std(2,:))
                        obj.vAxes.Children(2).HitTest = 'off'; % So as not to be interacted by "marker" cursor
                    end
                    set(obj.vAxes, 'XLim', [-inf, inf]);	% Creates smooth "sweep" of data
                    drawnow;                                % consider using animatedline
                case 2 % Lifetime
                    spcm = getObjByName(Spcm.NAME);
                    binWidth = spcm.binWidth/1000; % in ns
                    nBins = spcm.nBins;
                    bins = binWidth:binWidth:nBins*binWidth;
                    dimNum = 1;
                    AxesHelper.fill(obj.vAxes, spcm.lastTimeHist, dimNum, bins, [], 'ns', 'kcps');
                case 3 % G2
                    spcm = getObjByName(Spcm.NAME);
                    binWidth = spcm.binWidth/1000; % in ns
                    nBins = spcm.nBins;
                    bins = -nBins*binWidth:binWidth:nBins*binWidth;
                    dimNum = 1;
                    AxesHelper.fill(obj.vAxes, spcm.lastTimeG2, dimNum, bins, [], 'ns', 'g2');
            end
            % Update uicontrols
            obj.refresh;
        end
        
        %%%% Callbacks %%%%
        function cbxUsingWrapCallback(obj, ~, ~)
            obj.recolor(obj.edtWrap, ~obj.isUsingWrap)
            obj.update;
        end
        function edtWrapCallback(obj, ~, ~)
            if ~ValidationHelper.isValuePositiveInteger(obj.edtWrap.String)
                EventStation.anonymousWarning('Wrap needs to be a positive integer! Reverting.')
                obj.edtWrap.String = obj.wrap;
            end
            obj.wrap = str2double(obj.edtWrap.String);
            obj.update;
        end
        function btnStartCallback(obj, ~, ~)
            spcmCount = obj.getCounter;
            spcmCount.run;
        end
        function btnStopCallback(obj, ~, ~)
            spcmCount = obj.getCounter;
            spcmCount.pause;
        end
        function btnResetCallback(obj, ~ ,~)
            spcmCount = obj.getCounter;
            spcmCount.resetHistory;
        end
        function btnSaveCallback(obj, ~ ,~)
            spcmCount = obj.getCounter;
            spcmCount.save;
        end
        function edtIntegrationTimeCallback(obj, ~, ~) 
            spcmCount = obj.getCounter;
            spcmCount.integrationTimeMillisec = str2double(obj.edtIntegrationTime.String);
            % The counter will take care of the rest
        end
    end
    
    methods (Static)
        function spcmCounter = getCounter
            spcmCounter = getObjByName(SpcmCounter.NAME);
            if isempty(spcmCounter)
                % If we don't already have one, we want to create it
                spcmCounter = SpcmCounter;
            end
        end
    end
    
    %% overridden from EventListener
    methods
        % When events happens, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if isfield(event.extraInfo, SpcmCounter.EVENT_DATA_UPDATED)   % event = update
                obj.update;
            else
                obj.refresh;
            end
            if isfield(event.extraInfo, SpcmCounter.EVENT_SPCM_COUNTER_RESET)    % event = reset
                line = obj.vAxes.Children;
                delete(line);
            end
        end
    end
end