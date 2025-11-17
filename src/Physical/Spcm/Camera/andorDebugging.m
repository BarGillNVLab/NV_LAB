disp('Andor SDK3 Accumlate Example');
[rc] = AT_InitialiseLibrary();
AT_CheckError(rc);
[rc,hndl] = AT_Open(1);
AT_CheckError(rc);
disp('Camera initialized');
[rc, implemented] = AT_IsImplemented(hndl, 'AOIBinning');
if implemented
    AT_SetEnumString(hndl,'FeatureName','SomeValue');
else
    disp('FeatureName is not implemented on this camera.');
end
[rc] = AT_SetFloat(hndl,'ExposureTime',0.01);
AT_CheckWarning(rc);
[rc] = AT_SetEnumString(hndl,'CycleMode','Fixed');
AT_CheckWarning(rc);
[rc] = AT_SetEnumString(hndl,'TriggerMode','Software');
AT_CheckWarning(rc);
[rc] = AT_SetEnumString(hndl,'SimplePreAmpGainControl','16-bit (low noise & high well capacity)');
AT_CheckWarning(rc);
[rc] = AT_SetEnumIndex(hndl, 'AOIBinning', 1);
AT_CheckWarning(rc);
frameCount = 10;
[rc] = AT_SetInt(hndl,'FrameCount',frameCount);
AT_CheckWarning(rc);

accumulateCount=1; 
[rc] = AT_SetInt(hndl, 'AccumulateCount', accumulateCount);
AT_CheckWarning(rc);
[rc,imagesize] = AT_GetInt(hndl,'ImageSizeBytes');
AT_CheckWarning(rc);
[rc,height] = AT_GetInt(hndl,'AOIHeight');
AT_CheckWarning(rc);
[rc,width] = AT_GetInt(hndl,'AOIWidth');  
AT_CheckWarning(rc);
[rc,xCoo] = AT_GetInt(hndl,'AOILeft');
AT_CheckWarning(rc);
[rc,yCoo] = AT_GetInt(hndl,'AOITop');  
AT_CheckWarning(rc);
[rc,stride] = AT_GetInt(hndl,'AOIStride'); 
AT_CheckWarning(rc);
for x=1:10
    [rc] = AT_QueueBuffer(hndl,imagesize);
    AT_CheckWarning(rc);
end
disp('Starting acquisition...');
[rc] = AT_Command(hndl,'AcquisitionStart');
AT_CheckWarning(rc);
buf2 = zeros(width,height,10);
i=0;
while(i<frameCount/accumulateCount)
    AT_Command(hndl, 'SoftwareTrigger');
    AT_CheckWarning(rc);
    i = i+1;
    pause(1);
end
i=1;
while(i<11)
    [rc,buf] = AT_WaitBuffer(hndl,1000);
    AT_CheckWarning(rc);
    [rc,buf2(:,:,i)] = AT_ConvertMono16ToMatrix(buf,height,width,stride);
    AT_CheckWarning(rc);
    i = i+1;
end
for i = 1:10
    h = imagesc(zeros(width,height));
    set(h,'CData',buf2(:,:,i));
    colorbar
    pause(1)
end
disp('Acquisition complete');
[rc] = AT_Command(hndl,'AcquisitionStop');
AT_CheckWarning(rc);
[rc] = AT_Flush(hndl);
AT_CheckWarning(rc);
[rc] = AT_Close(hndl);
AT_CheckWarning(rc);
[rc] = AT_FinaliseLibrary();
AT_CheckWarning(rc);
disp('Camera shutdown');
%%
disp('Andor SDK3 Accumlate Example');
[rc] = AT_InitialiseLibrary();
AT_CheckError(rc);
[rc,hndl] = AT_Open(0);
AT_CheckError(rc);
disp('Camera initialized');
[rc] = AT_SetFloat(hndl,'ExposureTime',0.001);
AT_CheckWarning(rc);
[rc, framerate] = AT_GetFloat(hndl, 'FrameRate');
[rc] = AT_SetEnumString(hndl,'CycleMode','Fixed');
AT_CheckWarning(rc);
[rc] = AT_SetEnumString(hndl,'TriggerMode','Internal');
AT_CheckWarning(rc);
[rc] = AT_SetEnumString(hndl,'SimplePreAmpGainControl','16-bit (low noise & high well capacity)');
AT_CheckWarning(rc);
[rc, encodeInd] = AT_GetEnumIndex(hndl, 'PixelEncoding') ;
disp(encodeInd);
for i =0:11
    [rc,bin] = AT_GetEnumStringByIndex(hndl,'PixelEncoding',i, 64);
    disp(bin);
end
[rc] = AT_SetInt(hndl, 'AOIBinning', 4);
[rc,height] = AT_GetInt(hndl,'AOIHeight');
AT_CheckWarning(rc);
[rc,width] = AT_GetInt(hndl,'AOIWidth');  
AT_CheckWarning(rc);
[rc,stride] = AT_GetInt(hndl,'AOIStride'); 
AT_CheckWarning(rc);
[rc] = AT_Close(hndl);
AT_CheckWarning(rc);
[rc] = AT_FinaliseLibrary();
AT_CheckWarning(rc);
disp('Camera shutdown');

%% Andor SDK3 — 5 External Exposure frames, extract AFTER capture (no display)
disp('Andor SDK3 External Exposure: capture 5, then extract');

% --- Init & open
AT_CheckError(AT_InitialiseLibrary());
[rc,hndl] = AT_Open(0); AT_CheckError(rc);
disp('Camera initialized');
AT_CheckWarning(AT_Command(hndl,'AcquisitionStop'));
% --- Configure (set everything BEFORE reading sizes)
AT_CheckWarning(AT_SetEnumString(hndl,'CycleMode','Fixed'));
AT_CheckWarning(AT_SetInt(hndl,'FrameCount',5));

% External Exposure = integrate while trigger input is High
AT_CheckWarning(AT_SetEnumString(hndl,'TriggerMode','External Exposure'));
% pulsestreamer connection


% Safe encoding/binning; adjust if needed
AT_CheckWarning(AT_SetEnumString(hndl,'PixelEncoding','Mono16'));


% --- Query sizes AFTER config
[rc,height]   = AT_GetInt(hndl,'AOIHeight');      AT_CheckWarning(rc);
[rc,width]    = AT_GetInt(hndl,'AOIWidth');       AT_CheckWarning(rc);
[rc,stride]   = AT_GetInt(hndl,'AOIStride');      AT_CheckWarning(rc);
[rc,imgBytes] = AT_GetInt(hndl,'ImageSizeBytes'); AT_CheckWarning(rc);

% --- Queue 5 buffers (one per frame)
for k = 1:5
    AT_CheckWarning(AT_QueueBuffer(hndl, imgBytes));
end

% --- Start acquisition
AT_CheckWarning(AT_Command(hndl,'AcquisitionStart'));
pause(0.02);  % small arm time
% Repeat the sequence 5 times:


% --- Simulate the 5 external exposure gates (capture phase only)
% Assumes: btrigger(gate_s) sets trigger line High for gate_s seconds, then Low
gate_s = 0.003;   % 3 ms per exposure (ensure >= camera min integration)

% In Fixed mode, the camera will auto-stop after 5 frames,
% but calling stop explicitly is fine and keeps intent clear.
% AT_CheckWarning(AT_Command(hndl,'AcquisitionStop'));

% --- Extraction phase (after all frames are taken)
timeout_ms = 2000;
rawBufs = cell(1,5);   % store raw buffers first (optional but explicit)

for k = 1:5
    [rc, buf] = AT_WaitBuffer(hndl, timeout_ms);   AT_CheckWarning(rc);
    rawBufs{k} = buf;   % keep raw buffers so extraction is strictly "after"
end

% Convert ALL buffers to frames now
imgs = zeros( width, height, 5);
for k = 1:5
    buf = rawBufs{k};
   
    % Wrapper returns POINTER (int64): use SDK3 converter
    [rc, frame] = AT_ConvertMono16ToMatrix(buf, height, width, stride);
    AT_CheckWarning(rc);

    imgs(:,:,k) = frame;
end

% --- Cleanup
AT_CheckWarning(AT_Flush(hndl));      % return queued buffers to driver
AT_CheckWarning(AT_Close(hndl));
AT_CheckWarning(AT_FinaliseLibrary());
disp('Done. Frames are in imgs(:,:,1..5).');
