classdef SerialControlled < matlab.mixin.SetGet
    %SERIALCONTROLLED Object controlled via serial (RS232) connection
    % This object behaves similarly to a serial object, but adjusted for
    % our purposes
    
    properties (Hidden)
        s                   % serial. MATLAB representation of the connection
        commDelay = 0.01    % double. (Default value) time (in seconds) between consecutive commands
    end
    
    properties (Dependent)
        status
        bytesAvailable
    end
    
    properties
        keepConnected = true; % logical. Should this connection stay open. True by default
        
        % Properties of s we want available
        port
        baudRate
        dataBits
        stopBits
        parity
        flowControl
        terminator
    end
    
    methods
        function obj = SerialControlled(port)
            obj@matlab.mixin.SetGet;
            obj.s = serial(port);
        end
        
        function open(obj)
            try 
                fopen(obj.s);
            catch error
                if strcmp(error.identifier, 'MATLAB:serial:fopen:opfailed')
                    % If the device was opened by MATLAB, we can probably
                    % close it, and open a new connection
                    fclose(instrfind('Port', obj.port));
                    fopen(obj.s);
                else
                    rethrow(error)
                end
            end
        end
        
        function close(obj)
            fclose(obj.s);
        end
        
        function delete(obj)
            if strcmp(obj.status, 'open')
                % Free the instrument for other procceses
                try
                    obj.close;
                catch
                    msg = sprintf('Could not disconnect %s upon deletion!', obj.name);
                    obj.sendWarning(msg)
                end
            end
            delete(obj.s);
        end
    end
    
    %% Wrapper methods for serial class
    methods
        function sendCommand(obj, command)
            if ~ischar(command)
                EventStation.anonymousError('Command should be a string! Can''t send command to device.')
            end
            
            if ~obj.keepConnected; obj.open; end
            fprintf(obj.s, command);
            pause(obj.commDelay);
            if ~obj.keepConnected; obj.close; end
        end
        
        function string = read(obj, format)
            if ~obj.keepConnected; obj.open; end
            if exist('format', 'var')
                string = fscanf(obj.s, format);
            else % Realy, you should readAll(). But just in case you only want one line...
                string = fscanf(obj.s);
            end
            pause(obj.commDelay);
            if ~obj.keepConnected; obj.close; end
        end
        
        function string = readAll(obj)
            if ~obj.keepConnected; obj.open; end
            string = [];        % init
            while obj.s.BytesAvailable > 1
                % Might have one char, without terminator. Ideally, this should have been 0.
                % In the onefive Katana, it is 1.
                temp = fscanf(obj.s);
                string = [string temp]; %#ok<AGROW>
                pause(obj.commDelay);
            end
            if ~obj.keepConnected; obj.close; end
        end
        
        % One command to rule them all
        function string = query(obj, command, regex)
            % Sends command and empties output before next command --
            % should be used even if output is irrelevant
            % We can filter out only wanted information, using regular
            % expressions (RegEx, for short), the output will return the
            % tokens specified in the regex.
            obj.sendCommand(command);
            string = obj.readAll;
            if exist('regex', 'var') && ~isempty(string)
                string = regexp(string, regex, 'tokens', 'once');    % returns cell of strings
                if ~isempty(string) %cell2mat can't handle a 0x0 cell array
                    string = cell2mat(string);
                else
                    string = '';
                end
            end
        end
    end
    
    methods % Setters & getters
        % Setters
        function set(obj, varargin)
            % Validity of values is not checked here, It should be
            % done by programmer, or obj.s will alert about it.
            set(obj.s, varargin{:});
        end
        
        function obj = subsasgn(obj, S, value)
            switch S.type
                case '.'
                    len = length(S.subs);
                    assert(len == length(value));
                    A = [S.subs; value];
                    A = reshape(A, [1, 2*len]);
                    obj = set(obj.s, A{:});
                case '()'
                    obj.s(S.subs) = value;
                case '{}'
                    obj.s{S.subs} = value;
            end
        end
        
        function value = get(obj, varargin)
            if isprop(obj, varargin{:})
                value = obj.(varargin{:});
            else
                value = get(obj.s, varargin{:});
            end
        end
        
        function value = subsref(obj, S)
            args = {S.subs};
            if length(args) > 1 % this is a call to a function
                feval(args{1}, obj, args{2:end});
                return
            elseif ismethod(obj, args{:})
                fun = args{:};
                feval(fun, obj)
                return
            end
            
            switch S.type
                case '.'
                    if ~isprop(obj, S.subs)
                        error('No such property')
                    end
                    value = obj.get(S.subs);
                case '()'
                    value = obj.s(S.subs);
                case '{}'
                    value = obj.s{S.subs};
            end
        end
        
        function set.keepConnected(obj, value)
            assert(islogical(value), 'keepConnected must be logical (true/false)!')
                obj.keepConnected = value;
        end
        
        % Getters
        function status = get.status(obj)
            status = obj.s.Status;
        end
        
        function bytes = get.bytesAvailable(obj)
            bytes = obj.s.BytesAvailable;
        end
    end
    
end

