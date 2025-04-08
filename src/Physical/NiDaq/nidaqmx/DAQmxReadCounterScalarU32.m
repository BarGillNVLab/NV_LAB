function [status, readValue] = DAQmxReadCounterScalarU32(taskHandle, timeout)

[status, readValue, a] = daq.ni.NIDAQmx.DAQmxReadCounterScalarU32(taskHandle, timeout ,uint32(0), uint32(0));