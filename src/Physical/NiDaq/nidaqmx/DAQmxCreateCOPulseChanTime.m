function status = DAQmxCreateCOPulseChanTime(taskHandle, counter, nameToAssignToChannel,...
    units, idleState, initialDelay, lowTime, highTime)

if isempty(nameToAssignToChannel)
    nameToAssignToChannel=char(0);
end

[status] = daq.ni.NIDAQmx.DAQmxCreateCOPulseChanTime(uint64(taskHandle), counter, nameToAssignToChannel,...
    units, idleState, initialDelay, lowTime, highTime);