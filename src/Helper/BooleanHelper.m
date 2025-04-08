classdef BooleanHelper
    %HELPER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods (Static)
        function value = ifTrueElse(bool, valueIfTrue, valueIfFalse)
            if bool
                value = valueIfTrue;
            else
                value = valueIfFalse;
            end
        end
        
        function string = boolToString(bool)
            string = BooleanHelper.ifTrueElse(bool, 'true', 'false');
        end
        
        function string = boolToOnOff(bool)
            string = BooleanHelper.ifTrueElse(bool, 'on', 'off');
        end

        function value = onOffToBool(onOff)
            onOff = num2str(onOff);
            if any(strcmpi(onOff, ["on", "1"]))
                value = true;
            elseif any(strcmpi(onOff, ["off", "0"]))
                                value = false;
            else
                error('wrong input to boolean helper');
            end
        end
    end
    
end

