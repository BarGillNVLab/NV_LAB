classdef CameraImageParams < handle

    
    properties(Constant)
        DEFAULT_EXPOSURE_TIME = 10;
        DEFAULT_ROI = [0 0 1920 1200];
        DEFAULT_BINNING = 1;
    end

    properties

        % MW
        isMWcontrastImg     % 1 or 0 if the microwave is on or off
        MWAmplitude
        MWFrequency

        
        roi                   % [min_x, min_y, width, length]
        exposuretime
        binning
        
        Avarage_exposures
        nframes            % for the average exposures option
        timedelay           % time delay for the average exposures option
    end

    methods
        function obj = CameraImageParams(roi, exposure_time, binning, Avarage_exposures, nframes, timedelay, isMWcontrastImg, MWAmplitude, MWFrequency)

            %%%% default no-args constructor if needed %%%%
            
            if nargin == 0
                obj.roi = obj.DEFAULT_ROI;
                obj.exposuretime = obj.DEFAULT_EXPOSURE_TIME;
                obj.binning = obj.DEFAULT_BINNING;
                obj.Avarage_exposures = false;
                obj.nframes = 1;
                obj.timedelay = 0;
                obj.isMWcontrastImg = false;
                obj.MWAmplitude = -10;
                obj.MWFrequency = 2870;
                return
            end

            if ~isnumeric(roi) || numel(roi) ~= 4
                EventStation.anonymousError('ROI must be a numeric array of 4 elements.');
            end
        
            % Ensure all elements are integers
            if ~all(mod(roi, 1) == 0)
                EventStation.anonymousError('ROI elements must be integers.');
            end
        
            if roi(1)<1 || roi(2)<1||(roi(3)+roi(1))>MAX_ROI(3)|| (roi(4)+roi(2))<MAX_ROI(4)
                EventStation.anonymousError('roi not in legal range')
            end


            % check if the booleans are actually booleans
            objects_to_check_boolean = {'Avarage_exposures', 'isMWcontrastImg'};
            for i = 1 : length(objects_to_check_boolean)
                funcParamName = objects_to_check_boolean{i};
                funcParamValue = eval(funcParamName);
                if ~ValidationHelper.isTrueOrFalse(funcParamValue)
                    EventStation.anonymousError('"%s" should be logical!', funcParamName);
                end
            end
            obj.roi = roi;
            obj.exposuretime = exposure_time;
            obj.binning = binning;
            obj.Avarage_exposures = Avarage_exposures;
            obj.nframes = nframes;
            obj.timedelay = timedelay;
            obj.isMWcontrastImg = isMWcontrastImg;
            obj.MWAmplitude = MWAmplitude;
            obj.MWFrequency = MWFrequency;
        end

        function phAxis = getFirstImageAxisVector(obj)
            phAxis = obj.roi(1):(obj.roi(1)+obj.roi(3));
        end
        
        function phAxis = getSecondImageAxisVector(obj)
            phAxis = obj.roi(2):(obj.roi(2)+obj.roi(4));
        end

        function outStruct = asStruct(obj)
            outStruct = jsondecode(jsonencode(obj));
        end

        function CameraParams = copy(obj)
            CameraParams = CameraImageParams.fromStruct(obj.asStruct());
        end
    end
    methods (Static)
        function propNames = varProps
            % This should probably have been implemebted as a method of
            % some superclass, if anybody knows how to
            mc = metaclass(CameraImageParams);
            allProps = mc.PropertyList;
            mProps = allProps(not([allProps.Constant]));
            propNames = {mProps.Name};
        end
        
        function obj = fromStruct(inputStruct)
            neededFields = CameraImageParams.varProps;
            
            obj = CameraImageParams;
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