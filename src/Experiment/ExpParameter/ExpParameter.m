classdef (Abstract) ExpParameter < HiddenMethodsHandle & PropertiesDisplaySorted
    %EXPPARAMETER objects of type experiment-parameter
    %   ep = EXPPARAMETER(name) creates an empty parameter
    %
    %   ep = EXPPARAMETER(name,value) creates a parameter with VALUE
    %
    %   ep = EXPPARAMETER(___,expName) creates a parameter which is
    %   assigned to an experiment named expName
    %
    %   An experiment parameter can have a name, supported value-types and the actual
    %   values. Additionally, an ExpParameter-object will alyways point to the
    %   experiment using it
    
    properties (Abstract, SetAccess = protected)
        type            % string.
    end
    
    properties
        name            % string. Name to be presented in GUI
        value = [];     % value of type 'type'
        sterr = [];     % value of type 'type'
        units = '';
        desc = '';      % string. Name for legends
    end
    
    properties (Dependent, SetAccess = private)
        label
    end
    
    properties (SetAccess = ?Experiment)
        expName = nan;  % string. Name of associated experiment
    end
    
    properties (Constant, Hidden)
        TYPE_LOGICAL = 'logical'
        TYPE_DOUBLE = 'double'
        TYPE_VECTOR_OF_DOUBLES = 'vector of doubles'
        TYPE_RESULT = 'result vector of doubles'
    end
    
    methods
        function obj = ExpParameter(name, value, sterr, units, expName, desc)
            % All parameters except name are optional
            obj@HiddenMethodsHandle;
            obj@PropertiesDisplaySorted;
            
            obj.name = name;
            if exist('value', 'var'); obj.value = value; end
            if exist('sterr', 'var'); obj.sterr = sterr; end
            if exist('units', 'var'); obj.units = units; end
            if exist('expName', 'var'); obj.expName = expName; end
            if exist('desc', 'var'); obj.desc = desc; end
        end
    end
    

    
    %% Setters & getters
    methods
        function set.value(obj, newValue)
            if ~isempty(newValue) && ~obj.validateValue(newValue)
                
                % Formatting strings for error
                newType = class(newValue);
                if strcmp(newType, 'double') && length(newValue)>1; newType = obj.TYPE_VECTOR_OF_DOUBLES; end %#ok<STISA>
                
                parameterName = obj.name; %#ok<*MCSUP>
                % If we know the name of the associated experiment, we want to include it in the error message:
                if obj.isAssociatedToExp; parameterName = sprintf('%s.%s', obj.expName, parameterName); end
                
                EventStation.anonymousError('Trying to define value for %s failed! \nNew value: %s (of type %s) \nExpected type: %s', ...
                    parameterName, newValue, newType, obj.type);
            end
            obj.value = newValue;
            
            % If this is a parameter (as opposed to result) of a known
            % experiment, this is important, and we want everyone to know
            if obj.isAssociatedToExp && ~strcmp(obj.type, obj.TYPE_RESULT)
                exp = getObjByName(obj.expName);
                if isempty(exp)
                    % Associated experiment does not exist!
                    obj.expName = nan;
                else
                    exp.sendEventParamChanged();
                end
            end
        end
        
        function set.sterr(obj, newValue)
            if ~isempty(newValue) && ~obj.validateValue(newValue)
                
                % Formatting strings for error
                newType = class(newValue);
                if strcmp(newType, 'double') && length(newValue)>1; newType = obj.TYPE_VECTOR_OF_DOUBLES; end %#ok<STISA>
                
                parameterName = obj.name; %#ok<*MCSUP>
                % If we know the name of the associated experiment, we want to include it in the error message:
                if obj.isAssociatedToExp; parameterName = sprintf('%s.%s', obj.expName, parameterName); end
                
                EventStation.anonymousError('Trying to define sterr for %s failed! \nNew sterr: %s (of type %s) \nExpected type: %s', ...
                    parameterName, newValue, newType, obj.type);
            end
            obj.sterr = newValue;
        end
        
        function tf = isAssociatedToExp(obj)
            tf = ~isempty(obj.expName) && ischar(obj.expName);
        end
        
        function lbl = get.label(obj)
            if isempty(obj.units)
                lbl = obj.name;
            else
                if ~ischar(obj.units)
                    EventStation.anonymousWarning('The name of the units of %s.%s are %s, but they need to be of type char!', ...
                        obj.expName, obj.name, class(obj.units));
                    lbl = obj.name;
                else
                    lbl = sprintf('%s [%s]', obj.name, obj.units);
                end
            end
        end
    end
    
    %%
    methods (Static, Abstract)
        isOk = validateValue(newValue)
        % Check if a new value is valid, according to obj.type
    end
end