function [ status ] = DAQmxClearTask(taskhandle)

[status] = daq.ni.NIDAQmx.DAQmxClearTask(taskhandle);

