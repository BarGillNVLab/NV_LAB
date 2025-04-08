function [status, rate] = DAQmxGetSampClkRate(taskHandle)

data = 1;
[status, th1, rate]=calllib('mynidaqmx','DAQmxGetSampClkRate', taskHandle, data);

