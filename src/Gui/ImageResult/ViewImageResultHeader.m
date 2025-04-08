classdef ViewImageResultHeader < ViewHBox & EventListener
    %VIEWSTAGESCANHEADER the header for the ImageResults view
    %   consists of 3 panels.
    
    properties
        vPlotOptions
        vColorMap
        vCursor
        vBinning
        vContrast
        vCameraScan
        views   % all of them.
    end
    
    methods
        function obj = ViewImageResultHeader(parent, controller, camera)
            try 
                spcm = getObjByName(Spcm.NAME);
                hasAdvanced = spcm.hasG2 || spcm.hasLifetime;
            catch
                hasAdvanced = 0;
            end
            panel = ViewExpandablePanel(parent, controller, 'Image Options');
            padding = 5;
            spacing = 10;
            obj@ViewHBox(panel, controller, padding, spacing);
            obj@EventListener;
            
            % This sets the order!
            obj.vPlotOptions = ViewImageResultPanelPlot(obj,controller);
            obj.vColorMap = ViewImageResultPanelColormap(obj,controller);
            if hasAdvanced
                obj.vBinning = ViewImageResultPanelBinning(obj,controller);
            end
            if ~isempty(camera)
                obj.vCameraScan = ViewCameraZScan(obj, controller);
            end
            obj.vContrast = ViewImageResultPanelContrast(obj,controller);
            obj.vCursor = ViewImageResultPanelCursor(obj,controller);
            if hasAdvanced
                obj.views = {obj.vPlotOptions, obj.vColorMap, obj.vBinning, obj.vContrast, obj.vCursor};
            elseif ~isempty(camera)
                obj.views = {obj.vPlotOptions, obj.vColorMap, obj.vCameraScan, obj.vContrast, obj.vCursor};
            else
                obj.views = {obj.vPlotOptions, obj.vColorMap, obj.vContrast, obj.vCursor};
            end
            widths = cellfun(@(v) v.width, obj.views);
            heights = cellfun(@(v) v.height, obj.views);
            
            obj.setWidths(-widths); % minus to take all the space
            obj.width = sum(widths) + 15 + 5*length(widths);
            obj.height = max(heights) + 10;
        end
        
        function updateAxes(obj)
            cellfun(@(v) v.update, obj.views);
        end
    end
    
    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if strcmp(event.creator.name, ImageScanResult.NAME)
                if isfield(event.extraInfo, ImageScanResult.EVENT_IMAGE_UPDATED) || ...
                        event.isError
                    obj.updateAxes;
                end
            end
        end
    end
end