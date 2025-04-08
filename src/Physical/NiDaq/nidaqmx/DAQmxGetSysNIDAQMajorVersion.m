function [ status,majorVer ] = DAQmxGetSysNIDAQMajorVersion

p = libpointer('ulongPtr',1);
[status,majorVer] = calllib('mynidaqmx','DAQmxGetSysNIDAQMajorVersion',p);



