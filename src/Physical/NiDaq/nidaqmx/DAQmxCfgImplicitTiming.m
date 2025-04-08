function [status] = DAQmxCfgImplicitTiming(taskHandle, sampleMode, sampsPerChanToAcquire)

[status] = daq.ni.NIDAQmx.DAQmxCfgImplicitTiming(taskHandle, int32(sampleMode), uint64(sampsPerChanToAcquire));
