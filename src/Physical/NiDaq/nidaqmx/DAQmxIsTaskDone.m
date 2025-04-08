function [status, isTaskDone] = DAQmxIsTaskDone(taskHandle)

isTaskDone = uint32(0);
[status, isTaskDone] = daq.ni.NIDAQmx.DAQmxIsTaskDone(taskHandle, isTaskDone);

