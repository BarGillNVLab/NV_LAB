function status = DAQmxCreateCOPulseChanFreq(taskHandle, counter, nameToAssignToChannel,...
    units, idleState, initialDelay, freq, dutyCycle)

if isempty(nameToAssignToChannel)
    nameToAssignToChannel=char(0);
end

[status] = daq.ni.NIDAQmx.DAQmxCreateCOPulseChanFreq(taskHandle, counter, nameToAssignToChannel,...
    int32(units), int32(idleState), initialDelay, freq, dutyCycle);