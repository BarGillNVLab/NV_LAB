classdef ViewMwContainer < ViewVBox
    %VIEWMWCONTAINER Microwave controls, one block per frequency-generator channel
    %   Mirrors ViewLasersContainer: it asks the SignalGenerator what
    %   channels exist on this setup and builds a ViewMwChannel for each, so
    %   a setup with two MW channels gets two blocks and a setup with none
    %   gets a line of text rather than an error.
    %
    %   See also VIEWMWCHANNEL, SIGNALGENERATOR

    properties (Constant)
        SPACING = 6
        EMPTY_HEIGHT = 30
        DEFAULT_WIDTH = 300
    end

    properties (SetAccess = private)
        channelViews = {}
    end

    methods
        function obj = ViewMwContainer(parent, controller)
            obj@ViewVBox(parent, controller);

            channels = ViewMwContainer.availableChannels();

            heights = [];
            width = obj.DEFAULT_WIDTH;

            for i = 1 : numel(channels)
                try
                    view = ViewMwChannel(obj, controller, channels{i}, i);
                    obj.channelViews{end+1} = view;
                    heights(end+1) = view.height; %#ok<AGROW>
                    width = max(width, view.width);
                catch err
                    % One bad channel should not cost the whole panel
                    EventStation.anonymousWarning('Could not build MW controls for channel %d: %s', ...
                        i, err.message);
                end
            end

            if isempty(heights)
                uicontrol(obj.PROP_TEXT_NO_BG{:}, 'Parent', obj.component, ...
                    'String', 'No microwave channels on this setup.');
                heights = obj.EMPTY_HEIGHT;
            end

            set(obj.component, 'Heights', heights);
            set(obj.component, 'Spacing', obj.SPACING);

            obj.height = sum(heights) + numel(heights) * obj.SPACING;
            obj.width = width;
        end

        function refresh(obj)
            for i = 1 : numel(obj.channelViews)
                view = obj.channelViews{i};
                if isvalid(view); view.refresh(); end
            end
        end
    end

    methods (Static)
        function channels = availableChannels()
            % The frequency-generator channels of this setup, or {} when
            % there is no signal generator (a dummy setup, say)
            channels = {};
            try
                sg = getObjByName(SignalGenerator.NAME);
                if isempty(sg) || ~isvalid(sg); return; end
                channels = sg.FGchannels;
            catch err
                EventStation.anonymousWarning('Could not list MW channels: %s', err.message);
            end
        end
    end
end
