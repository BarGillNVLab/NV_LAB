classdef SpcmTimeTaggerControlledArduinoDaqEnabled < Spcm
    % Minimal SPCM for TimeTagger + Arduino digital gate (Case A)

    properties
        daq
        tt
        gateChannelName   % Logical name for Arduino digital output
        timeTaggerCountChannel
        timeTaggerCountDelay
        timeTaggerPGChannel
        timeTaggerPGDelay

        lastTimeG2
        lastTimeHist
    end

    methods
        function obj = SpcmTimeTaggerControlledArduinoDaqEnabled( ...
                name, gateChannelName, countChannel, countDelay, pgChannel, pgDelay)

            obj@Spcm(name);

            % Retrieve Arduino DAQ instance
            d = getObjByName(ArduinoGP8413Dac.NAME);   % or ArduinoGP8413Daq.NAME
        
            if isempty(d)
                error('SpcmTimeTaggerControlledArduinoDaqEnabled:NoArduinoDAQ', ...
                      ['No ArduinoGP8413Dac instance found. ' ...
                       'Make sure Daq.create() was called before SPCM initialization.']);
            end
        
            obj.daq = d;

            % Register digital gate pin
            obj.gateChannelName = gateChannelName;
            d.registerChannel(gateChannelName, 'spcm_gate', 0, 1);

            % Register channels in TimeTagger
            tt = getObjByName(TimeTaggerWrapper.NAME);
            if isempty(tt), tt = TimeTaggerWrapper.create(); end

            obj.tt = tt;

            obj.timeTaggerCountChannel = sprintf('%s_count',name);
            tt.registerChannel(countChannel, obj.timeTaggerCountChannel, countDelay);
            tt.setTriggerLevel(obj.timeTaggerCountChannel,1);

            obj.timeTaggerPGChannel = sprintf('%s_pg',name);
            tt.registerChannel(pgChannel, obj.timeTaggerPGChannel, pgDelay);

            obj.availableProperties.(obj.HAS_BINNING) = false;
            obj.availableProperties.(obj.HAS_LIFETIME) = false;
            obj.availableProperties.(obj.HAS_G2) = false;
        end

        % --- Required Abstract Methods (minimal versions) ---
        function prepareReadByTime(~,~)
            % TimeTagger handles timing directly; nothing to prepare
        end

        function [kcps, stdev] = readFromTime(obj)
            meas = obj.tt.createMeasurement('Counter', ...
                obj.timeTaggerCountChannel, 1e9, 1);
            obj.tt.sync();
            pause(0.001);
            data = meas.getData();
            kcps = data / 1e3;
            stdev = 0;
            meas.clear();
        end

        function clearTimeRead(~)
        end

        function prepareCountByStage(varargin)
            error('Stage-based scanning requires NI hardware; unavailable on Arduino backend.');
        end
        function startScanCount(varargin)
            error('Not supported on Arduino backend.');
        end
        function out = readFromScan(varargin)
            error('Not supported on Arduino backend.');
            out = [];
        end
        function clearScanRead(varargin)
        end

        function prepareExperimentCount(varargin)
            error('Experiment-based gating requires NI hardware; unavailable on Arduino backend.');
        end
        function startExperimentCount(varargin)
        end
        function out = readFromExperiment(varargin)
            error('Not supported.');
            out = [];
        end
        function stopExperimentCount(varargin)
        end
        function clearExperimentRead(varargin)
        end

        % Digital gating
        function setSPCMEnable(obj, newBooleanValue)
            obj.daq.writeDigital(obj.gateChannelName, newBooleanValue);
        end
    end

    %% ---- FACTORY ----
    methods (Static)
        function spcmObj = create(spcmName, spcmStruct)
            % Required fields for Case A
            needed = {'arduino_gate_channel','timeTagger_channel_counts', ...
                      'timeTagger_channel_counts_delay','timeTagger_channel_pg', ...
                      'timeTagger_channel_pg_delay'};

            missing = FactoryHelper.usualChecks(spcmStruct, needed);
            if ~isnan(missing)
                EventStation.anonymousError( ...
                    'TimeTagger+Arduino SPCM missing field %s', missing);
            end

            gate   = spcmStruct.arduino_gate_channel;
            counts = spcmStruct.timeTagger_channel_counts;
            cDelay = spcmStruct.timeTagger_channel_counts_delay;
            pg     = spcmStruct.timeTagger_channel_pg;
            pDelay = spcmStruct.timeTagger_channel_pg_delay;

            spcmObj = SpcmTimeTaggerControlledArduinoDaqEnabled( ...
                spcmName, gate, counts, cDelay, pg, pDelay);
        end
    end
end
