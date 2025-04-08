function [time, signal] = InvFourierTransform(frequency, amplitude)
% inverse fourier transform:
% frequency in Hz, from -pi to pi

df = frequency(2) - frequency(1);
time = linspace(0,1/df, length(frequency));
signal = ifft(ifftshift(amplitude));