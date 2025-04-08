classdef Channel < handle
    %CHANNEL Represents one channel for channel hubs (like Pulse Generators or NiDaq).
    % Data type with all properties common to channels, which also provides validation of values.
    % Includes 'value' property. Maybe will not be used.
    
    
    properties (Constant, Hidden)
        TYPE_DIGITAL = 'digital'
        TYPE_ANALOG = 'analog'
    end
    
    properties (Access = private)
        valuePrivate
    end
    
    properties (Dependent, Hidden)
        value
    end
    
    properties (SetAccess = private) % To be set on initialization only
        type            % digital or analog
        name            % char array. I will answer to this name only.
        address         % index in hub
        minimumValue    % double.
        maximumValue    % double.
        onDelay         % double. in microseconds
        offDelay        % double. in microseconds
    end
    
    %%
    methods (Access = private)
        function obj = Channel(type, name, address, minValue, maxValue, onDelay, offDelay)
            obj@handle;
            obj.type = type;
            obj.name = name;
            obj.address = address;
            obj.minimumValue = minValue;
            obj.maximumValue = maxValue;
            obj.onDelay = onDelay;
            obj.offDelay = offDelay;
        end
    end
    
    methods
        function set.value(obj, newVal)
            switch obj.type
                case obj.TYPE_ANALOG
                    if ~isnumeric(newval)
                        error('Analog channel value must be numeric!')
                    elseif (newVal < obj.minimumValue) || (newVal > obj.maximumValue)
                        error('Analog channel value must be between %d and %d! (requested: %d)', ...
                            obj.minimumValue, obj.maximumValue, newVal)
                    end
                case obj.TYPE_DIGITAL
                    if ~ValidationHelper.isTrueOrFalse(newVal)
                        error('Digital channel value must be convertible to logical!')
                    end
            end
            
            % newVal passed validation, so in it goes:
            obj.valuePrivate = newVal;
        end
        
        function val = get.value(obj)
            val = obj.valuePrivate;
        end
        
        function tf = isDigital(obj)
            tf = strcmp(obj.type, obj.TYPE_DIGITAL);
        end
        function tf = isAnalog(obj)
            tf = strcmp(obj.type, obj.TYPE_ANALOG);
        end
    end
    
    %% Public constructor methods
    methods (Static)
        function obj = Digital(name, address, onDelay, offDelay)
            if nargin < 3
                onDelay = 0;
                offDelay = 0;
            end
            obj = Channel(Channel.TYPE_DIGITAL, name, address, 0, 1, onDelay, offDelay);
        end
        
        function obj = Analog(name, address, minValue, maxValue, onDelay, offDelay)
            if nargin < 5
                onDelay = 0;
                offDelay = 0;
            end
            obj = Channel(Channel.TYPE_ANALOG, name, address, minValue, maxValue, onDelay, offDelay);
        end
    end
    
end

