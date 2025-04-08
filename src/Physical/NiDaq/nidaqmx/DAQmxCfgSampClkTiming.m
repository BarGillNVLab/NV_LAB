function [status] = DAQmxCfgSampClkTiming(task,source,rate,...
    activeEdge,sampleMode,sampsPerChanToAcquire)

if isempty(source)
    source=char(0);
end

status = daq.ni.NIDAQmx.DAQmxCfgSampClkTiming(task,source,rate,int32(activeEdge),int32(sampleMode),uint64(sampsPerChanToAcquire));