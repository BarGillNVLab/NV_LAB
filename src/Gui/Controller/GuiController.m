classdef GuiController < handle
    %MAINCONTROLLER controls the communication between the GUI and the physics
    %   Detailed explanation goes here
    
    properties (Access = public)
        views  % 1D array of gui components
        windowMinHeight = 0     % will be set when starting to the mainView.height
        windowMinWidth = 0      % will be set when starting to the mainView.width
        figureWindow            % the window
        confirmOnClose          % boolean. Should we ask the user before closing?
        openOnlyOne             % boolean. Should we restrict opening multiple instances of this window?
        startPosition = nan     % point on screen (1x2 double) or nan if not important
        windowName              % string
        screenWidth             % integer. in pixels
        screenHeight            % integer. in pixels
    end
    
    properties (Constant)
        POSITION_INDEX_X0_LEFT = 1
        POSITION_INDEX_Y0_BOT = 2
        POSITION_INDEX_WIDTH = 3
        POSITION_INDEX_HEIGHT = 4
    end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %                                                %
            %   Copy & Paste any one of the lines below!     %
            %       (Some nice callbacks lie here,           %
            %         waiting to be overridden...)           %
            %                                                %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %     %% Various callbacks to be overriden if needed
    %     methods
    %         function onAboutToStart(obj)
    %             % Callback. Things to run right before the window is
    %             % drawn on the screen.
    %             % Child classes can override this method
    %         end
    %
    %         function onStarted(obj)
    %             % Callback. Things to run after the window is already
    %             % started and running.
    %             % Child classes can override this method
    %         end
    %         function onSizeChanged(obj, newX0, newY0, newWidth, newHeight)
    %             % Callback. Things to run when the window size is changed
    %             % Child classes can override this method
    %         end
    %
    %         function bool = onAboutToclose(obj)
    %             % Callbcak. Things to run before closing. Returns true to close,
    %             % or false to abort closing
    %             bool = true;
    %         end
    %         function onClose(obj)
    %             % Callback. Things to run when need to close the GUI.
    %             % Child classes can override this method
    %         end
    %     end
    
    methods
        function obj = GuiController(windowName, confirmOnClose, openOnlyOne)
            obj = obj@handle;
            obj.windowName = windowName;
            obj.views = {};
            obj.confirmOnClose = confirmOnClose;
            obj.openOnlyOne = openOnlyOne;
        end
		
		% Start running the GUI window
        function start(obj)
            openAlready = GuiController.findOpenOrNan(obj.windowName);
            if obj.openOnlyOne && isobject(openAlready)
%                 fprintf('%s is already open!\n', obj.windowName);
                figure(openAlready);
            else
                try
                    obj.figureWindow = obj.createNewFigureInvis();
                    screenSize = get(groot, 'MonitorPositions');
                    obj.screenWidth = screenSize(obj.POSITION_INDEX_WIDTH);
                    obj.screenHeight = screenSize(obj.POSITION_INDEX_HEIGHT);
                    windowsBarHeight = 40;	% in px. Height of both taskbar and titlebar
                    
                    dummyGuiComponent.component = obj.figureWindow;
                    mainView = obj.getMainView(dummyGuiComponent);
                    obj.windowMinHeight = min(mainView.height, obj.screenHeight-2*windowsBarHeight); % The actual size of the screen is minus the taskbar and the titlebar 
                    obj.windowMinWidth = min(mainView.width, obj.screenWidth);
                    
                    obj.onAboutToStart();
                    obj.figureWindow.Visible = 'on';
                    obj.onStarted();
                catch err
                    delete(obj.figureWindow);
                    cellfun(@(v) delete(v), obj.views);
                    rethrow(err);
                end
            end
        end  % constructor
        
		% add a view to be called when the GUI will close
        function addView(obj, view)
            obj.views{end + 1} = view;
        end
        
    end
    
    %% Various callbacks to be overriden if needed
    methods
        function onAboutToStart(obj)
            % Callback. Things to run right before the window will be drawn
            % to the screen.
            % Child classes can override this method
        end
        
        function onStarted(obj)
            % Callback. Things to run after the window is already started
            % and running.
            % Child classes can override this method
        end
        
        function onSizeChanged(obj, newX0, newY0, newWidth, newHeight)
            % Callback. Things to run when the window size is changed
            % Child classes can override this method
        end
        
        function tf = onAboutToclose(obj)
            % Callbcak. Things to run before closing. Returns true to close,
            % or false to abort closing
            tf = true;
        end
        
        function onClose(obj)
            % Callback. Things to run when need to close the GUI.
            % Child classes can override this method
        end
    end
    
    methods
	
        % Actual callback used when user is trying to close the GUI window
        function callbackCloseRequest(obj, hObject)
            if ~obj.onAboutToclose; return; end
            
            if obj.confirmOnClose
                needToClose = QuestionUserYesNo(...
                    'Close Request Function', ...
                    sprintf('Are you sure you want to close %s?',...
                    obj.windowName));
            else
                needToClose = true;
            end
            
            if needToClose
                fprintf('Closing GUI "%s"\n', obj.windowName);
                for k = 1 : length(obj.views)
                    obj.views{k}.onCloseGui();
                end
                
                try 
                    obj.onClose();
                catch err
                    delete(hObject);
                    EventStation.anonymousWarning( ...
                        'Failed to properly terminate process. Closing window anyway.');
                    rethrow(err);
                end
                
                delete(hObject);
            end
        end
        
		% Callback that runs when the user changes the window size
		% Due to a MATLAB bug, this callback doesn't jump when the user drags the window, only on resizing
        function callbackSizeChanged(obj)
            % Make sure the view isn't too small!
            currentSize = obj.figureWindow.Position(3 : 4);
            [newX0, newY0, newWidth, newHeight] = multipleAssign(obj.figureWindow.Position);
            obj.onSizeChanged(newX0, newY0, newWidth, newHeight);
            windowMinSize = [obj.windowMinWidth obj.windowMinHeight];
            if ~any(windowMinSize > currentSize); return; end
            newSize = max(windowMinSize, currentSize);
            currentStartPoint = obj.figureWindow.Position(1 : 2);
            obj.figureWindow.Position = [currentStartPoint newSize];
        end
    end
    
    %% Helper methods
    methods
        function toFullscreen(obj)
            % Change the object size to be fullscreen
            obj.figureWindow.Position = [0,0, obj.screenWidth, obj.screenHeight];
        end
        
        function toAlmostFullscreen(obj)
            % Change the figure size to be almost fullscreen - leaving only
            % the "start" windows-bottom-line visible
            obj.figureWindow.Position = [2,40, obj.screenWidth - 3, obj.screenHeight - 65];
        end
        
        function maximize(obj)
            % Maximize the window.
            % This function can only run AFTER the window has been rendered. Calling it on an invisible window won't work
            warning('off', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
            jFrame = get(handle(obj.figureWindow), 'JavaFrame');
            set(jFrame, 'Maximized', true);
        end
        
		% Move the window to the middle of the screen
        function moveToMiddleOfScreen(obj)
            oldPos = obj.figureWindow.Position;
            fWidth = max(oldPos(obj.POSITION_INDEX_WIDTH), obj.windowMinWidth);
            fHeight = max(oldPos(obj.POSITION_INDEX_HEIGHT), obj.windowMinHeight);
            spaceX = max(obj.screenWidth - fWidth, 0);
            spaceY = max(obj.screenHeight - fHeight, 0);
            newX0 = spaceX / 2;
            newY0 = spaceY / 2;
            obj.figureWindow.Position = [newX0 newY0 fWidth fHeight];
        end
        
		% Create a new figure (window) to place the GUI inside
        function figureWindow = createNewFigureInvis(obj)
            % The figure is invisible when created, so that it will take
            % less time to load it (changing strings inside, etc.).
            % Only when it's ready, someone will need to call -
            % figureWindow.Visible = 'on'
            if isnan(obj.startPosition)
                startPos = [50 50];
            else
                startPos = obj.startPosition;
            end
            figureWindow = figure('Name', obj.windowName, ...
                'Position', [startPos obj.windowMinWidth obj.windowMinHeight], ...
                'MenuBar', 'none',...
                'Toolbar', 'none', ...
                'NumberTitle', 'off',...
                'Visible', 'off', ...
                ...
                ... % Closing - if anything else needs to be close d make it in this callback
               'CloseRequestFcn', @(hObject, eventdata, handles) obj.callbackCloseRequest(hObject), ...
                ...
                ... % Make sure resize doesn't make it too small
                'SizeChangedFcn', @(hObject, eventdata, handles) obj.callbackSizeChanged);
        end
    end
    
    %% To be overriden
    methods (Abstract)
        view = getMainView(obj, figureWindowParent)
        % This function should get the main View of this GUI.
        % It can call any view constructor with the params:
        % parent=figureWindowParent, controller=obj
    end
    
    methods (Static)
        function openWindow = findOpenOrNan(windowName)
            % Looks for a window with this name. if found, return it. else
            % - returns NaN
            openWindow = NaN;
            list = get(0, 'Children');
            for i = 1:size(list,1)
                if strcmp(handle(list(i)).Name, windowName)
                    openWindow = list(i);
                    return
                end
            end
        end
    end
    
end

