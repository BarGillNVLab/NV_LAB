classdef SpcmDummy < Spcm
    %SPCMDUMMY dummy spcm
    %   inherit from Spcm and have default implementations for all the
    %   methods
    
    properties
        timesToRead         % int
        isEnabled           % logical
        integrationTime     % double (in seconds). Time over which photons are counted
        calledScanStart     % logical. Used for checking that the user actually called startScanCount() before calling readFromScan()
        calledExperimentStart	% logical. Used for checking that the user actually called startExperimentCount() before calling readFromExperiment()
    end
    
    properties (Constant)
        MAX_RANDOM_READ = 1000;
        
        NEEDED_FIELDS = Spcm.SPCM_NEEDED_FIELDS;
    end
    
    methods
        function obj = SpcmDummy
            obj@Spcm(Spcm.NAME);
            obj.timesToRead = 0;
            obj.isEnabled = false;
            obj.integrationTime = 0;
            obj.calledScanStart = false;
            obj.calledExperimentStart = false;
        end
        
    %%% From time %%%
        function prepareReadByTime(obj, integrationTimeInSec)
            obj.integrationTime = integrationTimeInSec;
        end
        
        function [kcps, std] = readFromTime(obj, ~)
            if obj.integrationTime <= 0
                obj.sendError('Can''t call readFromTime() without calling obj.prepareReadByTime() first!');
            end
            pause(obj.integrationTime)
            kcps = randi([0 obj.MAX_RANDOM_READ],1,1);
            std = abs(0.2 * kcps * randn);	% Gaussian noise proportional to signal
        end
        
        function clearTimeRead(obj)
            obj.integrationTime = 0;
        end
    %%% End (from time) %%%
        
        
    %%% From stage %%%
        function prepareCountByStage(obj, ~, nPixels, timeout, ~)
            % Prepare to read from the spcm, when using a stage as a signal
            if ~ValidationHelper.isValuePositiveInteger(nPixels)
                obj.sendError(sprintf('Can''t prepare for reading %d times, only positive integers allowed! Igonring.', nPixels));
            end
            obj.timesToRead = nPixels;
            obj.integrationTime = timeout / (2 * nPixels);
        end
        
        function startScanCount(obj)
            % Actually start the process
            obj.calledScanStart = true;
        end
        
        function stopScanCount(obj)
            % Release resources
            obj.calledScanStart = false;
        end
        
        function vectorOfKcps = readFromScan(obj)
            % Read vector of signals from the spcm
            if ~obj.isEnabled
                obj.sendError('Can''t readFromScan() without calling ''setSPCMEnabled()''!');
            end
            
            if obj.timesToRead <= 0
                obj.sendError('Can''t readFromScan() without calling ''prepareCountByStage()''!  ');
            end
            
            if ~obj.calledScanStart
                obj.sendError('Can''t readFromScan() without calling startScanCount()!');
            end
            
            pause(obj.integrationTime * obj.timesToRead);
            vectorOfKcps = randi([0 obj.MAX_RANDOM_READ], 1, obj.timesToRead);
        end
        
        function clearScanRead(obj)
            % Complete the task of reading the spcm from a stage
            obj.timesToRead = 0;
        end
    %%% End (from stage) %%%
        
        
    %%% From PulseGenerator %%%
        function prepareExperimentCount(obj, nReads, timeout)
            % Prepare to read spcm count from opening the spcm window
            if ~ValidationHelper.isValuePositiveInteger(nReads)
                obj.sendError(sprintf('Can''t prepare for reading %d times, only positive integers allowed! Igonring.', nReads));
            end
            obj.timesToRead = nReads;
            obj.integrationTime = timeout / (15 * nReads);  % 15 is a fudge factor. Can be reduced, if we need longer scans
        end
        
        function startExperimentCount(obj)
            % Actually start the process
            obj.calledExperimentStart = true;
        end
        
        function stopExperimentCount(obj)
            % Release resources
            obj.calledExperimentStart = false;
        end
        
        function vectorOfKcps = readFromExperiment(obj)
            % Read vector of signals from the spcm
            if ~obj.isEnabled
                obj.sendError('Can''t readFromScan() without calling ''setSPCMEnabled()''!');
            end
            
            if obj.timesToRead <= 0
                obj.sendError('Can''t readFromScan() without calling ''prepareCountByStage()''!  ');
            end
            
            if ~obj.calledExperimentStart
                obj.sendError('Can''t readFromScan() without calling startScanCount()!');
            end
            
            pause(obj.integrationTime * obj.timesToRead);
            vectorOfKcps = randi([0 obj.MAX_RANDOM_READ], 1, obj.timesToRead);
        end
        
        function clearExperimentRead(obj)
            % Complete the task of reading the spcm
            obj.integrationTime = 0;
        end
        
    %%% End (from PulseGenerator) %%%
        
        function setSPCMEnable(obj, newBooleanValue)
            obj.isEnabled = newBooleanValue;
        end
    end
    
end