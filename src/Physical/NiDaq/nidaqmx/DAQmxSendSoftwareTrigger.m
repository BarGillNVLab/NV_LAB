function status = DAQmxSendSoftwareTrigger(taskHandle, triggerID)

[status] = daq.ni.NIDAQmx.DAQmxSendSoftwareTrigger(uint64(taskHandle), int32(daq.ni.NIDAQmx.DAQmx_Val_AdvanceTrigger));