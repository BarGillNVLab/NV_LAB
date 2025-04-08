function MagneticFieldGUI
% Creates list of opened figure and check if MagneticFieldGUI is already
% open. If it's open, return it.
control = []; %this will be initialized to hold external field class latter on.
list = get(0, 'Children');
for i = 1:size(list,1)
    if strcmp(handle(list(i)).Name, 'MagneticFieldGUI')
        sprintf('MagneticFieldGUI is already open')
        figure(list(i));
        return
    end
end

%% Open stages

%% Parameters
minSize = [650,300];
fontSize = 10;
normalTextProps = {'Style', 'text', 'FontSize', 8, 'ForegroundColor', 'black', 'BackgroundColor', 'white', 'HorizontalAlignment', 'left'};
textProps = {'Style', 'edit', 'FontSize', fontSize, 'FontWeight', 'bold', 'ForegroundColor', 'white', 'BackgroundColor', 'black', 'HorizontalAlignment', 'center', 'Enable', 'inactive'};
editProps = {'Style', 'edit', 'FontSize', fontSize, 'FontWeight', 'bold', 'ForegroundColor', 'black', 'BackgroundColor', 'white', 'HorizontalAlignment', 'center'};
buttonProps = {'Style', 'pushbutton', 'FontSize', fontSize, 'FontWeight', 'bold'};
checkboxProps = {'Style', 'checkbox', 'FontSize', fontSize};
popupProps = {'Style', 'popup', 'BackgroundColor', 'white', 'FontSize', fontSize};
radioProps = {'Style', 'radiobutton', 'FontSize', fontSize};
sliderProps = {'Style', 'slider'};

%% Create figure
handles.figure = figure('Name', 'MagneticFieldGUI', 'Position', [200 200 minSize], 'MenuBar', 'none', 'Toolbar', 'none', ...
    'NumberTitle', 'off', 'CloseRequestFcn', @CloseRequestFcn_Callback);
% Make sure resize doesn't make it too small
handles.figure.SizeChangedFcn = @(~,~) set(handles.figure, 'Position', max([0 0 minSize], handles.figure.Position));

% Creating the left column box
handles.figureLayout.mainColumns = uix.HBox('Parent', handles.figure, 'Spacing', 5, 'Padding', 5);
handles.figureLayout.leftColumn = uix.VBox('Parent', handles.figureLayout.mainColumns, 'Spacing', 5);
%handles.figureLayout.middleColumn = uix.VBox('Parent', handles.figureLayout.mainColumns, 'Spacing', 5);
handles.figureLayout.rightColumn = uix.VBox('Parent', handles.figureLayout.mainColumns, 'Spacing', 5);
set(handles.figureLayout.mainColumns, 'Widths', [400 -1]);

% Creating the left column boxes
%handles.figureLayout.scanParametersBox = uix.BoxPanel('Parent', handles.figureLayout.leftColumn, 'Title', 'Scan Parameters', 'Padding', 5);
handles.figureLayout.movementAndScanBox = uix.HBox('Parent', handles.figureLayout.leftColumn, 'Spacing', 5);
handles.figureLayout.movementControlBox = uix.BoxPanel('Parent', handles.figureLayout.movementAndScanBox, 'Title', 'Movement Control', 'Padding', 5);
%handles.figureLayout.scanBox = uix.BoxPanel('Parent', handles.figureLayout.movementAndScanBox, 'Title', 'Scan', 'Padding', 5);
%set(handles.figureLayout.movementAndScanBox, 'Widths', [275 -1]);
handles.figureLayout.stageLimitsBox = uix.BoxPanel('Parent', handles.figureLayout.rightColumn, 'Title', 'Stage Limits', 'Padding', 5);
%set(handles.figureLayout.leftColumn, 'Heights', [200 200 150]);

%% Movement Area
handles.figureLayout.movementControl = uix.HBox('Parent', handles.figureLayout.movementControlBox, 'Spacing', 5);
handles.figureLayout.movementControlArrowColumn = uix.VBox('Parent', handles.figureLayout.movementControl, 'Spacing', 5);
uix.Empty('Parent', handles.figureLayout.movementControl);
handles.figureLayout.movementControlOthersColumn = uix.VBox('Parent', handles.figureLayout.movementControl, 'Spacing', 5);
set(handles.figureLayout.movementControl, 'Widths', [200 5 -1]);


%% Rerad stage names from JSON file
stageNames = JsonInfoReader.getJson().magneticStages;
stageNames = {stageNames(:).axisName};
numStages = length(stageNames);
%% Create numStagesmovment areas, depending on the number of stages;
for k = 1:numStages
    eval(sprintf('handles.figureLayout.movementControl%sArrow = uix.HBox(''Parent'', handles.figureLayout.movementControlArrowColumn, ''Spacing'', 7);',num2str(k)));
    eval(sprintf('handles.figureLayout.movementControl%sLabel = uicontrol(textProps{:}, ''Parent'', handles.figureLayout.movementControl%sArrow, ''String'', stageNames{%d});',num2str(k),num2str(k),k));
    eval(sprintf('handles.Left%s = uicontrol(buttonProps{:}, ''Parent'', handles.figureLayout.movementControl%sArrow, ''string'', ''¬'', ''FontName'', ''Symbol'', ''FontSize'', 16,''Callback'',@Left%s_Callback);',num2str(k),num2str(k),num2str(k)));
    eval(sprintf('handles.Value%s = uicontrol(editProps{:}, ''Parent'', handles.figureLayout.movementControl%sArrow);',num2str(k),num2str(k)));
    eval(sprintf('handles.Right%s = uicontrol(buttonProps{:}, ''Parent'', handles.figureLayout.movementControl%sArrow, ''string'', ''®'', ''FontName'', ''Symbol'', ''FontSize'', 16,''Callback'',@Right%s_Callback);',num2str(k),num2str(k),num2str(k)));
end

%% steps
handles.figureLayout.movementControlLinearStep = uix.HBox('Parent', handles.figureLayout.movementControlArrowColumn, 'Spacing', 7);
uix.Empty('Parent', handles.figureLayout.movementControlLinearStep);
handles.figureLayout.movementControlStepLabel = uicontrol(textProps{:}, 'Parent', handles.figureLayout.movementControlLinearStep, 'String', 'Step mm:');
handles.StepSize = uicontrol(editProps{:}, 'Parent', handles.figureLayout.movementControlLinearStep,'Callback',@StepSize_Callback,'String','1','Value',1);

handles.figureLayout.movementControlAngleStep = uix.HBox('Parent', handles.figureLayout.movementControlArrowColumn, 'Spacing', 7);
uix.Empty('Parent', handles.figureLayout.movementControlAngleStep);
handles.figureLayout.movementControlStepLabel = uicontrol(textProps{:}, 'Parent', handles.figureLayout.movementControlAngleStep, 'String', 'Step deg:');
handles.StepSizeDeg = uicontrol(editProps{:}, 'Parent', handles.figureLayout.movementControlAngleStep,'Callback',@StepSizeDeg_Callback,'String','10','Value',10);

%% Others Column
handles.FixPos = uicontrol(buttonProps{:}, 'Parent', handles.figureLayout.movementControlOthersColumn, 'string', 'Fix Position','Callback',@FixPos_Callback);
handles.QueryPos = uicontrol(buttonProps{:}, 'Parent', handles.figureLayout.movementControlOthersColumn, 'string', 'Query Position','Callback',@QueryPos_Callback);
handles.StopMovement = uicontrol(buttonProps{:}, 'Parent', handles.figureLayout.movementControlOthersColumn, 'string', 'Halt Stages!', 'ForegroundColor', 'white', 'BackgroundColor', 'red', 'Fontsize', 14,'Callback',@StopMovement_Callback);
handles.Reset = uicontrol(buttonProps{:}, 'Parent', handles.figureLayout.movementControlOthersColumn, 'string', 'Reset','Callback',@Reset_Callback);
handles.Home = uicontrol(buttonProps{:}, 'Parent', handles.figureLayout.movementControlOthersColumn, 'string', 'Home','Callback',@Home_Callback);


%% Stage Limits Area
handles.figureLayout.stageLimits = uix.Grid('Parent', handles.figureLayout.stageLimitsBox, 'Spacing', 7);

% 1st Column
uix.Empty('Parent', handles.figureLayout.stageLimits);
for k = 1:numStages
    eval(sprintf('handles.figureLayout.stageLimits%sLabel = uicontrol(textProps{:}, ''Parent'', handles.figureLayout.stageLimits, ''String'', stageNames{%f});',num2str(k),k))     
end
uix.Empty('Parent', handles.figureLayout.stageLimits);
% 2nd Column
handles.figureLayout.stageLimitsLowerLabel = uicontrol(textProps{:}, 'Parent', handles.figureLayout.stageLimits, 'String', 'Lower');
for k = 1:numStages
    eval(sprintf('handles.llimit%s = uicontrol(editProps{:}, ''Parent'', handles.figureLayout.stageLimits,''Callback'',@llimit%s_Callback);',num2str(k),num2str(k)))
end
uix.Empty('Parent', handles.figureLayout.stageLimits);
% 3rd Column
handles.figureLayout.stageLimitsLowerLabel = uicontrol(textProps{:}, 'Parent', handles.figureLayout.stageLimits, 'String', 'Upper');
for k = 1:numStages
    eval(sprintf('handles.ulimit%s = uicontrol(editProps{:}, ''Parent'', handles.figureLayout.stageLimits,''Callback'',@ulimit%s_Callback);',num2str(k),num2str(k)))
end
uix.Empty('Parent', handles.figureLayout.stageLimits);
% % 4th Column
for k = 1:numStages
    uix.Empty('Parent', handles.figureLayout.stageLimits);
end
uix.Empty('Parent', handles.figureLayout.stageLimits);
set(handles.figureLayout.stageLimits, 'Widths', [25 55*ones(1,numStages-1) -1], 'Heights', [-3 -5*ones(1,numStages-1) -5 -1]);

%% Connect to stages
try
    control = ClassExternalFieldControl.GetInstance(handles); %connect to the external magnetic fields    
catch err
    rethrow(err);
end
%% Quary the position for the first time
QueryPos_Callback([],[])

%% Validation functions
    function oldValue = CheckValueInLimits(hObject, lowerLimit, upperLimit)
        % Checks if the value written in hObject 'String' is within the limits,
        % if not, restores the old value.
        % Old value is stored in the 'UserData' and in handled via this
        % function.
        oldValue = get(hObject, 'UserData');
        value = str2double(get(hObject, 'String'));
        if (isnan(value) || value <  lowerLimit || value > upperLimit)
            fprintf('Value should be between %.4f & %.4f!\n', lowerLimit, upperLimit);
            set(hObject, 'String', oldValue);
            oldValue = -inf;
        else
            set(hObject, 'UserData', value);
        end
    end

%     function MovementControl(what, handles)
%         % Enables or disables (Greys out) the movement control buttons.
%         % Control can be either 'On' or 'Off'
%         for n = 1:numStages
%             eval(sprints("set(handles.Left%s, 'Enable', %s);",num2str(n),what))
%             eval(sprints("set(handles.Right%s, 'Enable', %s);",num2str(n),what))
%             eval(sprints("set(handles.Value%s, 'Enable', %s);",num2str(n),what))
%         end
%         set(handles.FixPos, 'Enable', what);        
%         set(handles.Scan, 'Enable', what);
%         set(handles.QueryPos, 'Enable', what);
%     end

    function CheckValueIsNatural(hObject)
        % Checks if the value written in hObject 'String' is a positive
        % integer, if not, restores the old value.
        % Old value is stored in the 'UserData' and in handled via this
        % function.
        oldValue = get(hObject, 'UserData');
        value = str2double(get(hObject, 'String'));
        if (isnan(value) || mod(value,1) ~= 0 || value <= 0)
            fprintf('Value should a positive integer!\n');
            set(hObject, 'String', oldValue);
        else
            set(hObject, 'UserData', value);
        end
    end

    function CheckValueIsPositive(hObject)
        % Checks if the value written in hObject 'String' is a positive
        % number, if not, restores the old value.
        % Old value is stored in the 'UserData' and in handled via this
        % function.
        oldValue = hObject.Value;
        value = str2double(hObject.String);
        if (isnan(value) || value <= 0)
            fprintf('Value should be a positive number!\n');
            hObject.String = num2str(oldValue);
        else
            hObject.Value = value;
        end
    end

  
%% GUI callbacks
 % --- Executes left button press in XLeft.
    function Step(index,sign)
        steps.linear = sign*str2double(handles.StepSize.String);
        steps.rotation = sign*str2double(handles.StepSizeDeg.String);
        control.Step(index,steps);
    end
    function Left1_Callback(hObject, eventdata)
        % handles    structure with handles to all objects in the GUI        
        index = 1;
        sign = -1;        
        Step(index,sign)
    end
    function Left2_Callback(hObject, eventdata)
        % handles    structure with handles to all objects in the GUI
        index = 2;
        sign = -1;        
        Step(index,sign)
    end
    function Left3_Callback(hObject, eventdata)
        % handles    structure with handles to all objects in the GUI
        index = 3;
        sign = -1;        
        Step(index,sign)
    end
    function Left4_Callback(hObject, eventdata)
        % handles    structure with handles to all objects in the GUI
        index = 4;
        sign = -1;        
        Step(index,sign)
    end
    % --- Executes right button press in XLeft.
    function Right1_Callback(hObject, eventdata)
        % handles    structure with handles to all objects in the GUI
        index = 1;      
        sign = 1;        
        Step(index,sign)
    end
    function Right2_Callback(hObject, eventdata)
        % handles    structure with handles to all objects in the GUI
        index = 2;
        sign = 1;        
        Step(index,sign)
    end
    function Right3_Callback(hObject, eventdata)
        % handles    structure with handles to all objects in the GUI
        index = 3;
        sign = 1;        
        Step(index,sign)
    end
    function Right4_Callback(hObject, eventdata)
        % handles    structure with handles to all objects in the GUI
        index = 4;
        sign = 1;        
        Step(index,sign)
    end
 
% --- Executes on button press in FixPos.
    function FixPos_Callback(hObject, eventdata)
        % handles    structure with handles to all objects in the GUI
        for m = 1:numStages
            newPos = str2double(eval(sprintf('handles.Value%s.String',num2str(m))));
            
            control.SetPosition(m,newPos);
        end
    end

% --- Executes on button press in QueryPos.
    function QueryPos_Callback(hObject, eventdata)
        % handles    structure with handles to all objects in the GUI
        control.quaryPos();
    end

% --- Executes on button press in StopMovement
    function StopMovement_Callback(hObject, eventdata)
        % handles    structure with handles to all objects in the GUI
        control.Stop;
    end

    function StepSize_Callback(hObject, eventdata)
        % handles    structure with handles to all objects in the GUI
        CheckValueIsPositive(hObject);
    end
    function StepSizeDeg_Callback(hObject, eventdata)
        % handles    structure with handles to all objects in the GUI
        CheckValueIsPositive(handles.StepSizeDeg);
    end

    function llimit1_Callback(hObject, eventdata)
        % Get hard limits, compare and then change soft limits'
        % handles    structure with handles to all objects in the GUI
        val = str2double(handles.llimit1.String);
        control.SetSoftLimitsMin(1, val)
    end
    function llimit2_Callback(hObject, eventdata)
        % Get hard limits, compare and then change soft limits'
        % handles    structure with handles to all objects in the GUI
        val = str2double(handles.llimit2.String);
        control.SetSoftLimitsMin(2, val)
    end
    function llimit3_Callback(hObject, eventdata)
        % Get hard limits, compare and then change soft limits'
        % handles    structure with handles to all objects in the GUI
        val = str2double(handles.llimit3.String);
        control.SetSoftLimitsMin(3, val)
    end
    function llimit4_Callback(hObject, eventdata)
        % Get hard limits, compare and then change soft limits'
        % handles    structure with handles to all objects in the GUI
        val = str2double(handles.llimit4.String);
        control.SetSoftLimitsMin(4, val)
    end
    function ulimit1_Callback(hObject, eventdata)
        % Get hard limits, compare and then change soft limits'
        % handles    structure with handles to all objects in the GUI
        val = str2double(handles.ulimit1.String);
        control.SetSoftLimitsMax(1, val)
    end
    function ulimit2_Callback(hObject, eventdata)
        % Get hard limits, compare and then change soft limits'
        % handles    structure with handles to all objects in the GUI
        val = str2double(handles.ulimit2.String);
        control.SetSoftLimitsMax(2, val)
    end
    function ulimit3_Callback(hObject, eventdata)
        % Get hard limits, compare and then change soft limits'
        % handles    structure with handles to all objects in the GUI
        val = str2double(handles.ulimit3.String);
        control.SetSoftLimitsMax(3, val)
    end
    function ulimit4_Callback(hObject, eventdata)
        % Get hard limits, compare and then change soft limits'
        % handles    structure with handles to all objects in the GUI
        val = str2double(handles.ulimit4.String);
        control.SetSoftLimitsMax(4, val)
    end
    function CloseRequestFcn_Callback(hObject, eventdata)
        try
            if isempty(control)
            else
                control.Close;
            end
            delete(hObject);
        catch err
            warning(err)
            delete(hObject);
        end
    end
    function Reset_Callback(hObject, eventdata)
       control.Reset()
    end
    function Home_Callback(hObject, eventdata)
       control.Home()
    end
end