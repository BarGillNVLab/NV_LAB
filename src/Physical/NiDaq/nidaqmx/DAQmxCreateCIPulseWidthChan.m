function [status] = DAQmxCreateCIPulseWidthChan(taskHandle, strCounter,...
    strNameToAssignToChannel, minVal, maxVal, units, startingEdge, strCustomScaleName)

if isempty(strNameToAssignToChannel)
    strNameToAssignToChannel=char(0);
end

if isempty(strCustomScaleName)
    strCustomScaleName=char(0);
end

[status] = daq.ni.NIDAQmx.DAQmxCreateCIPulseWidthChan(taskHandle, strCounter,...
    strNameToAssignToChannel, minVal, maxVal, units, startingEdge, strCustomScaleName);