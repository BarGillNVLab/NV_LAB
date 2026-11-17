classdef SwitchPgControlled < EventSender & EventListener
    %SWITCHPGCONTROLLED Switch, controlled by a pulse generator (PG)
    %   A PG is either a pulse blaster or a pulse streamer, and they both
    %   have the same interface.
    
    % Maybe hould be subclass of class "Switch"
    
    properties
        isEnabled   % logical
        
        channel     % string
    end

    properties (Access = private)
        syncingFromPg = false   % true while copying the PG's state: update, don't command the hardware
    end
    
    methods (Access = private)
        function obj = SwitchPgControlled(name, pgChannel)
            % name - the nickname of the object
            % pgChannel - 'Channel. PG will work with *this*.'
            PG = getObjByName(PulseGenerator.NAME);
                if isempty(PG); throwBaseObjException(PulseGenerator.NAME); end
            removeObjIfExists(name); % If we try to create a switch and it already exists, replace it
            obj@EventSender(name);
            obj@EventListener(PG.NAME);
            
            addBaseObject(obj);  % so it can be reached by BaseObject.getByName()
            
            PG.registerChannel(pgChannel);
            obj.channel = pgChannel.name;
            obj.isEnabled = false;
        end
    end
       
    methods
        function set.isEnabled(obj, newValue)
            % newValue - logical (i.e. true \ false \ 1 \ 0)
            if ValidationHelper.isTrueOrFalse(newValue)
                newValue = logical(newValue);
                obj.isEnabled = newValue;
                if ~obj.syncingFromPg %#ok<MCSUP>
                    PG = getObjByName(PulseGenerator.NAME);
                    if newValue
                        PG.on(obj.channel); %#ok<MCSUP>
                    else
                        PG.off(obj.channel); %#ok<MCSUP>
                    end
                end
                obj.sendEvent(struct('isEnabled', newValue));
                % ^ let everyone know about the success! :)
            else
                EventStation.anonymousError('Can''t set "isEnabled" to anything other than (true \ false \ 1 \ 0). Aborting');
            end
        end
    end
    
    methods (Static)
        function switchPhysicalPart = create(partName, struct)
            % Maybe we need a global delays of the signal, due to
            % finite speed of signal
            if isnan(FactoryHelper.usualChecks(struct, LaserSwitchPhysicalFactory.OPTIONAL_FIELDS_DELAY))
                % usualChecks() returning nan means everything's ok
                switchChannel = Channel.Digital(struct.switchChannelName, struct.switchChannel, ...
                    struct.onDelay, struct.offDelay);
            else
                % No delay requested
                switchChannel = Channel.Digital(struct.switchChannelName, struct.switchChannel);
            end
            switchPhysicalPart = SwitchPgControlled(partName, switchChannel);
        end
    end
    
    methods (Access = private)
        function endSync(obj)
            obj.syncingFromPg = false;
        end
    end

    %% Overridden from EventListener
    methods
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            if event.isError
                return
            end
            % The PG changed its outputs on its own (e.g. streamed an
            % experiment sequence). Follow it, without sending anything back:
            % commanding the PG here could cut a running sequence short.
            PG = event.creator;
            newEnabled = logical(PG.isOn(obj.channel));
            if newEnabled ~= obj.isEnabled
                obj.syncingFromPg = true;
                c = onCleanup(@() obj.endSync());
                obj.isEnabled = newEnabled;     % the setter sends the event
            end
        end
    end
    
end

