function [status, readArray]=DAQmxReadCounterF64(taskHandle, numSampsPerChan,...
    timeout, readArray, arraySizeInSamps, sampsPerChanRead )

% new matlab
% [status, th1, readArray]=calllib('mynidaqmx','DAQmxReadCounterF64',taskHandle, numSampsPerChan, ...
%     timeout, readArray, arraySizeInSamps, sampsPerChanRead,[]);

% old matlab
[status, readArray, sampsPerChanRead, reserved]=daq.ni.NIDAQmx.DAQmxReadCounterF64(taskHandle, int32(numSampsPerChan), ...
    timeout, readArray, uint32(arraySizeInSamps), sampsPerChanRead, uint32(0));