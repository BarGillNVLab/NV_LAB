function [ status,minorVer ] = DAQmxGetSysNIDAQMinorVersion

p = libpointer('ulongPtr',1);
[status,minorVer] = calllib('mynidaqmx','DAQmxGetSysNIDAQMinorVersion',p);



