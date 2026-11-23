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
        exposuretime          % in milliseconds
        binning
        
        Avarage_exposures
        nframes            % for the average exposures option
        timedelay           % time delay for the average exposures option
    end

    methods
        function obj = CameraImageParams
            %%%% default no-args constructor if needed %%%%   
            obj.Avarage_exposures = false;
            obj.nframes = 1;
            obj.timedelay = 0;
            obj.isMWcontrastImg = false;
            obj.MWAmplitude = -10;
            obj.MWFrequency = 2870; 
            obj.roi = obj.DEFAULT_ROI;
            obj.exposuretime = obj.DEFAULT_EXPOSURE_TIME;
            obj.binning = obj.DEFAULT_BINNING;
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