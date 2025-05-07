classdef StageScanner < EventSender & EventListener & Savable
    %STAGESCANNER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        mScan
        mScanExtraInfo % Hist, if available.
        mStageName
        mStageScanParams
        mFocusGrade = []            % for widefield focus search
        mCurrentlyScanning = false
    end
    
    properties (Constant)
        NAME = 'stageScanner'
        
        EVENT_SCAN_UPDATED = 'scanUpdated'
        EVENT_SCAN_STARTED = 'scanStarted'
        EVENT_SCAN_FINISHED = 'scanFinished'
        EVENT_SCAN_STOPPED_MANUALLY = 'scanStoppedManually'
        % events can be sent with both EVENT_SCAN_FINISHED and EVENT_SCAN_STOPPED_MANUALLY
        % such events will always have EVENT_SCAN_FINISHED = true,
        %                and will have EVENT_SCAN_STOPPED_MANUALLY = (true or false)
        
        PROPERTY_SCAN_PARAMS = 'scanParameters'
        
        TRIALS_AMOUNT_ON_ERROR = 4;
    end
    
    methods (Access = private)
        function obj = StageScanner
            obj@EventSender(StageScanner.NAME);
            obj@Savable(StageScanner.NAME);
            obj@EventListener(SaveLoadCatImage.NAME);
            obj.clear();
        end
    end
    
    methods
        function sendEventScanFinished(obj)
            obj.sendEvent(struct( ...
                obj.EVENT_SCAN_FINISHED, true, ...
                obj.EVENT_SCAN_STOPPED_MANUALLY, false, ...
                obj.PROPERTY_SCAN_PARAMS, obj.mStageScanParams));
        end
        function sendEventScanStopped(obj)
            obj.sendEvent(struct(...
                obj.EVENT_SCAN_FINISHED, true, ...
                obj.EVENT_SCAN_STOPPED_MANUALLY, true, ...
                obj.PROPERTY_SCAN_PARAMS, obj.mStageScanParams));
        end
        function sendEventScanStarting(obj)
            obj.sendEvent(struct(obj.EVENT_SCAN_STARTED, true));
        end
        function sendEventScanUpdated(obj, scanResults, scanExtraInfo)
            axis1 = obj.mStageScanParams.getFirstScanAxisVector;
            axis2 = obj.mStageScanParams.getSecondScanAxisVector;
            phAxes = {axis1, axis2};
            scanAxes = obj.mStageScanParams.getScanAxes;
            stageName = obj.mStageName;
            botLabel = obj.getBottomScanLabel;
            leftLabel = obj.getLeftScanLabel;
            if ~exist('scanExtraInfo', 'var')
                scanExtraInfo = struct();
            end
            extra = EventExtraScanUpdated(scanResults, phAxes, scanAxes, stageName, botLabel, leftLabel, scanExtraInfo);
            obj.sendEvent(struct(obj.EVENT_SCAN_UPDATED, extra));
        end
        
        function startScan(obj, advancedScanParams)
            if isnan(obj.mStageName)
                obj.sendError(['Can''t start scan: unknown stage name!' ...
                    'Please call stageScanner.switchTo(your_stage_name)' ...
                    'before calling stageScanner.startScan(). Exiting']);
            end
            
            stage = getObjByName(obj.mStageName);
            if isempty(stage); throwBaseObjException(obj.mStageName); end
            if ~exist('advancedScanParams', 'var')
                obj.mStageScanParams = stage.scanParams.copy;
                obj.mStageScanParams.scanBlocks = {};
            else
                obj.mStageScanParams = advancedScanParams;
            end
            isFastScan = obj.mStageScanParams.fastScan;
            stage.FastScan(isFastScan);
            
            % From now on, changes in the GUI (from\to\fixed\numPoints)
            % won't affect the StageScanParmas object stored here.
            
            obj.mCurrentlyScanning = true;
            obj.sendEventScanStarting();
            
            spcm = getObjByName(Spcm.NAME);
            if isempty(spcm); throwBaseObjException(Spcm.NAME); end
            spcm.setSPCMEnable(true);
            
            try
                stage.sanityCheckForScanRange(obj.mStageScanParams);
            catch err
                obj.mCurrentlyScanning = false;
                obj.sendEventScanStopped;
                rethrow(err)
            end
            
            if obj.mStageScanParams.isMWContrastScan
                %%% Set Frequency Generator
                fg = getObjByName(FrequencyGenerator.getDefaultFgName); 
                fg.amplitude = obj.mStageScanParams.MWAmplitude;
                fg.frequency = obj.mStageScanParams.MWFrequency;
                fg.output = 1;
            end
            timerVal = tic;
            disp('Initiating scan...');
            try
                [kcpsScanMatrix, extraInfo] = obj.scan(stage, spcm, obj.mStageScanParams);
                % kcps = kilo counts per second
                
                while (stage.scanParams.continuous && obj.mCurrentlyScanning)
                    [kcpsScanMatrix, extraInfo] = obj.scan(stage, spcm, obj.mStageScanParams, kcpsScanMatrix, extraInfo);
                    drawnow; % todo check what happens if removing this line
                end
            catch err
                % We couldn't scan. Wrap it up nicely
                spcm.setSPCMEnable(false);
                obj.mCurrentlyScanning = false;
                stage.sendEventStageAvailabilityChanged;
                if obj.mStageScanParams.isMWContrastScan
                    fg = getObjByName(FrequencyGenerator.getDefaultFgName);
                    fg.output = 0;
                end
                
                rethrow(err)
            end
            if obj.mStageScanParams.isMWContrastScan
                fg = getObjByName(FrequencyGenerator.getDefaultFgName);
                fg.output = 0;
            end
            
            % Maybe we didn't encounter an error, but the scan still did not happen
            if isempty(kcpsScanMatrix)
                spcm.setSPCMEnable(false);
                obj.mCurrentlyScanning = false;
                stage.sendEventStageAvailabilityChanged;
                return
            end
            
            toc(timerVal)
            
            spcm.setSPCMEnable(false);
            obj.mScan = kcpsScanMatrix;
            obj.mScanExtraInfo = extraInfo;
            
            scanStoppedManually = ~obj.mCurrentlyScanning;  % maybe someone has changed this boolean meanwhile
            obj.mCurrentlyScanning = false;                 % So when events are sent, they will know we are done.
            
            if scanStoppedManually
                obj.sendEventScanStopped();
            else
                obj.sendEventScanFinished();
            end
            % (At least) two things should happen by this event:
            % 1. ImageScanResult will update
            % 2. SaveLoad will get the new scan, save it into local
            %    struct, and (if needed) will autosave it.
            
            stage.sendEventPositionChanged;
        end
        
        function [kcpsScanMatrix, extraInfo] = scan(obj, stage, spcm, scanParams, kcpsScanMatrixOptional, optionalExtraInfo)
            % Scan the stage.
            % stage - an object deriving from ClassStage
            % spcm - an object deriving from Spcm
            % scanParams - the scan parameters. an object deriving from StageScanParams
            % kcpsScanMatrixOptional - the last scanned matrix, if exists
            skipCreatingMatrix = exist('kcpsScanMatrixOptional', 'var');
            
            kcpsScanMatrix = [];        % Return value for nonvalid dinemsion number
            nDimensions = sum(~scanParams.isFixed);
            switch nDimensions
                case 0
                    EventStation.anonymousWarning('Nothing to scan, dude!');
                    return;
                case 1
                    % One dimensional scanning
                    [kcpsScanMatrix, extraInfo] = obj.scan1D(stage, spcm, scanParams);
                case 2
                    % 2D scan
                    if skipCreatingMatrix
                        [kcpsScanMatrix, extraInfo] = obj.scan2D(stage, spcm, scanParams, kcpsScanMatrixOptional, optionalExtraInfo);
                    else
                        [kcpsScanMatrix, extraInfo] = obj.scan2D(stage, spcm, scanParams);
                    end
                case 3
                    EventStation.anonymousWarning('3D scan is not implemented!');
                otherwise
                    EventStation.anonymousWarning('%d-dimensional scan requested. String thoery is not yet implemented!\n', nDimensions);
            end
        end
        
        function [kcpsValue, steValue] = scanPoint(obj, stage, spcm, scanParams)
            % scan "0D"
            % input arg's:
            %    stage - object deriving from ClassStage
            %    spcm - object deriving from Spcm
            %    scanParams - object deriving from StageScanParams
            % output:
            %    kcpsValue - double. Value read by the spcm
            
            % To be used by TrackablePosition. Should NOT be used for
            % actual scanning.
            
            %%%% move to location %%%%
            pos = scanParams.fixedPos;
            phAxes = stage.availableAxes;
            stage.move(phAxes, pos);
            
            %%%% try to scan %%%%
            scanOk = false;
            for trial = 1:StageScanner.TRIALS_AMOUNT_ON_ERROR
                try
                    spcm.prepareReadByTime(scanParams.pixelTime);
                    [kcps, kcps_ste] = spcm.readFromTime();
                    spcm.clearTimeRead;
                    if kcps == 0
                        obj.sendError('No Signal Detected!')
                    end
                    scanOk = true;
                    break;
                catch err
                    %                    rethrow(err) % Uncomment to debug
                    warning(err.message);
                    fprintf('Reading from SPCM failed at trial %d, attempting to rescan.\n', trial);
                end
            end
            
            % This line will be reached when break()ing out of the for,
            % or when all trials went without success
            if ~scanOk
                obj.sendError(sprintf('Reading from SPCM failed after %d trials', StageScanner.TRIALS_AMOUNT_ON_ERROR));
            end
            
            kcpsValue = kcps;
            steValue = kcps_ste;
        end
        
        function [kcpsScanVector, extraInfo] = scan1D(obj, stage, spcm, scanParams)
            % scan 1D
            % stage - an object deriving from ClassStage
            % spcm - an object deriving from Spcm
            % scanParams - the scan parameters. an object deriving from StageScanParams
            % returns - a vector of the scan
            
            % If the area to scan is bigger than the maximum scanning-area
            % of the stage, divide it to smallers chunks to scan
            
            % ~~~~ preparing variables: ~~~~
            isFastScan = scanParams.fastScan;
            nFlat = 0;      % A flat section at the start of ramp. parameter not needed genrally, a stage can overwrite if needed
            nOverRun = 0;   % Let the waveform over run the start and end. Not needed genrally, a stage can overwrite if needed
            tPixel = scanParams.pixelTime;
            maxScanSize = stage.ReturnMaxScanSize(1);
            nPixels = length(scanParams.getFirstScanAxisVector());
            isMWContrastScan = scanParams.isMWContrastScan;
            kcpsScanVector = zeros(nPixels, 1+isMWContrastScan);
            if isa(spcm, 'CameraControlled');obj.mFocusGrade = zeros(nPixels, 1);end
            axisToScan = scanParams.getScanAxes; % string of size 1
            x = scanParams.getScanAxisVector(1); % vector between [min, max] or the fixed position if exist
            y = scanParams.getScanAxisVector(2); % vector between [min, max] or the fixed position if exist
            z = scanParams.getScanAxisVector(3); % vector between [min, max] or the fixed position if exist
            
            bHasLiftime = spcm.hasLifetime();
            extraInfo = struct();
            spcm = getObjByName(Spcm.NAME);
            if bHasLiftime && ~isMWContrastScan
                extraInfo.hist = zeros(nPixels, spcm.nBins);
            end
            if isMWContrastScan
                pg = getObjByName(PulseGenerator.NAME);
            end
            
            if ~obj.mCurrentlyScanning
                return
            end
            
            % ~~~~ checks on size of scan ~~~~
            if (nPixels > maxScanSize)
                fprintf('Max number of points to scan is %d, %d were requested for %s axis. Scanning in parts.\n', maxScanSize, nPixels, axisToScan);
            end
            
            % ~~~~ continue scanning until finishing all the scan ~~~~
            
            vectorStartIndex = 1;
            while (vectorStartIndex <= nPixels)
                % every iteration in the "while" scans one chunk
                pixelsLeftToScan = nPixels - vectorStartIndex + 1;
                curPixelsAmountToScan = min(pixelsLeftToScan, maxScanSize);
                vectorEndIndex = vectorStartIndex + curPixelsAmountToScan - 1;
                nPoints = curPixelsAmountToScan + 2*(nFlat + nOverRun);
                timeout = 2*nPoints*tPixel;
                scanOk = false;
                
                % Prepare Scan
                
                prepareScanfuncName = sprintf('PrepareScan%s', upper(axisToScan));
                feval(prepareScanfuncName, stage, x, y, z, nFlat, nOverRun, tPixel);
                
                
                % try to scan
                kcps = zeros(curPixelsAmountToScan , size(kcpsScanVector, 2));
                focusGrade = zeros(size(kcps));
                for i = 1:size(kcpsScanVector, 2) % MW Contrast
                    for trial = 1:StageScanner.TRIALS_AMOUNT_ON_ERROR
                        if i==2
                            pg.on('MW');
                        end
                        try
                            if ~obj.mCurrentlyScanning
                                stage.AbortScan();
                                spcm.clearScanRead();  % todo - added to try resolving the problem. Wasn't here in the first place!
                                return
                            end

                            if isa(spcm, "CameraControlled")
                                spcm.prepareCountByStage(stage.name, curPixelsAmountToScan, timeout, isFastScan, tPixel);
                            else
                                spcm.prepareCountByStage(stage.name, curPixelsAmountToScan, timeout, isFastScan);
                            end
                            spcm.startScanCount();
                            
                            % scan stage
                            scanfuncName = sprintf('Scan%s', upper(axisToScan));
                            feval(scanfuncName, stage, x,y,z, nFlat, nOverRun, tPixel);
                            
                            % read counter
                            if isa(spcm, 'CameraControlled')
                                [kcps(:,i), ~, focusGrade(:,i)] = spcm.readFromScan();
                            else
                                kcps(:,i) = spcm.readFromScan();
                            end
                            if bHasLiftime && ~isMWContrastScan
                                hist = spcm.lastScanHist;
                            end
                            spcm.clearScanRead();
                            if ~nnz(kcps(:,i))
                                obj.sendError('No Signal Detected!')
                            end
                            
                            scanOk = true;
                            break;
                        catch err
%                             rethrow(err) % Uncomment to debug
                            warning(err.message);
                            
                            if ~obj.mCurrentlyScanning
                                stage.AbortScan();
                                return
                            end
                            fprintf('Scan failed at trial %d, attempting to rescan.\n', trial);
                        end
                    end
                    if i==2
                        pg.off('MW');
                    end
                end % MW Contrast
                
                % This line will be reached when break()ing out of the for,
                % or when all trials went without success
                stage.AbortScan();
                if ~scanOk; obj.sendError(sprintf('Scan failed after %d trials', StageScanner.TRIALS_AMOUNT_ON_ERROR));end
                
                % Update the scan results in the returned vector
                if isMWContrastScan % Contrast
                    kcpsScanVector(vectorStartIndex:vectorEndIndex, :) = kcps;
                    if ~isempty(obj.mFocusGrade); obj.mFocusGrade(vectorStartIndex:vectorEndIndex) = focusGrade(:, 1);end
                else
                    kcpsScanVector(vectorStartIndex:vectorEndIndex) = kcps;
                    if ~isempty(obj.mFocusGrade); obj.mFocusGrade(vectorStartIndex:vectorEndIndex) = focusGrade;end
                    if bHasLiftime
                        extraInfo.hist(vectorStartIndex:vectorEndIndex, :) = hist;
                    end
                end

                if ~isempty(obj.mFocusGrade)
                    extraInfo.FocusGrade = obj.mFocusGrade;
                end
                
                % Go tell everybody
                obj.sendEventScanUpdated(kcpsScanVector, extraInfo);
                
                % Prepare the next scan chunk
                vectorStartIndex = vectorEndIndex + 1;
            end
        end
        
        function [kcpsScanMatrix, extraInfo] = scan2D(obj, stage, spcm, scanParams, optionalKcpsScanMatrix, optionalExtraInfo)
            % Scans a 2D image.
            % stage - an object deriving from ClassStage
            % spcm - an object deriving from Spcm
            % scanParams - the scan parameters. an object deriving from StageScanParams
            % optionalKcpsScanMatrix - if exists, the previous scan results
            % returns - a matrix of the scan
            
            
            % Method:
            % First, check what would be the best way to scan (minimize
            % amount of scans needed)
            % Then, call scan2dChunk for each chunk to get scan results and combine them together
            
            % The movement between pixels in each line is called "axis a",
            % while movement between lines is called "axis b"
            
            if ~obj.mCurrentlyScanning
                return
            end
            
            isMWContrastScan = scanParams.isMWContrastScan;
            spcm = getObjByName(Spcm.NAME);
            
            if isempty(scanParams.scanBlocks) % Normal scan, look for chucks due to stages limits
                % ~~~~ preparing variables: ~~~~
                maxScanSize = stage.ReturnMaxScanSize(2);
                [axisAIndex, axisBIndex] = StageScanner.optimize2dScanDirections(maxScanSize, scanParams.copy);
                axisCIndex = setdiff(ClassStage.getAxis(ClassStage.SCAN_AXES), [axisAIndex, axisBIndex]);
                % axis c is where the zero point is not moving throgh the scan
                isFlipped = axisAIndex > axisBIndex;  % (for example, if axis y is before axis x, than "isFlipped" == true)
                isFastScan = scanParams.fastScan;    % a boolean
                tPixel = scanParams.pixelTime;   % time for each pixel
                numPointsAxisA = scanParams.numPoints(axisAIndex);
                numLinesAxisB = scanParams.numPoints(axisBIndex);
                vectorAxisA = scanParams.getScanAxisVector(axisAIndex);
                vectorAxisB = scanParams.getScanAxisVector(axisBIndex);
                pointAxisC = scanParams.getScanAxisVector(axisCIndex);
                chunksPerLine = ceil(numPointsAxisA / maxScanSize);
                
                bHasLiftime = spcm.hasLifetime();
                
                if exist('optionalKcpsScanMatrix', 'var')
                    kcpsScanMatrix = optionalKcpsScanMatrix;
                    extraInfo = optionalExtraInfo;
                else
                    extraInfo = struct();
                    if isFlipped
                        kcpsScanMatrix = zeros(numPointsAxisA, numLinesAxisB, 1+scanParams.isMWContrastScan);
                        if bHasLiftime && ~isMWContrastScan
                            extraInfo.hist = zeros(numPointsAxisA, numLinesAxisB, spcm.nBins);
                        end
                    else
                        kcpsScanMatrix = zeros(numLinesAxisB, numPointsAxisA, 1+scanParams.isMWContrastScan);
                        if bHasLiftime && ~isMWContrastScan
                            extraInfo.hist = zeros(numLinesAxisB, numPointsAxisA, spcm.nBins);
                        end
                    end
                end
                obj.mScan = kcpsScanMatrix;
                obj.mScanExtraInfo = extraInfo;
                
                %%%%%% iterate through the chunks and scan each chunk %%%%%%%
                startIndexAxisA = 1;
                for chunkIndex = 1 : chunksPerLine
                    if ~obj.mCurrentlyScanning
                        break;
                    end
                    
                    pixelsLeftAxisA = numPointsAxisA - startIndexAxisA + 1;
                    chunkSizeAxisA = min(maxScanSize, pixelsLeftAxisA);
                    endIndexAxisA = startIndexAxisA + chunkSizeAxisA - 1;
                    chunkAxisA = vectorAxisA(startIndexAxisA:endIndexAxisA);
                    chunkAxisB = vectorAxisB;  % no restriction on number of lines!
                    [kcpsScanMatrix, extraInfo] = obj.scan2dChunk(...
                        kcpsScanMatrix, spcm, stage, tPixel, chunkAxisA, chunkAxisB, ...
                        axisAIndex, axisBIndex, pointAxisC, isFastScan, isFlipped, ...
                        1, length(chunkAxisB), ...
                        startIndexAxisA, endIndexAxisA, ...
                        extraInfo);
                    obj.mScan = kcpsScanMatrix;
                    obj.mScanExtraInfo = extraInfo;
                    obj.sendEventScanUpdated(kcpsScanMatrix, extraInfo);
                    
                    startIndexAxisA = endIndexAxisA + 1;     % Updating for next chunk
                end
            else % Advanced scan, look for chucks defined in scan params
                % ~~~~ preparing variables: ~~~~
                maxScanSize = stage.ReturnMaxScanSize(2);
                isFastScan = scanParams.fastScan;    % a boolean
                tPixel = scanParams.pixelTime;   % time for each pixel
                [axisAIndex, axisBIndex] = StageScanner.optimize2dScanDirections(maxScanSize, scanParams.copy);
                isFlipped = axisAIndex > axisBIndex;  % (for example, if axis y is before axis x, than "isFlipped" == true)
                fullVectorAxisA = scanParams.getScanAxisVector(axisAIndex);
                fullVectorAxisB = scanParams.getScanAxisVector(axisBIndex);
                
                bHasLiftime = spcm.hasLifetime();
                
                if exist('optionalKcpsScanMatrix', 'var')
                    kcpsScanMatrix = optionalKcpsScanMatrix;
                    extraInfo = optionalExtraInfo;
                else
                    extraInfo = struct();
                    if isFlipped
                        kcpsScanMatrix = zeros(length(fullVectorAxisA), length(fullVectorAxisB), 1+scanParams.isMWContrastScan);
                        if bHasLiftime && ~isMWContrastScan
                            extraInfo.hist = zeros(length(fullVectorAxisA), length(fullVectorAxisB), spcm.nBins);
                        end
                    else
                        kcpsScanMatrix = zeros(length(fullVectorAxisB), length(fullVectorAxisA), 1+scanParams.isMWContrastScan);
                        if bHasLiftime && ~isMWContrastScan
                            extraInfo.hist = zeros(length(fullVectorAxisB), length(fullVectorAxisA), spcm.nBins);
                        end
                    end
                end
                obj.mScan = kcpsScanMatrix;
                obj.mScanExtraInfo = extraInfo;
                
                %%%%%% iterate through the chunks and scan each chunk %%%%%%%
                for i = 1:length(scanParams.scanBlocks)
                    if ~obj.mCurrentlyScanning
                        break;
                    end
                    if isFlipped
                        scanBlock = scanParams.scanBlocks{i}([3:4, 1:2, 5]);
                    else
                        scanBlock = scanParams.scanBlocks{i};
                    end
                    fromA = scanBlock(1);
                    toA = scanBlock(2);
                    fromB = scanBlock(3);
                    toB = scanBlock(4);
                    pointAxisC = scanBlock(5);
                    
                    indicesToScanA = find(fullVectorAxisA >= fromA & fullVectorAxisA <= toA);
                    indicesToScanB = find(fullVectorAxisB >= fromB & fullVectorAxisB <= toB);
                    vectorAxisA = fullVectorAxisA(indicesToScanA);
                    vectorAxisB = fullVectorAxisB(indicesToScanB);
                    
                    [kcpsScanMatrix, extraInfo] = obj.scan2dChunk(...
                        kcpsScanMatrix, spcm, stage, tPixel, vectorAxisA, vectorAxisB, ...
                        axisAIndex, axisBIndex, pointAxisC, isFastScan, isFlipped, ...
                        indicesToScanB(1), indicesToScanB(end), ...
                        indicesToScanA(1), indicesToScanA(end), ...
                        extraInfo);
                    obj.mScan = kcpsScanMatrix;
                    obj.mScanExtraInfo = extraInfo;
                    obj.sendEventScanUpdated(kcpsScanMatrix, extraInfo);
                end
            end
        end
        
        function [kcpsMatrix, extraInfo] = scan2dChunk(...
                obj, ...  StageScanner object
                kcpsMatrix, ... scan matrix (maybe partly filled)
                spcm, ... Spcm object
                stage, ... Stage object. to scan
                tPixel, ... double. Time per pixel (in sec)
                axisAPixelsPerLine, ... vector of double
                axisBLinesPerScan, ... vector of double
                axisADirectionIndex, ... integer. Index in {1, 2, 3} for "xyz"
                axisBDirectionIndex, ... integer. Index in {1, 2, 3} for "xyz"
                axisCPoint0, ... scalar. Zero point in the 3rd axis
                isFastScan, ... logical
                isFlipped, ... logical. Is the matrix flipped or not
                matrixIndexLineStart, ... integer. Index at which to start inserting lines to the matrix
                matrixIndexLineEnd, ... integer. Index at which to stop inserting lines to the matrix
                matrixIndexPixelInLineStart, ... integer. Index at which to start inserting pixels to the line in the matrix
                matrixIndexPixelInLineEnd, ... integer. Index in which to stop inserting pixels to the line in the matrix
                extraInfo ... extra info matrix (maybe partly filled)
                )
            % This function scans a chunk from the scan-matrix
            if length(axisAPixelsPerLine) ~= matrixIndexPixelInLineEnd - matrixIndexPixelInLineStart + 1
                obj.sendError('Can''t scan - mismatch size of vector!')
            end
            if length(axisBLinesPerScan) ~= matrixIndexLineEnd - matrixIndexLineStart + 1
                obj.sendError('Can''t scan - mismatch size of vector!')
            end
            
            if ~obj.mCurrentlyScanning; return; end %Yoav: Will create error because no output. Nadav: or will it?
            if size(kcpsMatrix, 3) == 2 % MW Contrast
                pg = getObjByName(PulseGenerator.NAME);
            end
            
            % for each in {x, y, z}, it could be one of:
            % the axisA vector, the axisB vector, or the axisC point
            [x, y, z] = obj.getXYZfor2dScanChunk(axisAPixelsPerLine, axisBLinesPerScan, axisADirectionIndex, axisBDirectionIndex, axisCPoint0);
            nPixels = length(axisAPixelsPerLine);
            timeout = 2*nPixels*tPixel;
            
            % prepare scan
            nFlat = 0;      % A flat section at the start of ramp. parameter not needed genrally, a stage can overwrite if needed. BACKWARD_COPITABILITY
            nOverRun = 0;   % Let the waveform over run the start and end. Not needed genrally, a stage can overwrite if needed. BACKWARD_COPITABILITY
            axesLettersUpper = upper(ClassStage.SCAN_AXES([axisADirectionIndex, axisBDirectionIndex]));
            prapareScanFuncHndl = sprintf('PrepareScan%s', axesLettersUpper);
            feval(prapareScanFuncHndl, stage, x, y, z, nFlat, nOverRun, tPixel);
            spcm.prepareCountByStage(stage.name, nPixels, timeout, isFastScan);
            
            bHasLiftime = spcm.hasLifetime();
            isMWContrastScan = (size(kcpsMatrix, 3) == 2);
            
            % do the scan
            spcm.startScanCount();
            for lineIndex = matrixIndexLineStart : matrixIndexLineEnd
                if ~obj.mCurrentlyScanning; break; end
                success = false;
                for i = 1:size(kcpsMatrix, 3) % MW Contrast
                    if i==2
                        stage.PrepareRescanLine();
                        pg.on('MW');
                    end
                    for trial = 1 : StageScanner.TRIALS_AMOUNT_ON_ERROR    
                        try
                            if isa(spcm, 'PhotoDiodeDigitizerNiDaqControlled')
                                spcm.startScanCount();
                            end
                            wasScannedForward = stage.ScanNextLine();
                            % forwards - if true, the line was scanned normally,
                            %            if false - should flip the results
                            kcpsVector = spcm.readFromScan();
                            kcpsVector = BooleanHelper.ifTrueElse(wasScannedForward, kcpsVector, fliplr(kcpsVector));
                            if isFlipped
                                kcpsMatrix(matrixIndexPixelInLineStart:matrixIndexPixelInLineEnd, lineIndex, i) = kcpsVector;
                            else
                                kcpsMatrix(lineIndex, matrixIndexPixelInLineStart:matrixIndexPixelInLineEnd, i) = kcpsVector;
                            end
                            
                            if bHasLiftime && ~isMWContrastScan
                                hist = spcm.lastScanHist;
                                hist = BooleanHelper.ifTrueElse(wasScannedForward, hist, fliplr(hist));
                                if isFlipped
                                    extraInfo.hist(matrixIndexPixelInLineStart:matrixIndexPixelInLineEnd, lineIndex, :) = hist;
                                else
                                    extraInfo.hist(lineIndex, matrixIndexPixelInLineStart:matrixIndexPixelInLineEnd, :) = hist;
                                end
                            end
                            
                            success = true;
                            break;
                        catch err
%                             rethrow(err);  % Uncomment to debug
                            warning(err.message);
                            
                            if ~obj.mCurrentlyScanning
                                stage.AbortScan();
                                spcm.clearScanRead();
                                return;
                            end
                            
                            fprintf('Line %d failed at trial %d, attempting to rescan line.\n', lineIndex, trial);
                            
                            try
                                stage.PrepareRescanLine(); % Prepare to rescan the line
                            catch err2
                                stage.AbortScan();
                                spcm.clearScanRead();
                                rethrow(err2)
                            end
                        end % try catch
                    end % for trial = 1 : StageScanner.TRIALS_AMOUNT_ON_ERROR
                    if i==2
                        pg.off('MW');
                    end
                end % MW Contrast
                obj.sendEventScanUpdated(kcpsMatrix, extraInfo);
                
                if ~success
                    % We failed at reading the line, so there is probably
                    % no point in scanning next line
                    obj.mCurrentlyScanning = false;     % will abort the scan
                end
            end % lineIndex = 1 : length(axisBLinesPerScan)
            stage.AbortScan();
            spcm.clearScanRead();
        end
        
        function [x,y,z] = getXYZfor2dScanChunk(obj, axisAPointsPerLine, axisBLinesPerScan, axisADirectionIndex, axisBDirectionIndex, axisCPoint0) %#ok<INUSD,STOUT,INUSL>
            % Converts from "axisA", "axisB", to xyz: calculates the vectors for x,y,z to be used in scan2dChunk()
            for letter = ClassStage.SCAN_AXES
                % Iterate over the string "xyz" letter by letter
                ll = lower(letter);
                switch ClassStage.getAxis(letter)
                    case axisADirectionIndex
                        eval(sprintf('%s = axisAPointsPerLine;', ll));
                    case axisBDirectionIndex
                        eval(sprintf('%s = axisBLinesPerScan;', ll));
                    otherwise
                        eval(sprintf('%s = axisCPoint0;', ll));
                end
            end
            % todo: this needs to be redone. No need to use eval here.
        end
        
        
        function stopScan(obj)
            obj.mCurrentlyScanning = false;
            % todo: check maybe we need also
            %   stage = getObjByName(obj.mStageName);
            %   stage.scanRunning = false;
        end
        
        function switchTo(obj, newStageName)
            if obj.mCurrentlyScanning && ~strcmp(obj.mStageName, newStageName)
                obj.sendError('Can''t switch stage when scan running!');
            end
            obj.mStageName = newStageName;
        end
        
        function autosaveAfterScan(obj) %#ok<MANU>
            saveLoad = SaveLoad.getInstance(Savable.CATEGORY_IMAGE);
            saveLoad.autoSave();
        end
        
        function number = getScanDimensions(obj)
            number = sum(~obj.mStageScanParams.isFixed);
        end
        
        function [globalFirstAxisPos, globalSecondAxisPos] = getGlobalScanPosition(obj, stagesCell)
            % Returns the location of the scan-vector(s), relative to a
            % global zero
            pos = [0, 0, 0];
            % First get data from scanning stage
            
            params = obj.mStageScanParams;
            fixedInd = find(params.isFixed);
            pos(fixedInd) = pos(fixedInd) + params.fixedPos(fixedInd);
            for i = 1:length(stagesCell)
                stage = stagesCell{i};
                if ~strcmp(stage.name, obj.mStageName)
                    phAxes = stage.availableAxes;
                    ind = stage.getAxis(phAxes);
                    pos(ind) = pos(ind) + stage.Pos(ind);
                end
            end
            
            firstAxisInd = params.getFirstScanAxisIndex;
            globalFirstAxisPos = pos(firstAxisInd);
            
            secondAxisInd = params.getSecondScanAxisIndex;
            if secondAxisInd == -1
                globalSecondAxisPos = 0;
            else
                globalSecondAxisPos = pos(secondAxisInd);
            end
        end
    end
    
    methods
        function clear(obj)
            if (obj.mCurrentlyScanning)
                obj.stopScan();
            end
            
            obj.mScan = nan;
            obj.mScanExtraInfo = nan;
            obj.mStageName = nan;
            obj.mStageScanParams = nan;
            obj.mCurrentlyScanning = false;     % probably redundant; appears in obj.stopScan
        end
        
        function dummyScan(obj)
            obj.sendEventScanStarting();
            obj.mStageName = ClassStage.getStages{1}.name;
            data = 5 + peaks;
            obj.mScan = data;
            obj.mScanExtraInfo = struct();
            obj.mStageScanParams = StageScanParams([0,0,0], [48,48,48], [49,49,49], [0,0,0], [false false true], 1, 0, 0, 0);
            obj.sendEventScanUpdated(data, struct());
            obj.sendEventScanFinished();
            obj.autosaveAfterScan();
        end
        
        function value = dummyScanGaussian(obj,scanParams)
            pos = scanParams.fixedPos;
            stage = getObjByName(obj.mStageName);
            if isempty(stage); throwBaseObjException(obj.mStageName); end
            
            phAxes = stage.availableAxes;
            stage.move(phAxes, pos);
            
            X = scanParams.getScanAxisVector(1);
            Y = scanParams.getScanAxisVector(2);
            Z = scanParams.getScanAxisVector(3);
            f = @(x,y,z) 100*exp(-((z+5).^2+x.^2+(y-7).^2)/100);   % some test function
            value = f(X,Y,Z);
        end
        
        function boolean = isScanReady(obj)
            boolean = ~isnan(obj.mScan);
        end
        
        function string = getBottomScanLabel(obj)
            axisLetters = obj.mStageScanParams.getScanAxes;
            switch obj.getScanDimensions
                case 1
                    string = sprintf('%s [%s]', axisLetters, StringHelper.MICRON); % for example, 'x (?m)'
                case 2
                    string = sprintf('%s [%s]', axisLetters(1), StringHelper.MICRON); % (as above)
                otherwise
                    string = 'bottom label :)';
            end
        end
        
        function string = getLeftScanLabel(obj)
            switch obj.getScanDimensions
                case 1
                    string = 'kcps';
                case 2
                    axisLetters = obj.mStageScanParams.getScanAxes;
                    string = sprintf('%s [%s]', axisLetters(2), StringHelper.MICRON); % for example, 'y (?m)'
                otherwise
                    string = 'left label :)';
            end
        end
    end
    
    methods (Static)
        function obj = init
            obj = getObjByName(StageScanner.NAME);
            if isempty(obj)
                obj = StageScanner;
                addBaseObject(obj);
            end
        end
        
        function [axisAIndex, axisBIndex] = optimize2dScanDirections(stageMaxScanSizeInt, scanParams)
            % calculates the best way to scan a 2d scan (given by the scanParams)
            % the movement between pixels in each line is called "axis a",
            % while movement between lines is called "axis b"
            %
            % returns:
            % axisAIndex - for each line in the 2d-scan, scan the pixels in the line in this direction
            % axisBIndex - move between lines in this direction
            %
            % for example, in a 2D scan (XY) where x is [0...30] and y is
            % [0...70] and maxScanSize is 100, the returned values will be:
            % axisAIndex  = 2 (Y)
            % axisBIndex  = 1 (X)
            % as the optimized results will be 30 scans
            
%             %%% Ty debug setup 1 10/04/21
%             firstAxisIndex = scanParams.getFirstScanAxisIndex();
%             secondAxisIndex = scanParams.getSecondScanAxisIndex();
%             axisAIndex = secondAxisIndex;
%             axisBIndex = firstAxisIndex;

            firstAxisIndex = scanParams.getFirstScanAxisIndex();
            secondAxisIndex = scanParams.getSecondScanAxisIndex();
            
            firstAxisNumPoints = scanParams.numPoints(firstAxisIndex);
            secondAxisNumPoints = scanParams.numPoints(secondAxisIndex);
            
            % Option ONE: scan each line by axis 1, move between lines in axis 2
            % Calculate how many steps would be needed then:
            timesMaxInFirst = ceil(firstAxisNumPoints / stageMaxScanSizeInt);
            totalTimesOptionOne = timesMaxInFirst * secondAxisNumPoints;
            
            % Option TWO: scan each line by axis 2, move between lines in axis 1
            % Calculate how many steps would be needed then:
            timesMaxInSecond = ceil(secondAxisNumPoints / stageMaxScanSizeInt);
            totalTimesOptionTwo = timesMaxInSecond * firstAxisNumPoints;
            
            if totalTimesOptionOne <= totalTimesOptionTwo
                axisAIndex = firstAxisIndex;
                axisBIndex = secondAxisIndex;
            else
                axisAIndex = secondAxisIndex;
                axisBIndex = firstAxisIndex;
            end
        end
    end
    
    %% overridden from EventListener
    methods
        % When events happen, this function jumps.
        % event is the event sent from the EventSender
        function onEvent(obj, event)
            % Check if event is "loaded file to SaveLoad" and need to show the image
            if strcmp(event.creator.name, SaveLoadCatImage.NAME) ...
                    && isfield(event.extraInfo, SaveLoad.EVENT_LOAD_SUCCESS_FILE_TO_LOCAL)
                % Need to load the image!
                category = Savable.CATEGORY_IMAGE;
                subcat = Savable.SUB_CATEGORY_DEFAULT;
                saveLoad = event.creator;
                struct = saveLoad.getStructToSavable(obj);
                if ~isempty(struct)
                    obj.loadStateFromStruct(struct, category, subcat);
                end
            end
        end
    end
    
    %% overriding from Savable
    methods (Access = protected)
        function outStruct = saveStateAsStruct(obj, category, type)
            % Saves the state as struct. if you want to save stuff, make
            % (outStruct = struct;) and put stuff inside. If you dont
            % want to save, make (outStruct = NaN;)
            %
            % category - string. Some objects saves themself only with
            %                    specific category (image/experiments/etc.)
            % type - string.     Whether the objects saves at the beginning
            %                    of the run (parameter) or at its end (result)
            if ~strcmp(category, Savable.CATEGORY_IMAGE)
                outStruct = nan;
                return
            end
            
            outStruct = struct;
            switch type
                case Savable.TYPE_PARAMS
                    outStruct.scanParams = obj.mStageScanParams.asStruct();
                    outStruct.stageName = obj.mStageName;
                case Savable.TYPE_RESULTS
                    if isnan(obj.mScan)
                        outStruct = NaN;
                    else
                        outStruct.scan = obj.mScan;
                        outStruct.scanExtraInfo = obj.mScanExtraInfo;
                    end
            end
        end
        
        function loadStateFromStruct(obj, savedStruct, category, subCategory)
            % Loads the state from a struct.
            % to support older versions, always check for a value in the
            % struct before using it. View example in the first line.
            if ~strcmp(category, Savable.CATEGORY_IMAGE); return; end
            if ~any(strcmp(subCategory, {Savable.CATEGORY_IMAGE_SUBCAT_STAGE})); return; end
            
            
            % for field = {'scan', 'scanParams', 'stageName'} - removed 'scan', for when scan has not yet been saved.
            for field = {'scanParams', 'stageName'}
                if ~isfield(savedStruct, field{:})
                    return
                end
            end
            if ~isfield(savedStruct, 'scan')
                savedStruct.scan = [];
                obj.sendWarning('No scan results found. Loading only scan parameters');
            end
            stage = getObjByName(savedStruct.stageName);
            if isempty(stage)
                obj.sendError(sprintf('Can''t load stage! No stage with name "%s"', savedStruct.stageName));
            end
            obj.mStageScanParams = StageScanParams.fromStruct(savedStruct.scanParams);
            stage.scanParams = obj.mStageScanParams; % This will send an event that the scan-parameters have changed
            
            obj.mScan = savedStruct.scan;
            obj.mStageName = savedStruct.stageName;
            if isfield(savedStruct, 'extraInfo')
                obj.mScanExtraInfo = savedStruct.extraInfo;
            else
                obj.mScanExtraInfo = struct();
            end
            obj.sendEventScanUpdated(savedStruct.scan, obj.mScanExtraInfo);
        end
        
        function string = returnReadableString(~, savedStruct)
            % Return a readable string to be shown. If this object
            % doesn't need a readable string, make (string = NaN;) or
            % (string = '');
            
            string = NaN;
            % for field = {'scan', 'scanParams', 'stageName'} - removed 'scan', for when scan has not yet been saved.
            for field = {'scanParams', 'stageName'}
                if ~isfield(savedStruct, field{:})
                    return
                end
            end
            
            % Getting initial information from stage ...
            stageName = savedStruct.stageName;
            stage = getObjByName(stageName);
            if isempty(stage); throwBaseObjException(obj.mStageName); end
            availAxes = stage.getAxis(stage.availableAxes);
            
            % and from scan parameters, ...
            params = savedStruct.scanParams;
            scanAxes = find(~params.isFixed);
            axesLetters = upper(ClassStage.GetLetterFromAxis(scanAxes));
            fixAxes = find(params.isFixed);
            fixAxes = intersect(fixAxes, availAxes);    % Some of the "fixed axes" might not actually be real
            
            % so we can create the output string
            string = sprintf('Scanning %s %s:', stageName, axesLetters);
            
            indentation = 5;
            for i = 1:length(fixAxes)
                index = fixAxes(i);
                ax = ClassStage.GetLetterFromAxis(index);
                position = params.fixedPos(index);
                axisString = sprintf('%s position: %.3f', upper(ax), position);
                string = sprintf('%s\n%s', string, ...
                    StringHelper.indent(axisString, indentation));
            end
            for i = 1:length(scanAxes)
                index = scanAxes(i);
                ax = ClassStage.GetLetterFromAxis(index);
                from = params.from(index);
                to = params.to(index);
                numPoints = params.numPoints(index);
                axisString = sprintf('%s: %d points from %.3f to %.3f', upper(ax), numPoints, from, to);
                string = sprintf('%s\n%s', string, ...
                    StringHelper.indent(axisString, indentation));
            end
            
        end
    end
end