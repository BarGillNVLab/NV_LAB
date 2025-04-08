classdef ViewCameraResultImage < GuiComponent
    %VIEWIMAGERESULTIMAGE view that shows the scan results
    %   it is being used by other GUI components (such as the various
    %   options above it) as well as the StageScanner when it needs to
    %   duplicate the axes() object (which is obj.vAxes)
    
    properties
        vAxes       % the axes view to use for the plotting
    end
    properties (Constant)
        NAME = 'ViewCameraResultImage';
    end
    
    methods
        function obj = ViewCameraResultImage(parent, controller, minImageSize)
            obj@GuiComponent(parent, controller);
            cameraResult = getObjByName(CameraDisplay.NAME);
            if isempty(cameraResult)
                throwBaseObjException(CameraDisplay.NAME)
            end
            
            obj.component = uicontainer('parent', parent.component);
            obj.vAxes = axes('Parent', obj.component, 'ActivePositionProperty', 'outerposition');
            cameraResult.addGraphicAxes(obj.vAxes);
            
            % Set colormap and colorbar
            cMap = cameraResult.COLORMAP_OPTIONS{cameraResult.colormapType};
            colormap(obj.vAxes, cMap);
            
            % Creating floating axes() so that default calls to axes (such
            % as image() surf() etc.) won't reach this view but rather the
            % invisible floating one
            axes();
            cameraResult.update;
            
            if isempty(minImageSize)
                obj.height = 600;   % minimum
                obj.width = 600;    % minimum
            else
                obj.height = minImageSize(1);   % minimum
                obj.width = minImageSize(2);    % minimum
            end
        end
    end
end