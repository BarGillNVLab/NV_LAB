classdef ViewLaser < GuiComponent
    %VIEWLASER view for one laser.
    %   Consists of:
    %   	* a checkbox (should always exist), 
    %   	* aom controller part (if the laser supports it), and
    %   	* the actual-laser controller part (if the laser supports it)
    
    properties
    end
    
    methods
        % constructor
        function obj = ViewLaser(parent, controller, laserGate)
            
            %%%% init variables %%%%
            sourceAvailBool = laserGate.isSourceAvail();
            aomAvailBool = laserGate.isAomAvail();
            
            %%%% Constructors %%%%
            obj@GuiComponent(parent, controller);
            
            %%%% UI components init %%%%
            boxPanel = ViewExpandablePanel(parent, controller, sprintf('Laser Control - %s', laserGate.name));
            laserControlBox = uix.VBox('Parent', boxPanel.component, 'Spacing', 3, 'Padding', 5);
            obj.component = laserControlBox;
            
            hboxCbx = ViewHBox(obj, controller);
            cbxFastOn = ViewBooleanSwitch(hboxCbx, controller, laserGate.aomSwitch, 'Fast AOM Switch');
            heights = [cbxFastOn.height];
            width = cbxFastOn.width;
            
            if sourceAvailBool
                if laserGate.source.canSetEnabled && ~laserGate.source.canSetValue
                    % ^ Checking: maybe we only need an on/off switch
                    % 1st condition: otherwise there is no point in switch
                    % 2nd condition: otherwise, the checkbox is contained in ViewLaserPart
                    cbxSourceOn = ViewBooleanSwitch(hboxCbx, controller, laserGate.source, 'Source on?');
                    heights = max([cbxSourceOn.height cbxSourceOn.height]);
                    width = cbxFastOn.width + cbxSourceOn.width;
                end
                
                sourceView = ViewLaserPart(obj, controller, laserGate.source, 'Source:');
                heights = [heights, sourceView.height];
                width = max([width, sourceView.width]);
            end
            
            if aomAvailBool
                aom = laserGate.aom;
                if isa(aom, 'AomDoubleNiDaqControlled')
                    aomView = ViewDoubleAom(obj, controller, aom);
                else
                    aomView = ViewLaserPart(obj, controller, aom, 'AOM:');
                end
                heights = [heights, aomView.height];
                width = max([width, aomView.width]);
            end
            
            
            %%%% UI components set values  %%%%
            set(laserControlBox, 'Heights', heights);
            obj.width = width + 20;
            obj.height = sum(heights) + 5 * length(heights) + 30;
            
        end % constructor
    end  % methods
end

