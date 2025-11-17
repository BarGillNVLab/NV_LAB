classdef ViewAndorSensorTemperature < GuiComponent

    % addition features available for the andor camera

    properties
        cbxTempControl
        edttemperature          %setting the sensor's temperature
        camera
        maxtemp
        mintemp
    end

    methods

        function obj = ViewAndorSensorTemperature(parent, controller)
            obj@GuiComponent(parent, controller);
            obj.camera = getObjByName(Camera.NAME);
            obj.maxtemp = obj.camera.MAXSENSORTEMPERATURE;
            obj.mintemp = obj.camera.MINSENSORTEMPERAURE;

            panelScan = uix.Panel('Parent', parent.component, 'Title', 'Temperature Control', 'Padding', 5);
            hboxMain = uix.HBox('Parent', panelScan, 'Spacing', 1, 'Padding', 0);
            
            obj.cbxTempControl = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', hboxMain, 'String', 'On');

            
            obj.edttemperature = uicontrol(obj.PROP_EDIT{:}, 'Parent', hboxMain, 'Enable','off');
            uix.Empty('Parent', hboxMain);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', hboxMain, 'String', ['Min Temperature: ', num2str(obj.mintemp)], 'FontSize', 8);
            uix.Empty('Parent', hboxMain);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', hboxMain, 'String', ['Max Temperature: ', num2str(obj.maxtemp)], 'FontSize', 8);
            
            hboxMain.Widths = [-3 -3 -1 -6.5 -1 -6];
            
            %%%% callbacks %%%%
            obj.cbxTempControl.Callback = @(h,e) obj.cbxTempControlCallback;
            obj.edttemperature.Callback = @(h,e) obj.edtFrequencyCallback;
            
            %%%% internal values %%%%
            obj.height = 45;
            obj.refresh();  % init values
            end
            
            
            function refresh(obj)
                obj.edttemperature.String = StringHelper.formatNumber(obj.camera.readTemperature);
            end
        
            function cbxTempControlCallback(obj)
                bool = obj.cbxTempControl.Value;
                obj.edttemperature.Enable = 'on';
                obj.camera.Cooling(bool);
            end
        
            function edtFrequencyCallback(obj)
                if ~ValidationHelper.isStringValueInBorders(obj.edttemperature.String, obj.mintemp, obj.maxtemp)
                    obj.edttemperature.String = StringHelper.formatNumber(0);
                    EventStation.anonymousError('Temperature not in range');
                end
                obj.camera.setSensorTemperature(str2double(obj.edttemperature.String));
                status = obj.camera.sensorTemperatureStatus;
                while ~strcmp(status, 'Stabilised')
                    status = obj.camera.sensorTemperatureStatus;
                    obj.refresh;
                    pause(3);
                end
            end
    end
end

