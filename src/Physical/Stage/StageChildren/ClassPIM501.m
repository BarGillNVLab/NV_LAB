classdef (Sealed) ClassPIM501 < ClassPIMicos
    % Created by Yoav Romach, The Hebrew University, September, 2016
    % Used to control PI Micos M-501 stage.
    % libfunctionsview('PI') to view functions
    
    properties (Constant, Access = protected)
        controllerModel = 'C-863';
        validAxes = 'z';
        units = ' um';
    end
    
    properties (Access = protected)
        ID
        posRangeLimit
        negRangeLimit
        posSoftRangeLimit
        negSoftRangeLimit
        defaultVel
        curPos
        curVel
        forceStop
        scanRunning
    end
    
    properties (Constant)
        NAME = 'Stage (coarse) - ClassPIM501'
        
        STEP_MINIMUM_SIZE = 0.3
        STEP_DEFAULT_SIZE = 100
    end
    
    methods (Static, Access = public) % Get instance constructor
        function obj = GetInstance()
            % Returns a singelton instance of this class.
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj) || localObj.ID == -1
                localObj = ClassPIM501;
            end
            obj = localObj;
        end
    end
    
    methods (Access = private) % Private Functions
        function obj = ClassPIM501
            % Private default constructor.
            name = ClassPIM501.NAME;
            availAxis = ClassPIM501.validAxes;
            obj = obj@ClassPIMicos(name, availAxis);

            obj.ID = -1;
            obj.posRangeLimit = 12500; % Units set to microns.
            obj.negRangeLimit = 0; % Units set to microns.
            obj.posSoftRangeLimit = obj.posRangeLimit;
            obj.negSoftRangeLimit = obj.negRangeLimit;
            obj.defaultVel = 500; % Default velocity is 500 um/s.
            obj.curPos = 0;
            obj.curVel = 0;
            obj.forceStop = 0;
            obj.scanRunning = 0;
            
            obj.availableProperties.(obj.HAS_CLOSED_LOOP) = true;
            obj.availableProperties.(obj.HAS_OPEN_LOOP) = true;
            
            obj.Connect();
            obj.Initialization();
        end
    end
    
    methods (Access = protected) % Overwrite ClassPIMicos functions
        function [szAxes, zerosVector] = ConvertAxis(obj, phAxis)
            % Returns the corresponding szAxes string needed to
            % communicate with PI controllers that are connected to
            % multiple axes. Also returns a vector containging zeros with
            % the length of the axes.
            % 'phAxis' can be either a specific axis (x,y,z or 1 for x,
            % 2 for y, and 3 for z) or any vectorial combination of them.
            CheckAxis(obj, phAxis);
            szAxes = '1';
            zerosVector = 0;
        end
        
        function Refernce(obj, phAxis)
            % Reference the given axis.
            % 'phAxis' can be either a specific axis (x,y,z or 1 for x, 2 for y
            % and 3 for z) or any vectorial combination of them.
            CheckAxis(obj, phAxis)
            [szAxes, zerosVector] = ConvertAxis(obj, phAxis);
            SendPICommand(obj, 'PI_FPL', obj.ID, szAxes);
            
            % Check if ready & if referenced succeeded
            WaitFor(obj, 'ControllerReady', phAxis)
            [~, refernced] = SendPICommand(obj, 'PI_qFRF', obj.ID,szAxes, zerosVector);
            if (~all(refernced))
                errorMsg = sprintf('Referencing failed for controller %s with ID %d: Reason unknown.', ...
                    obj.controllerModel, obj.ID);
                obj.sendError(errorMsg);
            end
        end
    end
end