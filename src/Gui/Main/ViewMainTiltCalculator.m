classdef ViewMainTiltCalculator < GuiComponent
    %VIEWMAINTILTCALCULATOR tilt calculator GUI
    %   consists of 3 points, (x, y and z axes)
    %   each point has 2 setter buttons
    %
    
    properties
        edtX1      % edit input
        edtY1      % edit input
        edtZ1      % edit input
        edtX2      % edit input
        edtY2      % edit input
        edtZ2      % edit input
        edtX3      % edit input
        edtY3      % edit input
        edtZ3      % edit input
        
        stageName  % string
        tiltPointsSaver % object that has the properties tiltPoint1, tiltPoint2, tiltPoint3
    end
    
    methods
        function obj = ViewMainTiltCalculator(parent, controller, stageConnector)
            % stageConnector - object which has those properties: stageName, tiltPoint1, tiltPoint2, tiltPoint3
            
            obj@GuiComponent(parent, controller);
            obj.tiltPointsSaver = stageConnector;
            obj.stageName = stageConnector.stageName;
            
            mainPanel = uipanel(parent.component, 'BackgroundColor', [0.941 0.941 0.941]);
            
            xColumn = 20;
            yColumn = xColumn+70;
            zColumn = yColumn+70;
            buttonSetCurrentColumn = zColumn + 70;
            buttonSetFixedColumn = buttonSetCurrentColumn + 120;
            buttonRow = 20;
            rowSpace = 38;
            row1 = buttonRow + rowSpace;
            row2 = buttonRow + (2*rowSpace);
            row3 = buttonRow + (3*rowSpace);
            row4 = buttonRow + (4*rowSpace);
            
            width = 60;
            height = 30;
            
            obj.width = buttonSetFixedColumn + 2 * width;
            obj.height = row4 + height;
            
            
            fontSize = 10;
            
            % label x
            uicontrol(mainPanel, 'Style', 'text', 'position', [xColumn+10 row4 30 20],...
                'ForegroundColor', [0.502 0.502 0.502],...
                'string', 'x', 'FontSize', 10);
            
            % label y
            uicontrol(mainPanel, 'Style', 'text', 'position', [yColumn+12 row4 30 20],...
                'ForegroundColor', [0.502 0.502 0.502],...
                'string', 'y', 'FontSize', 10);
            
            
            % label z
            uicontrol(mainPanel, 'Style', 'text', 'position', [zColumn+12 row4 40 20],...
                'ForegroundColor', [0.502 0.502 0.502],...
                'string', 'z', 'FontSize', 10);
            
            % x coordinate
            
            obj.edtX1 = uicontrol(mainPanel, 'Style', 'edit', 'position', [xColumn row3 width height],...
                'ForegroundColor', 'black',...
                'string', 'x1', 'FontSize', fontSize, 'FontWeight', 'bold',...
                'BackgroundColor', 'white', 'HorizontalAlignment', 'center');
            obj.edtX2 = uicontrol(mainPanel, 'Style', 'edit', 'position', [xColumn row2 width height],...
                'ForegroundColor', 'black',...
                'string', 'x2', 'FontSize', fontSize, 'FontWeight', 'bold',...
                'BackgroundColor', 'white', 'HorizontalAlignment', 'center');
            obj.edtX3 = uicontrol(mainPanel, 'Style', 'edit', 'position', [xColumn row1 width height],...
                'ForegroundColor', 'black',...
                'string', 'x3', 'FontSize', fontSize, 'FontWeight', 'bold',...
                'BackgroundColor', 'white', 'HorizontalAlignment', 'center');
            
            % y coordinate
            obj.edtY1 = uicontrol(mainPanel, 'Style', 'edit', 'position', [yColumn row3 width height],...
                'ForegroundColor', 'black',...
                'string', 'y1', 'FontSize', fontSize, 'FontWeight', 'bold',...
                'BackgroundColor', 'white', 'HorizontalAlignment', 'center',...
                'FontUnits', 'pixels', 'FontName', 'MS Sans Serif');
            obj.edtY2 = uicontrol(mainPanel, 'Style', 'edit', 'position', [yColumn row2 width height],...
                'ForegroundColor', 'black',...
                'string', 'y2', 'FontSize', fontSize, 'FontWeight', 'bold',...
                'BackgroundColor', 'white', 'HorizontalAlignment', 'center',...
                'FontUnits', 'pixels', 'FontName', 'MS Sans Serif');
            obj.edtY3 = uicontrol(mainPanel, 'Style', 'edit', 'position', [yColumn row1 width height],...
                'ForegroundColor', 'black',...
                'string', 'y3', 'FontSize', fontSize, 'FontWeight', 'bold',...
                'BackgroundColor', 'white', 'HorizontalAlignment', 'center',...
                'FontUnits', 'pixels', 'FontName', 'MS Sans Serif');
            
            % z coordinate
            obj.edtZ1 = uicontrol(mainPanel, 'Style', 'edit', 'position', [zColumn row3 width height],...
                'ForegroundColor', 'black',...
                'string', 'z1', 'FontSize', fontSize, 'FontWeight', 'bold',...
                'BackgroundColor', 'white', 'HorizontalAlignment', 'center');
            obj.edtZ2 = uicontrol(mainPanel, 'Style', 'edit', 'position', [zColumn row2 width height],...
                'ForegroundColor', 'black',...
                'string', 'z2', 'FontSize', fontSize, 'FontWeight', 'bold',...
                'BackgroundColor', 'white', 'HorizontalAlignment', 'center');
            obj.edtZ3 = uicontrol(mainPanel, 'Style', 'edit', 'position', [zColumn row1 width height],...
                'ForegroundColor', 'black',...
                'string', 'z3', 'FontSize', fontSize, 'FontWeight', 'bold',...
                'BackgroundColor', 'white', 'HorizontalAlignment', 'center');
            
            % Buttons
            btnSetCur1 = uicontrol(mainPanel, 'Style', 'pushbutton', ...
                'position', [buttonSetCurrentColumn row3 width+50 height],...
                'string', 'Set to current point', 'FontSize',8);
            btnSetCur2 = uicontrol(mainPanel, 'Style', 'pushbutton', ...
                'position', [buttonSetCurrentColumn row2 width+50 height],...
                'string', 'Set to current point', 'FontSize',8);
            btnSetCur3 = uicontrol(mainPanel, 'Style', 'pushbutton', ...
                'position', [buttonSetCurrentColumn row1 width+50 height],...
                'string', 'Set to current point', 'FontSize',8);
            
            btnSetFixed1 = uicontrol(mainPanel, 'Style', 'pushbutton', ...
                'position', [buttonSetFixedColumn row3 width+50 height],...
                'string', 'Set to fixed position', 'FontSize',8);
            btnSetFixed2 = uicontrol(mainPanel, 'Style', 'pushbutton', ...
                'position', [buttonSetFixedColumn row2 width+50 height],...
                'string', 'Set to fixed position', 'FontSize',8);
            btnSetFixed3 = uicontrol(mainPanel, 'Style', 'pushbutton', ...
                'position', [buttonSetFixedColumn row1 width+50 height],...
                'string', 'Set to fixed position', 'FontSize',8);
            
            btnCalculateAngles = uicontrol(mainPanel, 'Style', 'pushbutton', ...
                'position', [xColumn+9 buttonRow 3*width height],...
                'string', 'Calculate angles', 'FontSize',8);
            
            
            
            
            obj.stageName = stageConnector.stageName;
            % example: point3 = stageConnector.tiltPoint3;
            
            xyz = 'XYZ';
            for pIndex = 1: 3
                for xyzIndex = 1: 3
                    stageTiltPoint = str2func(sprintf('stageConnector.tiltPoint%d', pIndex));
                    point = stageTiltPoint;
                    if ~isnan(point)
                        eval(sprintf('obj.edt%s%d.String = point(%d);', ...
                            xyz(xyzIndex), ...
                            pIndex, ...
                            xyzIndex));
                    end
                end
            end
            
            %%%% callbacks %%%%
            for i = 1: 3
                eval(sprintf('btnSetCur%d.Callback = @(e,h) obj.btnSetToCurrentPointCallback(%d);', i, i));
                eval(sprintf('btnSetFixed%d.Callback = @(e,h) obj.btnSetToFixedCallback(%d);', i, i));
            end
            btnCalculateAngles.Callback = @(e,h) obj.calculateAnglesCallback();
            
        end
        
        function btnSetToFixedCallback(obj, pointNumber)
            % pointNumber - can be 1, 2 or 3
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            point = stage.scanParams.fixedPos;
            obj.updatePoint(point, pointNumber);    
        end
        
        function btnSetToCurrentPointCallback(obj, pointNumber)
            % pointNumber - can be 1, 2 or 3
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            
            point = stage.Pos('XYZ');
            obj.updatePoint(point, pointNumber);
        end
        
        function updatePoint(obj, point, pointNumber) %#ok<INUSL>
            % point - the actual point. 1x3 double
            % point number - can be 1, 2 or 3
            xyz = 'XYZ';
            % "li" ---> letter index. iterate over the string 'XYZ'
            for li = 1 : 3
                eval(sprintf('obj.edt%s%d.String = point(%d);',xyz(li), pointNumber, li));
            end
            eval(sprintf('obj.tiltPointsSaver.tiltPoint%d = point;', pointNumber));
        end
        
        function calculateAnglesCallback(obj)
            x1 = str2double(obj.edtX1.String);
            x2 = str2double(obj.edtX2.String);
            x3 = str2double(obj.edtX3.String);
            y1 = str2double(obj.edtY1.String);
            y2 = str2double(obj.edtY2.String);
            y3 = str2double(obj.edtY3.String);
            z1 = str2double(obj.edtZ1.String);
            z2 = str2double(obj.edtZ2.String);
            z3 = str2double(obj.edtZ3.String);
            
            deltaX12 = x2 - x1;
            deltaX23 = x3 - x2;
            
            deltaY12 = y2 - y1;
            deltaY23 = y3 - y2;
            
            deltaZ12 = z2 - z1;
            deltaZ23 = z3 - z2;
            
            anglesVec = atan([deltaX12 deltaY12; deltaX23 deltaY23]^-1*[deltaZ12; deltaZ23])*180/pi;
            
            anglesVec(isnan(anglesVec)) = 0; % This means that deltaZ was zero, so angle should be zero
            thetaXZ = anglesVec(1);
            thetaYZ = anglesVec(2);
            
            stage = getObjByName(obj.stageName);
            if isempty(stage); throwBaseObjException(obj.stageName); end
            stage.setTiltAngle(thetaXZ, thetaYZ);
            
            % update the points to be saved in the gui
            for i = 1: 3
                eval(sprintf('obj.tiltPointsSaver.tiltPoint%d = [x%d y%d z%d];',i,i,i,i));
            end
        end
    end
    
    
end
