classdef MyRioDaq < Daq
    %MyRioDaq Class for interfacing with NI myRIO 1900 using MATLAB DAQ interface.
    %   Inherits from the base Daq class and implements myRIO-specific interactions.
    %   Requires the "MATLAB Support Package for NI myRIO".

    properties (Access = protected)
        % Handle to the MATLAB DataAcquisition object for the myRIO
        daqSession = []; 
        % Store registered output channels to add them to the session just before writing
        registeredOutputs = {}; % Cell array to store {channelId, minV, maxV}
        % Store registered input channels to add them to the session just before reading
        registeredInputs = {}; % Cell array to store {channelId, type} e.g. {'ai0', 'Voltage'} or {'dio1', 'Digital'}
    end

    properties (Constant)
        NAME = 'MyRioDaq'; % Unique name for this DAQ type
        UNITS = ' V';      % Default units for display
        EVENT_MYRIO_RESET = 'MyRio_Daq_reset'; % Event name for reset
        
        % Define known voltage ranges based on datasheet (can be overridden by registration)
        MXP_AI_MIN = 0;
        MXP_AI_MAX = 5;
        MXP_AO_MIN = 0;
        MXP_AO_MAX = 5;
        MSP_AI_MIN = -10;
        MSP_AI_MAX = 10;
        MSP_AO_MIN = -10;
        MSP_AO_MAX = 10;
        AUDIO_AI_MIN = -2.5;
        AUDIO_AI_MAX = 2.5;
        AUDIO_AO_MIN = -2.5; % Note: AC coupled, range is nominal
        AUDIO_AO_MAX = 2.5;
    end

    %% Initialization %%
    methods % Public constructor
        function obj = MyRioDaq(deviceName, dummyMode)
            %MyRioDaq Constructor
            %   deviceName: String identifying the myRIO device (e.g., 'myRIO-1900-SERIAL' or alias).
            %   dummyMode: Logical to enable dummy mode.
            
            % Call the Daq superclass constructor
            obj@Daq(deviceName, MyRioDaq.NAME, dummyMode);
            
            % Initialize myRIO specific things
            obj.initMyRio(); 
        end
    end
    
    methods (Access = protected)
        function initMyRio(obj)
            % initMyRio Initializes the myRIO device connection using daq interface.
            
            % Clear any previously stored channels for this instance
            obj.registeredOutputs = {};
            obj.registeredInputs = {};
            
            if ~obj.dummyMode
                try
                    % Release any previous session gracefully
                    if ~isempty(obj.daqSession) && isvalid(obj.daqSession)
                        release(obj.daqSession); % Use release for DAQ sessions
                        delete(obj.daqSession);
                        obj.daqSession = [];
                        fprintf('MyRioDaq: Released previous session for "%s".\n', obj.deviceName);
                    end
                    
                    % Create a new DataAcquisition session for NI devices.
                    % If deviceName is specific and needed, use daq("ni", obj.deviceName)
                    % For simplicity, assume deviceName matches what daq("ni") finds or is default.
                    % Use daqlist("ni") to see available devices and IDs.
                    fprintf('MyRioDaq: Attempting to create DAQ session for NI device: "%s"...\n', obj.deviceName);
                    obj.daqSession = daq("ni", obj.deviceName); % Connect using the name from JSON/constructor
                    
                    if isempty(obj.daqSession)
                       error('MyRioDaq:FailedToConnect', 'Could not create DAQ session. Check device connection and name.');
                    end
                    
                    % Set a default rate, can be overridden later if needed for continuous ops
                    obj.daqSession.Rate = 1000; % Default scans/sec, adjust as necessary
                    
                    fprintf('MyRioDaq: Successfully created DAQ session for device "%s".\n', obj.deviceName);
                    
                catch ME
                    obj.sendError(sprintf('MyRioDaq Error: Failed to initialize session for device "%s". Error: %s', obj.deviceName, ME.message));
                    % Fallback to dummy mode if connection fails
                    warning('MyRioDaq: Connection failed, falling back to dummy mode for device "%s".', obj.deviceName);
                    obj.dummyMode = true; 
                    obj.daqSession = []; % Ensure session handle is empty
                end
            else
                fprintf('MyRioDaq: Initialized in dummy mode for device "%s".\n', obj.deviceName);
                obj.daqSession = []; % Ensure session handle is empty in dummy mode
            end
        end
    end

    methods (Static)
        % Static create method (aligns with framework if needed, but Daq.create handles the call)
        function create(myRioStruct)
             missingField = FactoryHelper.usualChecks(myRioStruct, {'deviceName'});
             if ~isnan(missingField)
                 EventStation.anonymousError('MyRioDaq: Missing field: %s', missingField); return;
             end
             % Creation is typically handled by Daq.create -> feval(MyRioDaq, ...)
             % This static method is mostly a placeholder for pattern consistency.
             fprintf('MyRioDaq.create: Object creation is handled by Daq.create via feval.\n');
        end
    end

    %% Channel Management Override %%
    % Override registerChannel to store channel info locally for session setup
    methods
        function registerChannel(obj, newChannelId, newChannelName, minValue, maxValue)
            %registerChannel Registers a channel AND stores info for later session configuration.
            %   newChannelId: Hardware ID (e.g., 'ao0', 'ai1', 'dio3')
            %   newChannelName: User-friendly name (e.g., 'ControlSignal')
            %   minValue: Minimum expected/allowed value (used for validation)
            %   maxValue: Maximum expected/allowed value (used for validation)

            % Call the parent's registerChannel first to handle checks and storage in channelArray
            % Provide default min/max if not specified
            if nargin < 5
                maxValue = obj.DEFAULT_MAX_VOLTAGE; % Use Daq default
            end
            if nargin < 4
                minValue = obj.DEFAULT_MIN_VOLTAGE; % Use Daq default
            end
            registerChannel@Daq(obj, newChannelId, newChannelName, minValue, maxValue);

            % Now, store info locally based on channel type for session setup
            if contains(newChannelId, 'ao', 'IgnoreCase', true) % Analog Output
                obj.registeredOutputs{end+1, 1} = newChannelId;
                obj.registeredOutputs{end, 2} = minValue;
                obj.registeredOutputs{end, 3} = maxValue;
                fprintf('MyRioDaq: Stored AO %s for later session config.\n', newChannelId);
                
            elseif contains(newChannelId, 'ai', 'IgnoreCase', true) % Analog Input
                obj.registeredInputs{end+1, 1} = newChannelId;
                obj.registeredInputs{end, 2} = 'Voltage'; % Assuming voltage measurement type
                fprintf('MyRioDaq: Stored AI %s for later session config.\n', newChannelId);

            elseif contains(newChannelId, 'dio', 'IgnoreCase', true) % Digital I/O
                 obj.registeredInputs{end+1, 1} = newChannelId; % Store for input by default
                 obj.registeredInputs{end, 2} = 'Digital'; 
                 % Note: For output, we might add the channel just-in-time in writeDigital
                 fprintf('MyRioDaq: Stored DIO %s for later session config (as input initially).\n', newChannelId);
            else
                 % Handle other types like counters ('ctr') if needed
                 warning('MyRioDaq:registerChannel: Unknown channel type for ID "%s". Not stored for session.', newChannelId);
            end
        end
    end
    
    %% Task Handling (Manages the daqSession object) %%
    % These methods might be less relevant for simple foreground R/W using daq object
    % but are kept for consistency with the Daq base class structure.
    methods (Access = protected)
        function task = createTask(obj)
            %createTask Returns the existing daqSession or initializes if needed.
            if isempty(obj.daqSession) && ~obj.dummyMode
                obj.initMyRio(); % Attempt to re-initialize if session is gone
            end
            task = obj.daqSession; % Return the session handle
            if obj.dummyMode
                 % fprintf('MyRioDaq (dummy): Create Task (returns empty)\n');
                 task = []; % Return empty for dummy mode consistency
                 return;
            end
            fprintf('MyRioDaq: Create Task (returns session handle).\n');
        end

        function clearTask(obj, task)
            %clearTask Releases the DAQ session resources.
            if obj.dummyMode
                % fprintf('MyRioDaq (dummy): Clear Task\n');
                return;
            end
            
            % Check if the passed task is the current session object
            if ~isempty(obj.daqSession) && isvalid(obj.daqSession) && isequal(task, obj.daqSession)
                 try
                    fprintf('MyRioDaq: Releasing DAQ session for "%s".\n', obj.deviceName);
                    release(obj.daqSession); % Use release for DAQ sessions
                    delete(obj.daqSession);
                 catch ME
                    warning('MyRioDaq: Error releasing DAQ session: %s', ME.message);
                 end
                 obj.daqSession = []; % Clear the handle
            elseif ~isempty(task) && isvalid(task) && isa(task, 'daq.ni.Session') % Handle case where a different valid session was passed
                 warning('MyRioDaq:clearTask: Clearing a session handle different from the stored one.');
                 try
                    release(task);
                    delete(task);
                 catch ME
                    warning('MyRioDaq: Error releasing passed DAQ session: %s', ME.message);
                 end
            else
                 fprintf('MyRioDaq: Clear Task - No valid session to clear.\n');
            end
        end

        function startTask(obj, task)
            %startTask Starts a background acquisition/generation if configured.
            % For simple foreground read/write, this might be a no-op.
            if obj.dummyMode 
                % fprintf('MyRioDaq (dummy): Start Task\n');
                return; 
            end
            
            if ~isempty(task) && isvalid(task) && isa(task, 'daq.ni.Session')
                if task.IsRunning
                    fprintf('MyRioDaq: Task/Session is already running.\n');
                    return;
                end
                % Check if channels are added, might be needed before start for background
                if isempty(task.Channels)
                   warning('MyRioDaq:startTask: No channels added to the session. Starting might have no effect.');
                end
                 try
                    fprintf('MyRioDaq: Starting DAQ session (relevant for background ops).\n');
                    start(task, "Duration", seconds(inf)); % Example for continuous background
                    % Or startForeground(task) if that's the intended use here
                 catch ME
                     obj.sendError(sprintf('MyRioDaq Error: Failed to start session. Error: %s', ME.message));
                 end
            else
                 warning('MyRioDaq:startTask: Invalid or empty session handle provided.');
            end
        end
        
         function stopTask(obj, task)
            %stopTask Stops a background acquisition/generation.
            if obj.dummyMode
                % fprintf('MyRioDaq (dummy): Stop Task\n');
                return; 
            end
            
            if ~isempty(task) && isvalid(task) && isa(task, 'daq.ni.Session')
                if task.IsRunning
                    try
                        fprintf('MyRioDaq: Stopping DAQ session.\n');
                        stop(task);
                    catch ME
                        obj.sendError(sprintf('MyRioDaq Error: Failed to stop session. Error: %s', ME.message));
                    end
                else
                     fprintf('MyRioDaq: Stop Task - Session was not running.\n');
                end
            else
                 warning('MyRioDaq:stopTask: Invalid or empty session handle provided.');
            end
         end

        % endTask is inherited from Daq.m and calls stopTask then clearTask.
    end

    %% Read & Write Operations %%
    methods
        function writeVoltage(obj, channelOrChannelName, newVoltage)
            %writeVoltage Writes a voltage to a registered analog output channel.
            
            % --- Get Registered Channel Info ---
            try
                idx = obj.getIndexFromChannelOrName(channelOrChannelName);
                physicalChannelID = obj.getChannelFromIndex(idx); % Hardware ID, e.g., 'ao0'
                minVal = obj.getChannelMinimumFromIndex(idx);     % Registered min voltage
                maxVal = obj.getChannelMaximumFromIndex(idx);     % Registered max voltage
            catch ME
                obj.sendError(sprintf('MyRioDaq: Cannot write voltage. Channel "%s" not found or invalid. Error: %s', ...
                                channelOrChannelName, ME.message));
                return;
            end

            % --- Dummy Mode ---
            if obj.dummyMode
                if newVoltage < minVal || newVoltage > maxVal
                   fprintf('MyRioDaq (dummy): Warning - Voltage %.3f is outside registered range [%.2f, %.2f] for %s\n', ...
                           newVoltage, minVal, maxVal, channelOrChannelName);
                end
                obj.dummyChannel(idx) = newVoltage; % Store dummy value
                return;
            end
            
            % --- Ensure DAQ Session ---
             if isempty(obj.daqSession) || ~isvalid(obj.daqSession)
                 obj.sendError(sprintf('MyRioDaq: No valid DAQ session for device %s. Cannot write voltage.', obj.deviceName));
                 obj.initMyRio(); % Try to re-initialize
                 if isempty(obj.daqSession) || ~isvalid(obj.daqSession)
                     return; % Still no session, abort
                 end
             end

            % --- Hardware Interaction ---
            if newVoltage < minVal || newVoltage > maxVal
                errMsg = sprintf('MyRioDaq: Voltage %.3f is outside registered range [%.2f, %.2f] for %s (ID: %s). Aborting write.', ...
                                newVoltage, minVal, maxVal, channelOrChannelName, physicalChannelID);
                obj.sendError(errMsg);
                return; 
            end

            try
                % --- Add Channel to Session (if not already added) ---
                % Check if this specific channel ID is already in the session
                chanExists = false;
                for i = 1:length(obj.daqSession.Channels)
                    % Channel IDs in session might include device name, need robust check
                    if contains(obj.daqSession.Channels(i).ID, physicalChannelID) && ...
                       strcmpi(obj.daqSession.Channels(i).MeasurementType, 'Voltage')
                        chanExists = true;
                        break;
                    end
                end
                
                if ~chanExists
                    fprintf('MyRioDaq: Adding output channel %s to session.\n', physicalChannelID);
                    % Use addoutput(session, channelID, measurementType)
                    % Note: Range limits might be set here if API supports it, or rely on validation above.
                    addoutput(obj.daqSession, physicalChannelID, 'Voltage'); 
                end
                % --- End Add Channel ---

                % --- Perform Write ---
                % Use write(session, data). Data should be a matrix [scans x channels].
                % For single scan, single channel:
                fprintf('MyRioDaq: Writing %.3f V to %s (ID: %s).\n', newVoltage, channelOrChannelName, physicalChannelID);
                write(obj.daqSession, newVoltage); 
                % --- End Perform Write ---
                
            catch ME
                obj.sendError(sprintf('MyRioDaq Error: Failed to write voltage to %s (ID: %s). Error: %s', ...
                                channelOrChannelName, physicalChannelID, ME.message));
                obj.checkError(ME); % Pass the exception to checkError
            end
            % --- End Hardware Interaction ---
        end 

        function voltage = readVoltage(obj, channelOrChannelName, numSampsPerChan, timeout)
            %readVoltage Reads voltage from a registered analog input channel.
            %   numSampsPerChan (optional): Default 1.
            %   timeout (optional): Default based on session Rate.
            
            voltage = 0; % Default return value
            if nargin < 3, numSampsPerChan = 1; end
            % Timeout argument might not be directly used in foreground read

            % --- Get Registered Channel Info ---
             try
                idx = obj.getIndexFromChannelOrName(channelOrChannelName);
                physicalChannelID = obj.getChannelFromIndex(idx); % Hardware ID, e.g., 'ai0'
             catch ME
                obj.sendError(sprintf('MyRioDaq: Cannot read voltage. Channel "%s" not found or invalid. Error: %s', ...
                                channelOrChannelName, ME.message));
                return;
             end

            % --- Dummy Mode ---
            if obj.dummyMode
                voltage = 0.5 + (idx/100); 
                if numSampsPerChan > 1
                    voltage = repmat(voltage, 1, numSampsPerChan);
                end
                return;
            end

            % --- Ensure DAQ Session ---
             if isempty(obj.daqSession) || ~isvalid(obj.daqSession)
                 obj.sendError(sprintf('MyRioDaq: No valid DAQ session for device %s. Cannot read voltage.', obj.deviceName));
                 obj.initMyRio(); % Try to re-initialize
                 if isempty(obj.daqSession) || ~isvalid(obj.daqSession)
                     return; % Still no session, abort
                 end
             end
             
            % --- Hardware Interaction ---
            try
                 % --- Add Channel to Session (if not already added) ---
                 chanExists = false;
                 for i = 1:length(obj.daqSession.Channels)
                     if contains(obj.daqSession.Channels(i).ID, physicalChannelID) && ...
                        strcmpi(obj.daqSession.Channels(i).MeasurementType, 'Voltage')
                         chanExists = true;
                         break;
                     end
                 end
                 
                 if ~chanExists
                     fprintf('MyRioDaq: Adding input channel %s to session.\n', physicalChannelID);
                     % Use addinput(session, channelID, measurementType)
                     addinput(obj.daqSession, physicalChannelID, 'Voltage'); 
                 end
                 % --- End Add Channel ---

                 % --- Perform Read ---
                 fprintf('MyRioDaq: Reading %d sample(s) from %s (ID: %s).\n', numSampsPerChan, channelOrChannelName, physicalChannelID);
                 if numSampsPerChan == 1
                     % read(session, "OutputFormat", "Matrix") returns [1 x numChannels]
                     % read(session) returns a timetable by default
                     data = read(obj.daqSession, "OutputFormat", "Matrix");
                     % Find the column corresponding to our channel (might be tricky if multiple channels added)
                     % Assuming only this channel was added for this read or it's the last one:
                     voltage = data(1, end); % Get the value for the last added channel
                 else
                     % read(session, numScans) returns timetable
                     % read(session, numScans, "OutputFormat", "Matrix") returns [numScans x numChannels]
                     data = read(obj.daqSession, numSampsPerChan, "OutputFormat", "Matrix");
                     % Assuming only this channel was added for this read or it's the last one:
                     voltage = data(:, end)'; % Get the column for the last added channel, transpose to row vector
                 end
                 fprintf('MyRioDaq: Read value(s): %.3f ...\n', voltage(1));
                 % --- End Perform Read ---

            catch ME
                 obj.sendError(sprintf('MyRioDaq Error: Failed to read voltage from %s (ID: %s). Error: %s', ...
                                 channelOrChannelName, physicalChannelID, ME.message));
                 obj.checkError(ME); % Pass the exception
                 voltage = NaN; % Indicate error
            end
            % --- End Hardware Interaction ---
        end
        
        function digitalValue = readDigital(obj, channelOrChannelName)
            %readDigital Reads the state of a registered digital input line.
            digitalValue = false; % Default return value

             % --- Get Registered Channel Info ---
             try
                idx = obj.getIndexFromChannelOrName(channelOrChannelName);
                physicalChannelID = obj.getChannelFromIndex(idx); % Hardware ID, e.g., 'dio3'
             catch ME
                obj.sendError(sprintf('MyRioDaq: Cannot read digital. Channel "%s" not found or invalid. Error: %s', ...
                                channelOrChannelName, ME.message));
                return;
             end

            % --- Dummy Mode ---
            if obj.dummyMode
                % digitalValue = mod(idx,2) == 0; % Alternate dummy true/false
                return;
            end

            % --- Ensure DAQ Session ---
             if isempty(obj.daqSession) || ~isvalid(obj.daqSession)
                 obj.sendError(sprintf('MyRioDaq: No valid DAQ session for device %s. Cannot read digital.', obj.deviceName));
                 obj.initMyRio(); % Try to re-initialize
                 if isempty(obj.daqSession) || ~isvalid(obj.daqSession)
                     return; % Still no session, abort
                 end
             end
             
            % --- Hardware Interaction ---
            try
                 % --- Add Channel to Session (if not already added) ---
                 chanExists = false;
                 for i = 1:length(obj.daqSession.Channels)
                     if contains(obj.daqSession.Channels(i).ID, physicalChannelID) && ...
                        strcmpi(obj.daqSession.Channels(i).MeasurementType, 'Digital')
                         chanExists = true;
                         break;
                     end
                 end
                 
                 if ~chanExists
                     fprintf('MyRioDaq: Adding digital input channel %s to session.\n', physicalChannelID);
                     % Use addinput(session, channelID, measurementType)
                     % For digital, measurement type is often 'Digital' or 'Port'
                     addinput(obj.daqSession, physicalChannelID, 'Digital'); 
                 end
                 % --- End Add Channel ---

                 % --- Perform Read ---
                 fprintf('MyRioDaq: Reading digital from %s (ID: %s).\n', channelOrChannelName, physicalChannelID);
                 % read(session) returns timetable; read(..., "Matrix") returns numeric
                 data = read(obj.daqSession, "OutputFormat", "Matrix");
                 % Assuming only this channel was added or it's the last one:
                 digitalValue = logical(data(1, end)); % Convert numeric 0/1 to logical
                 fprintf('MyRioDaq: Read value: %d\n', digitalValue);
                 % --- End Perform Read ---

            catch ME
                 obj.sendError(sprintf('MyRioDaq Error: Failed to read digital from %s (ID: %s). Error: %s', ...
                                 channelOrChannelName, physicalChannelID, ME.message));
                 obj.checkError(ME); % Pass the exception
            end
            % --- End Hardware Interaction ---
        end

        function writeDigital(obj, channelOrChannelName, newLogicalValue)
            %writeDigital Writes a state to a registered digital output line.
            
             % --- Get Registered Channel Info ---
             try
                idx = obj.getIndexFromChannelOrName(channelOrChannelName);
                physicalChannelID = obj.getChannelFromIndex(idx); % Hardware ID, e.g., 'dio3'
             catch ME
                obj.sendError(sprintf('MyRioDaq: Cannot write digital. Channel "%s" not found or invalid. Error: %s', ...
                                channelOrChannelName, ME.message));
                return;
             end

            % --- Dummy Mode ---
            if obj.dummyMode
                obj.dummyChannel(idx) = newLogicalValue; % Store dummy value
                return;
            end

            % --- Ensure DAQ Session ---
             if isempty(obj.daqSession) || ~isvalid(obj.daqSession)
                 obj.sendError(sprintf('MyRioDaq: No valid DAQ session for device %s. Cannot write digital.', obj.deviceName));
                 obj.initMyRio(); % Try to re-initialize
                 if isempty(obj.daqSession) || ~isvalid(obj.daqSession)
                     return; % Still no session, abort
                 end
             end
             
            % --- Hardware Interaction ---
            try
                 % --- Add Channel to Session (if not already added) ---
                 chanExists = false;
                 for i = 1:length(obj.daqSession.Channels)
                     if contains(obj.daqSession.Channels(i).ID, physicalChannelID) && ...
                        strcmpi(obj.daqSession.Channels(i).MeasurementType, 'Digital')
                         chanExists = true;
                         break;
                     end
                 end
                 
                 if ~chanExists
                     fprintf('MyRioDaq: Adding digital output channel %s to session.\n', physicalChannelID);
                     % Use addoutput(session, channelID, measurementType)
                     addoutput(obj.daqSession, physicalChannelID, 'Digital'); 
                 end
                 % --- End Add Channel ---

                 % --- Perform Write ---
                 valueToWrite = double(logical(newLogicalValue)); % Ensure 0.0 or 1.0
                 fprintf('MyRioDaq: Writing digital %d to %s (ID: %s).\n', valueToWrite, channelOrChannelName, physicalChannelID);
                 write(obj.daqSession, valueToWrite); 
                 % --- End Perform Write ---

            catch ME
                 obj.sendError(sprintf('MyRioDaq Error: Failed to write digital to %s (ID: %s). Error: %s', ...
                                 channelOrChannelName, physicalChannelID, ME.message));
                 obj.checkError(ME); % Pass the exception
            end
            % --- End Hardware Interaction ---
        end

    end % End Read/Write methods block

    %% Error Handling and Reset %%
    methods (Access = protected)
        function checkError(obj, statusOrException)
            %checkError Handles errors from DAQ operations.
            % Can accept a status code (though less common with daq interface) or a MATLAB Exception object.
            
            if obj.dummyMode, return; end 

            errorMessage = 'Unknown MyRioDaq Error';
            if isnumeric(statusOrException) && statusOrException ~= 0
                 % Handle numeric status codes if the API uses them
                 errorMessage = sprintf('myRIO specific error code: %d.', statusOrException);
            elseif isa(statusOrException, 'MException')
                 % Handle MATLAB exceptions caught in try/catch blocks
                 errorMessage = sprintf('Exception: %s (ID: %s)', statusOrException.message, statusOrException.identifier);
                 % Log stack trace if needed: disp(getReport(statusOrException));
            elseif statusOrException == 0 || (isa(statusOrException, 'MException') && isempty(statusOrException.message))
                 % No error or empty exception, just return
                 return;
            end
            
            % Send error event via parent class method
            obj.sendError(['MyRioDaq Error: ' errorMessage]);
            
            % Optional: Attempt reset on certain errors?
            % if contains(errorMessage, 'Session invalidated', 'IgnoreCase', true)
            %     warning('MyRioDaq: Session invalidated. Attempting reset.');
            %     obj.reset();
            % end
        end

        function reset(obj)
            %reset Resets the connection by re-initializing the DAQ session.
            if obj.dummyMode
                fprintf('MyRioDaq (dummy): Device "%s" reset called.\n', obj.deviceName);
                obj.sendEvent(struct(MyRioDaq.EVENT_MYRIO_RESET, true));
                return;
            end

            fprintf('MyRioDaq: Resetting connection for device "%s" by re-initializing session.\n', obj.deviceName);
            % Re-initialization handles releasing old session and creating new one
            obj.initMyRio(); 
            
            % Send reset event only if initialization was successful (or still in dummy mode)
            if ~isempty(obj.daqSession) || obj.dummyMode
                obj.sendEvent(struct(MyRioDaq.EVENT_MYRIO_RESET, true)); 
            else
                 warning('MyRioDaq: Reset failed to establish a new session.');
            end
        end
    end % End protected methods block
    
    %% Cleanup on Deletion %%
    methods (Access = public)
        function delete(obj)
            %delete Custom destructor to ensure DAQ session is released.
            fprintf('MyRioDaq: Deleting object for device "%s".\n', obj.deviceName);
            if ~isempty(obj.daqSession) && isvalid(obj.daqSession)
                try
                    fprintf('MyRioDaq: Releasing DAQ session during object deletion.\n');
                    release(obj.daqSession);
                    delete(obj.daqSession);
                catch ME
                    warning('MyRioDaq: Error releasing DAQ session during object deletion: %s', ME.message);
                end
            end
            obj.daqSession = [];
            % No need to call delete@Daq explicitly unless Daq has its own delete method
        end
    end

end % End classdef
