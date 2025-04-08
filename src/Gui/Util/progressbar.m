function h = progressbar(handle, varargin)
%PROGRESSBAR Display progress bar.
%   H = PROGRESSBAR(X,'message', property, value, property, value, ...)
%   creates and displays a waitbar of fractional length X.  The
%   handle to the waitbar figure is returned in H.
%   X should be between 0 and 1.
%
% Adapted by Nadav Slotky, September 2018,
%       from code by Doug Schwarz, 11 December 2008
%       and MathWorks code (in matlab:waitbar)

    narginchk(1,3)

    if ishghandle(handle, 'axes')
        ax = handle;
        value = (varargin{1});
        ptch = ax.Children;
        ptch.XData(3:4) = value;
        
        if nargin == 3
            ttl = (varargin{2});
            title(ax, ttl);
        end
        drawnow
        
    elseif ~isnumeric(handle) ...   % Apparently 0 and 1 are also handles...
            && ishandle(handle)
        % No colorbar yet, so we need to create it
        % We first need to create the progress bar
        bg_color = [.6 .6 .6];        %'b';
        fg_color = [0 .75 0]; %'r';
        handle = axes('Parent', handle, ...
            'Units',    'normalized', ...
            'XLim',     [0 1],      'YLim',     [0 1],...
            'XTick',    [],         'YTick',    [],...
            'Color',    bg_color, ...
            'XColor',   bg_color,   'YColor', bg_color, ...
            'NextPlot', 'replacechildren');
        patch([0 0 0 0], [0 1 1 0], fg_color,...
            'Parent',    handle, ...
            'EdgeColor', 'none', ...
            'PickableParts', 'none');
        
        progressbar(handle, varargin{:});
        h = handle;
    else
        % No handle was supplied
        figHandle = gcf;
        args = [{handle} varargin];
        h = progressbar(figHandle, args{:});
    end

end