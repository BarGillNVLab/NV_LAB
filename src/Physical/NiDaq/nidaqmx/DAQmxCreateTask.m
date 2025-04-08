function [status, taskname, taskhandle] = DAQmxCreateTask(taskname)

%p=libpointer;
% p = uint32(1);
% [status,taskname,taskhandle] = calllib('mynidaqmx','DAQmxCreateTask',taskname,p);

if isempty(taskname)
    taskname=char(0);
end

[status,taskhandle] = daq.ni.NIDAQmx.DAQmxCreateTask(taskname, uint64(0));