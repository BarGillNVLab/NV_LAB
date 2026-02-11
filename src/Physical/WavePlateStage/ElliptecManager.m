classdef ElliptecManager < handle
    properties
        controllers % Map of deviceKey ("port_id") -> ElliptecController
        serialPool  % Map of portName -> shared serialport objects
    end

    methods
        function obj = ElliptecManager()
            obj.controllers = containers.Map();
            obj.serialPool = containers.Map();
        end

        function addDevice(obj, portName, deviceID)
            key = obj.makeKey(portName, deviceID);
            if ~isKey(obj.controllers, key)
                serialObj = obj.getOrCreateSerial(portName);
                obj.controllers(key) = ElliptecController(portName, deviceID, serialObj);
            end
        end

        function removeDevice(obj, portName, deviceID)
            key = obj.makeKey(portName, deviceID);
            if isKey(obj.controllers, key)
                delete(obj.controllers(key));
                remove(obj.controllers, key);
            end
        end

        function delete(obj)
            keysList = keys(obj.controllers);
            for i = 1:numel(keysList)
                delete(obj.controllers(keysList{i}));
            end
            portKeys = keys(obj.serialPool);
            for i = 1:numel(portKeys)
                try
                    clear obj.serialPool(portKeys{i});
                catch
                end
            end
        end

        function homeAll(obj)
            keysList = keys(obj.controllers);
            for i = 1:numel(keysList)
                ctrl = obj.controllers(keysList{i});
                ctrl.home();
            end
        end

        function moveToAngle(obj, portName, deviceID, angle_deg)
            key = obj.makeKey(portName, deviceID);
            ctrl = obj.controllers(key);
            ctrl.moveToAngle(angle_deg);
        end

        function moveBy(obj, portName, deviceID, angle_deg)
            key = obj.makeKey(portName, deviceID);
            ctrl = obj.controllers(key);
            ctrl.moveBy(angle_deg);
        end

        function angle_deg = getAngle(obj, portName, deviceID)
            key = obj.makeKey(portName, deviceID);
            angle_deg = obj.controllers(key).getAngle();
        end

        function list = listDeviceIDs(obj)
            list = keys(obj.controllers);
        end
    end

    methods (Access = private)
        function key = makeKey(~, portName, deviceID)
            key = [portName '_' deviceID];
        end

        function serialObj = getOrCreateSerial(obj, portName)
            if isKey(obj.serialPool, portName)
                serialObj = obj.serialPool(portName);
            else
                serialObj = serialport(portName, 9600);
                configureTerminator(serialObj, "CR");
                flush(serialObj);
                obj.serialPool(portName) = serialObj;
            end
        end
    end
end
