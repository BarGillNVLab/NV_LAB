function status = DAQmxSetDigitalLogicFamilyPowerUpState(deviceName, logicFamily)

% status = calllib('mynidaqmx','DAQmxSetDigitalLogicFamilyPowerUpState',...
%     deviceName, int32(logicFamily));
[status] = daq.ni.NIDAQmx.DAQmxSetDigitalLogicFamilyPowerUpState(deviceName, int32(logicFamily));
