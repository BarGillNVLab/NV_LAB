classdef StageScanParams < handle
    %STAGESCANPARAMS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Constant)
        DEFAULT_POINT_NUM = 51;
        DEFAULT_PIXEL_TIME = 0.015;
    end
    
    properties
        % all below are number-arrays with size 1x3
        from
        to
        numPoints
        fixedPos
        
        % boolean(logicals \ 1\0)-with size 1x3
        isFixed
        
        % double
        pixelTime
        MWAmplitude
        MWFrequency
        
        % all below are logicals (boolean)
        continuous
        fastScan
        autoSave
        isMWContrastScan
        
        % Advanced map indicating where to scan:
        % Should be a cell array of vectors of length 5 [x1, x2, y1, y2, z].
        % Each cell is a block from (x1, y1) to (x2, y2), scanned at "z".
        scanBlocks = {}; % empty means that it is a normal scan.
    end
    
    methods
        function obj = StageScanParams(from, to, numPoints, fixedPos, isFixed, pixelTime, continuous, fastScan, autoSave, isMWContrastScan, MWAmplitude, MWFrequency)
            
            %%%% default no-args constructor if needed %%%%
            if nargin == 0
                obj.from = zeros(1,length(ClassStage.SCAN_AXES));
                obj.to = zeros(1,length(ClassStage.SCAN_AXES));
                obj.fixedPos = zeros(1,length(ClassStage.SCAN_AXES));
                obj.numPoints = obj.DEFAULT_POINT_NUM * ones(1,length(ClassStage.SCAN_AXES));
                obj.isFixed = false(1,length(ClassStage.SCAN_AXES));
                obj.pixelTime = obj.DEFAULT_PIXEL_TIME;
                obj.continuous = false;
                obj.fastScan = false;
                obj.autoSave = true;
                obj.isMWContrastScan = false;
                obj.MWAmplitude = -10;
                obj.MWFrequency = 2870;
                return
            end
            
            %%%% input params checks %%%%
            objectsToCheckNumeric1x3Vector = {'from', 'to', 'numPoints', 'fixedPos'};
            
            for i = 1 : length(objectsToCheckNumeric1x3Vector)
                funcParamName = objectsToCheckNumeric1x3Vector{i};
                funcParamValue = eval(funcParamName);
                if ~isnumeric(funcParamValue) || length(funcParamValue) ~= 3
                    EventStation.anonymousError('"%s" parameter should be a 1x3 number array!', funcParamName)
                end
            end
            
            % check if "pixelTime" is a positive double
            if ~ValidationHelper.isValuePositive(pixelTime)
                EventStation.anonymousError('pixelTime parameter should be a positive double!')
            end
            
            % check if "isFixed" is logical array of size 3
            isFixedIsBooleanArray = all(or(isFixed==0, isFixed==1));
            if ~isFixedIsBooleanArray || length(isFixed) ~= 3
                EventStation.anonymousError('"isFixed" parameter should be a 1x3 boolean array!')
            end
            
            % check if the booleans are actually booleans
            objects_to_check_boolean = {'continuous', 'fastScan', 'autoSave', 'isMWContrastScan'};
            for i = 1 : length(objects_to_check_boolean)
                funcParamName = objects_to_check_boolean{i};
                funcParamValue = eval(funcParamName);
                if ~ValidationHelper.isTrueOrFalse(funcParamValue)
                    EventStation.anonymousError('"%s" should be logical!', funcParamName);
                end
            end
            
            
            
            %%%% create object %%%%
            obj.from = from;
            obj.to = to;
            obj.numPoints = numPoints;
            obj.fixedPos = fixedPos;
            obj.isFixed = isFixed;
            obj.pixelTime = pixelTime;
            obj.continuous = continuous;
            obj.fastScan = fastScan;
            obj.autoSave = autoSave;
            obj.isMWContrastScan = isMWContrastScan;
            obj.MWAmplitude = MWAmplitude;
            obj.MWFrequency = MWFrequency;
        end
        
        function outStruct = asStruct(obj)
            outStruct = jsondecode(jsonencode(obj));
        end
        
        function wasChanged = updateByLimit(obj, phAxis, newLimNeg, newLimPos)
            % phAxis - the axis to change
            % newLimNeg, newLimPos - the new limits to consider
            % supports vectorial axis!
            % NO INPUT CHECKS!
            phAxis = ClassStage.getAxis(phAxis);
            oldFrom = obj.from;
            oldTo = obj.to;
            oldFixedPos = obj.fixedPos;
            
            from_ = obj.from(phAxis);
            from_(from_ > newLimPos) = newLimPos(from_ > newLimPos);
            from_(from_ < newLimNeg) = newLimNeg(from_ < newLimNeg);
            obj.from(phAxis) = from_;
            
            to_ = obj.to(phAxis);
            to_(to_ > newLimPos) = newLimPos(to_ > newLimPos);
            to_(to_ < newLimNeg) = newLimNeg(to_ < newLimNeg);
            obj.to(phAxis) = to_;
            
            fixedPos_ = obj.fixedPos(phAxis);
            fixedPos_(fixedPos_ > newLimPos) = newLimPos(fixedPos_ > newLimPos);
            fixedPos_(fixedPos_ < newLimNeg) = newLimNeg(fixedPos_ < newLimNeg);
            obj.fixedPos(phAxis) = fixedPos_;
            
            sameAsBefore = all(oldFrom == obj.from) ...
                && all(oldTo == obj.to) ...
                && all(oldFixedPos == obj.fixedPos);
            wasChanged = ~sameAsBefore;
        end
        
        function newScanParams = copy(obj)
            newScanParams = StageScanParams.fromStruct(obj.asStruct());
        end
        
        function plotScanMap(obj)
            if isempty(obj.scanBlocks)
                return
            end
            firstScanVector = obj.getFirstScanAxisVector;
            secondScanVector = obj.getSecondScanAxisVector;
            scanMap = zeros(length(firstScanVector), length(secondScanVector));
            for i = 1:length(obj.scanBlocks)
                fromA = obj.scanBlocks{i}(1);
                toA = obj.scanBlocks{i}(2);
                fromB = obj.scanBlocks{i}(3);
                toB = obj.scanBlocks{i}(4);
                scanMap(firstScanVector >= fromA & firstScanVector <= toA, ...
                        secondScanVector >= fromB & secondScanVector <= toB) = 1;
            end
            figure;
            imagesc(firstScanVector, secondScanVector, scanMap');
            xlabel(obj.getFirstScanAxisLetter)
            ylabel(obj.getSecondScanAxisLetter)
            axis xy
        end
    end
    
    % getters
    methods
        function string = getScanAxes(obj)
            string = '';
            for i = 1 : ClassStage.SCAN_AXES_SIZE
                if ~obj.isFixed(i)
                    phAxis = ClassStage.SCAN_AXES(i);
                    string = [string phAxis]; %#ok<AGROW>
                end
            end
        end
        
        function string = getFixedAxes(obj)
            obj.sendWarningIfNotScannable();
            string = '';
            for i = 1 : ClassStage.SCAN_AXES_SIZE
                if obj.isFixed(i)
                    phAxis = ClassStage.SCAN_AXES(i);
                    string = [string phAxis]; %#ok<AGROW>
                end
            end
        end
        
        function index = getFirstScanAxisIndex(obj)
            obj.sendWarningIfNotScannable();
            for i = 1 : ClassStage.SCAN_AXES_SIZE
                if ~obj.isFixed(i)
                    index = i;
                    return
                end
            end
            index = -1;
        end
        
        function index = getSecondScanAxisIndex(obj)
            isScannable = obj.sendWarningIfNotScannable;
            if ~isScannable
                index = -1;
                return
            end
            
            for i = obj.getFirstScanAxisIndex + 1 : ClassStage.SCAN_AXES_SIZE
                if ~obj.isFixed(i)
                    index = i;
                    return
                end
            end
            index = -1;  % if not found
        end

        function phAxis = getFirstScanAxisVector(obj)
            obj.sendWarningIfNotScannable();
            phAxis = obj.getScanAxisVector(obj.getFirstScanAxisIndex);
        end
        
        function phAxis = getSecondScanAxisVector(obj)
            phAxis = obj.getScanAxisVector(obj.getSecondScanAxisIndex);
        end
        
        function axisVector = getScanAxisVector(obj, axisIndex)
            % gets a vector to scan, by the axis-index
            % or, if it's a fixed position, gets the position
            if axisIndex < 0 || axisIndex > length(obj.from)
                axisVector = [];
                return
            end
            
            if obj.isFixed(axisIndex)
                axisVector = obj.fixedPos(axisIndex);
                return
            end
            
            first = obj.from(axisIndex);
            last = obj.to(axisIndex);
            jumps = obj.numPoints(axisIndex) -1;
            dist = (last - first) / jumps;
            axisVector = first : dist : last;
        end
        
        function string1Letter = getFirstScanAxisLetter(obj)
            string1Letter = ClassStage.SCAN_AXES(obj.getFirstScanAxisIndex);
        end
        function string1Letter = getSecondScanAxisLetter(obj)
            % returns a 1char string, or empty string if this scan
            % parameters object doesn't request a 2 dim scan
            index = obj.getSecondScanAxisIndex;
            if index > ClassStage.SCAN_AXES_SIZE || index <= 0
                string1Letter = '';
                return
            end
            string1Letter = ClassStage.SCAN_AXES(obj.getSecondScanAxisIndex);
        end
    end
    
    % Helper methods
    methods (Access = protected)
        function isOk = sendWarningIfNotScannable(obj)
            if all(obj.isFixed)
                EventStation.anonymousWarning('Attention - StageScanParams object is not scan-friendly! All the axes are fixed!');
                isOk = false;
            else
                isOk = true;
            end
        end
        
    end
    
    methods (Static)
        function propNames = varProps
            % This should probably have been implemebted as a method of
            % some superclass, if anybody knows how to
            mc = metaclass(StageScanParams);
            allProps = mc.PropertyList;
            mProps = allProps(not([allProps.Constant]));
            propNames = {mProps.Name};
        end
        
        function obj = fromStruct(inputStruct)
            neededFields = StageScanParams.varProps;
            
            obj = StageScanParams;
            for fieldIndex = 1 : length(neededFields)
                fieldName = neededFields{fieldIndex};
                if isfield(inputStruct, fieldName)
                    obj.(fieldName) = inputStruct.(fieldName)';
                else
                    warning('Couldn''t find field "%s" in struct. Using default value.', fieldName, obj.(fieldName));
                end
            end
        end
    end
end