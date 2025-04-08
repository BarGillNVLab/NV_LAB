classdef ViewStagePanelMWContrast < GuiComponent & EventListener & EventSender
    %VIEWSTAGESCANSCAN Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        cbxMWContrast       % checkbox
        edtFrequency        % edit text
        edtAmplitude        % edit text
        
        stageName           % string
    end
    methods
        function obj = ViewStagePanelMWContrast(parent, controller, stage)
            obj@GuiComponent(parent, controller);
            obj@EventListener(stage.name);
            obj@EventSender(sprintf('%s%s', stage.name, ' _ panel Scan Contrast'));
            obj.stageName = stage.name;
            
            %%%% Scan panel init %%%%
            panelScan = uix.Panel('Parent', parent.component, 'Title', 'MW Contrast', 'Padding', 5);
            hboxMain = uix.HBox('Parent', panelScan, 'Spacing', 5, 'Padding', 0);
            
            obj.cbxMWContrast = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', hboxMain, 'String', 'On');
            
            uix.Empty('Parent', hboxMain);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', hboxMain, 'String', 'Frequency', 'FontSize', 8);
            obj.edtFrequency = uicontrol(obj.PROP_EDIT{:}, 'Parent', hboxMain);
            
            uix.Empty('Parent', hboxMain);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', hboxMain, 'String', 'Amplitude', 'FontSize', 8);
            obj.edtAmplitude = uicontrol(obj.PROP_EDIT{:}, 'Parent', hboxMain);
            
            hboxMain.Widths = [-3 -1 -3 -3 -1 -3 -3];
            
            %%%% callbacks %%%%
            obj.cbxMWContrast.Callback = @(h,e) obj.cbxMWContrastCallback;
            obj.edtFrequency.Callback = @(h,e) obj.edtFrequencyCallback;
            obj.edtAmplitude.Callback = @(h,e) obj.edtAmplitudeCallback;
            
            %%%% internal values %%%%
            obj.height = 45;
            obj.refresh();  % init values
        end
        
        
        function refresh(obj)
            stage = getObjByName(obj.stageName);
            scanParams = stage.scanParams;
            obj.cbxMWContrast.Value = scanParams.isMWContrastScan;
            obj.edtFrequency.String = StringHelper.formatNumber(scanParams.MWFrequency);
            obj.edtAmplitude.String = StringHelper.formatNumber(scanParams.MWAmplitude);
        end
        
        function cbxMWContrastCallback(obj)
            stage = getObjByName(obj.stageName);
            scanParams = stage.scanParams;
            scanParams.isMWContrastScan = obj.cbxMWContrast.Value;
            stage.sendEventScanParamsChanged();
        end
        
        function edtFrequencyCallback(obj)
            stage = getObjByName(obj.stageName);
            scanParams = stage.scanParams;
            if ~ValidationHelper.isValuePositive(obj.edtFrequency.String)
                obj.edtFrequency.String = StringHelper.formatNumber(scanParams.MWFrequency);
                EventStation.anonymousError('Frequency has to be a positive number! Reverting.');
            end
            scanParams.MWFrequency = str2double(obj.edtFrequency.String);
            stage.sendEventScanParamsChanged();
        end

        function edtAmplitudeCallback(obj)
            stage = getObjByName(obj.stageName);
            scanParams = stage.scanParams;
            if ~ValidationHelper.isStringValueANumber(obj.edtAmplitude.String)
                obj.edtAmplitude.String = StringHelper.formatNumber(scanParams.MWAmplitude);
                EventStation.anonymousError('Amplitude has to be a number! Reverting.');
            end
            scanParams.MWAmplitude = str2double(obj.edtAmplitude.String);
            stage.sendEventScanParamsChanged();
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