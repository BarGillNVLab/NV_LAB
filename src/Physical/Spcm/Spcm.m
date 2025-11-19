classdef (Abstract) Spcm < EventSender
    %SPCM single photon counter
    %   the spcm is controlled by the NiDaq
    
    properties
        availableProperties = struct;
    end
    
    properties (Constant)
        NAME = 'spcm';
        
        HAS_LIFETIME = 'hasLifetime';
        HAS_G2 = 'hasG2';
        HAS_BINNING = 'hasBinning';
        HAS_ALTCOUNT = 'hasAltCount';
        HAS_PHOTODIODE = 'hasPhotodiode';
        HAS_GATED_INTEGRATOR = 'hasGatedIntegrator';
        HAS_LASER_REF = 'hasLaserRef';
        HAS_DIFF_INPUT = 'hasDiffInput';
        HAS_CAMERA = 'hasCamera';
        
    end
    properties (Constant, Hidden)
        % This needs to be implemented, one way or another, in all SPCMs
        SPCM_NEEDED_FIELDS = {'classname'};
    end
    
        
    methods (Access = protected)
        function obj = Spcm(spcmName)
            obj@EventSender(spcmName);
        end
    end
    
    methods (Abstract)
    %%% By time %%%
        prepareReadByTime(obj, integrationTimeInSec)
        % Prepare to read spcm count from opening the spcm window to unit of time
        
        [kcps, std] = readFromTime(obj)
        % Actually do the read - it takes "integrationTimeInSec" to do so
        
        clearTimeRead(obj)
        % Clear the reading task
        
        
     %%% By stage %%%
        prepareCountByStage(obj, stageName, nPixels, timeout, fastScan)
        % Prepare to read from the spcm, when using a stage as a signal
        
        startScanCount(obj)
        % Actually start the process
        
        vectorOfKcps = readFromScan(obj)
        % Read vector of signals from the spcm
        
        clearScanRead(obj)
        % Complete the task of reading the spcm from a stage
        
        
     %%% Experiment (by PulseGenerator) %%%
        prepareExperimentCount(obj)
        % Prepare to read spcm count from opening the spcm window  
        
        startExperimentCount(obj)
        % Actually start the process
        
        vectorOfKcps = readFromExperiment(obj)
        % Read vector of signals from the spcm
        
        stopExperimentCount(obj, varargin)
        % Stop reading (to clear memory)
        
        clearExperimentRead(obj)
        % Complete the task of reading the spcm 
        
        
        %%% General %%%
        setSPCMEnable(obj, newBooleanState)
        % Turn the spcm on\off
    end
       
    methods (Access = ?SpcmCounter)
        function clearTimeTask(obj)
            obj.clearTimeRead;
            obj.setSPCMEnable(false);
        end
    end

    methods (Static)
        function create(spcmTypeStruct)
            % Validate minimal required fields
            missingField = FactoryHelper.usualChecks(spcmTypeStruct, Spcm.SPCM_NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError( ...
                    'Can''t initialize SPCM - needed field "%s" was not found in initialization struct!', ...
                    missingField);
            end
    
            % Check if SPCM object already exists
            obj = getObjByName(Spcm.NAME);
            if ~isempty(obj)
                warning('Another instance of the SPCM already exists');
                return;
            end
    
            % ----------------------------
            %   SELECT BACKEND BY JSON
            % ----------------------------
            classname = lower(string(spcmTypeStruct.classname));
    
            switch classname
    
                % ============================================
                % 1. NI-DAQ HIGH LEVEL BACKEND (old behavior)
                % ============================================
                case "nidaq"
                    spcmObject = SpcmNiDaqControlled.create(Spcm.NAME, spcmTypeStruct);
    
                % ============================================
                % 2. TimeTagger + NI-DAQ (old behavior)
                % ============================================
                case "timetagger"
                    spcmObject = SpcmTimeTaggerControlledNiDaqEnabled.create( ...
                        Spcm.NAME, spcmTypeStruct);
    
                % ============================================
                % 3. TimeTagger + Arduino Gate (NEW)
                % ============================================
                case "timetagger_arduino"
                    spcmObject = SpcmTimeTaggerControlledArduinoDaqEnabled.create( ...
                        Spcm.NAME, spcmTypeStruct);
    
                % ============================================
                % 4. Photodiode (NI)
                % ============================================
                case "photodiodenidaq"
                    spcmObject = PhotoDiodeNiDaqControlled.create(Spcm.NAME, spcmTypeStruct);
    
                % ============================================
                % 5. Photodiode Digitizer (NI)
                % ============================================
                case "photodiodedigitizernidaq"
                    spcmObject = PhotoDiodeDigitizerNiDaqControlled.create( ...
                        Spcm.NAME, spcmTypeStruct);
    
                % ============================================
                % 6. Camera Backends
                % ============================================
                case "camera"
                    spcmObject = CameraControlled.create(Spcm.NAME, spcmTypeStruct);
    
                % ============================================
                % 7. Dummy SPCM
                % ============================================
                case "dummy"
                    spcmObject = SpcmDummy();
    
                % ============================================
                % UNKNOWN TYPE
                % ============================================
                otherwise
                    EventStation.anonymousError( ...
                        ['The requested SPCM classname ("%s") was not recognized.\n', ...
                         'Valid options: nidaq, timetagger, timetagger_arduino, ', ...
                         'photodiodenidaq, photodiodedigitizernidaq, camera, dummy'], ...
                        spcmTypeStruct.classname);
            end
    
            % -------------------------------------
            % CREATE THE SWITCH CHANNEL(S)
            % -------------------------------------
            switchStruct = spcmTypeStruct.Switch;
    
            if isfield(switchStruct, 'classname')
                % Single switch
                SwitchPgControlled.create(switchStruct.switchChannelName, switchStruct);
            else
                % Multiple switches
                pgChannels = fieldnames(switchStruct);
                for i = 1:numel(pgChannels)
                    singleSwitchStruct = switchStruct.(pgChannels{i});
                    SwitchPgControlled.create(singleSwitchStruct.switchChannelName, singleSwitchStruct);
                end
            end
    
            % -------------------------------------
            % REGISTER THE SPCM IN THE FRAMEWORK
            % -------------------------------------
            addBaseObject(spcmObject);
        end

    end
    
    methods % Available properties    
        function properties = getAvailableProperties(obj)
            properties = obj.avilableProperties;
        end

        function bool = hasLifetime(obj)
            bool = isfield(obj.availableProperties,obj.HAS_LIFETIME);
        end
        
        function bool = hasG2(obj)
            bool = isfield(obj.availableProperties,obj.HAS_G2);
        end
        
        function bool = hasBinning(obj)
            bool = isfield(obj.availableProperties,obj.HAS_BINNING);
        end
        
        function bool = hasAltCount(obj)
            bool = isfield(obj.availableProperties,obj.HAS_ALTCOUNT);
        end
        
        function bool = hasPhotodiode(obj)
            bool = isfield(obj.availableProperties,obj.HAS_PHOTODIODE);
        end
        
        function bool = hasGatedIntegrator(obj)
            bool = isfield(obj.availableProperties,obj.HAS_GATED_INTEGRATOR);
        end
        
        function bool = hasLaserRef(obj)
            bool = isfield(obj.availableProperties,obj.HAS_LASER_REF);
        end
        
        function bool = hasDiffInput(obj)
            bool = isfield(obj.availableProperties,obj.HAS_DIFF_INPUT);
        end
        
        function bool = hasCamera(obj)
            bool = isfield(obj.availableProperties, obj.HAS_CAMERA);
        end
    end
    
    methods (Access = public)
        function [kcps, stdev, hist] = timed_lifetime(obj,intTime) % Jonathan's lifetime measurement on setup 4 22.06.2021
            % get a lifetime measurement integrated over intTime seconds
            % turn on spcm
            obj.setSPCMEnable(true);
            % reset histogram
            obj.resetTimeRead();
            % prepare a new time measurement (required after any reset operation
            obj.prepareReadByTime(intTime);
            % do the reading
            [kcps, stdev] = obj.readFromTime();
            % hist data
            hist = obj.lastTimeHist;
        end
    end    
    
end