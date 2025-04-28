% Clean up previous connections
imaqreset;

% Create camera object
camera = videoinput('gentl', 1, 'Mono8');
src = getselectedsource(camera);

% Configure manual trigger
triggerconfig(camera, 'manual');
camera.FramesPerTrigger = 1;    % <-- 1 frame per trigger
camera.TriggerRepeat = 9;       % <-- 9 repeats → total of 10 triggers allowed

src.BinningHorizontal = 3;
src.BinningVertical = 3;
src.ExposureAuto = 'Continuous';  % or src.ExposureTime = xxx

% Start camera (arms it)
start(camera);

if ~strcmp(camera.Running, 'on')
    error('Camera is not running after start().');
end

% Send 10 software triggers
disp('Sending triggers...');
for i = 1:10
    trigger(camera);   % one trigger for each frame
    pause(0.015);
end

% Wait for acquisition to complete
timeoutInSeconds = 5;
disp('Waiting for acquisition to complete...');
wait(camera, timeoutInSeconds);

% Now retrieve 10 frames
disp('Retrieving frames...');
   % Pull all frames at once

stop(camera);
[allFramesArray, timeData, metadata] = getdata(camera, 10);
% Display the first frame
figure;
imshow(allFramesArray(:,:,1), []);
title('First Captured Frame');

% Cleanup
delete(camera);
clear camera;
disp('Camera session closed.');
