classdef PSSequence
    %PSSEQUENCE class contains all information about the signal sequence
    % and the channel assignments. 
    %
    %   The sequence data cannot be modified on per channel basis but allows 
    %   for concatenation and repetitions.
    
    properties (Constant)
       class_ver='1.0';     % class version 
    end
    
    properties (SetAccess=private)
        ticks = []; % State durations
        digi = [];  % Digital channels data
        ao0 = [];   % Analog channel 0
        ao1 = [];   % Analog channel 1
    end
    
    methods
        function obj = PSSequence(RLE)
            %PSSEQUENCE Construct an instance of this class
            %   RLE is a 2D array [ticks(:),digi(:),ao0(:),ao1(:)]
            
            if exist('RLE', 'var') 
                if ~(isnumeric(RLE) && size(RLE,2)==4)
                    error('Wrong RLE data format')
                end
                obj.ticks = RLE(:,1);
                obj.digi = RLE(:,2);
                obj.ao0 = RLE(:,3);
                obj.ao1 = RLE(:,4);
            else
                % Create empty sequence
            end
        end
        
        function TF = isEmpty(obj)
            % Returns True if sequence is empty
            TF = isempty(obj.ticks);
        end
        
        function t = getDuration(obj)
            % Get sequence duration
            t = sum(obj.ticks(:));
        end
        
        function state = getLastState(obj)
            % GETLASTSTATE returns last state of the sequence.
            
            if isempty(obj.digi)
                state = OutputState(0,0,0);
            else
                state = OutputState(obj.digi(end), obj.ao0(end), obj.ao1(end));
            end
        end
        
        function obj = repeat(obj, count)
            % REPEAT return sequence data duplicated "count" times.
            
            if count >= 0 && isscalar(count)
                obj.ticks = repmat(obj.ticks, count, 1);
                obj.digi = repmat(obj.digi, count, 1);
                obj.ao0 = repmat(obj.ao0, count, 1);
                obj.ao1 = repmat(obj.ao1, count, 1);
            else
                error('Repeat "count" must be non-negative integer number');
            end
        end
        
        function obj = horzcat(varargin)
            % Overrides horizontal concatenation
            
            obj = varargin{1};
            for ii = 2:numel(varargin)
               obj = obj.append(varargin{ii});
            end
        end
        
        function obj = vertcat(varargin)
            % Overrides vertical concatenation
            
            obj = varargin{1};
            for ii = 2:numel(varargin)
               obj = obj.append(varargin{ii});
            end
        end
       
        function plot(obj)
            % Plot both, analog and digital data in a current figure
            
            ax1=subplot(2,1,1);
            obj.plotAnalog();
            title('Analog outputs');
            legend show;
            ax2=subplot(2,1,2);
            obj.plotDigital();
            title('Digital outputs');
            legend show;
            xlabel('Time [ns]');
            linkaxes([ax1,ax2], 'x');
        end
        
        function plotDigital(obj)
            % Plot digital sequence data in current axes
            ylbl = {};
            ytick = [];
            for ii = 8:-1:1
                ytick(ii) = (ii-1);
                ylbl{ii} = sprintf('D% 2d',ii-1);
                plot_levels(obj.ticks, ...
                    bitget(obj.digi, ii, 'uint8')*0.5 + ytick(ii), ...
                    {'.-', 'DisplayName', ylbl{ii}});
                
                hold on
            end
            ax = gca;
            ax.YTick = ytick;
            ax.YTickLabel = ylbl;
            ylim(ax, [min(ytick)-0.5, max(ytick)+0.5]);
            hold off
        end
        
        function plotAnalog(obj)
            % Plot analog sequence data in current axes
            
            plot_levels(obj.ticks, obj.ao1, {'b.-', 'DisplayName', 'A1', 'MarkerSize', 12, 'LineWidth', 0.8});
            hold on
            plot_levels(obj.ticks, obj.ao0, {'r.-', 'DisplayName', 'A0', 'MarkerSize', 8, 'LineWidth', 0.5});
            hold off
            ylim([-1.01, 1.01]);
        end
    end
    
    methods (Access=private)
        function obj = append(obj, seq2)
            % APPEND Adds 'seq2' at the end of the current sequence
            %   seq2    - PSSequence object to be appended.
            
            obj.ticks = [obj.ticks; seq2.ticks];
            obj.digi = [obj.digi; seq2.digi];
            obj.ao0 = [obj.ao0; seq2.ao0];
            obj.ao1 = [obj.ao1; seq2.ao1];
        end
    end
end


function plot_levels(ticks, levels, linespec)
    % PLOT_LEVELS plots the signal levels as stair-case plot, which
    % represents best the real signals at the Pulse Streamer output. 
    
    t = [0; cumsum(ticks(:))];
    lvl = [levels(:); levels(end)];
    stairs(t, lvl, linespec{:});
end
