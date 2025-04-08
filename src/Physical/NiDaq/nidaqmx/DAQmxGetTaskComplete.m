function [status, isTaskComplete] = DAQmxGetTaskComplete(taskHandle)

isTaskComplete = uint32(0);
[status, isTaskComplete] = daq.ni.NIDAQmx.DAQmxGetTaskComplete(taskHandle, isTaskComplete);

