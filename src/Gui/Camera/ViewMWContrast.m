classdef ViewMWContrast < GuiComponent 
    %VIEWSTAGESCANSCAN Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        cbxMWContrast       % checkbox
        edtFrequency        % edit text
        edtAmplitude        % edit text

        
    end
    methods
        function obj = ViewMWContrast(parent, controller)
            obj@GuiComponent(parent, controller);
            
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
            camera = getObjByName(Camera.NAME);
            imageParams = camera.imgparams;
            obj.cbxMWContrast.Value = imageParams.isMWcontrastImg;
            obj.edtFrequency.String = StringHelper.formatNumber(imageParams.MWFrequency);
            obj.edtAmplitude.String = StringHelper.formatNumber(imageParams.MWAmplitude);
        end
    
        function cbxMWContrastCallback(obj)
            camera = getObjByName(Camera.NAME);
            imageParams = camera.imgparams;
            imageParams.isMWcontrastImg = obj.cbxMWContrast.Value;
            camera.sendEventScanParamsChanged();
        end
    
        function edtFrequencyCallback(obj)
            camera = getObjByName(Camera.NAME);
            srs = getObjByName(FrequencyGenerator.getDefaultFgName);
            imageParams = camera.imgparams;
            if ~ValidationHelper.isValuePositive(obj.edtFrequency.String)
                obj.edtFrequency.String = StringHelper.formatNumber(imageParams.MWFrequency);
                EventStation.anonymousError('Frequency has to be a positive number! Reverting.');
            end
            imageParams.MWFrequency = str2double(obj.edtFrequency.String);
            srs.frequency = str2double(obj.edtFrequency.String);
            camera.sendEventScanParamsChanged();
        end
    
        function edtAmplitudeCallback(obj)
            camera = getObjByName(Camera.NAME);
            srs = getObjByName(FrequencyGenerator.getDefaultFgName);
            imageParams = camera.imgparams;
            if ~ValidationHelper.isStringValueANumber(obj.edtAmplitude.String)
                obj.edtAmplitude.String = StringHelper.formatNumber(imageParams.MWAmplitude);
                EventStation.anonymousError('Amplitude has to be a number! Reverting.');
            end
            imageParams.MWAmplitude = str2double(obj.edtAmplitude.String);
            srs.amplitude = str2double(obj.edtAmplitude.String);
            camera.sendEventScanParamsChanged();
        end
    end
    
    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if event.isError || isfield(event.extraInfo, Camera.EVENT_CAMERA_PARAMS_CHANGED)
                obj.refresh()
            end
        end
     end
end