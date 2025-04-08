function [status,task,chans] = DAQmxCreateAOVoltageChan(task,chans,minVal,maxVal,Units)

name = char(0);
% measure volts
Units = daq.ni.NIDAQmx.DAQmx_Val_Volts;    
scaleName = char(0);

% [status,task,chans] = daq.ni.NIDAQmx.DAQmxCreateAOVoltageChan(task,chans,name,minVal,maxVal,Units,scaleName);
[status] = daq.ni.NIDAQmx.DAQmxCreateAOVoltageChan(task,chans,name,minVal,maxVal,Units,scaleName);
