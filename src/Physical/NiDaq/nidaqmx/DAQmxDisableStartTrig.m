function status = DAQmxDisableStartTrig(task)

status = calllib('mynidaqmx','DAQmxDisableStartTrig',task);
