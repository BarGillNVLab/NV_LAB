function [status, task] = DAQmxWriteAnalogScalarF64(task,bAutoStart,WaitSec,Scalar)

[status,task]=daq.ni.NIDAQmx.DAQmxWriteAnalogScalarF64(task,uint32(bAutoStart),WaitSec,Scalar,uint32(0));
