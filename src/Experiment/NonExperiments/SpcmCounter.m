classdef SpcmCounter < Experiment
    %SPCMCOUNTER Read counts from SPCM via timer
    %   When switched on (reset), inits the vector of reads to be empty,
    %   and start a timer to read every 100ms.
    %   every time the timer clocks, a new read will be added to the
    %   vector.
    %
    %   The counter implements events from class Experiment, and adds event
    %   EVENT_SPCM_COUNTER_RESET, when we want to clear all results until
    %   now, and start anew.
    
    properties
        records     % vector, saves all previous scans since reset
        records2    % vector, when there are 2 spcms.
        hist        % vector, histogram.
        G2          % vector, G2.
        integrationTimeMillisec     % float, in milliseconds
        currentType = 1; % Options are given in TYPE_OPTIONS
    end
    
    properties (Access = private)
        mTimer	% Timer for new records
    end
    
    properties (Constant)
        NAME = 'SpcmCounter'

        EVENT_SPCM_COUNTER_RESET = 'SpcmCounterReset';
        
        INTEGRATION_TIME_DEFAULT_MILLISEC = 100;
        DEFAULT_EMPTY_STRUCT = struct('time', 0, 'kcps', NaN, 'std', NaN, 'realTime', 0);
        TYPE_OPTIONS = {'Counter', 'Lifetime', 'G2'};
    end
    
    methods
        function obj = SpcmCounter
            obj@Experiment(SpcmCounter.NAME);
            obj.integrationTimeMillisec = obj.INTEGRATION_TIME_DEFAULT_MILLISEC;
            obj.mTimer = ExactTimer;
            obj.stopFlag = true; % It is stopped (not running) by default
            
            obj.averages = 1;   % This Experiment has no averaging over repeats
            obj.shouldAutosave = false;
            obj.reset();
        end
    end
    
    methods (Access = protected)
        function sendEventReset(obj)
            obj.sendEvent(struct(obj.EVENT_SPCM_COUNTER_RESET,true));
        end
        
        function reset(obj)
            spcm = getObjByName(Spcm.NAME);
            obj.records = obj.DEFAULT_EMPTY_STRUCT;
            obj.records2 = obj.DEFAULT_EMPTY_STRUCT;
            if spcm.hasLifetime()
                obj.hist = zeros(1, spcm.nBins);
            end
            if spcm.hasG2()
                obj.G2 = zeros(1, spcm.nBins*2+1);
            end
            obj.currIter = 0;
            obj.mTimer.reset;
            obj.sendEventReset;
        end
        
        function newRecord(obj, kcps, std)
            % creates new record in a struct of the type "record" =
            % record.{time,kcps,std}, with proper validation.
			integrationTime = obj.integrationTimeMillisec / 1000;
            time = obj.records(end).time + integrationTime;
            realTime = obj.mTimer.toc;  % Personalized timer
            
            spcm = getObjByName(Spcm.NAME);
            if (any(kcps < -eps) || any(std < -eps) || any(kcps < std-eps)) && (~spcm.hasPhotodiode())
                recordNum = length(obj.records);
                EventStation.anonymousWarning('Invalid values in time %d (record #%i)', time, recordNum)
            end
            obj.records(end + 1) = struct('time', time, 'kcps', kcps(1), 'std', std(1), 'realTime', realTime);
            if length(kcps) == 2
                obj.records2(end + 1) = struct('time', time, 'kcps', kcps(2), 'std', std(2), 'realTime', realTime);
            end
            obj.currIter = obj.currIter + 1;
        end
    end
       
    methods % Setters and getters
        function [time, kcps, std, realTime] = getRecords(obj, lenOpt)
            lenRecords = length(obj.records);
            if ~exist('lenOpt', 'var')
                wrapLength = lenRecords;
            else
                wrapLength = lenOpt;
            end
            
            difference = lenRecords - wrapLength;
            if difference < 0
                padding = abs(difference) - 1;
                maxTime = wrapLength*obj.integrationTimeMillisec/1000;  % Create time for end of wrap
                zeroStruct = struct('time', maxTime, 'kcps', 0, 'std', 0, 'realTime', NaN);
                data = [obj.records, ...
                    repelem(obj.DEFAULT_EMPTY_STRUCT, padding), ...
                    zeroStruct];
            elseif difference == 0
                data = obj.records;
            else
                position = difference + 1;
                data = obj.records(position:end);
            end
            
            time = [data.time];
            realTime = [data.realTime];
            kcps = [data.kcps];
            std = [data.std];
            
            if ~isempty(obj.records2)
                [check, i] = ismember([obj.records2.time], time);
                i = i(i>0);
                if any(check)
                    kcps(2, i) = [obj.records2(check).kcps];
                    std(2, i) = [obj.records2(check).std];
                    kcps(2, isnan(kcps(1,:))) = NaN;
                    std(2, isnan(std(1,:))) = NaN;
                end
            end
        end
        
        function set.integrationTimeMillisec(obj, newValue)
            if ValidationHelper.isValuePositiveInteger(newValue)
                obj.integrationTimeMillisec = newValue;
            else
                EventStation.anonymousWarning('Integration time needs to be a positive integer. Reverting.')
            end
            
            obj.sendEventParamChanged;
        end
    end
    
    %% Overridden from Experiment
    methods
        function run(obj)
            obj.getSetCurrentExp(obj.NAME);
            obj.stopFlag = false;
            sendEventExpResumed(obj);
            
            integrationTime = obj.integrationTimeMillisec;  % For convenience
            
            spcm = getObjByName(Spcm.NAME);
            if isempty(spcm); throwBaseObjException(Spcm.NAME); end
            if spcm.hasGatedIntegrator()
                spcm.detectionWithGI = 0;
            end
            spcm.setSPCMEnable(true);
            spcm.prepareReadByTime(integrationTime/1000);
            obj.isRunning = true;
            try
                while ~obj.stopFlag
                    % Creating data to be saved
                    [kcps, std] = spcm.readFromTime;
                    obj.newRecord(kcps, std);
                    obj.sendEventDataUpdated;
                    
                    % Update integration time, if necessary
                    if integrationTime ~= obj.integrationTimeMillisec
                        integrationTime = obj.integrationTimeMillisec;
                        spcm.clearTimeRead;
                        spcm.prepareReadByTime(integrationTime/1000);
                    end
                end
                spcm.clearTimeTask;
            catch err
                obj.pause;
                try
                    spcm.clearTimeTask;
                catch
                end
                rethrow(err);
            end
            sendEventExpPaused(obj)
        end
        
        function pause(obj)
            obj.stopFlag = true;
            pause((obj.integrationTimeMillisec + 1) / 1000);    % Let me finish what I was doing
            obj.isRunning = false;
            obj.sendEventExpPaused;
        end
        
        function resetHistory(obj)
            obj.reset;
            spcm = getObjByName(Spcm.NAME);
            spcm.prepareReadByTime(obj.integrationTimeMillisec/1000);
        end
        
        function params = getTotalNumberOfParams(obj) %#ok<MANU>
            params = 0;
        end
    end
     
    methods (Access = protected)
        % Functions that are abstract in superclass. Not relevant here.
        function prepare(obj) %#ok<MANU>
        end
        function perform(obj) %#ok<MANU> 
        end
        function alternateSignal(obj)%#ok<MANU>
        end
        function wrapUp(obj) %#ok<MANU>
        end
    end
    
    %%
	methods (Static)
        function init
            obj = getObjByName(SpcmCounter.NAME);
            if isempty(obj)
                % There was no such object, so we create one
                SpcmCounter;
            else
                obj.pause;
            end
        end
    end
end