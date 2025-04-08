classdef ViewStagePanelScan < GuiComponent & EventListener
    %VIEWSTAGESCANSCAN Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        btnScan             % the Holy Main Button!
        cbxContinuous       % checkbox
        cbxFastScan         % checkbox
        cbxAutoSave         % checkbox
        edtPixelTime        % edit text
        
        stageName           % string
    end
    methods
        function obj = ViewStagePanelScan(parent, controller, stageName)
            obj@GuiComponent(parent, controller);
            expNames = Experiment.getExperimentNames();
            obj@EventListener({stageName, expNames{:}, StageScanner.NAME}); %#ok<CCAT>
            obj.stageName = stageName;
            
            %%%% Scan panel init %%%%
            panelScan = uix.Panel('Parent', parent.component, 'Title', 'Scan', 'Padding', 5);
            vboxMain = uix.VBox('Parent', panelScan, 'Spacing', 5, 'Padding', 0);
            
            obj.btnScan = ButtonStartStop(vboxMain, 'Scan', 'Stop Scan');
            hboxPixelTime = uix.HBox('Parent', vboxMain, 'Spacing', 3, 'Padding', 0);
                uicontrol(obj.PROP_LABEL{:}, 'Parent', hboxPixelTime, 'String', 'Pixel time', 'FontSize', 8);
                obj.edtPixelTime = uicontrol(obj.PROP_EDIT{:}, 'Parent', hboxPixelTime);
                hboxPixelTime.Widths = [-3 -2];
            
            % Get scan speed parameters from stage
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            fastScannable = stage.hasFastScan;
            slowScannable = stage.hasSlowScan;
            enable = BooleanHelper.boolToOnOff(fastScannable && slowScannable);
            value = fastScannable;      % If fast scan is implemented, it is the default
            
            % Create checkboxes
            obj.cbxContinuous = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', vboxMain, 'String', 'Continuous');
            obj.cbxFastScan = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', vboxMain, 'String', 'Fast Scan', 'Enable', enable, 'Value', value);
            obj.cbxAutoSave = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', vboxMain, 'String', 'Auto-Save');
            
            vboxMain.Heights = [-4 -3 -2 -2 -2];
            
            %%%% callbacks %%%%
            obj.cbxAutoSave.Callback = @(h,e) obj.cbxAutoSaveCallback;
            obj.cbxContinuous.Callback = @(h,e) obj.cbxContCallback;
            obj.cbxFastScan.Callback = @(h,e) obj.cbxFastScanCallback;
            obj.edtPixelTime.Callback = @(h,e) obj.edtPixelTimeCallback;
            obj.btnScan.startCallback = @(h,e) obj.btnScanCallback;
            obj.btnScan.stopCallback = @(h,e) obj.btnStopScanCallback;
            
            %%%% internal values %%%%
            obj.height = 215;
            obj.width = 120;
            obj.refresh();  % init values
        end
        
        
        function refresh(obj)
            stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
            scanParams = stage.scanParams;
            
            obj.cbxAutoSave.Value = scanParams.autoSave;
            obj.cbxContinuous.Value = scanParams.continuous;
            obj.cbxFastScan.Value = scanParams.fastScan;
            obj.edtPixelTime.String = StringHelper.formatNumber(scanParams.pixelTime);
        end
        
        function cbxAutoSaveCallback(obj)
            stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
            scanParams = stage.scanParams;
            
            scanParams.autoSave = obj.cbxAutoSave.Value;
            stage.sendEventScanParamsChanged();
        end
        
        function cbxContCallback(obj)
            stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
            scanParams = stage.scanParams;
            
            scanParams.continuous = obj.cbxContinuous.Value;
            stage.sendEventScanParamsChanged();
        end
        
        function cbxFastScanCallback(obj)
            stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
            scanParams = stage.scanParams;
            
            scanParams.fastScan = obj.cbxFastScan.Value;
            stage.sendEventScanParamsChanged();
        end
        
        function edtPixelTimeCallback(obj)
            stage = getObjByName(obj.stageName);
                if isempty(stage); throwBaseObjException(obj.stageName); end
            scanParams = stage.scanParams;
            
            if ~ValidationHelper.isValuePositive(obj.edtPixelTime.String)
                obj.edtPixelTime.String = StringHelper.formatNumber(scanParams.pixelTime);
                EventStation.anonymousError('Pixel time has to be a positive number! Reverting.');
            end
            scanParams.pixelTime = str2double(obj.edtPixelTime.String);
            stage.sendEventScanParamsChanged();
        end
        
        function btnScanCallback(obj)
            scanner = getObjByName(StageScanner.NAME);
            scanner.switchTo(obj.stageName);
            scanner.startScan();
            obj.btnScan.isRunning = false;  % Scan is now finished
        end
        function btnStopScanCallback(obj) %#ok<MANU>
            scanner = getObjByName(StageScanner.NAME);
            scanner.stopScan();
        end
    end
    
    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if event.isError ...
                    || isfield(event.extraInfo, StageScanner.EVENT_SCAN_FINISHED)
                % Scan stopped, either intentionally or not
                obj.refresh();
                obj.btnScan.Enable = 'on';
                obj.btnScan.isRunning = false;
            end
            
            if isfield(event.extraInfo, StageScanner.EVENT_SCAN_STARTED)
                % Scan started
                obj.btnScan.isRunning = true;
            end
            
            if isfield(event.extraInfo, ClassStage.EVENT_SCAN_PARAMS_CHANGED)
                obj.refresh();
            end
            
            if isfield(event.extraInfo, Experiment.EVENT_EXP_RESUMED) ...
                    || isfield(event.extraInfo, Experiment.EVENT_EXP_PAUSED)
                % When experiments run, we can't scan
                exp = event.creator;
                isScanPossible = ~exp.isRunning;
                obj.btnScan.Enable = BooleanHelper.boolToOnOff(isScanPossible);
            end
        end
    end
end

