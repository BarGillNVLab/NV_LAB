classdef SaveLoadCatExp < SaveLoad & EventListener
    %SAVELOADCATIMAGE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Constant)
        NAME = SaveLoad.getInstanceName(Savable.CATEGORY_EXPERIMENTS);
    end
    
    methods
        function obj = SaveLoadCatExp
            obj@SaveLoad(Savable.CATEGORY_EXPERIMENTS);
            expNames = Experiment.getExperimentNames;
            obj@EventListener(expNames);
        end
    end
    
     %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            % There are two kinds of relevant events: when an Experiment
            % (re)starts and when there are new results (so we can save
            % backup).
            
            info = event.extraInfo;
            
            if isfield(info, Experiment.EVENT_PARAM_CHANGED)
                obj.saveParamsToLocalStruct;
                
            elseif isa(event.creator, 'SpcmCounter')
                % The SPCM counter updates so frequently, we want to treat
                % it seperately, and save backup only when we pause the
                % Counter
                if isfield(info, Experiment.EVENT_EXP_PAUSED)
                    obj.saveResultsToLocalStruct();
                    obj.saveBackup;
                elseif isfield(info, SpcmCounter.EVENT_SPCM_COUNTER_RESET)
                    obj.saveParamsToLocalStruct;
                end
            elseif isfield(info, Experiment.EVENT_EXP_RESUMED) ...
                    && event.creator.shouldAutosave
                diaryName = [obj.PATH_DEFAULT_AUTO_SAVE, obj.mLoadedFileName, '_log.txt'];
                diary(diaryName)
            elseif isfield(info, Experiment.EVENT_DATA_UPDATED)
                obj.saveResultsToLocalStruct();
                obj.saveBackup;
            elseif isfield(info, Experiment.EVENT_EXP_PAUSED) ...
                    && event.creator.shouldAutosave
                diary off
                % Only save non empty experiments
                if ~isempty(event.creator) && isprop(event.creator, 'currIter') && event.creator.currIter == 0
                    return;
                end
                obj.autoSave
            end
        end
    end
    
end

