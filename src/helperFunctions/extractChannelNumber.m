function number = extractChannelNumber(inputStr)
    % Extracts a trailing number from the end of a string.
    % Example: 'ch10' --> 10

    % Use regular expression to find the digits at the end
    tokens = regexp(inputStr, '\d+$', 'match');

    if isempty(tokens)
        error('No trailing number found in the string.');
    end

    % Convert matched string to number
    number = str2double(tokens{1});
end
