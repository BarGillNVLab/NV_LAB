classdef PSSequenceBuilder < handle
    %PSSEQUENCEBUILDER Use this class to build sequences by assigning 
    % signal patterns to output channels and create sequence
    %   
    
    properties (Constant)
       class_ver='1.0';     % class version 
    end
    
    properties (Access = private)
        ps = [];       % keep reference to active PulseStreamer object
        dp_time;
        dp_cumtime;
        dp_level;
        ap_time;
        ap_cumtime;
        ap_level;
    end
    
    methods
        function obj = PSSequenceBuilder(pstreamer)
            %PSSEQUENCEBUILDER Construct an instance of this class
            %   Detailed explanation goes here
            
            if isa(pstreamer, 'PulseStreamer')
                obj.ps = pstreamer;
                obj.dp_time = cell(numel(obj.ps.digitalChannels),1);
                obj.dp_cumtime = cell(numel(obj.ps.digitalChannels),1);
                obj.dp_level = cell(numel(obj.ps.digitalChannels),1);
                obj.ap_time = cell(numel(obj.ps.analogChannels),1);
                obj.ap_cumtime = cell(numel(obj.ps.analogChannels),1);
                obj.ap_level = cell(numel(obj.ps.analogChannels),1);
            end
        end
        
        function setDigital(obj, chan, pattern)
            %SETDIGITAL Assigns signal pattern to digital output
            %   Detailed explanation goes here
            
            if ~(isscalar(chan) && ismember(chan, obj.ps.digitalChannels))
                error('Digital channnel "%d" does not exist. Valid channels %d', chan, obj.ps.digitalChannels )
            end
            if ~(iscell(pattern) && size(pattern, 2) == 2)
                error('Pattern must be a cell array of dimensions [N,2]');
            end
            
            ch_idx = (chan == obj.ps.digitalChannels); % channel index in the list of channels
            obj.dp_time{ch_idx} = cell2mat(pattern(:,1));
            obj.dp_cumtime{ch_idx} = cumsum(obj.dp_time{ch_idx});
            obj.dp_level{ch_idx} = cell2mat(pattern(:,2));
        end
        
        function setAnalog(obj, chan, pattern)
            %SETANALOG Assigns signal pattern to analog output
            %   Detailed explanation goes here
            
            if ~(isscalar(chan) && ismember(chan, obj.ps.analogChannels))
                error('Analog channnel "%d" does not exist. Valid channels %d', chan, obj.ps.analogChannels )
            end
            if ~(iscell(pattern) && size(pattern, 2) == 2)
                error('Pattern must be a cell array of dimensions [N,2]');
            end
            
            ch_idx = (chan == obj.ps.analogChannels); % channel index in the list of channels
            obj.ap_time{ch_idx} = cell2mat(pattern(:,1));
            obj.ap_cumtime{ch_idx} = cumsum(obj.ap_time{ch_idx});
            obj.ap_level{ch_idx} = cell2mat(pattern(:,2));
        end
        
        function seq_obj = buildSequence(obj)
        % Builds synchronous sequence
            
            % find unique time points
            ct_sync = unique([cell2mat(obj.dp_cumtime); cell2mat(obj.ap_cumtime)]);
            
            % allocate arrays
            digi_vals = zeros(numel(ct_sync), numel(obj.ps.digitalChannels)); 
            aout_vals = zeros(numel(ct_sync), numel(obj.ps.analogChannels));
            
            % resample digital channel levels for common time
            for chan = 1:numel(obj.ps.digitalChannels)
                if ~isempty(obj.dp_level{chan})
                    ct = obj.dp_cumtime{chan};
                    lvls = obj.dp_level{chan};
                    digi_vals(:,chan) = resample_constpw(ct, lvls, ct_sync);
                end
            end
            
            % resample analog channel levels for common time
            for chan = 1:numel(obj.ps.analogChannels)
                if ~isempty(obj.ap_level{chan})
                    ct = obj.ap_cumtime{chan};
                    lvls = obj.ap_level{chan};
                    aout_vals(:,chan) = resample_constpw(ct, lvls, ct_sync);
                end
            end
            
            powof2 = pow2((0:numel(obj.ps.digitalChannels)-1)); % powers of 2 
            
            tick = diff([0;ct_sync]);
            digi = digi_vals*powof2(:); % convert array of bits to decimal number
            ao0 = aout_vals(:,1);
            ao1 = aout_vals(:,2);
            
            % RLE data, real valued.
            RLE = [tick(:), digi(:), ao0(:), ao1(:)];
            
            % Create PSSequence object
            seq_obj = PSSequence(RLE);
        end
    end
end

function lvlq = resample_constpw(ct, lvl, ctq)
    % Resample using constant piecewise interpolation.
    % "ct" and "ctq" must be 
    % - ctq value such that ct(i) <= ctq < ct(i+1) -> lvlq = lvl(i);
    % - ctq value smaller than any value in ct -> lvlq = lvl(1);
    % - ctq value larger than any value in ct  -> lvlq = lvl(end);
    
    N = numel(ct);
    Nsync = numel(ctq);
    lvlq = zeros(Nsync,1);
    jj=1;
    for ii=1:numel(ctq)
        while (ctq(ii)>ct(jj) && jj<N)
            jj=jj+1;
        end
        lvlq(ii)=lvl(jj);
    end
end

