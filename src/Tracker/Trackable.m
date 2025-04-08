classdef (Abstract) Trackable < Experiment
    %TRACKABLE trackable experiment -- watches over drift of system
    % This experiment is invoked in constant intervals, to check if the
    % relevant parameters for the experiment have not changed
    
    properties (SetAccess = protected)
        parent
        
        % Saving history/records of tracking
        mHistory = {};
        sessionEnds = [];   % Marks the indices (in mHistory) where tracking stopped
        
        timer       % Stores tic from beginning of tracking
        isCurrentlyTracking = false;
    end
    
    properties
        isRunningContinuously
    end
    
    properties (Constant)
        PATH_ALL_TRACKABLES = sprintf('%sControl code\\%s\\Tracker\\Trackables\\', ...
            PathHelper.getPathToNvLab(), PathHelper.SetupMode);
        
        EVENT_TRACKABLE_EXP_ENDED = 'TrackableExperimentFinished'
        EVENT_TRACKABLE_EXP_UPDATED = 'TrackableExperimentUpdated'
        EVENT_CONTINUOUS_TRACKING_CHANGED = 'continuousTrackingChanged'
        
        TRACKABLE_CLASS_NAME = 'trackable';
    end
    
    properties (Constant, Abstract)
        HISTORY_FIELDS
       
        DEFAULT_CONTINUOUS_TRACKING     % Should this tracker be on continuously by default? (probably false for all...)
    end
    
    %%
    methods
        function obj = Trackable(name)
            obj@Experiment(name);
            obj.mCategory = Savable.CATEGORY_TRACKER;
            obj.isRunningContinuously = obj.DEFAULT_CONTINUOUS_TRACKING;
            obj.timer = ExactTimer();
        end
        
        %%% Events
        function sendEventTrackableExpEnded(obj)
            s = struct;
            s.(obj.EVENT_TRACKABLE_EXP_ENDED) = true;
            s.(obj.EVENT_EXP_PAUSED) = true;
            s.text = obj.textOutput;
            obj.sendEvent(s);
        end
        
        function sendEventTrackableUpdated(obj)
            obj.sendEvent(struct(obj.EVENT_TRACKABLE_EXP_UPDATED,true));
        end
        
        %%% Tracking general structure
        function startTrack(obj, parent)
            % (All functions are inherited from Experiment and implemented
            %  in subclasses)
            if nargin < 2
                parent = '';
            end
            obj.parent = parent;
            
            obj.stopFlag = false;
            obj.isCurrentlyTracking = true;
            obj.sendEventTrackableUpdated; % Make sure GUI is updated.
            
            prepare(obj)
            obj.sendEventParamChanged;  % That happenned at preperation
            sendEventExpResumed(obj);
            
            perform(obj);
            
            stopTrack(obj)  % Signaling internally and externally that we are done
            obj.isCurrentlyTracking = false;
            obj.sendEventTrackableExpEnded;
            wrapUp(obj)
            sendEventPlotAnalyzeFit(obj)
        end
        
        function stopTrack(obj)
            obj.stopFlag = true;
            obj.sendEventTrackableUpdated; % Make sure GUI is updated.
        end
        
    end
        
    %% Helper functions
    methods
        function clearHistory(obj)
            obj.mHistory = {};
            obj.sessionEnds = [];
        end
        
        function [historyStruct, sessionEndsIdx] = convertHistoryToStructToSave(obj)
            % Takes obj.mHistory and formats it as a struct which can be
            % sent to SaveLoad
            for fCell = obj.HISTORY_FIELDS
                field = char(fCell);    % MATLAB needs casting from cell to char array for the next line
                historyStruct.(field) = cellfun(@(c) c.(field), obj.mHistory, 'UniformOutput', false);
                historyStruct.(field) = historyStruct.(field)';     % better formatting
            end
            sessionEndsIdx = obj.sessionEnds;
        end
        
        function tf = isHistoryEmpty(obj)
            tf = isempty(obj.mHistory);
        end
        
    end
    
    methods % Setters
        function set.isRunningContinuously(obj,newValue)
            obj.isRunningContinuously = newValue;
            obj.sendEvent(struct(obj.EVENT_CONTINUOUS_TRACKING_CHANGED,true));
        end
    end
    
    methods (Abstract)
       params = getAllTrackalbeParameter(obj)
       % Returns a cell of values/paramters from the trackable experiment
       
       resetTrack(obj)
       % Re-initialize the trackable
       
       str = textOutput(obj)
       % returns readable string with the results of the trackable
       % experiment
       
       %%%% Useful architecture, but private (so not obligatory)
       % recordCurrentState(obj)
       % Creates a record with the current state of the system (i.e. the
       % value of each of obj.HISTORY_FIELDS), and add it to obj.mHistory
       %
       % recordSessionEnd(obj)
       % calls obj.recordCurrentState, and also save the index of that
       % point in time, since it marks the end of a tracking session.
    end
    
    %% Overridden from Experiment
    methods (Access = protected)
        function reset(obj)
            % Here it has a specific name
            obj.resetTrack(obj)
        end
    end
    
%     %% overridden from EventListener
%     methods
%         % When events happen, this function jumps.
%         % event is the event sent from the EventSender
%         function onEvent(obj, event) %#ok<INUSD>
%         end
%     end
    
end

