function status = DAQmxCreateCOPulseChanTicks(taskHandle, counter, nameToAssignToChannel,...
    sourceTerminal, idleState, initialDelay, lowTicks, highTicks)

if isempty(nameToAssignToChannel)
    nameToAssignToChannel=char(0);
end

[status] = daq.ni.NIDAQmx.DAQmxCreateCOPulseChanTicks(uint64(taskHandle), counter, nameToAssignToChannel,...
    sourceTerminal, int32(idleState), int32(initialDelay), int32(lowTicks), int32(highTicks));