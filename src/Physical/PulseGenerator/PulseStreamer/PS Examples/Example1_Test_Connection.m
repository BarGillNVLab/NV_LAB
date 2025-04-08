%% Example 1: Test connection and get hardware info.
% This script connects to PulseStreamer and prints: 
%  - MAC address of the ethernet interface 
%  - Serial number of the Pulse Streamer
%  - Firmware version
%  - Version of the API class
%

clear all;

% Add API functions to MATLAB path
addpath('PulseStreamer');

% DHCP is activated in factory settings
% IP address of the pulse streamer (default hostname is PulseStreamer)
ipAddress = 'pulsestreamer';

% connect to the pulse streamer
ps = PulseStreamer(ipAddress);

% Print summary to MATLAB console
fprintf('*** Pulse Streamer ***\n');
fprintf('MAC address:   %s\n', ps.getSerial(PSSerial.MAC));
fprintf('Serial:        %s\n', ps.getSerial(PSSerial.Serial));
fprintf('Firmware ver:  %s\n', ps.getFirmwareVersion());
fprintf('API version:   %s\n', ps.class_ver);

