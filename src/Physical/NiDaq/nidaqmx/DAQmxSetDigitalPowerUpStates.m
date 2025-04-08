function [ status ] = DAQmxSetDigitalPowerUpStates(deviceName, channelNames, state)

[status] = daq.ni.NIDAQmx.DAQmxSetDigitalPowerUpStates(char(deviceName), char(channelNames), int32(state), t{:});
