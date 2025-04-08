 classdef ValidationHelper
    %PHYSICSGUARD Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods (Static)
        function tf = isInBorders(valueNumber, minBorder, maxBorder)
            tf = and(all(valueNumber >= minBorder), all(valueNumber <= maxBorder));
        end
        
        function tf = isTrueOrFalse(value)
            tf = (isequal(value, false) || isequal(value, true)); % isequal(1, true) == true
        end
        
        function [tf, value] = isValueInteger(inputValue)
            % Checks if a string\numeric value is a positive integer
            % Also returns the number, in case it needed converting
            if ischar(inputValue)
                value = str2double(inputValue);
            else
                value = inputValue;
            end
            
            if any(isnan(value)) ...         	% Conversion to double failed,
                    || any(mod(value,1)) ~= 0	% or: it is not an integer
                tf = false;
            else
                tf = true;
            end
        end
        
        function tf = isValuePositiveInteger(inputValue)
            % Checks if a string\numeric value is a positive integer
            [isInteger, value] = ValidationHelper.isValueInteger(inputValue);
            
            if isInteger && (value > 0)
                tf = true;
            else
                tf = false;
            end
        end
        
        function tf = isStringValueANumber(stringValues)
            % Checks if all the string values are inside the borders
            % stringValues - can be a string or a cell string
            value = str2double(stringValues);
            tf = ~any(isnan(value));
        end
        
        function tf = isStringValueInBorders(stringValues, lowerBorder, upperBorder)
            % Checks if all the string values are inside the borders
            % stringValues - can be a string or a cell string
            value = str2double(stringValues);
            if any(isnan(value)) || any(value < lowerBorder) || any(value > upperBorder)
                tf = false;
            else
                tf = true;
            end
        end
        
        function tf = isValuePositive(stringValues)
            % Checks if the value written in a string is a positive number
            % stringValues - can be a string or a cell string
            value = str2double(stringValues);
            if any(isnan(value)) || any(value <= 0)
                tf = false;
            else
                tf = true;
            end
        end
        
        function tf = isValueNonNegative(stringValues)
            % Checks if the value written in a string is a positive number
            % stringValues - can be a string or a cell string
            tf = ValidationHelper.isStringValueInBorders(stringValues, 0, inf);
        end
        
        function tf = isValueFraction(newValue)
            tf = isnumeric(newValue) && ValidationHelper.isInBorders(newValue, 0, 1);
        end
        
        function tf = isValidVector(val, maxLength)
            % Checks whether 'val' is a vector (that is, a Nx1 or 1xN
            % matrix) and makes sure it isn't longer than 'maxLength'
            s = size(val);
            tf = (length(s) == 2) ...      % MATLAB arrays are always at least 2-dimensional. Shouldn't be more, though
                 && (min(s) == 1) ...      % One of the dimensions is of length 1
                 && (max(s) <= maxLength); % The other one is not TOO long
        end
        
        function tf = isValidVectorOrMatrix(val, maxLength)
            % Checks whether 'val' is a vector (that is, a Nx1 or 1xN
            % matrix) and makes sure it isn't longer than 'maxLength'
            s = size(val);
            tf = (length(s) == 2) ...      % MATLAB arrays are always at least 2-dimensional. Shouldn't be more, though
                 && (max(s) <= maxLength); % One of the dimensions is not TOO long
        end
    end
    
end

