classdef StageControlEvents < EventSender
    %STAGECONTROLEVENTS sends an event to ALL THE STAGES
    %   when calling a StageControlEvents static method, it will create an
    %   object of this type and make it send an event. 
    %   all the stages are listener to StageControlEvents objects, so they
    %   all will react to this event.
    %
    %   if you want to call only one stage to do some work, this IS NOT the
    %   appropriate method!
    
    properties (Constant)
        NAME = 'stageController';
        HALT = 'haltAllStages';
        CLOSE_CONNECTION = 'closeConnectionAllStages';
    end
    
    methods
        function obj = StageControlEvents()
            obj@EventSender(StageControlEvents.NAME);
        end
    end
    
    methods (Static)
        function sendHalt()
            stageController = StageControlEvents();
            stageController.sendEvent(struct(StageControlEvents.HALT, true));
        end
        
        function sendCloseConnection()
            stageController = StageControlEvents();
            stageController.sendEvent(struct(StageControlEvents.CLOSE_CONNECTION, true));
        end
    end
end