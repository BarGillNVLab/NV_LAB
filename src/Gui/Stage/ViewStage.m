classdef ViewStage < ViewVBox
    %ViewStage one full box to view and control the stage
    %   consists of a couple of expandable panels:
    %   1. scan area
    %   2. movement control
    
    properties
    end
    
    methods
        function obj = ViewStage(parent, controller, stage, camera)
            vMainPanel = ViewExpandablePanel(parent, controller, stage.name);
            obj@ViewVBox(vMainPanel, controller);
            % This might need to be redone. Was done in a hurry.
            
            %%%% ui component init %%%%
            obj.component.Spacing = 5;
            obj.component.Padding = 5;
                        
            if stage.isScannable
                hboxTop = ViewHBox(obj, controller, 0, 16);
                
                vboxTopLeft = ViewVBox(hboxTop, controller, 0, 0);
                vScanParams = ViewStagePanelScanParams(vboxTopLeft, controller, stage);
                vMWContrast = ViewStagePanelMWContrast(vboxTopLeft, controller, stage);
                vLimits = ViewStagePanelLimits(vboxTopLeft, controller, stage);
                topLeft = {vLimits, vMWContrast, vScanParams};
                vboxTopLeft.height = sum(cellfun(@(p) p.height,topLeft));
                vboxTopLeft.setHeights([-1 vMWContrast.height -1]);
                vboxTopLeft.width = max(cellfun(@(p) p.width,topLeft));
                
                vboxTopRight = ViewVBox(hboxTop, controller, 0, 0);
                vScan = ViewStagePanelScan(vboxTopRight, controller, stage.name);
                vGeneral = ViewStagePanelGeneral(vboxTopRight, controller, stage);
                topRight = {vScan, vGeneral};
                vboxTopRight.setHeights([vScan.height, vGeneral.height]);
                vboxTopRight.height = sum(cellfun(@(p) p.height,topRight));
                vboxTopRight.width = max(cellfun(@(p) p.width,topRight)) + 15 * length(topRight);

                top = {vboxTopLeft vboxTopRight};
                hboxTop.setWidths([-1 vboxTopRight.width]);
                hboxTop.height = sum(cellfun(@(p) p.height,top));
                
                hboxBottom = ViewHBox(obj, controller, 0, 16);
                vMovement = ViewStagePanelMovementControl(hboxBottom, controller, stage);
                vboxBottomRight = ViewVBox(hboxBottom, controller, 0, 0);
                    if stage.tiltAvailable
                        vTilt = ViewStagePanelTiltCorrection(vboxBottomRight, controller, stage);
                    else
                        vTilt = ViewEmpty(vboxBottomRight);
                    end
                    if isempty(camera)
                        vTrackPosition = ViewStagePanelTrack(vboxBottomRight, controller, stage);
                    else
                        vTrackPosition = ViewFocalDistance(vboxBottomRight, controller);
                    end
                    vboxBottomRight.setHeights([vTilt.height, vTrackPosition.height])
                    bottom = {vMovement, vboxBottomRight};
                hboxBottom.setWidths([vMovement.width, -1]);
                
                heights = [...
                    max(cellfun(@(p) p.height, top)), ...
                    max(cellfun(@(p) p.height, bottom)), ...
                    ];
                
                widths = [...
                    sum(cellfun(@(p) p.width, top)) + 15 * length(top), ...
                    sum(cellfun(@(p) p.width, bottom))+ 15 * length(bottom), ...
                    ];
            else
                hboxTop = ViewHBox(obj, controller, 0, 16);  
                vMovement = ViewStagePanelMovementControl(hboxTop, controller, stage);
                vGeneral = ViewStagePanelGeneral(hboxTop, controller, stage);
                top = {vMovement, vGeneral};
                hboxTop.setWidths([-1 vGeneral.width]);
                
                hboxBottom = ViewHBox(obj, controller, 0, 10);  
                vLimits = ViewStagePanelLimits(hboxBottom, controller, stage);
                vboxBottomRight = ViewVBox(hboxBottom, controller, 0, 8);
                    if stage.tiltAvailable
                        vTilt = ViewStagePanelTiltCorrection(vboxBottomRight, controller, stage);
                    else
                        vTilt = ViewEmpty(vboxBottomRight);
                    end
                    uix.Empty('Parent', vboxBottomRight.component);
                    vboxBottomRight.setHeights([vTilt.height -1]);
                bottom = {vLimits, vTilt};
                hboxBottom.setWidths([vLimits.width, -1]);
                
                heights = [...
                    max(cellfun(@(p) p.height,top)), ...
                    max(cellfun(@(p) p.height,bottom)), ...
                    ];
                
                widths = [...
                    sum(cellfun(@(p) p.width, top)) + 15 * length(top), ...
                    sum(cellfun(@(p) p.width, bottom))+ 15 * length(bottom), ...
                    ];
            end
                  
            
            %%%% init internal settings %%%%
            obj.setHeights(heights);
            obj.height = sum(heights) + 35;
            obj.width = max(widths);
        end
    end
    
end

