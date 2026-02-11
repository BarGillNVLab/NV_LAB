classdef ElliptecGUI < handle
    properties
        fig
        ui
        manager
    end

    methods
        function obj = ElliptecGUI(manager)
            if nargin < 1 || isempty(manager)
                manager = ElliptecManager();
            end
            obj.manager = manager;
            keysList = obj.manager.listDeviceIDs();
            n = numel(keysList);

            obj.fig = figure('Name', 'Elliptec Waveplate Control', 'NumberTitle', 'off', ...
                             'MenuBar', 'none', 'ToolBar', 'none', 'Position', [400, 300, 500, 100 + 60 * n]);
            obj.ui = struct();

            for i = 1:n
                key = keysList{i};
                y = 100 + (n - i) * 60;

                uicontrol(obj.fig, 'Style', 'text', 'String', ['Waveplate: ' key], ...
                          'Position', [10, y+25, 100, 20], 'HorizontalAlignment', 'left');

                obj.ui.(key).posText = uicontrol(obj.fig, 'Style', 'text', 'String', 'Angle: --', ...
                          'Position', [120, y+25, 100, 20]);

                obj.ui.(key).absField = uicontrol(obj.fig, 'Style', 'edit', 'String', '0', ...
                          'Position', [230, y+25, 60, 20]);

                uicontrol(obj.fig, 'Style', 'pushbutton', 'String', 'Go To', ...
                          'Position', [300, y+25, 50, 20], ...
                          'Callback', @(~,~) obj.moveTo(key));

                obj.ui.(key).relField = uicontrol(obj.fig, 'Style', 'edit', 'String', '0', ...
                          'Position', [360, y+25, 60, 20]);

                uicontrol(obj.fig, 'Style', 'pushbutton', 'String', 'Move Rel', ...
                          'Position', [430, y+25, 60, 20], ...
                          'Callback', @(~,~) obj.jog(key));

                obj.refresh(key);
            end

            uicontrol(obj.fig, 'Style', 'pushbutton', 'String', 'Refresh All', ...
                      'Position', [200, 20, 100, 30], ...
                      'Callback', @(~,~) obj.refreshAll());
        end

        function moveTo(obj, key)
            angle = str2double(obj.ui.(key).absField.String);
            [port, id] = strtok(key, '_'); id = extractAfter(id, 1);
            obj.manager.moveToAngle(port, id, angle);
            obj.refresh(key);
        end

        function jog(obj, key)
            delta = str2double(obj.ui.(key).relField.String);
            [port, id] = strtok(key, '_'); id = extractAfter(id, 1);
            ctrl = obj.manager.controllers(key);
            ctrl.jog(delta);
            pause(0.1);
            obj.refresh(key);
        end

        function refresh(obj, key)
            [port, id] = strtok(key, '_'); id = extractAfter(id, 1);
            angle = obj.manager.getAngle(port, id);
            obj.ui.(key).posText.String = sprintf('Angle: %.2f', angle);
        end

        function refreshAll(obj)
            keysList = obj.manager.listDeviceIDs();
            for i = 1:numel(keysList)
                obj.refresh(keysList{i});
            end
        end
    end
end
