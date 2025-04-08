function [status, output] = DAQmxReadAnalogScalarF64(taskHandle)

timeout = 1.5;
output = zeros(1,1);

[status, th1, output] = calllib('mynidaqmx','DAQmxReadAnalogScalarF64',taskHandle, timeout,...
    output,[]);