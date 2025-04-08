function status = DAQmxCreateAIVoltageChan(taskHandle, physicalChannel, ...
    nameToAssignToChannel, terminalConfig, minVal, maxVal,...
    units, customScaleName)

if isempty(nameToAssignToChannel)
    nameToAssignToChannel=char(0);
end

if isempty(customScaleName)
    customScaleName=char(0);
end

status = daq.ni.NIDAQmx.DAQmxCreateAIVoltageChan(taskHandle, physicalChannel, ...
    nameToAssignToChannel, terminalConfig, minVal, maxVal, units, customScaleName);
