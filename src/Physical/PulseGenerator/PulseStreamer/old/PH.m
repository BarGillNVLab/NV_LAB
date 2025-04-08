classdef PH < handle
    % PH class (PH means Pulse, Hex input) combines a duration (ticks) and
    % an output state.
    % the JSON string sent to the pulse streamer is calculated as soon as
    % a pulse is generated
    %
    % usage:
    % PH(100,3,0,1)
    % defines a pulse of length 100ns
    % with the channel mask (3) set such that channel 0 and 1 are high (3 V)
    % analog channel 0: 0 V
    % analog channel 1: 1 V
    properties
        ticks@uint64
        digital@uint8
        analog0@int16
        analog1@int16
        json
        locked
        initialize
    end    
    methods
        function obj = PH(ticks, digchan, analog0, analog1)
            if nargin < 2
                error('P must have at least the ticks ans digchan parameter');
            end
            if nargin < 3
                analog0 = 0;
            end
            if nargin < 4
                analog1 = 0;
            end
            if ~isnumeric(digchan)
                error('digchan must be a single value (bitmask)');
            end
            obj.initialize = true;
            obj.ticks = uint64(ticks);
            assert((0 <= digchan) && (digchan < 256))
            assert((-1 <= analog0) && (analog0 <= 1))
            assert((-1 <= analog1) && (analog1 <= 1))
            obj.digital = uint8(digchan);
            obj.analog0 = int16(analog0*32767);
            obj.analog1 = int16(analog1*32767);
            obj.locked = false;
            obj.initialize = false;
            obj.generateJSON();
        end
        function generateJSON(obj)
            if ~obj.initialize
                obj.json = encodePulse(obj);
            end
        end
        function set.ticks(obj,val)
            if obj.locked
                error('Property is not mutable due to the use of + or * before.');
            end
            if obj.initialize || obj.ticks ~= val
                obj.ticks = val;
                obj.generateJSON();
            end
        end
        function set.digital(obj,val)
            if obj.locked
                error('Property is not mutable due to the use of + or * before.');
            end
            if obj.initialize || obj.digital ~= val
                obj.digital = val;
                obj.generateJSON();
            end
        end
        function set.analog0(obj,val)
            if obj.locked
                error('Property is not mutable due to the use of + or * before.');
            end
            if obj.initialize || obj.analog0 ~= val
                obj.analog0 = val;
                obj.generateJSON();
            end
        end
        function set.analog1(obj,val)
            if obj.locked
                error('Property is not mutable due to the use of + or * before.');
            end
            if obj.initialize || obj.analog1 ~= val
                obj.analog1 = val;
                obj.generateJSON();
            end
        end
        function p = plus(p1,p2)
            p = [p1 p2];
        end
        function pout = not(p)
            pout = P(p.ticks, [], -(p.analog0), -(p.analog1));
            pout.digital = bitcmp(p.digital);
        end
        function p = times(p,times)
            p = mtimes(p, times);
        end
        function lock(obj)
            arrayfun(@(x) x.lock_internal(), obj);
        end
        function lock_internal(obj)
            obj.locked = true;
        end
        function clonedPulse = clone(obj)
            clonedPulse = P(obj.ticks, '', obj.analog0, obj.analog1);
            clonedPulse.digital = obj.digital;
        end
        function unlockedPulse = unlock(obj)
            unlockedPulse = obj.clone();
        end
        function pout = mtimes(p,times)
            if isnumeric(p) && isa(times, 'P')
                % wrong order but handle it the right way
                times.lock();
                pout = repmat(times, 1, p);
            else
                p.lock();
                pout = repmat(p, 1, times);
            end
        end
    end
    methods (Static)
        function equal = eqOutput(a,b)
            equal = (a.digital == b.digital && a.analog0 == b.analog0 && a.analog1 == b.analog1);
        end
        function d = duration(pulseList)
            d = sum([pulseList.ticks]);            
        end
        function result = unlockPulseList(pulses)
            result = pulses;
            for i=1:length(result)
                result(i) = result(i).unlock();
            end
        end
        function simplify(pulseList)
            pos = 2;
            while pos <= length(pulseList)
                p1 = pulseList(pos-1);
                p2 = pulseList(pos);
                if P.eqOutput(p1, p2)
                    newP = p1.clone();
                    newP.ticks = p1.ticks + p2.ticks;
                    pulseList(pos-1) = newP;
                    pulseList(pos) = [];
                end
                pos = pos + 1;
            end
        end
        function final = union(varargin)
            if nargin < 2
                error('At least two lists of P objects are required for union');
            end
            lists = varargin;
            
            allTicksCum = [];
            for i=1:length(lists)
                cumticks{i} = cumsum([lists{i}.ticks]);
                allTicksCum = unique([allTicksCum cumticks{i}]);
            end
            
            allTicks = allTicksCum(1:end) - [0 allTicksCum(1:end-1)];
            
            pos = ones(1,length(lists));
            
            for iTick=1:length(allTicksCum)
                a0 = 0;
                a1 = 0;
                channels = uint8(0);
                for i=1:length(lists)
                    %check whether the sequence is shorter than the total
                    %sequence
                    if pos(i) > length(lists{i})
                        continue
                    end
                    p = lists{i}(pos(i));
                    % digital channels are ease - bitwise or
                    channels = bitor(channels, p.digital);
                    
                    % bitwise or for analog channels does not make sense
                    % allow only one single value different from 0 for the union
                    if (p.analog0 ~= 0)
                        if (a0 ~= 0 && a0 ~= p.analog0)
                            error('More than one analog0 value set. Union not defined!');
                        end
                        a0 = p.analog0;
                    end
                    if (p.analog1 ~= 0)
                        if (a1 ~= 0 && a1 ~= p.analog1)
                            error('More than one analog1 value set. Union not defined!');
                        end
                        a1 = p.analog1;
                    end
                    
                    % check whether the read position of the current list must be
                    % increased
                    if allTicksCum(iTick) == cumticks{i}(pos(i))
                        pos(i) = pos(i) + 1;
                    end
                end
                % there is no constructor with the channelMask - so use an empty
                % channel list first and then overwrite it
                final(iTick) = P(allTicks(iTick), '', a0, a1);
                final(iTick).digital = channels;
            end
        end
        
    end
end