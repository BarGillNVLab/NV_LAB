classdef (Abstract) Scope < BaseObject
    
    properties (Constant, Hidden)
        SCOPE_NEEDED_FIELDS = {'type', 'address'};
    end

    properties
        % power supply model parameters:
        nChannels       % number of analog channels
        nDigital        % number of digital channels
        range         % string array (size: #channels * 2) - ranges span for each channel.
        
        address
        v
    end
    
    % Constructor
    methods (Access = protected)
        function obj = Scope(name, address)
            obj@BaseObject(name);
            obj.address = address;
            try
                obj.initilize;
            catch err
                obj.close;
                obj.delete;
                err2warning(err);
            end                
        end
    end
    
    methods (Static)
        function create(name, scopaStruct)
            % Get all we need from json
            missingField = FactoryHelper.usualChecks(scopaStruct, scope.SCOPE_NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError('Can''t initialize scope - needed field "%s" was not found in initialization struct!', missingField);
            end
            
            switch (scopaStruct.type)
                case 'MSO_X_3000'
                    scopeObject = scope_MSO_X_3000.create(name, scopaStruct);
                otherwise
                    EventStation.anonymousError(...
                        ['The requested scope classname ("%s") was not recognized.\n', ...
                        'Please fix the .json file and try again.'], ...
                        scopaStruct.type);
            end
            addBaseObject(scopeObject);
        end
        
    end
    
    methods
        function close(obj)
            obj.closeConnection;
            scope = getObjByName(obj.name);
            scope.delete;
        end
        
        function state = bool2OnOff(obj, state)
            switch lower(state)
                case {1, 'on'}
                    state = 'ON';
                case {0, 'off'}
                    state = 'OFF';
                otherwise
                    error('output must be 0, 1, ON, or OFF')
            end
        end
        
    end
    
    
    %% Check methods
    methods
        function checkLim(obj, value, channel)
        end
        
        function checkChannel(obj, channel)
            if channel > obj.nChannels
                obj.close;
                error('No channel %d in this scope. $d channels are Avaliable', channel, obj.nChannels)
            end
        end
        
    end
    
    %% those methods must be implemented in children classes
    
    methods (Abstract, Access = public)        
        connect(obj)
        
        closeConnection(obj)  
        
        reset(obj)
        
        sendCommand(obj, what)
        
        checkError(obj)
    end
    
    
    %% Help methods
    methods
        
    end

end