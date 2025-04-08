classdef AomDoubleNiDaqControlled < LaserPartAbstract
    %AOMDOUBLENIDAQCONTROLLED handle to layout with two AOMs
    
    properties
        canSetEnabled = false;
        canSetValue = true;     % By default, we set the value of the current active channel
    end
    
    properties (Dependent)
        activeChannel
        values
    end
    
    properties (Hidden)
        aomOne          % AomNiDaqControlled
        aomTwo          % AomNiDaqControlled
        swapSwitch      % string
    end
    
    properties (Constant)
        NEEDED_FIELDS = {'channelOne', 'channelTwo', 'swapSwitch'};
        OPTIONAL_FIELDS = {'currentChannel', 'minVal', 'maxVal'}
    end
    
    methods
        function obj = AomDoubleNiDaqControlled(laserName, pgChannelStruct, channelOneStruct, channelTwoStruct, minVal, maxVal)
            % AOM is made of 3 parts, all are created elsewhere
            obj@LaserPartAbstract(laserName, minVal, maxVal, NiDaq.UNITS);
            
            %%% Create swapper
            swapperName = sprintf('%s swapper', laserName);
            obj.swapSwitch = SwitchPgControlled.create(swapperName, pgChannelStruct);
            
            %%% Create channel 1
            nameOne = sprintf('%s channel #1', laserName);
            % Append necessary data to channel struct
            channelOneStruct.minVal = minVal;
            channelOneStruct.maxVal = maxVal;
            obj.aomOne = AomNiDaqControlled.create(nameOne, channelOneStruct);
            
            %%% Create channel 2
            nameTwo = sprintf('%s channel #2', laserName);
            % Append necessary data to channel struct
            channelTwoStruct.minVal = minVal;
            channelTwoStruct.maxVal = maxVal;
            obj.aomTwo = AomNiDaqControlled.create(nameTwo, channelTwoStruct);
        end     % constructor
    end
       
    %% For dependent properties
    methods
        function set.activeChannel(obj, newChannel)
            % The switch swaps between controlling via AOM 1 and 2.
            % Channel 1 is active, if it's "on", and channel 2 -- if it's
            % "off"
            switch newChannel
                case {1, '1', 'one'}
                    falseforOneTrueForTwo = false;
                case {2, '2', 'two'}
                    falseforOneTrueForTwo = true;
            end
            obj.swapSwitch.isEnabled = falseforOneTrueForTwo;
        end
        function channel = get.activeChannel(obj)
            channel = BooleanHelper.ifTrueElse(obj.swapSwitch.isEnabled, 2, 1);
        end
        
        function mValues = get.values(obj)
            value1 = obj.aomOne.value;
            value2 = obj.aomTwo.value;
            mValues = [value1, value2];
        end
    end
    
    %% Overridden from LaserPartAbstract
    %%%% These functions call physical objects. Tread with caution! %%%%
    methods (Access = protected)
        function setValueRealWorld(obj, newValue)
            % Sets the voltage value in physical laser part
            switch obj.activeChannel
                case 1
                    obj.aomOne.value = newValue;
                case 2
                    obj.aomTwo.value = newValue;
            end
        end

        function value = getValueRealWorld(obj)
            % Gets the voltage value from physical laser part
            switch obj.activeChannel
                case 1
                    value = obj.aomOne.value;
                case 2
                    value = obj.aomTwo.value;
            end
        end
    end
    
    %% Factory
    methods (Static)
        function obj = create(laserName, jsonStruct)
            missingField = FactoryHelper.usualChecks(jsonStruct, AomDoubleNiDaqControlled.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError('Error while creating a Double AOM object (name: "%s"), missing field! (field missing: "%s")', ...
                    laserName, missingField);
            end
            % We want to get either values set in json, or empty variables
            % (which will be handled by NiDaqControlled constructor):
            jsonStruct = FactoryHelper.supplementStruct(jsonStruct, AomDoubleNiDaqControlled.OPTIONAL_FIELDS);
            
            name = sprintf('%s Double AOM', laserName);
            
            niDaqChannelOne = jsonStruct.channelOne;
            niDaqChannelTwo = jsonStruct.channelTwo;
            swapSwitch = jsonStruct.swapSwitch;
            minVal = jsonStruct.minVal;
            maxVal = jsonStruct.maxVal;
            
            obj = AomDoubleNiDaqControlled(name, swapSwitch, ...
                niDaqChannelOne, niDaqChannelTwo, minVal, maxVal);
            
            % check for optional field "currentChannel" and set it correctly
            if ~isempty(jsonStruct.currentChannel)
                % usualChecks() returning nan means everything ok
                obj.activeChannel = jsonStruct.currentChannel;
            end
        end
    end
    
end