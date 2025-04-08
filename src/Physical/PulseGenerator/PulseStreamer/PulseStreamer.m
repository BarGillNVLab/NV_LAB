classdef PulseStreamer < handle
    % PulseStreamer is a wrapper class to communicate with the JSON-RPC
    % interface of the Pulse Streamer
    properties (Constant)
        class_ver = '1.0';      % current version of the Pulse Streamer MATLAB driver
    end
    
    properties (SetAccess = private, GetAccess = public)
        ipAddress               % IP address of the Pulse Streamer
        fwVersion               % version of the Pulse Streamer firmware
        triggerStart = PSTriggerStart.Immediate        % defines how sequence is triggered (PSTriggerStart enumeration)
        triggerMode = PSTriggerMode.Normal         % controls how many time uploaded sequence can be retriggered (PSTrigger enumeration)
        hasFinishedCallbackFcn     % callback function called when the stream of the Pulse Streamer has finished
        analogChannels = 0:1;    % List of valid analog channels for the connected Pulse Streamer
        digitalChannels = 0:7;   % List of valid analog channels for the connected Pulse Streamer
    end
    
    properties (Access = private)
        maxLevelDuration = 4294967295; % Maximum duration of a level (uint32). Longer durations will be split.
        maxPulseCount = 2e6;    % maximum number of pulses
        analogScale = 32767;    % Scaling factor that converts physical value to ADC value
        
        pollTimer               % poll timer to detect when the sequence has finished
        sequenceDuration        % length of the sequence in ns including multiple runs
        nRuns                   % store internally the number of runs
        finalOutput             % store internally final output value
        isDummy = false;        % True when object was initialized as "dummy" by providing empty IP address string.
    end
    
    methods
        % constructor
        function obj = PulseStreamer(ipAddress)
            % ipAdress: hostname or ip address of the pulse streamer (e.g.
            % 'pulsestreamer' or '192.168.178.20')
            % You can specify empty string as IP address for offline sequence design.
            
            obj.ipAddress = ipAddress;
            
            if isempty(obj.ipAddress)
                warning('off','backtrace');
                warning('No IP address provided. PulseStreamer object is initialized as dummy. Use only for offline sequence design.')
                warning('off','backtrace');
                obj.fwVersion = 'dummy';
                obj.isDummy = true;
                return;
            end
            
            try
                fwver = obj.getFirmwareVersion();
            catch e
                showChars = min(150, length(e.message));
                error(['Could not connect to Pulse Streamer at "' ipAddress '". ' e.message(1:showChars) ' (...)'])
            end
            
            if isempty(fwver)
                error('This class requires Pulse Streamer firmware version >=1.0');
            end
            
            obj.fwVersion = fwver;
            
        end
        
        %%%%%%%%%%%%%%%%%%%% wrapped JSON-RPC methods %%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function reset(obj)
           % resets the Pulse Streamer device
           obj.stopTimer();
           obj.RPCall('reset');
        end
        
        function constant(obj, outputState)
            % set a constant output at the Pulse Streamer outputs
            if ~isa(outputState, 'OutputState')
                error('Invalid parameter: outputState must be an OutputState object!');
            end
            obj.stopTimer();
            outstate_json = obj.output_state_to_json(outputState);
            obj.RPCall('constant', outstate_json);
        end
    
        function timing = stream(obj, sequence, nRuns, finalState)
            % STREAM sends the sequence to the Pulse Streamer
            %  sequence:       PSSequence object.
            %  nRuns:          Number of times to repeat the sequence.
            %                  Infinite repetitions if nRuns<0.
            %  finalState:     OutputState object which defines the output
            %                  after the sequence has ended
            
            if ~isa(sequence, 'PSSequence')
                error('Invalid parameter: sequence must be a PSSequence object!');
            end
            if ~exist('nRuns', 'var')
                nRuns = -1;
            end
            if ~exist('finalState', 'var')
                finalState = OutputState.Zero();
            elseif ~isa(finalState,'OutputState')
                error('Invalid parameter: finalState must be an OutputState object!');
            end
            
            if sequence.isEmpty()
                % Do nothing when sequence is empty
                fprintf('Sequence is empty. Nothing to stream\n');
                return;
            end
            
            tStart = tic;
            obj.stopTimer();
            
            % rescale sequence data as the first processing step
            seq = obj.sequence_rescale_data(sequence);
%             seq = obj.sequence_cleanup(seq);
            seq = obj.sequence_split_long(seq);
            
            nPulses = numel(seq.ticks);
            if nPulses > obj.maxPulseCount
                error('Maximum number of pulses within one run exceeded!  pulses: %0.0f max: %0.0f', nPulses, obj.maxPulseCount);
            end
            
            timing.ready = toc(tStart);
            
            encodedSeq = obj.sequence_encode(seq);
            
            timing.encoded = toc(tStart);
            
            obj.streamEncodedSequence(encodedSeq, nRuns, finalState);
            
            timing.transmitted = toc(tStart); 
 
        end
        
        function streamEncodedSequence(obj, encodedSeqStr, nRuns, finalState)
            % This is low-level function that sends encoded sequence data
            
            obj.nRuns = nRuns;
            finstate_json = obj.output_state_to_json(finalState);
            obj.RPCall('stream', ['"', encodedSeqStr, '"'], nRuns, finstate_json); 
            
            if (nRuns > 0) && isa(obj.hasFinishedCallbackFcn, 'function_handle')
                % the callback timer is only started if a callback function
                % is set by the user and as long the sequence has no infinite runs
                obj.callbackTimerStart();
            end
        end
        
        function TF = rearm(obj)
            % Rearm Pulse Streamer
            ret = obj.RPCall('rearm');
            TF = jsonToBool(ret);
        end
        
        function startNow(obj)
            % starts the sequence if the sequence was uploaded with the
            % PSStart.Software option
            obj.RPCall('startNow');
        end
        
        function forceFinal(obj)
            % Interrupts the sequence and sets the final state. This
            % method does not modify the output state if the sequence has 
            % already finished and the Pulse Streamer was in the final 
            % state. This method also releases the hardware resources of  
            % the Pulse Streamer and, therefore, allows for faster upload
            % sequence during next call of "stream" method.
            
            obj.RPCall('forceFinal');
        end  
        
        function setTrigger(obj, triggerStart, triggerMode)
            %SETTRIGGER: Defines how the uploaded sequence is triggered.
            
            if ~isa(triggerStart,'PSTriggerStart')
                error('Invalid type of triggerStart. Use PSTriggerEdge enumeration.');
            end
            if exist('triggerMode', 'var')
                if ~isa(triggerMode, 'PSTriggerMode')
                    error('Invalid type of triggerMode. Use PSTriggerMode enumeration.');
                end
            else
                triggerMode = PSTriggerMode.Normal;
            end
            obj.RPCall('setTrigger', triggerStart, triggerMode);
            obj.triggerStart = triggerStart;
            obj.triggerMode = triggerMode;
        end
        
        function TF = isStreaming(obj)
            % check whether the Pulse Streamer is currently outputting a sequence
            ret = obj.RPCall('isStreaming');
            TF = jsonToBool(ret);
        end
        
        function TF = hasSequence(obj)
            % check whether a sequence was uploaded to 
            ret = obj.RPCall('hasSequence');
            TF = jsonToBool(ret);
        end
        
        function TF = hasFinished(obj)
            % check whether all sequences are finished
            ret = obj.RPCall('hasFinished');
            TF = jsonToBool(ret);
        end
        
        function selectClock(obj, clockSource)
            % Select Clock source type
            if ~isa(clockSource,'PSClockSource')
                error('Invalid type of clockSource. Use PSClockSource enumeration.');
            end
            obj.RPCall('selectClock', clockSource);
        end
        
        function serial_str = getSerial(obj, serialID)
            % Request serial number
            if ~exist('serialID', 'var')
                serialID = PSSerial.Serial;
            end
            if ~isa(serialID, 'PSSerial')
                error('Invalid type of serialID. Use PSSerial enumeration.');
            end
            ret = obj.RPCall('getSerial', serialID);
            response = jsonToStruct(ret);
            serial_str = response.result;
        end
        
        function fw_ver = getFirmwareVersion(obj)
            % Request firmware version
            ret = obj.RPCall('getFirmwareVersion');
            response = jsonToStruct(ret);
            fw_ver = response.result;
        end
        
        function status(obj)
            % displays the current status of the Pulse Streamer
            fprintf('hasSequence:\t %s\n', boolToYesNo(obj.hasSequence));
            fprintf('isStreaming:\t %s\n', boolToYesNo(obj.isStreaming));
            fprintf('hasFinished:\t %s\n', boolToYesNo(obj.hasFinished));
        end
        
        %%%%%%%% callback function and event handling %%%%%%%%%%%%%%%%%%%%%
        function setCallbackFinished(obj, func)
            % sets the callback function to detect when the Pulse Streamer
            % is finished with all sequences
            % this must be set before the the sequence is started.
            % e.g. fun: @myCallbackFunction
            %
            % the signature of the callback function must be
            % callbackFunction(pulseStreamer)
            
            % check whether the parameter is valid
            if ~isa(func,'function_handle')
                error('Callback function must be a function handle');
            end
            
            if exist(func2str(func)) == 0
                error(['Callback function not found. ' func2str(func)]);
            end
            obj.hasFinishedCallbackFcn = func;
        end
    end
    
    
    methods
       % Overriden methods. 
       function delete(obj)
           % class destructor
           % Stop and delete timer on object deletion.
           % This method exists only in handle classes, 
           % i.e. ones subclassed from "handle" superclass
           
           % delete(h) deletes a handle object, but does not clear the
           % handle variable from the workspace. The handle variable is
           % not valid once the handle object has been deleted.
           %
           % https://uk.mathworks.com/help/matlab/matlab_oop/handle-class-destructors.html
           %
           % To be a valid class destructor, the delete method:
           %   *  Must define one, scalar input argument, which is an object of the class.
           %   *  Must not define output arguments
           %   *  Cannot be Sealed, Static, or Abstract
           % In addition, the delete method should not:
           %   *  Throw errors, even if the object is invalid.
           %   *  Create new handles to the object being destroyed
           %   *  Call methods or access properties of subclasses
           
           tmr = obj.pollTimer;
           if isa(tmr, 'timer')
               if tmr.isvalid
                   stop(tmr);
               end
               delete(tmr);
           end
           obj.pollTimer = [];
          
           % Defining a delete method in a handle subclass
           % does not override the handle class delete method.
           % No need to call delete@handle(obj) ourselves!!!
       end
    end
    

    methods (Access = private)
%     methods (Access = protected) % Uncomment this and comment previous for debug only

        function seq_out = sequence_cleanup(obj, seq_in)
            %SEQUENCE_CLEANUP removes pulses with zero duration and joins
            %pulses of the same state
            
            % remove zero duration levels
            nz_idxs = ~(uint32(seq_in.ticks) == 0);
            nz_idxs(end) = true; % last one always included
            ticks = seq_in.ticks(nz_idxs);
            digi = seq_in.digi(nz_idxs);
            ao0 = seq_in.ao0(nz_idxs);
            ao1 = seq_in.ao1(nz_idxs);
            
            % find equal pairs, first element must always exist
            neq_digi = [true; logical(diff(digi))];
            neq_ao0 =  [true; logical(diff(ao0))];
            neq_ao1 =  [true; logical(diff(ao1))];
            neqmsk = neq_digi | neq_ao0 | neq_ao1; % repeated state => false
            
            N = sum(double(neqmsk)); % number of states without repeated ones
            
            seq_out.ticks = zeros(1,N); % preallocate
            
            % just copy nonrepeated states
            seq_out.digi = digi(neqmsk); 
            seq_out.ao0 = ao0(neqmsk);
            seq_out.ao1 = ao1(neqmsk);
            
            jj=0;
            for ii=1:numel(ticks)
                if neqmsk(ii)
                    jj = jj + 1;
                    seq_out.ticks(jj) = ticks(ii);
                else
                    seq_out.ticks(jj) = seq_out.ticks(jj) + ticks(ii);
                end
            end
        end
        
        function seq_out = sequence_split_long(obj, seq_in)
            % split long state durations that exceed maximum duration
            % 

            if all(seq_in.ticks < obj.maxLevelDuration)
                seq_out.ticks = seq_in.ticks;
                seq_out.digi = seq_in.digi;
                seq_out.ao0 = seq_in.ao0;
                seq_out.ao1 = seq_in.ao1;
            else
                t_max = obj.maxLevelDuration;
                N = ceil((seq_in.ticks+1) / t_max); % +1 is needed to handle cases with ticks=0.
                M = sum(N);
                ticks = zeros(1,M);
                idxs = zeros(1,M);
                jj = 1;
                t = seq_in.ticks;
                for ii = 1:numel(N)
                    newN=N(ii); % original pulse is represented by this number of pulses
                    idx = jj + (1:newN)-1; % indexes of array elements corresponding to current pulse parts
                    ticks(idx) = t_max; % replace with t_max
                    ticks(idx(end)) = t(ii) - t_max*(newN-1); % last level is the difference
                    idxs(idx) = ii; % build list of indices of elements to duplicate
                    jj = jj + newN;
                end
                % compose new states from original arrays
                seq_out.ticks = ticks;
                seq_out.digi = seq_in.digi(idxs);
                seq_out.ao0 = seq_in.ao0(idxs);
                seq_out.ao1 = seq_in.ao1(idxs);
            end
        end
        
        function seq_out = sequence_rescale_data(obj, seq_in)
           % Convert sequence data to hardware values.
           % Input shall be a class or structure with fields accessible
           % with dot notation. 
           % Required fields: ['ticks', 'digi', 'ao0', 'ao1'] 
           % This function produces structure with same field names.
           seq_out.ticks = seq_in.ticks;
           seq_out.digi = seq_in.digi;
           seq_out.ao0 = round(seq_in.ao0 .* obj.analogScale);
           seq_out.ao1 = round(seq_in.ao1 .* obj.analogScale);
        end
        
        function seq_encoded = sequence_encode(obj, seq_in)
            %SEQUENCE_ENCODE: Convert the sequence into the binary format with base64 encoding.
            % seq can either be a PSSequence or a structure of arrays with
            % fields as:
            %       seq_in = struct('ticks',[], 'digi',[], 'ao0',[], 'ao1',[]);
            
            try
                error(javachk('jvm'));
                
                % Use Java function to encode base64.
                % this is the fastest algorithm
                seq_encoded = encode64_jvm(uint32(seq_in.ticks), uint8(seq_in.digi), int16(seq_in.ao0), int16(seq_in.ao1));
            catch ME
                % if java based base64 encoding fails then fallback to pure
                % MATLAB implementation
                if strcmp(ME.identifier, 'MATLAB:javachk:thisFeatureNotAvailable')
                    warning('JVM is not available. Using pure MATLAB base64 encoder. Performance may be reduced.')
                    seq_encoded = encode64_matlab(uint32(seq_in.ticks), uint8(seq_in.digi), int16(seq_in.ao0), int16(seq_in.ao1));
                else
                    rethrow(ME)
                end
            end
        end
        
        function out_str = output_state_to_json(obj, outputState)
           % Encodes OutputState object into JSON representation
           
           % Rescale to hardware values
           state = obj.sequence_rescale_data(outputState);
           % convert to JSON string
           out_str = sprintf('[0,%d,%d,%d]', state.digi, state.ao0, state.ao1);
        end
        
        function callbackTimerStart(obj)
            % Start timer that polls hasFinished state and executes
            % callback function is such was defined
            
            % Before starting make sure previous timer don't exist
            obj.stopTimer();
            
            obj.pollTimer = timer;
            obj.pollTimer.TimerFcn = @obj.callbackTimerPollFcn;
            obj.pollTimer.ErrorFcn = @(mt,evt) delete(mt); % if error occurs in timer it will delete itself
            obj.pollTimer.Period = 0.1; %s
            obj.pollTimer.ExecutionMode = 'fixedSpacing';
            
            start(obj.pollTimer);
        end
        
        function callbackTimerPollFcn(obj, ~, ~)
            % Internal callback to check the status of the Pulse Streamer
            % and handling the external callback function.
            % The Pulse Streamer is polled only if the external callback function
            % was set by the user.

            try
                if obj.hasFinished()
                    obj.stopTimer();
                    obj.hasFinishedCallbackFcn(obj);
                end
            catch ME
                % cleanup the timer on error
                obj.stopTimer();
                rethrow(ME);
            end
        end
        
        function stopTimer(obj)
            %Stops and deletes timer object
            
            if isa(obj.pollTimer, 'timer')
                if obj.pollTimer.isvalid
                    stop(obj.pollTimer);
                end
                delete(obj.pollTimer)
            end
            obj.pollTimer = [];
        end
        
        function response = RPCall(obj, method, varargin)
            % Make JSON-RPC call and wait for response
            % method:   name of the RPC call method
            % varagin:  arbitary number of arguments (string or numeric)
            request = obj.makeJsonRpcRequestString(method, varargin{:});

            response = obj.httpRequest(request);
            
            if contains(response, 'error', 'IgnoreCase',true)
                resp = jsonToStruct(response);
                e = resp.error;
                error('\tERROR code: %d, MESSAGE: %s, DATA: %s', e.code, e.message, e.data);
            end
        end  

        function ret = httpRequest(obj, req)
            % Send HTTP request and return response
            % http handling
            
            if obj.isDummy
                warning('off','backtrace');
                warning('PulseStreamer object initialized as "dummy". Communication with hardware is disabled!');
                warning('on','backtrace');
                ret = '{"jsonrpc":"2.0","id":1,"result":"0"}';
                return;
            end
            
            url = sprintf('http://%s:8050/json-rpc', obj.ipAddress);
            % set the timeout to 3s
            ret = urlread2(url, 'POST', req, []);
        end

        function jsonString = makeJsonRpcRequestString(obj, method, varargin)
            % create a JSON-RPC string
            % method:   name of the RPC call method
            % varagin:  arbitary number of arguments (string or numeric)
            if nargin == 2
                s = sprintf('{"jsonrpc":"2.0","id":"1","method":"%s"}', method); % sprintf() is much faster than strcat()
            else
                paramstr = '';
                for i = 1:length(varargin)
                    p = varargin{i};
                    if isnumeric(p)
                        paramstr = sprintf('%s%d,',paramstr,p);
                    elseif ischar(p)
                        paramstr = sprintf('%s%s,',paramstr,p);
                    else
                        error('Unsupported parameter type.')
                    end
                end
                s = sprintf('{"jsonrpc":"2.0","id":"1","method":"%s","params":[%s]}',method, paramstr(1:end-1));
            end
            jsonString = s;
        end
    end
end


%%%%%%%%%%%%%%%%%%%%%%% string handling %%%%%%%%%%%%%%%%%%%%%%%%%%
function str = boolToYesNo(bool)
    % converts a boolean value into a 'Yes' or 'No' string
    if bool == 0
        str = 'no';
    elseif bool == 1
        str = 'yes';
    else
        error('not a boolean value');
    end
end

function stru = jsonToStruct(string)
    % converts the returned string from an JSON-RPC call 
    % to a struct
    stru = parse_json(string);
    stru = stru{1};
end

function bool = jsonToBool(string)
    % converts the returned string from an JSON-RPC call to
    % a boolean value
    stru = jsonToStruct(string);
    if stru.result == 0
        bool = false;
    elseif stru.result == 1
        bool = true;
    else
        error(['return value is not a boolean (0 or 1) but ' num2str(stru.result)]);
    end
end

function value = jsonToUInt32(string)
    % extracts the returned value from an JSON-RPC call and
    % converts it into a uint32
    stru = jsonToStruct(string);
    value = uint32(stru.result);
end

function enc = encode64_jvm(tick,digi,ao0,ao1)
    % Encode sequence data to base64 string using Java function

    N = numel(tick);
    % Cast each value into individual bytes. Reshape the result so the columns
    % represent the pulse and rows represent individual bytes for these
    % values
    tick_bytes = reshape(typecast(swapbytes(uint32(tick(:))), 'int8'), 4,N);
    digi_bytes = reshape(typecast(swapbytes(uint8(digi(:))), 'int8'), 1,N);
    ao0_bytes =  reshape(typecast(swapbytes(int16(ao0(:))), 'int8'), 2,N);
    ao1_bytes =  reshape(typecast(swapbytes(int16(ao1(:))), 'int8'), 2,N);

    % combine byte arrays along byte dimension to get [9,N] array
    bytes = [tick_bytes; digi_bytes; ao0_bytes; ao1_bytes]; 
    % reshape byte arrays such that the corect byte sequence (along
    % columns) so the bytes are 
    % [b11,b21,b31,...,b91, b12,b22,b32,...,b92, ..., b1N,...,b9N]
    bytes = reshape(bytes, 1, 9*N); 
    % encode into base64 string
    enc = transpose(char(org.apache.commons.codec.binary.Base64.encodeBase64(bytes, 0)));
end

function enc = encode64_matlab(tick,digi,ao0,ao1)
    % Encode sequence data to base64 string using MATLAB function
    % Used as fallback when JVM is not available.

    N = numel(tick);
    % Cast each value into individual bytes. Reshape the result so the columns
    % represent the pulse and rows represent individual bytes for these
    % values
    tick_bytes = reshape(typecast(swapbytes(uint32(tick(:))), 'uint8'), 4,N);
    digi_bytes = reshape(typecast(swapbytes(uint8(digi(:))), 'uint8'), 1,N);
    ao0_bytes =  reshape(typecast(swapbytes(int16(ao0(:))), 'uint8'), 2,N);
    ao1_bytes =  reshape(typecast(swapbytes(int16(ao1(:))), 'uint8'), 2,N);
    
    % combine byte arrays along byte dimension to get [9,N] array
    bytes = [tick_bytes; digi_bytes; ao0_bytes; ao1_bytes];
    
    % reshape byte arrays such that the corect byte sequence (along
    % columns) so the bytes are 
    % [b11,b21,b31,...,b91, b12,b22,b32,...,b92, ..., b1N,...,b9N]
    bytes = reshape(bytes, 1, 9*N);
    
    % encode into base64 string
    enc = matlab.net.base64encode(bytes);
end

