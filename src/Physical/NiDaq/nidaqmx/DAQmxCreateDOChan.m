function [status] = DAQmxCreateDOChan(taskHandle, strLines,...
    strNameToAssignToLines, lineGrouping)

if isempty(strNameToAssignToLines)
    strNameToAssignToLines=char(0);
end

[status] = daq.ni.NIDAQmx.DAQmxCreateDOChan(taskHandle,strLines,strNameToAssignToLines,int32(lineGrouping));