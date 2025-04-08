function status = DAQmxCreateCICountEdgesChan(taskHandle,counter,nameToAssignToChannel,...
    edge, initialCount, countDirection)

if isempty(nameToAssignToChannel)
    nameToAssignToChannel=char(0);
end


[status]=daq.ni.NIDAQmx.DAQmxCreateCICountEdgesChan(taskHandle,counter,...
    nameToAssignToChannel, int32(edge), uint32(initialCount), int32(countDirection));

