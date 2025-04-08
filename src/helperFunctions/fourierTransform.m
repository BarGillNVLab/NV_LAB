function [frequency, amplitude] = fourierTransform(time, signal, LPF, toPlot)
% fourier transform:
% frequency in Hz, from -pi to pi
% LPF: Low pass filter. 0 for no filtering, 1 for DC filter, specific frequency for filter below this value.
% toPlot: boolean. if to plot the fourier transform

if ~exist('LPF', 'var')
    LPF = 0;
end

if ~exist('toPlot', 'var')
    toPlot = 0;
end

dt = time(2) - time(1);
frequency = linspace(-0.5/dt,0.5/dt, length(time));
amplitude = fftshift(fft(signal));

if LPF == 1
    i = length(amplitude)/2;
    if mod(i,2)
        amplitude(i+0.5) = 0;
    else
        amplitude(i:i+1) = [0 0];
    end
elseif LPF > 0
    amplitude(abs(frequency) < LPF) = 0;
end

if toPlot
    figure;
    plot(frequency, abs(amplitude.^2));
    xlabel('frequency');
    ylabel('power');
    title('DFT plot');
end