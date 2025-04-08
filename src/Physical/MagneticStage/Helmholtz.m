classdef (Sealed) Helmholtz < BaseObject & EventSender
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    properties (Constant)
        AXIS = ['X', 'Y', 'Z'];
        DIAMOND_AXES = {'D_rotate', 'D_theta', 'D_phi'};
        CONTROL_STATE = {'ON', 'AUTO', 'OFF'};

        NVaxis = 1/sqrt(3) * [1  -1  1 -1;
                              1  -1 -1  1;
                              1   1 -1 -1];
        NAME = 'Helmholtz';
        
        NORMAL_OPTIONS = {'100', '111'};
        EDGE_OPTIONS = {'100', '110'};
        
        
        EVENT_OUTPUT_STATE_CHANGED = 'outputStateChanged';
        EVENT_CONTROL_STATE_CHANGED = 'controlStateChanged';
        EVENT_STEP_SIZE_CHANGED = 'stepSizeChanged';
        EVENT_MAGNETIC_FIELD_CHANGED = 'magneticFieldChanged';
        EVENT_DIAMOND_PROPERTIES_CHANGED = 'diamondPropertiesChanged';
        EVENT_FLIP_STATE_CHANGED = 'flipStateChanged';
        EVENT_VIEW_ANGLE_CHANGED = 'viewAngleChanged';

        VIEW_ANGLE_STEP = 10;
        ESR_WIDTH = 10;
    end
    
    
    properties (Dependent = true)
        maxMagneticField
        minMagneticField
        NVcoordinates
        maxBrho
        Bsphere
        Dangles
    end
    
    properties (Access = private)       
        stopFlag = 0;        
        GUI
        psNames
        psChannels
        magneticFieldRatio
        magneticFieldOffset
        digitalChannel
        digitalName
        flipAvailable
        flipControl
    end
    
    properties
        % power supplies properties
        I       % [Ix, Iy, Iz], Ampers
        
        % magnetic field properties
        B       % [Bx, By, Bz], Gauss
        Brho    % Gauss
        Btheta  % degrees
        Bphi    % degrees    
        flip    % boolean - flip direction of B
        
        % diamond properties
        normal      % string. '100' for example
        edge        % string. '110' for example
        D_rotate
        D_theta
        D_phi
        dontChange  % don't rotate axis in NV to B function
        stepSizeD
        
        stepSize
        stepSizeI
        maxCurrent
        minCurrent

        viewAng
        
        helmOn
        helmControl     % can get three types pf control: 'on', 'off', and 'auto' - on during the experiments.
        gAxes
        gAxesESR
        plotMode        % boolean. true if there is ploted figure in the GUI.
        
    end
    
    methods (Static, Access = public)
%         function obj = GetInstance(varargin)
%             %input varargin{1} can contain the GUI handle (or be empty)
%             persistent localObj
%             if isempty(localObj) || ~isvalid(localObj)
%                 localObj = ClassExternalFieldControl;             
%             end
%             obj = localObj;
%             if nargin && ~isempty(varargin{1}) % insert a new handle
%                 obj.GUI=varargin{1};
%             end
%             %%% open GUI if needed. If GUI is closed (the obj was clled not
%             %%% from the GUI), the GUI will in turn call it again but this
%             %%% time with it's handle
%             if isempty(obj.GUI) || ~nnz(findall(0,'Type','Figure') == obj.GUI.figure) %the latter tests if the GUI is open
%                 HelmholtzGUI;
%             else
%                 obj.Initialize;
%             end
%         end
    end
    
    methods
        function obj = Helmholtz()
            obj@BaseObject(Helmholtz.NAME);
            obj@EventSender(Helmholtz.NAME);
            obj.Initialize;
            addBaseObject(obj);  % so it can be reached by getObjByName()
            obj.helmOn = 0;
            obj.helmControl = obj.CONTROL_STATE{3};

            % diamond properties
            obj.normal = '100';
            obj.edge = '100';
            obj.D_rotate = 0;
            obj.D_theta = 0;
            obj.D_phi = 0;
            obj.dontChange = 'D_theta';
            obj.stepSizeD = 5;
            
            obj.stepSize = 1;
            obj.stepSizeI = 0.1;
            obj.flip = 0;
            obj.plotMode = 0;
            
            obj.viewAng = [-37.5, 30];
            
            try 
                HelmholtzGUI().start;
            catch err
                obj.close;
                rethrow(err);
            end
        end
        
        function Initialize(obj)
            helmholtzStruct = JsonInfoReader.getJson().Helmholtz;
            obj.psNames = {};
            obj.psChannels = {};
            obj.maxCurrent = zeros(1,3);
            obj.minCurrent = zeros(1,3);
            obj.magneticFieldRatio = zeros(1,3);
            obj.magneticFieldOffset = zeros(1,3);
            obj.I = zeros(1, 3);
            for k = 1:3
                axisStruct = helmholtzStruct.(obj.AXIS(k));
                psName = sprintf('power_supply_%s', axisStruct.address);
                if ~any(strcmp(obj.psNames, psName))               % if use same power supply with several channels we shouldn't create again
                    powerSupply.create(psName, axisStruct);
                end
                obj.psNames{k} = psName;
                ps = getObjByName(psName);
                if isfield(axisStruct, 'channel')
                    channel = axisStruct.channel;
                else
                    channel = [];
                end
                obj.psChannels{k} = channel;
                if isfield(axisStruct, 'range')
                    ps.setRange(axisStruct.range, channel);
                end
                ps.setMode('current', channel);
                if isfield(axisStruct, 'min_current')
                    minCur = axisStruct.min_current;
                else
                    minCur = 0;
                end
                obj.maxCurrent(k) = min([axisStruct.max_current, ps.maxCurrentActive(channel)]);
                obj.minCurrent(k) = max([minCur, ps.minCurrentActive(channel)]);
                obj.magneticFieldRatio(k) = axisStruct.magnetic_field_ratio;
                obj.magneticFieldOffset(k) = axisStruct.magnetic_field_offset;
                obj.I(k) = ps.current(ps.chan2ind(channel));
            end

            flipSrtucrt = helmholtzStruct.flip_direction;
            if flipSrtucrt.available
                obj.flipAvailable = 1;
                obj.flipControl = struct;
                obj.flipControl.type = flipSrtucrt.type;
                switch obj.flipControl.type
                    case "power_supply"
                        obj.sendError('power suplly control does not implemented');
                    case "pulse_generator"
                        partName = 'flip relay switch';
                        obj.flipControl.switchPhysicalPart = SwitchPgControlled.create(partName, flipSrtucrt.switch);
                        obj.flipControl.switchPhysicalPart.isEnabled = false;
                    case "daq"
                        obj.sendError('DAQ control does not implemented');
                end
            else
                obj.flipAvailable = 0;
            end
%             if ~all(obj.I == 0)
%                 obj.setI(obj.I);
%             else
            obj.setI(obj.maxCurrent*0.5);
%             end
        end
        
    end
    
%% set current and magnetic field methods
    methods
        function Bmax = get.maxMagneticField(obj)
            Bup = obj.magneticFieldOffset + obj.magneticFieldRatio .* obj.maxCurrent;
            Bdown = obj.magneticFieldOffset + obj.magneticFieldRatio .* obj.minCurrent;
            Bmax = max([Bup; Bdown]);
        end

        function Bmin = get.minMagneticField(obj)
            Bup = obj.magneticFieldOffset + obj.magneticFieldRatio .* obj.maxCurrent;
            Bdown = obj.magneticFieldOffset + obj.magneticFieldRatio .* obj.minCurrent;
            Bmin = min([Bup; Bdown]);
        end
        
        function coor = get.NVcoordinates(obj)
            coor = obj.fixCoordinates(obj.NVaxis, true);
        end
        
        function rho = get.maxBrho(obj)
            [~, rho] = obj.BrhoLimits;
        end
        
        function Bout = get.Bsphere(obj)
            Bout = [obj.Brho, obj.Btheta, obj.Bphi];
        end
        
        function angles = get.Dangles(obj)
            angles = [obj.D_rotate, obj.D_theta, obj.D_phi];
        end
        
        function set.normal(obj, newVal)
            obj.normal = newVal;
            obj.sendEvent(struct(obj.EVENT_DIAMOND_PROPERTIES_CHANGED, true));
        end
        
        function set.edge(obj, newVal)
            obj.edge = newVal;
            obj.sendEvent(struct(obj.EVENT_DIAMOND_PROPERTIES_CHANGED, true));
        end
        
        function set.D_rotate(obj, newVal)
            obj.D_rotate = mod(newVal, 360);
            obj.sendEvent(struct(obj.EVENT_DIAMOND_PROPERTIES_CHANGED, true));
        end
        
        function set.D_theta(obj, newVal)
            obj.D_theta = mod(newVal, 360);
            obj.sendEvent(struct(obj.EVENT_DIAMOND_PROPERTIES_CHANGED, true));
        end
        
        function set.D_phi(obj, newVal)
            obj.D_phi = mod(newVal, 360);
            obj.sendEvent(struct(obj.EVENT_DIAMOND_PROPERTIES_CHANGED, true));
        end
        
        function set.stepSize(obj, newVal)
            obj.stepSize = newVal;
            obj.sendEvent(struct(obj.EVENT_STEP_SIZE_CHANGED, true));
        end
        
        function set.stepSizeI(obj, newVal)
            obj.stepSizeI = newVal;
            obj.sendEvent(struct(obj.EVENT_STEP_SIZE_CHANGED, true));
        end
        
        function set.viewAng(obj, newVal)
            obj.viewAng = newVal;
            obj.sendEvent(struct(obj.EVENT_VIEW_ANGLE_CHANGED, true));
        end
        
        function setI(obj, I_new)
            obj.checkILimits(I_new);
            obj.B = obj.magneticFieldOffset + obj.magneticFieldRatio .* I_new;
            [obj.Brho, obj.Btheta, obj.Bphi] = obj.cart2sphI(obj.B);
            obj.I = I_new;
            obj.setCurrent(I_new);
            obj.sendEvent(struct(obj.EVENT_MAGNETIC_FIELD_CHANGED, true));
%             if obj.plotMode; obj.updatePlot; end
        end
        
        function setB(obj, B_new)
            obj.checkBLimits(B_new);
            Inew = (B_new - obj.magneticFieldOffset) ./ obj.magneticFieldRatio;
            [obj.Brho, obj.Btheta, obj.Bphi] = obj.cart2sphI(B_new);
            obj.B = B_new;
            obj.setI(Inew);
        end
        
        function setBrho(obj, Brho_new)
            obj.checkRhoLimits(Brho_new);
            B_new = obj.sph2cartI(Brho_new, obj.Btheta, obj.Bphi);
            obj.setB(B_new);
        end

        function setBtheta(obj, Btheta_new)
            obj.checkThetaLimits(Btheta_new);
            B_new = obj.sph2cartI(obj.Brho, Btheta_new, obj.Bphi);
            obj.setB(B_new);
        end
        
        function setBphi(obj, Bphi_new)
            obj.checkPhiLimits(Bphi_new);
            B_new = obj.sph2cartI(obj.Brho, obj.Btheta, Bphi_new);
            obj.setB(B_new);
        end
        
        function relativeBsphereStep(obj, index, step)
            switch index
                case 1
                    set(obj, 'Brho', obj.Brho+step);
                case 2
                    set(obj, 'Btheta', obj.Btheta+step);
                case 3
                    set(obj, 'Bphi', obj.Bphi+step);
            end
        end
        
        function relativeBcartStep(obj, index, step)
            switch index
                case 1
                    set(obj, 'Bx', obj.B(1)+step);
                case 2
                    set(obj, 'By', obj.B(2)+step);
                case 3
                    set(obj, 'Bz', obj.B(3)+step);
            end
        end
        
        function relativeCurrentStep(obj, index, step)
            switch index
                case 1
                    setI(obj, obj.I + [step 0 0]);
                case 2
                    setI(obj, obj.I + [0 step 0]);
                case 3
                    setI(obj, obj.I + [0 0 step]);
            end
        end
        
        function set(obj, what, value)
            switch what
                case 'Bx'
                    obj.setB([value, obj.B(2), obj.B(3)]);
                case 'By'
                    obj.setB([obj.B(1), value, obj.B(3)]);
                case 'Bz'
                    obj.setB([obj.B(1), obj.B(2), value]);
                case 'Brho'
                    obj.setBrho(value);
                case 'Btheta'
                    obj.setBtheta(value);
                case 'Bphi'
                    obj.setBphi(value);
                otherwise
                    obj.sendError('no field %s to set', what)
            end
        end
        
        function NVtoB(obj, dontChange)
            % we should rotate two of the three degree of freedom -
            % 'rotate' the diamond around it's normal, 'theta' and 'phi'.
            % you can choose the 'dontChange' to be one of them.
            if exist('dontRotate', 'var')
                obj.dontChange = dontChange;
            end
            [~, closeNV] = max(abs(obj.B * obj.NVcoordinates));
            NV = obj.NVcoordinates(:, closeNV);
            NV = NV * sign(obj.B * obj.NVcoordinates(:, closeNV));
            n = obj.sph2cartI(1, obj.D_theta, obj.D_phi); % diamond normal vector

            switch obj.dontChange
                case obj.DIAMOND_AXES{1} % 'rotate'
                    [~, NV_theta, NV_phi] = obj.cart2sphI(NV);
                    obj.D_theta = obj.D_theta + (obj.Btheta - NV_theta);
                    obj.D_phi = obj.D_phi + (obj.Bphi - NV_phi);
                case obj.DIAMOND_AXES{2} % 'theta'
                    alpha = 54.75;    % angle between NV to the normal
                    theta = obj.Btheta;
                    syms phi
                    eqn = dot(n, [sind(phi)*cosd(theta), sind(phi)*sind(theta), cosd(phi)]) == cosd(alpha);
                    phi_s = real(double(solve(eqn, phi)));
                    if length(phi_s) > 1
                        [~, i] = min(obj.Bphi - phi_s);
                        phi_s = phi_s(i);
                        p = obj.sph2cartI(1, theta, phi_s);
                    end
                    rotateAngle = dot(n, cross(NV',p)) * acosd(dot(NV'-n, p-n));
                    obj.D_rotate = obj.D_rotate + rotateAngle;
                    obj.D_phi = obj.D_phi + (obj.Bphi - phi_s);
                case obj.DIAMOND_AXES{3} % 'phi'
                    alpha = 54.75;    % angle between NV to the normal
                    phi = obj.Bphi;
                    syms theta
                    eqn = dot(n, [sind(phi)*cosd(theta), sind(phi)*sind(theta), cosd(phi)]) == cosd(alpha);
                    theta_s = real(double(solve(eqn, theta)));
                    if length(theta_s) > 1
                        [~, i] = min(obj.Btheta - theta_s);
                        theta_s = theta_s(i);
                        p = obj.sph2cartI(1, theta_s, phi);
                    end
                    rotateAngle = dot(n, cross(NV',p)) * acosd(dot(NV'-n, p-n));
                    obj.D_rotate = obj.D_rotate + rotateAngle;
                    obj.D_theta = obj.D_theta + (obj.Btheta - theta_s);
                otherwise
                    obj.sendError('the optional "don''t rotate" values are "rotate", "theta" and "phi"')
            end
        end
        
        function BtoNV(obj)
            [~, closeNV] = max(abs(obj.B * obj.NVcoordinates));
            NV = obj.NVcoordinates(:, closeNV)';
            NV = NV * sign(obj.B * obj.NVcoordinates(:, closeNV));
            if ~prod([0 <= NV, NV <= obj.maxMagneticField])
                fprintf('close NV vector out of the limits\n');
            else
                obj.setB(obj.Brho * NV);
            end
        end

        function flipDirection(obj, state)
            if obj.flipAvailable
                state = num2str(state);
                if ~any(strcmpi({'on', 'off', '0', '1'}, state))
                    obj.sendError('flip state can get just ''ON'' or ''OFF''')
                end
                obj.flip = BooleanHelper.onOffToBool(state);
                switch obj.flipControl.type
                    case "power_supply"
                        obj.sendError('power suplly control does not implemented');
                    case "pulse_generator"
                        obj.flipControl.switchPhysicalPart.isEnabled = obj.flip;
                    case "daq"
                        obj.sendError('DAQ control does not implemented');
                end
                obj.sendEvent(struct(obj.EVENT_FLIP_STATE_CHANGED, true));
            else
                obj.sendWarning('Flip direction option is not available');
            end
        end
    end
    
    %% Limits methods
    methods
        function OK = checkILimits(obj, I, dispError)
            if ~exist('dispError', 'var')
                dispError = 1;
            end
            OK = 1;
            if ~prod(I <= obj.maxCurrent) || ~prod(obj.minCurrent <= I)
                OK = 0;
                err = sprintf('Out of limits! The current range is between [%.1f, %.1f, %.1f] to [%.1f, %.1f, %.1f] Amper', ...
                              obj.minCurrent(1), obj.minCurrent(2), obj.minCurrent(3), ...
                              obj.maxCurrent(1), obj.maxCurrent(2), obj.maxCurrent(3));
                obj.dispErrorWarning(err, dispError);
            end
        end
        
        function OK = checkBLimits(obj, B, dispError)
            if ~exist('dispError', 'var')
                dispError = 1;
            end
            OK = 1;
            if ~prod(prod(B <= obj.maxMagneticField)) || ~prod(prod(obj.minMagneticField <= B))
                OK = 0;
                err = sprintf('Out of limits! The magnetic field range is between [%.1f, %.1f, %.1f] to [%.1f, %.1f, %.1f] Gauss', ...
                              obj.minMagneticField(1), obj.minMagneticField(2), obj.minMagneticField(3), ...
                              obj.maxMagneticField(1), obj.maxMagneticField(2), obj.maxMagneticField(3));
                obj.dispErrorWarning(err, dispError);
            end
        end
        
        function OK = checkThetaLimits(obj, theta, dispError)
            if ~exist('dispError', 'var')
                dispError = 1;
            end
            OK = 1;
            [lowerLimit, upperLimit] = obj.BthetaLimits;
            if (~prod(theta <= upperLimit)) || (~prod(lowerLimit <= theta))
                OK = 0;
                err = sprintf('Out of limits! ''theta'' range now is between %.1f to %.1f degrees.', lowerLimit, upperLimit);
                obj.dispErrorWarning(err, dispError);
            end
        end
        
        function OK = checkPhiLimits(obj, phi, dispError)
            if ~exist('dispError', 'var')
                dispError = 1;
            end
            OK = 1;
            [lowerLimit, upperLimit] = obj.BphiLimits;
            if (~prod(phi <= upperLimit)) || (~prod(lowerLimit <= phi))
                OK = 0;
                err = sprintf('Out of limits! ''phi'' range now is between %.1f to %.1f degrees.', lowerLimit, upperLimit);
                obj.dispErrorWarning(err, dispError);
            end
        end
        
        function OK = checkRhoLimits(obj, rho, dispError)
            if ~exist('dispError', 'var')
                dispError = 1;
            end
            OK = 1;
            [lowerLimit, upperLimit] = obj.BrhoLimits;
            if (~prod(rho <= upperLimit)) || (~prod(lowerLimit <= rho))
                OK = 0;
                err = sprintf('Out of limits! ''rho'' range now is between %.1f to %.1f Gauss.', lowerLimit, upperLimit);
                obj.dispErrorWarning(err, dispError);
            end
        end
        
        function OK = checkLimits(obj, what, value, dispError)
            if ~exist('dispError', 'var')
                dispError = 1;
            end
            switch what
                case 'I'
                    OK = obj.checkILimits(value, dispError);
                case 'Brho'
                    OK = obj.checkRhoLimits(value, dispError);
                case 'Btheta'
                    OK = obj.checkThetaLimits(value, dispError);
                case 'Bphi'
                    OK = obj.checkPhiLimits(value, dispError);
                case {'B', 'Bx', 'By', 'Bz'}
                    if ~strcmp(what, 'B')
                        N = length(value);
                        value = reshape(value,N,1);
                        No = ones(N, 1);
                    end
                    switch what
                        case 'B'
                            B_new = value;
                        case 'Bx'
                            B_new = [value, obj.B(2)*No, obj.B(3)*No];
                        case 'By'
                            B_new = [obj.B(1)*No, value, obj.B(3)*No];
                        case 'Bz'
                            B_new = [obj.B(1)*No, obj.B(2)*No, value];
                    end
                    OK = obj.checkBLimits(B_new, dispError);
                otherwise
                    obj.sendError('no type of fiels %s', what)
            end
        end
        
        function dispErrorWarning(obj, err, dispError)
            % 'err': error string;
            % 'dispError': 0 - no display, 1 - error display, 2 - warning display.
            if dispError == 1
                obj.sendError(err)
            else
                warning(err)
            end
        end
        
        function [theta_min, theta_max] = BthetaLimits(obj)
            % return the theta limits in constant phi and rho
            xLow = obj.minMagneticField(1);
            yLow = obj.minMagneticField(2);
            xHigh = obj.maxMagneticField(1);
            yHigh = obj.maxMagneticField(2);
            p = zeros(8, 3);
            z = obj.B(3);
            
            % y limits
            y = [yLow;yLow;yHigh;yHigh];
            x = [1;-1;1;-1] .* sqrt(obj.Brho^2 - z^2 - y.^2);
            p(1:4,:) = [x, y, repmat(z,4,1)];
            
            % x limits
            x = [xLow;xLow;xHigh;xHigh];
            y = [1;-1;1;-1] .* sqrt(obj.Brho^2 - z^2 - x.^2);
            p(5:8,:) = [x, y, repmat(z,4,1)];
            
            p(~prod(imag(p)==0, 2),:) = [];
            [~, theta, ~] = obj.cart2sphI(p);
            if length(theta) < 2    % all angles optional
                theta_min = 0;
                theta_max = 360;    
            else
                [~, i] = min(mod(obj.Btheta - theta, 360)); 
                theta_min = theta(i);
                [~, i] = min(mod(theta - obj.Btheta, 360)); 
                theta_max = theta(i);
            end
        end
        
        function [phi_min, phi_max] = BphiLimits(obj)
            % return the phi limits in constant theta and rho
            xLow = obj.minMagneticField(1);
            yLow = obj.minMagneticField(2);
            zLow = obj.minMagneticField(3);
            xHigh = obj.maxMagneticField(1);
            yHigh = obj.maxMagneticField(2);
            zHigh = obj.maxMagneticField(3);
            p = zeros(12, 3);
            
            % z limits
            z = [zLow;zLow;zHigh;zHigh];
            x = [1;-1;1;-1] .* sqrt((obj.Brho^2 - z.^2) / (1 + tand(obj.Btheta)^2));
            y = x * tand(obj.Btheta);
            p(1:4,:) = [x, y, z];
            
            % y limits
            y = [yLow;yLow;yHigh;yHigh];
            x = y / tand(obj.Btheta);
            z = [1;-1;1;-1] .* sqrt(obj.Brho^2 - x.^2 - y.^2);
            p(5:8,:) = [x, y, z];
            
            % x limits
            x = [xLow;xLow;xHigh;xHigh];
            y = x * tand(obj.Btheta);
            z = [1;-1;1;-1] .* sqrt(obj.Brho^2 - x.^2 - y.^2);
            p(9:12,:) = [x, y, z];
            
            p(~prod(imag(p)==0, 2),:) = [];
            [~, ~, phi] = obj.cart2sphI(p);
            phi(phi > 180) = [];
            if length(phi) < 2    % all angles optional
                phi_min = 0;
                phi_max = 360;    
            else
                [~, i] = min(mod(obj.Bphi - phi, 360)); 
                phi_min = phi(i);
                [~, i] = min(mod(phi - obj.Bphi, 360)); 
                phi_max = phi(i);
            end
        end
        
        function [rho_min, rho_max] = BrhoLimits(obj)
            i = min(max([obj.maxMagneticField ./ obj.B; obj.minMagneticField ./ obj.B]));
            rho_max = i*obj.Brho;
            i = max(min([obj.maxMagneticField ./ obj.B; obj.minMagneticField ./ obj.B]));
            rho_min = i*obj.Brho;
        end
        
        function lowerLimits = BsphereLowerLimits(obj)
            [rhoLim, ~] = obj.BrhoLimits;
            [thetaLim, ~] = obj.BthetaLimits;
            [phiLim, ~] = obj.BphiLimits;
            lowerLimits = [rhoLim, thetaLim, phiLim];
        end
        
        function upperLimits = BsphereUpperLimits(obj)
            [~, rhoLim] = obj.BrhoLimits;
            [~, thetaLim] = obj.BthetaLimits;
            [~, phiLim] = obj.BphiLimits;
            upperLimits = [rhoLim, thetaLim, phiLim];
        end
end
 
    
    %% communication to power supplies methods
    methods
        function setCurrent(obj, current)
            for k = 1:3
                ps = getObjByName(obj.psNames{k});
                channel = obj.psChannels{k};
                pause(0.1);
                ps.setCurrent(current(k), channel);
            end
        end
        
        function output(obj, value)
            for k = 1:3
                ps = getObjByName(obj.psNames{k});
                channel = obj.psChannels{k};
                ps.output(value, channel);
            end
            
            obj.helmOn = strcmpi(value, 'on') || any((value==1));
            obj.sendEvent(struct(obj.EVENT_OUTPUT_STATE_CHANGED, true));
        end
        
        function control(obj, value)
            if ~any(strcmpi(value, obj.CONTROL_STATE))
                error('cntrol state can be just ''ON'', ''AUTO'' or ''OFF''')
            end
            obj.helmControl = upper(value);
            if strcmp(value, obj.CONTROL_STATE{1})
                obj.output('on');
            else
                obj.output('off');
            end
            obj.sendEvent(struct(obj.EVENT_CONTROL_STATE_CHANGED, true));
        end
        
        function close(obj)
            for k = 1:3
                ps = getObjByName(obj.psNames{k});
                if ~isempty(ps)
                    ps.close;
                end
            end
            h = getObjByName('Helmholtz');
            h.delete;
        end
        
        function reset(obj)
            for k = 1:3
                ps = getObjByName(obj.psNames{k});
                ps.reset;
            end
            obj.setI([0, 0, 0]);
        end
        
    end
    
    %% plots
    methods
        function plotSetup(obj, gAxes)
            if ~exist('gAxes', 'var')
                figure;
                gAxes = axes(gcf);
            end
            cla(gAxes);
            hold(gAxes, 'on');
            obj.plotMagneticField(gAxes);
            obj.plotDiamond(gAxes);
            obj.plotMap(gAxes);
            obj.setView(gAxes);
            axis(gAxes, 'equal');
            hold(gAxes, 'off');
        end
           
        function setView(obj, gAxes)
            limits = [min(obj.minMagneticField) - 20, max(obj.maxMagneticField)];
            gAxes.XLim = limits; obj.gAxes.YLim = limits; obj.gAxes.ZLim = limits;
            gAxes.View = obj.viewAng;
        end
        
        function plotMap(obj, gAxes)
            edges = (obj.maxMagneticField - obj.minMagneticField);
            origin = obj.minMagneticField;
            alpha = 0.1;
            clr = 'r';
            XYZ = {[0 0 0 0]  [0 0 1 1]  [0 1 1 0] ; ...
                   [1 1 1 1]  [0 0 1 1]  [0 1 1 0] ; ...
                   [0 1 1 0]  [0 0 0 0]  [0 0 1 1] ; ...
                   [0 1 1 0]  [1 1 1 1]  [0 0 1 1] ; ...
                   [0 1 1 0]  [0 0 1 1]  [0 0 0 0] ; ...
                   [0 1 1 0]  [0 0 1 1]  [1 1 1 1]};
            XYZ = mat2cell(cellfun( @(x,y,z) x*y+z, XYZ , ...
                           repmat(mat2cell(edges,1,[1 1 1]),6,1) , ...
                           repmat(mat2cell(origin,1,[1 1 1]),6,1) , ...
                           'UniformOutput',false), 6, [1 1 1]);
%             cellfun(@patch, obj.gAxes, XYZ{1}, XYZ{2}, XYZ{3},...
%                     repmat({clr},6,1), repmat({'FaceAlpha'},6,1), repmat({alpha},6,1));
            a1 = XYZ{1}; a2 = XYZ{2}; a3 = XYZ{3};
            for i = 1:6
                patch(gAxes, a1{i}, a2{i}, a3{i}, 'r', 'FaceAlpha', alpha);
            end
            gAxes.XLabel.String = 'B_{x}';
            gAxes.YLabel.String = 'B_{y}';
            gAxes.ZLabel.String = 'B_{z}';
        end
        
        function plotMagneticField(obj, gAxes)
            obj.arrow3d(gAxes, [0, obj.B(1)], [0, obj.B(2)], [0, obj.B(3)], 0.7, 2, 4, 'r');
        end
        
        function plotDiamond(obj, gAxes)
            hold on;
            D_w = 7;
            D_t = 1;
            cornersList = D_w .* [1  1  1  1 -1 -1  1  1  1 -1 -1 -1 -1  1 -1 -1; ...
                                 -1  1  1 -1 -1 -1 -1 -1  1  1 -1 -1  1  1  1  1; ...
                                  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0] ...
                        + D_t .* [0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0; ...
                                  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0; ...
                                  1  1 -1 -1 -1  1  1 -1 -1 -1 -1  1  1  1  1 -1];
            coordinates = obj.fixCoordinates(cornersList - [0; 0; D_t], false);
            plot3(gAxes, coordinates(1,:), coordinates(2,:), coordinates(3,:), 'color', 'b');
            
            NV_L = 15;
            coordinates = obj.NVcoordinates * NV_L;
            for i = 1:4
                x = coordinates(1,i); y = coordinates(2,i); z = coordinates(3,i);
                plot3(gAxes, [0, x] , [0, y], [0, z], 'color', 'k', 'LineWidth', 5)
                plot3(gAxes, [0,-x] , [0,-y], [0,-z], 'color', 'k', 'LineWidth', 5, 'LineStyle', ':')
                [X,Y,Z] = sphere;
                s = surf(gAxes, X+x,Y+y,Z+z);
                set(s, 'FaceColor', [0 0 0], 'EdgeColor', 'none');
            end
        end
        
        function plotExpectedESR(obj, gAxes)
            if ~exist('gAxes', 'var')
                figure;
                gAxes = axes(gcf);
            end
            cla(gAxes);
            width = obj.ESR_WIDTH;
            gamma = 2.8;
            center = 2870;
            G = @(f, f0) (1 - 5*width/pi * 1./((f-f0).^2 + width^2)) / 8;
            BonNV = obj.B * obj.NVcoordinates;
            span = max(abs(BonNV)) * gamma + 4*width;
            f = center-span : 0.1 : center+span;
            Y = zeros(1, length(f));
            for i = 1:4
                Y = Y + G(f, center + gamma*BonNV(i));
                Y = Y + G(f, center - gamma*BonNV(i));
            end
            plot(gAxes, f, Y, 'k');
            gAxes.XLabel.String = 'frequency (MHz)';
        end
    end
    
    %% help methods
    methods
        function r = sph2cartI(obj, rho, theta, phi)
            % sph2cart Internal: theta is azimutal, phi is elavation - as
            % angle from the Z axis
            % angle in degrees. return r as column vector (or matrix N*3).
            [x, y, z] = sph2cart(obj.d2r(theta), obj.d2r(90-phi), rho);
            r = [x, y, z];
        end

        function [rho, theta, phi] = cart2sphI(obj, r)
            % cart2sph Internal: theta is azimutal, phi is elavation - as
            % angle from the Z axis
            % angle in degrees. r is column vector (or matrix N*3).
            [theta_r, phi_r, rho] = cart2sph(r(:,1), r(:,2), r(:,3));
            theta = obj.r2d(theta_r);
            phi = 90 - obj.r2d(phi_r);
        end
        
        function out = fixCoordinates(obj, in, isNV)
            % this function tekes the coordinates of points on the diamond
            % and fix them due to the diamond properties and placement.
            % 'in': matrix (3*N) - list of column vectors to calculate.
            % 'isNV': boolean. true if the coordinates is of NN
            NVfix = eye(3);
            if isNV
                switch obj.normal
                    case '100'
                        NVfix = eye(3);
                    case '111'
                        NVfix = rotx(54.75) * rotz(45);
                    otherwise
                        obj.sendError('no type of NV normal %s', obj.normal)
                end
                switch obj.edge
                    case '100'
                        NVfix = eye(3) * NVfix;
                    case '110'
                        NVfix = rotz(45) * NVfix;
                    otherwise
                        obj.sendError('no type of NV edge %s', obj.edge)
                end
            end
            out = rotz(obj.D_phi) * roty(obj.D_theta) * rotz(obj.D_rotate) * NVfix * in;
        end
        
        function save(obj, address)
            expStruct = struct;
            expStruct.B = obj.B;
            expStruct.flip = obj.flip;
            expStruct.normal = obj.normal;
            expStruct.edge = obj.edge;
            expStruct.D_rotate = obj.D_rotate;
            expStruct.D_theta = obj.D_theta;
            expStruct.D_phi = obj.D_phi;
            expStruct.dontChange = obj.dontChange;
            expStruct.stepSizeD = obj.stepSizeD;
            expStruct.stepSize = obj.stepSize;
            expStruct.stepSizeI = obj.stepSizeI;
            expStruct.viewAng = obj.viewAng;
            
            save(address', 'expStruct');
            clear expStruct;
        end
        
        function load(obj, address)
            expStruct = load(address);
            expStruct = expStruct.expStruct;
            obj.setB(expStruct.B);
            obj.flipDirection(expStruct.flip);
            obj.normal = expStruct.normal;
            obj.edge = expStruct.edge;
            obj.D_rotate = expStruct.D_rotate;
            obj.D_theta = expStruct.D_theta;
            obj.D_phi = expStruct.D_phi;
            obj.dontChange = expStruct.dontChange;
            obj.stepSizeD = expStruct.stepSizeD;
            obj.stepSize = expStruct.stepSize;
            obj.stepSizeI = expStruct.stepSizeI;
            obj.viewAng = expStruct.viewAng;
            clear expStruct;
        end
    end
    
    methods (Static, Access = protected)
        function rad = d2r(deg)
            rad = deg * 2*pi/360;
        end
        
        function deg = r2d(rad)
            deg = rad * 360/(2*pi);
        end
        
        function [h] = arrow3d(gAxes, x, y, z, head_frac, radii, radii2, colr)
            % The function plotting 3-dimensional arrow
            % The inputs are:
            %       x,y,z =  vectors of the starting point and the ending point of the
            %           arrow, e.g.:  x=[x_start, x_end]; y=[y_start, y_end];z=[z_start,z_end];
            %       head_frac = fraction of the arrow length where the head should  start
            %       radii = radius of the arrow
            %       radii2 = radius of the arrow head (defult = radii*2)
            %       colr =   color of the arrow, can be string of the color name, or RGB vector  (default='blue')
            %
            % The output is the handle of the surfaceplot graphics object.
            % The settings of the plot can changed using: set(h, 'PropertyName', PropertyValue)
            % Written by Moshe Lindner , Bar-Ilan University, Israel. July 2010 (C)
            if nargin==5
                radii2=radii*2;
                colr='blue';
            elseif nargin==6
                colr='blue';
            end
            if size(x,1)==2
                x=x';
                y=y';
                z=z';
            end
            x(3)=x(2);
            x(2)=x(1)+head_frac*(x(3)-x(1));
            y(3)=y(2);
            y(2)=y(1)+head_frac*(y(3)-y(1));
            z(3)=z(2);
            z(2)=z(1)+head_frac*(z(3)-z(1));
            r=[x(1:2)',y(1:2)',z(1:2)'];
            N=50;
            dr=diff(r);
            dr(end+1,:)=dr(end,:);
            origin_shift=(ones(size(r))*(1+max(abs(r(:))))+[dr(:,1) 2*dr(:,2) -dr(:,3)]);
            r=r+origin_shift;
            normdr=(sqrt((dr(:,1).^2)+(dr(:,2).^2)+(dr(:,3).^2)));
            normdr=[normdr,normdr,normdr];
            dr=dr./normdr;
            Pc=r;
            n1=cross(dr,Pc);
            normn1=(sqrt((n1(:,1).^2)+(n1(:,2).^2)+(n1(:,3).^2)));
            normn1=[normn1,normn1,normn1];
            n1=n1./normn1;
            P1=n1+Pc;
            X1=[];Y1=[];Z1=[];
            j=1;
            for theta=([0:N])*2*pi./(N)
                R1=Pc+radii*cos(theta).*(P1-Pc) + radii*sin(theta).*cross(dr,(P1-Pc)) -origin_shift;
                X1(2:3,j)=R1(:,1);
                Y1(2:3,j)=R1(:,2);
                Z1(2:3,j)=R1(:,3);
                j=j+1;
            end
            r=[x(2:3)',y(2:3)',z(2:3)'];
            dr=diff(r);
            dr(end+1,:)=dr(end,:);
            origin_shift=(ones(size(r))*(1+max(abs(r(:))))+[dr(:,1) 2*dr(:,2) -dr(:,3)]);
            r=r+origin_shift;
            normdr=(sqrt((dr(:,1).^2)+(dr(:,2).^2)+(dr(:,3).^2)));
            normdr=[normdr,normdr,normdr];
            dr=dr./normdr;
            Pc=r;
            n1=cross(dr,Pc);
            normn1=(sqrt((n1(:,1).^2)+(n1(:,2).^2)+(n1(:,3).^2)));
            normn1=[normn1,normn1,normn1];
            n1=n1./normn1;
            P1=n1+Pc;
            j=1;
            for theta=([0:N])*2*pi./(N)
                R1=Pc+radii2*cos(theta).*(P1-Pc) + radii2*sin(theta).*cross(dr,(P1-Pc)) -origin_shift;
                X1(4:5,j)=R1(:,1);
                Y1(4:5,j)=R1(:,2);
                Z1(4:5,j)=R1(:,3);
                j=j+1;
            end
            X1(1,:)=X1(1,:)*0 + x(1);
            Y1(1,:)=Y1(1,:)*0 + y(1);
            Z1(1,:)=Z1(1,:)*0 + z(1);
            X1(5,:)=X1(5,:)*0 + x(3);
            Y1(5,:)=Y1(5,:)*0 + y(3);
            Z1(5,:)=Z1(5,:)*0 + z(3);
            X1(2,:)=X1(2,:)*0;
            Y1(2,:)=Y1(2,:)*0;
            Z1(2,:)=Z1(2,:)*0;
            h = surf(gAxes, X1,Y1,Z1,'facecolor',colr,'edgecolor','none');
            camlight(gAxes);
            lighting(gAxes, 'phong');
        end
    end
end