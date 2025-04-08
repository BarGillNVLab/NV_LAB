function [ status,updateVer ] = DAQmxGetSysNIDAQUpdateVersion

p = libpointer('ulongPtr',1);
[status,updateVer] = calllib('mynidaqmx','DAQmxGetSysNIDAQUpdateVersion',p);



