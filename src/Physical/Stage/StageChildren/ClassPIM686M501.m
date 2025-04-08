classdef (Sealed) ClassPIM686M501 < ClassStage
    %CLASSPIM686M501 Wrapper class for ClassPIM686 & ClassPIM501

    properties (Access = protected)
        stageCoarseZ
        stageCoarseXY
    end
    
    properties (Constant)
        NAME = 'Stage (coarse) - ClassPIM686&PIM501'
        AVAILABLE_AXES = 'xyz'
        
        STEP_MINIMUM_SIZE = 0.3
        STEP_DEFAULT_SIZE = 100
    end
    
    methods (Static, Access = public) % Get instance constructor
        function obj = GetInstance()
            % No need for singleton here
            obj = ClassPIM686M501;
        end
        
        function warningScanUnimplemented
            warning('Scan is not implemented for coarse stages');
        end
        
        function warningTiltUnimplemented
            warning('Tilt is not implemented for this stages');
        end
    end
    
    methods (Access = private) % Private Functions
        function obj = ClassPIM686M501
            % Private default constructor
            name = ClassPIM686M501.NAME;
            availableAxes = ClassPIM686M501.AVAILABLE_AXES;
%             tiltAvailable = true;         todo: implement
            
            obj@ClassStage(name, availableAxes);
            obj.stageCoarseZ = ClassPIM501.GetInstance();
            obj.stageCoarseXY = ClassPIM686.GetInstance();
            
            obj.availableProperties.(obj.HAS_CLOSED_LOOP) = true;
            obj.availableProperties.(obj.HAS_OPEN_LOOP) = true;
        end 
    end
    
    methods % Implement ClassStage Abstracts
        function CloseConnection(obj)
            % Closes the connection to the stages.
            obj.stageCoarseZ.CloseConnection();
            obj.stageCoarseXY.CloseConnection();
        end
        
        function Reconnect(obj)
            % Reconnects the controller.
            obj.stageCoarseZ.Reconnect();
            obj.stageCoarseXY.Reconnect();
        end
        
        function ok = PointIsInRange(obj, phAxis, point)
            % Checks if the given point is within the soft (and hard)
            % limits of the given axis (x,y,z or 1 for x, 2 for y and 3 for z).
            % Vectorial axis is possible.
            phAxis = GetAxis(obj, phAxis);
            if all(phAxis == 3) % Only Z Axis.
                ok = obj.stageCoarseZ.PointIsInRange(phAxis, point);
            elseif all(phAxis ~= 3) % No Z Axis.
                ok = obj.stageCoarseXY.PointIsInRange(phAxis, point);
            else % Mixture.
                ok = obj.stageCoarseZ.PointIsInRange(phAxis(phAxis==3), point) ...
                    & obj.stageCoarseXY.PointIsInRange(phAxis(phAxis~=3), point);
            end
        end
        
        function [negSoftLimit, posSoftLimit] = ReturnLimits(obj, phAxis)
            % Return the soft limits of the given axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            phAxis = GetAxis(obj, phAxis);
            if all(phAxis == 3) % Only Z Axis
                [negSoftLimit, posSoftLimit] = obj.stageCoarseZ.ReturnLimits(phAxis);
            elseif all(phAxis ~= 3) % No Z Axis
                [negSoftLimit, posSoftLimit] = obj.stageCoarseXY.ReturnLimits(phAxis);
            else % Mixture
                zAxisBool = (phAxis == 3);
                xyAxesBool = (phAxis ~= 3);
                [negSoftLimit(zAxisBool),  posSoftLimit(zAxisBool)]  = obj.stageCoarseZ.ReturnLimits(phAxis(zAxisBool));
                [negSoftLimit(xyAxesBool), posSoftLimit(xyAxesBool)] = obj.stageCoarseXY.ReturnLimits(phAxis(xyAxesBool));
            end
        end
        
        function [negHardLimit, posHardLimit] = ReturnHardLimits(obj, phAxis)
            % Return the hard limits of the given axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            phAxis = GetAxis(obj, phAxis);
            if all(phAxis == 3) % Only Z Axis.
                [negHardLimit, posHardLimit] = obj.stageCoarseZ.ReturnHardLimits(phAxis);
            elseif all(phAxis ~= 3) % No Z Axis.
                [negHardLimit, posHardLimit] = obj.stageCoarseXY.ReturnHardLimits(phAxis);
            else % Mixture.
                zAxisBool = (phAxis == 3);
                xyAxesBool = (phAxis ~= 3);
                [negHardLimit(zAxisBool), posHardLimit(zAxisBool)] = obj.stageCoarseZ.ReturnHardLimits(phAxis(zAxesBool));
                [negHardLimit(xyAxesBool), posHardLimit(xyAxesBool)] = obj.stageCoarseXY.ReturnHardLimits(phAxis(xyAxesBool));
            end
        end
        
        function SetSoftLimits(obj, phAxis, softLimit, negOrPos)
            % Set the new soft limits:
            % if negOrPos = 0 -> then softLimit = lower soft limit
            % if negOrPos = 1 -> then softLimit = higher soft limit
            % This is because each time this function is called only when
            % one of the limits updates.
            phAxis = GetAxis(obj, phAxis);
            if all(phAxis == 3) % Only Z Axis
                obj.stageCoarseZ.SetSoftLimits(phAxis, softLimit, negOrPos);
            elseif all(phAxis ~= 3) % No Z Axis
                obj.stageCoarseXY.SetSoftLimits(phAxis, softLimit, negOrPos);
            else % Mixture
                obj.stageCoarseZ.SetSoftLimits(phAxis(phAxis==3), softLimit(phAxis==3), negOrPos);
                obj.stageCoarseXY.SetSoftLimits(phAxis(phAxis~=3), softLimit(phAxis~=3), negOrPos);
            end
        end
        
        function pos = Pos(obj, phAxis)
            % Query and return position of axis (x,y,z or 1 for x, 2 for y
            % and 3 for z)
            % Vectorial axis is possible.
            phAxis = GetAxis(obj, phAxis);
            if all(phAxis == 3) % Only Z Axis.
                pos = obj.stageCoarseZ.Pos(phAxis);
            elseif all(phAxis ~= 3) % No Z Axis.
                pos = obj.stageCoarseXY.Pos(phAxis);
            else % Mixture.
                pos(phAxis==3) = obj.stageCoarseZ.Pos(phAxis(phAxis==3));
                pos(phAxis~=3) = obj.stageCoarseXY.Pos(phAxis(phAxis~=3));
            end
        end
        
        function vel = Vel(obj, phAxis)
            % Query and return velocity of axis (x,y,z or 1 for x, 2 for y
            % and 3 for z)
            % Vectorial axis is possible.
            phAxis = GetAxis(obj, phAxis);
            if all(phAxis == 3) % Only Z Axis.
                vel = obj.stageCoarseZ.Vel(phAxis);
            elseif all(phAxis ~= 3) % No Z Axis.
                vel = obj.stageCoarseXY.Vel(phAxis);
            else % Mixture.
                if phAxis(end) ~= 3; obj.sendError('Last axis is not Z, unsupported'); end
                velZ = obj.stageCoarseZ.Vel(phAxis(phAxis==3));
                velXY = obj.stageCoarseXY.Vel(phAxis(phAxis~=3));
                vel = [velXY, velZ];
            end
        end
        
        function Move(obj, phAxis, pos)
            % Absolute change in position (pos) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            phAxis = GetAxis(obj, phAxis);
            if all(phAxis == 3) % Only Z Axis.
                obj.stageCoarseZ.Move(phAxis, pos);
            elseif all(phAxis ~= 3) % No Z Axis.
                obj.stageCoarseXY.Move(phAxis, pos);
            else % Mixture.
                obj.stageCoarseZ.Move(phAxis(phAxis==3), pos(phAxis==3));
                obj.stageCoarseXY.Move(phAxis(phAxis~=3), pos(phAxis~=3));
            end
        end
        
        function RelativeMove(obj, phAxis, change)
            % Relative change in position (pos) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            phAxis = GetAxis(obj, phAxis);
            if all(phAxis == 3) % Only Z Axis.
                obj.stageCoarseZ.RelativeMove(phAxis, change);
            elseif all(phAxis ~= 3) % No Z Axis.
                obj.stageCoarseXY.RelativeMove(phAxis, change);
            else % Mixture.
                obj.stageCoarseZ.RelativeMove(phAxis(phAxis==3), change(phAxis==3));
                obj.stageCoarseXY.RelativeMove(phAxis(phAxis~=3), change(phAxis~=3));
            end
        end
        
        function Halt(obj)
            % Halts all stage movements.
            obj.stageCoarseZ.Halt();
            obj.stageCoarseXY.Halt();
        end
        
        function SetVelocity(obj, phAxis, vel)
            % Absolute change in velocity (vel) of axis (x,y,z or 1 for x,
            % 2 for y and 3 for z).
            % Vectorial axis is possible.
            phAxis = GetAxis(obj, phAxis);
            if all(phAxis == 3) % Only Z Axis.
                obj.stageCoarseZ.SetVelocity(phAxis, vel);
            elseif all(phAxis ~= 3) % No Z Axis.
                obj.stageCoarseXY.SetVelocity(phAxis, vel);
            else % Mixture.
                obj.stageCoarseZ.SetVelocity(phAxis(phAxis==3), vel(phAxis==3));
                obj.stageCoarseXY.SetVelocity(phAxis(phAxis~=3), vel(phAxis~=3));
            end
        end
        
        function JoystickControl(obj, enable)
            % Changes the joystick state for all axes to the value of
            % 'enable' - 1 to turn Joystick on, 0 to turn it off.
            obj.stageCoarseZ.JoystickControl(enable);
            obj.stageCoarseXY.JoystickControl(enable);
        end
        
        function binaryButtonState = ReturnJoystickButtonState(obj)
            % Returns the state of the buttons in 3 bit decimal format.
            % 1 for first button, 2 for second and 4 for the 3rd.
            binaryButtonState = obj.stageCoarseZ.ReturnJoystickButtonState();
            binaryButtonState = binaryButtonState + obj.stageCoarseXY.ReturnJoystickButtonState();
        end
        
        function FastScan(obj, enable)
            % Not scannable stage, this function will never be called
        end
        
        function ChangeLoopMode(obj, mode)
            % Changes between closed and open loop.
            % Mode should be either 'Open' or 'Closed'.
            obj.stageCoarseXY.ChangeLoopMode(mode);
            obj.stageCoarseZ.ChangeLoopMode(mode);
        end
        
        function success = SetTiltAngle(obj, thetaXZ, thetaYZ)
            % Sets the tilt angles between Z axis and XY axes.
            % Angles should be in degrees, valid angles are between -5 and 5
            % degrees.
            success = 0;
            obj.warningTiltUnimplemented();
        end
        
        function success = EnableTiltCorrection(obj, enable)
            % Enables the tilt correction according to the angles.
            success = 0;
            obj.warningTiltUnimplemented();
        end
        
        function [tiltEnabled, thetaXZ, thetaYZ] = GetTiltStatus(obj) %#ok<MANU>
            % Return the status of the tilt control.
            tiltEnabled = 0;
            thetaXZ = 0;
            thetaYZ = 0;
        end
    end
    
    %% overriding from Savable
    % This pseudo-stage should not return string.
    methods (Access = protected)
        function string = returnReadableString(obj, savedStruct)
            % return a readable string to be shown. if this object
            % doesn't need a readable string, make (string = NaN;) or
            % (string = '';)
            
            string = NaN;
        end
    end
    
    %% Blank/warning Implementions of scan methods
    methods (Access = public)
        function PrepareScanX(obj, x, y, z, nFlat, nOverRun, tPixel)  %#ok<*INUSD>
        end
        function PrepareScanY(obj, x, y, z, nFlat, nOverRun, tPixel)
        end
        function PrepareScanZ(obj, x, y, z, nFlat, nOverRun, tPixel)
        end
        function PrepareScanXY(obj, x, y, z, nFlat, nOverRun, tPixel)
        end
        function PrepareScanXZ(obj, x, y, z, nFlat, nOverRun, tPixel)
        end
        function PrepareScanYX(obj, x, y, z, nFlat, nOverRun, tPixel)
        end
        function PrepareScanYZ(obj, x, y, z, nFlat, nOverRun, tPixel)
        end
        function PrepareScanZX(obj, x, y, z, nFlat, nOverRun, tPixel)
        end
        function PrepareScanZY(obj, x, y, z, nFlat, nOverRun, tPixel)
        end
        function PrepareRescanLine(obj) %#ok<MANU>
        end
        
        function ScanX(obj, x, y, z, nFlat, nOverRun, tPixel)
            obj.warningScanUnimplemented();
        end
        function ScanY(obj, x, y, z, nFlat, nOverRun, tPixel)
            obj.warningScanUnimplemented();
        end
        function ScanZ(obj, x, y, z, nFlat, nOverRun, tPixel)
            obj.warningScanUnimplemented();
        end
        
        function AbortScan(obj) %#ok<MANU>
        end
        
        function forwards = ScanNextLine(obj)
            obj.warningScanUnimplemented();
            forwards = 1;
        end
        function maxScanSize = ReturnMaxScanSize(obj, nDimensions)
            obj.warningScanUnimplemented();
            maxScanSize = 0;
        end
    end
    
    methods (Access = public) % created by Jonathan for drift measurement 20.5.2021
        function xyLoopMode=getXYLoopMode(obj)
            xyLoopMode=obj.stageCoarseXY.loopMode;
        end
        
        function setXYLoopMode(obj,mode)
            obj.stageCoarseXY.ChangeLoopMode(mode)
        end
                     
        function [xPos,yPos,zPos]=getPosition(obj)
            xPos=obj.stageCoarseXY.Pos('x');
            yPos=obj.stageCoarseXY.Pos('y');
            zPos=obj.stageCoarseZ.Pos('z');
        end
        
    end
            
            
end