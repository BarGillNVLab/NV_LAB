function [I, Q] = generateIQwaveform(waveform, dt, f0, DecimationFactor, BW)
% This function used to caculate the IQ control you need in order to
% generate the 'waveform'.
% For example - if you want some complicated MW control of the NV, you just
% need to create it as full waveform, and then the I and Q is the control
% input you should enter the SRS.
% 'waveform': vector of the waveform to generate
% 'dt': time step of the 'waveform'
% 'f0': The carrier frequency to work with
% 'DecimationFactor': Is the factor between the time step of waveform to the time step in I and Q.
% 'waveform' length must be an integer multiple of the 'DecimationFactor'
% 'BW': the bandwidth of the IQ modulation.
% Output:
% 'I' and 'Q': vectors of the IQ control



Fs = 1/dt;
dwnConv = dsp.DigitalDownConverter(...
  'DecimationFactor', DecimationFactor,...
  'SampleRate', Fs,...
  'Bandwidth', BW,...
  'StopbandAttenuation', 150,...
  'PassbandRipple',0.2,...
  'CenterFrequency',f0);
S = dwnConv(waveform');
I = smooth(real(S),10);
Q = -smooth(imag(S),10);
