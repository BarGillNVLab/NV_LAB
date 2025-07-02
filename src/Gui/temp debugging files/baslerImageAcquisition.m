%%
% Clean up previous connections
imaqreset;

% Create camera object
camera = videoinput('gentl', 1, 'Mono8');
src = getselectedsource(camera);

% Configure camera and MATLAB for manual (software) trigger
src.TriggerSelector = 'FrameStart';
src.TriggerSource = 'Software';
src.TriggerMode = 'On';

triggerconfig(camera, 'manual');
camera.FramesPerTrigger = 1;
camera.TriggerRepeat = 9;  % Total 10 frames = 1 + 9


% Check if frame rate is a supported property
if isprop(src, 'AcquisitionFrameRate')
    fprintf('Current frame rate: %.2f fps\n', src.AcquisitionFrameRate);
    
    % Check property info for limits
    info = propinfo(src, 'AcquisitionFrameRate');
    fprintf('Allowed frame rate range: %.2f - %.2f fps\n', ...
        info.ConstraintValue(1), info.ConstraintValue(2));
else
    disp('Frame rate property not directly available for this camera.');
end

%%
src.BinningHorizontal = 1;
src.BinningVertical = 1;
src.ExposureAuto = 'Off';
src.ExposureTime = 20000;  % 10 ms

% Start (arms the camera for manual triggering)
start(camera);

% Confirm camera is ready
if ~isrunning(camera)
    error('Camera failed to start.');
end

% Send 10 software triggers
disp('Sending triggers...');
nTriggers = 10;
for i = 1:nTriggers
    trigger(camera);        % Send one software trigger
    pause(0.025);           % Add a short gap between triggers (15 ms)
end

% Wait until all frames are acquired
timeoutInSeconds = 5;
disp('Waiting for acquisition...');
wait(camera, timeoutInSeconds);


% Check acquired frame count
nAcquired = camera.FramesAcquired;
if nAcquired < nTriggers
    warning('Timeout or missed triggers: only %d of %d frames acquired.', nAcquired, nTriggers);
else
    disp('✅ All frames acquired successfully.');
end

% Retrieve acquired frames
if nAcquired > 0
    [allFrames, timeData, metadata] = getdata(camera, nAcquired);
else
    warning('No frames were acquired.');
    allFrames = [];
end

% Stop and clean up
stop(camera);
delete(camera);
clear camera;

% Display first frame (if available)
if ~isempty(allFrames)
    figure;
    imshow(allFrames(:,:,1), []);
    title('First Captured Frame');
end
%%
% Connect to the Basler camera
imaqreset;
info = imaqhwinfo('gentl');  % or 'gige', 'basler', etc., depending on your setup
deviceInfo = info.DeviceInfo(1);  % use the first available camera
vid = videoinput('gentl', deviceInfo.DeviceID, deviceInfo.SupportedFormats{1});
src = getselectedsource(vid);

% --- Check ExposureMode support ---
if isprop(src, 'ExposureMode')
    fprintf('[INFO] ExposureMode is supported.\n');
    try
        % Query valid options (some cameras expose it as enum or string set)
        propInfo = propinfo(src, 'ExposureMode');
        if isfield(propInfo, 'ConstraintValue') && any(strcmp('TriggerWidth', propInfo.ConstraintValue))
            fprintf('[INFO] "TriggerWidth" is a valid value for ExposureMode.\n');
        else
            fprintf('[WARN] "TriggerWidth" is NOT listed among valid ExposureMode values.\n');
        end
    catch
        fprintf('[WARN] Could not query allowed values for ExposureMode.\n');
    end
else
    fprintf('[ERROR] ExposureMode property is NOT supported on this camera.\n');
end

% --- Check ExposureOverlapTimeMaxAbs support ---
if isprop(src, 'ExposureOverlapTimeMaxAbs')
    fprintf('[INFO] ExposureOverlapTimeMaxAbs is supported.\n');
else
    fprintf('[ERROR] ExposureOverlapTimeMaxAbs is NOT supported on this camera.\n');
end

% Cleanup
delete(vid);
clear vid;
%%
vid = videoinput('gentl', 1); 
src = getselectedsource(vid);
