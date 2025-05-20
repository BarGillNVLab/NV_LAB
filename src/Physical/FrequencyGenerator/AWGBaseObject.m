classdef AWGBaseObject < FrequencyGenerator

    properties
        bandwidth
        sampleRate
        useAWG
        mode % internal or external
        waveforms
        channelName
    end

end