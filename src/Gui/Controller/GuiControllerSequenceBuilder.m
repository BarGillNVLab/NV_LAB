classdef GuiControllerSequenceBuilder < GuiController
    %GUICONTROLLERSEQUENCEBUILDER Its own window for the sequence builder
    %   The builder needs room: three tables, a channel-lane preview and a
    %   row of actions do not fit in the main window's experiment column.
    %
    %   Only one is open at a time, and it keeps editing whichever spec it
    %   was given, so closing and reopening does not lose the work.
    %
    %   See also VIEWSEQUENCEBUILDER, VIEWEXPERIMENTCOLUMN

    properties
        spec        % UserSequenceSpec to edit, or empty for the example one
        view        % ViewSequenceBuilder
    end

    methods
        function obj = GuiControllerSequenceBuilder(spec)
            shouldConfirmOnExit = false;
            openOnlyOne = true;
            obj = obj@GuiController('Sequence builder', shouldConfirmOnExit, openOnlyOne);
            if exist('spec', 'var') && isa(spec, 'UserSequenceSpec')
                obj.spec = spec;
            end
        end

        function view = getMainView(obj, figureWindowParent)
            view = ViewSequenceBuilder(figureWindowParent, obj, obj.spec);
            obj.view = view;
            obj.spec = view.currentSpec();
        end

        function onAboutToStart(obj)
            obj.moveToMiddleOfScreen();
        end

        function onStarted(obj)
            % Let the user shrink it if they want to; the views cope
            obj.windowMinHeight = 480;
            obj.windowMinWidth = 560;
        end
    end
end
