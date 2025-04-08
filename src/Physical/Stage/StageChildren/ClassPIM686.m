classdef (Sealed) ClassPIM686 < ClassPIMicos
    % Created by Yoav Romach, The Hebrew University, October, 2016
    % Used to control PI Micos M-686 stage.
    % libfunctionsview('PI') to view functions
    
    properties (Constant, Access = protected)
        controllerModel = 'C-867';
        validAxes = 'xy';
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
        NAME = 'Stage (coarse) - ClassPIM686'
        
        STEP_MINIMUM_SIZE = 0.3
        STEP_DEFAULT_SIZE = 100
    end
    
    methods (Static, Access = public) % Get instance constructor
        function obj = GetInstance()
            % Returns a singelton instance of this class.
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj) || localObj.ID == -1
                localObj = ClassPIM686;
            end
            obj = localObj;
        end
    end
    
    methods (Access = private) % Private Functions
        function obj = ClassPIM686
            % Private default constructor.
            name = ClassPIM686.NAME;
            availAxis = ClassPIM686.validAxes;
            obj = obj@ClassPIMicos(name, availAxis);

            obj.ID = -1;
            obj.posRangeLimit = [12500 12500]; % Units set to microns.
            obj.negRangeLimit = [-12500 -12500]; % Units set to microns.
            obj.posSoftRangeLimit = obj.posRangeLimit;
            obj.negSoftRangeLimit = obj.negRangeLimit;
            obj.defaultVel = 2500; % Default velocity is 2500 um/s.
            obj.curPos = [0 0];
            obj.curVel = [0 0];
            obj.forceStop = 0;
            obj.scanRunning = 0;
            
            obj.availableProperties.(obj.HAS_CLOSED_LOOP) = true;
            obj.availableProperties.(obj.HAS_OPEN_LOOP) = true;
            
            obj.Connect();
            obj.Initialization();
        end
    end
end