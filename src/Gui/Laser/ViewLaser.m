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

                if ismethod(laserGate.source, 'measuredPower')
                    heights = [heights, ViewLaser.addMeasuredRow(laserControlBox, laserGate.source)];
                end
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

    methods (Static)
        function tf = timingSensitiveRunIsOn()
            % The SPCM counter or an experiment is running: background
            % instrument polling should wait.
            tf = false;
            try
                c = getObjByName(SpcmCounter.NAME);
                tf = ~isempty(c) && isvalid(c) && c.isRunning;
                if ~tf
                    name = Experiment.current();
                    if ~isempty(name)
                        e = getObjByName(name);
                        tf = ~isempty(e) && isvalid(e) && e.isRunning;
                    end
                end
            catch
            end
        end
    end

    methods (Static, Access = private)
        function h = addMeasuredRow(box, source)
            % Live power reported by the laser head, next to the set point slider
            h = 22;
            row = uix.HBox('Parent', box, 'Spacing', 5);
            uicontrol(GuiComponent.PROP_TEXT_NO_BG{:}, 'Parent', row, 'String', 'Measured:');
            lbl = uicontrol(GuiComponent.PROP_TEXT_BIG{:}, 'Parent', row, 'String', '');
            row.Widths = [70, -1];
            % Every 5 s, and never while the SPCM counter or an experiment
            % runs: each reading is a serial round trip on MATLAB's main
            % thread, which those loops share - it showed as stalls in the
            % SPCM counter.
            t = timer('ExecutionMode', 'fixedSpacing', 'Period', 5, 'ErrorFcn', @(~, ~) [], ...
                'TimerFcn', @(~, ~) update());
            row.DeleteFcn = @(~, ~) stopTimer();
            update();
            start(t);

            function update()
                if ~isvalid(lbl); return; end
                if ViewLaser.timingSensitiveRunIsOn()
                    lbl.String = 'paused while counting';
                    return
                end
                try
                    p = source.measuredPower();
                    if ~isnan(p); lbl.String = sprintf('%.1f %s', p, source.units); end
                catch
                    lbl.String = 'no reply';
                end
            end
            function stopTimer()
                if isvalid(t); stop(t); delete(t); end
            end
        end
    end
end

