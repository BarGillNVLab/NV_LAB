classdef (Sealed) PulseGeneratorDummyClass < PulseGenerator
    %PULSEGENERATORDUMMYCLASS Dummy pulse generator.
    % Note: code assumes channel addresses are implemented as int.
    
    properties (Constant, Hidden)
        MAX_REPEATS = Inf;       	% int. Maximum value for obj.repeats
        MAX_PULSES = Inf;           % int. Maximum number of pulses in acceptable sequences
        MAX_DURATION = Inf;         % double. Maximum duration of pulse.
        
        AVAILABLE_ADDRESSES = 0:7;	% List of all available physical addresses.
                                    % Should be either vector of doubles or cell of char arrays
    end
    
    properties (Access = public)
        values
    end
    
    methods (Static, Access = public) % Get instance constructor
        function obj = GetInstance(~)       % (~ is a json struct)
            % Returns a singelton instance.
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = PulseGeneratorDummyClass();
                init(localObj);
            end
            obj = localObj;
            addBaseObject(obj);
        end
    end
    
    methods (Access = private)
        function obj= PulseGeneratorDummyClass()
            % Private default constructor.
            obj@PulseGenerator;
        end
        
        function init(obj)
            obj.values = false(size(obj.AVAILABLE_ADDRESSES));
            obj.initSequence;
        end
    end

    methods (Access = protected)

        function validateSequence(obj)
        % Needs to run before uploading it to PG hardware
        end
    end


    methods
        
        function on(obj, channel)
            % Get two lists of channel addresses -- those of registered
            % ones and those of requested ones -- find the appropriate
            % indices, and turn relevant channels on.
            address = obj.channelName2Address(channel);
            mAddresses = obj.channelAddresses;
            for i = 1:length(address)
                ind = (mAddresses == address(i));
                if isempty(ind)
                    format = 'Channel ''%s'' could not be found! Ignoring.';
                    if iscell(channel)
                        warnMsg = sprintf(format, channel{i});
                    else
                        warnMsg = sprintf(format, channel);
                    end
                    obj.sendWarning(warnMsg);
                    continue
                end
                obj.values(ind) = true;
            end
        end
        
        function off(obj, channel)
            if isempty(channel)
                obj.values(:) = false;
                return
            end
            
            address = obj.channelName2Address(channel);
            mAddresses = obj.channelAddresses;
            for i = 1:length(address)
                ind = (mAddresses == address(i));
                if isempty(ind)
                    format = 'Channel ''%s'' could not be found! Ignoring.';
                    if iscell(channel)
                        warnMsg = sprintf(format, channel{i});
                    else
                        warnMsg = sprintf(format, channel);
                    end
                    obj.sendWarning(warnMsg);
                    continue
                end
                obj.values(ind) = true;
            end
            
        end
        
        function run(obj) %#ok<MANU>
        % Upload sequence to hardware (if needed) and actually start it
        end
            
        function sendToHardware(obj) %#ok<MANU>
        % After all validation is done - upload the sequence to PG hardware
        end

    end
    
    methods (Static)
        function PulseGeneratorDummyClass.GetInstance(struct)
            
        end
    end
end