function [ propertyValue ] = getConstPropertyfromString( varargin )
%GETCONSTPROPERTYFROMSTRING Gets a constant property from a class, by name
% 
% Input:
%   Either 1. string of pattern 'className.propertyName', or
%          2. two strings: 'className', 'propertyName'
% Output:
%   The value of the reqested property
%
% Note that the property should be constant. Otherwise, calling this function
% might result in an error.

% Parse input
    narginchk(1,2)

    switch nargin
        case 1
            % Split
            splitInput = strsplit(fullPath, '.');
        case 2
            % This is ready. Use as is.
            splitInput = varargin;
    end

    className = splitInput{1};
    propertyName = splitInput{2};

% Retrieve value
    mc = meta.class.fromName(className);
    mp = mc.PropertyList;
    [~, loc] = ismember(propertyName,{mp.Name}); % mp.Name is a list of all property names
    propertyValue = mp(loc).DefaultValue;


end