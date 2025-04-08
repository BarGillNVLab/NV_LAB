currentPath = 'G:\\My Drive\\NV Lab\\Control code\\prod\\helperFunctions\\setup 7 run scripts\\setup calibration\\2025_02_19\\';
main;
h = Helmholtz;
h.load('G:\My Drive\NV Lab\Control code\prod\helperFunctions\setup 7 run scripts\setup calibration\2024_03_10\helmholtz.mat');
h.control('auto');

%% Time delay
delays = ([-100:10:100]) * 1e-6;
for i = 2:length(delays)
    b = AWGExpRabi;
    b.isTracking = 0; b.nChannels = 2; b.GIMeas = 0; b.AWGorSRSswitch = 0; b.lastDelay = 1;
    b.amplitude = -10;
    b.repeats = 3000;
    b.averages = 1;
    b.tau = 0.005:0.01:0.4;
    b.referenceDetectionDuration = 0.5;
    b.detectionDuration = 0.5;
    b.frequency = 2761;
    
    b.timeDelay = delays(i);
    
    b.run;
    str = [currentPath, 'time delay\\Rabi_timeDelay_', num2str(delays(i)*1e6), 'ps'];
    b.save(str);
end
%%
N = length(delays);
freq = zeros(1,N);
for i = 1:length(delays)
    str = [currentPath, 'time delay\\Rabi_timeDelay_', num2str(delays(i)*1e6), 'ps.mat'];
    load(str);
    [~, f] = rabiFit(myStruct.AWGRabi, 0, 0, 1, 2);
    pause(1);
    close(gcf);
    freq(i) = f;
end

[maxFreq, maxLocs] = max(freq);
d = delays*1e6;
startPoint = [maxFreq, d(maxLocs), 1/myStruct.AWGRabi.frequency * 1e6 * sqrt(2)];
f = 'a*(1+cos(2*pi*(x-x0)/T))';
myfittype = fittype(f, 'coefficients', {'a', 'x0', 'T'});
fitObj = fit(d', freq', myfittype, 'StartPoint', startPoint);
coeff = coeffvalues(fitObj);

figure; hold on;
di = d(1):0.1:d(end);
plot(di, fitObj(di));
plot(d, freq, '.', 'MarkerSize', 7, 'color', 'k');
ylabel('Rabi frequency (MHz)');
xlabel('delay time (ps)');
title('Delay time optimization');
annotation('textbox', [0.4,0.15,0.3,0.1], 'String', sprintf('Time delay = %.0f ps', coeff(2)), 'FontSize', 14, 'LineStyle', 'None');

%% Resonance frequency
f0 = 2766;
B0 = 38.7;
frequencies = 2750:5:2770;
B = round(B0 - (frequencies - f0) / 2.8, 2);

h = getObjByName('Helmholtz');
AWG = getObjByName('TektronixAWG-SN-NA');
for i = 1%2:length(frequencies)
    b = AWGExpRabiCont;
    b.isTracking = 0; b.nChannels = 2; b.GIMeas = 0; b.AWGorSRSswitch = 0; b.lastDelay = 1;
    b.amplitude = -25 + [0 0];
    b.repeats = 3000;
    b.averages = 3;
    b.tau = 0.005:0.015:0.5;
    b.referenceDetectionDuration = 0.5;
    b.detectionDuration = 0.5;
    b.timeDelay = 25e-6;
    
    b.frequency = frequencies(i);
    h.setBrho(B(i));
    
    b.run;
    str = [currentPath, 'resonance\Rabi_resonance_', num2str(frequencies(i)), '_MHz'];
    b.save(str);
end

%%
N = length(frequencies);
freq = zeros(1,N);
for i = 1:length(frequencies)
    str = [currentPath, 'resonance\Rabi_resonance_', num2str(frequencies(i)), '_MHz'];
    load(str);
    % if i>5
    [~, f] = rabiFit(myStruct.AWGRabi, 0, 0, 1, 1);
    % else
    %     [~, f] = rabiFit(myStruct.AWGRabi, 0, 0, 1, '', 'f', 3, 'q', 2);
    % end
    pause(1);
    close(gcf);
    freq(i) = f;
end
%%
myfittype = fittype('a * s^2 / ((x-f0)^2 + s^2)+c', 'coefficients',{'a','f0', 's', 'c'});
myfit = fit(frequencies', freq', myfittype, 'StartPoint', [max(freq), mean(frequencies), 25, 1]);
coeff = coeffvalues(myfit);
f0 = coeff(2);

figure; hold on;
f = frequencies(1):0.1:frequencies(end);
plot(f, myfit(f));
plot(frequencies, freq, '*');
ylabel('Rabi frequency (MHz)');
xlabel('resonance frequency (MHz)');
title('Resonance frequency optimization');
annotation('textbox', [0.4, 0.2, 0.3, 0.1], 'String', sprintf('f_0 = %.1f MHz', f0), 'LineStyle', 'none');

%% Amplitude differance
mwChan = {'MW', 'MW2'};
freq = zeros(1, 2);
for i = 1:2
    b = AWGExpRabi;
    b.loadJsonParams;
    b.repeats = 3000;
    b.averages = 1;
    b.tau = 0.005:0.02:0.8;

    b.amplitude = -25 - (i==1)*2;

    b.nChannels = 1;
    b.MWChannel = mwChan{i};
    b.run;

    [~, f] = rabiFit(b, 0, 0, 1, '', 'q', 1);
    freq(i) = f;
end

da = 20*log10(freq(1)/freq(2));
%%
b = AWGExpRabi;
b.loadJsonParams;
b.repeats = 3000;
b.averages = 3;
b.tau = 0.005:0.02:0.8;

b.amplitude = -25 - abs(da);

b.nChannels = 1;
if da < 0
    b.MWChannel = mwChan{2};
else
    b.MWChannel = mwChan{1};
end
b.run;

[~, f] = rabiFit(b, 0, 0, 1, '', 'q', 1);


%% Saturation power - Rabi
rabiCont = 0;
amplitudes = -20:2:-6;
for i = 1%:length(amplitudes)
    if rabiCont
        b = AWGExpRabiCont;
    else
        b = AWGExpRabi;
    end
    b.isTracking = 0; b.nChannels = 2; b.GIMeas = 0; b.AWGorSRSswitch = 0; b.lastDelay = 0.2;
    b.repeats = 3000;
    b.averages = 1;
    b.tau = 0.005:0.01:0.6;
    b.referenceDetectionDuration = 0.5;
    b.detectionDuration = 0.5;
    b.timeDelay = 20e-6;
    b.frequency = 2756;
    
    b.amplitude = amplitudes(i) + [0 0];
    
    b.run;
    if rabiCont
        str = [currentPath, 'RabiCont power\\Rabi_amplitude_', strrep(num2str(amplitudes(i)), '.', 'p'), 'dBm'];
    else
        str = [currentPath, 'Rabi power\\Rabi_amplitude_', strrep(num2str(amplitudes(i)), '.', 'p'), 'dBm'];
    end
    b.save(str);
end

%%
rabiCont = 1;
N = length(amplitudes);
freq = zeros(1, N);
for i = 1:length(amplitudes)
    if rabiCont
        str = [currentPath, 'RabiCont power\\Rabi_amplitude_', strrep(num2str(amplitudes(i)), '.', 'p'), 'dBm'];
    else
        str = [currentPath, 'Rabi power\\Rabi_amplitude_', strrep(num2str(amplitudes(i)), '.', 'p'), 'dBm'];
    end
    load(str);
    [~, f] = rabiFit(myStruct.AWGRabi, 0, 0, 1, 2);
    freq(i) = f;
    pause(1);
    close(gcf);
end

field = 10.^(amplitudes./20);
field = field/max(field);
%%
myfittype = fittype('a*(1-exp(-((10.^(x/20))/x0)))', 'coefficients',{'a','x0'});
myfit = fit(amplitudes', freq', myfittype, 'StartPoint', [max(freq)*2, 0.5]);
coeff = coeffvalues(myfit);

figure;
a = -35:0.01:amplitudes(end)+5;
semilogy(a, myfit(a));
hold on
semilogy(amplitudes, freq, '*');
ylabel('Rabi frequency (MHz)');
xlabel('amplitude field (dBm)');
title('power saturation');
box on; grid on;

