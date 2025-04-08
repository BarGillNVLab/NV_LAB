classdef (Sealed) CameraClass_Father <  handle
    
    properties (Access = private)
        camera
    end
    
    properties (Access = public)
        ROI_DEFULT %ROI = Region Of Interest
        Binning % the ammount of pixels that you want to sum together
        ExposureTime % the emount of time that you want to do the exposure
        imageSize
        y %the height x of the ROI
        x %the width x of the ROI
        minx % the minimum x of the ROI
        miny % the minimum y of the ROI
        stride
        trigger
        fps % the Frames Per Second we want to shoot
        vid % the video
        src % the source that we thke the video from
        Image_data % the Image data it self
        location = '' % the location that we would like to put the image to
        file_name = '' % the file name that we would like to give the data
    end

    
    methods (Static)  %create object
        function CamSon = getInstance()
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj) 
                % this should be done by the JSON file
                localObj = CameraClassBasler;
            end
            CamSon =  localObj;
        end
    end
%% the main methods
    methods % the general function that the camera should do
        
        %this function starts the camera
        function ImageStart(gCam,handles)
            global CamSon; 
            CamSon = gCam.getInstance();
            CamSon.ImageStart(handles);
        end
        
        % this function returns the minx
        function [minX]=GetMinX(obj)
            global CamSon;
            minX = CamSon.GetMinX();
        end

        % this function returns the miny
        function [minY]=GetMinY(obj)
            global CamSon;
            minY = CamSon.GetMinY();
        end
        
        % this function returns the maxX
        function [x]=GetWidth(obj)
            global CamSon;
            x= CamSon.GetWidth();
        end
        
        % this function returns the maxy
        function [y]=GetHeight(obj)
            global CamSon;
            y = CamSon.GetHeight();
        end
        
        function SetROI(obj, what,handles)
            % the minX,minY is confused with the minX, maxX
            % maxX => in MaxY and so on 
            global CamSon;
            if strcmp(what,'setMaxY')
                what = 'setMaxX';
            elseif  strcmp(what,'setMaxX')
                what = 'setMaxY';

            elseif  strcmp(what,'setMinY')
                what = 'setMinX';

            elseif  strcmp(what,'setMinX')
                what = 'setMinY';
            end
            CamSon.SetCamROI(what,handles, ...
                [str2double(handles.minY.String), ...
                str2double(handles.minX.String),...
                str2double(handles.maxY.String), ...
                str2double(handles.maxX.String)]);
        end
        
        % this function sets the expose time
        function SetExposeTime(obj,t)
            global CamSon;
            CamSon.SendCamCommand('SetExposureTime',str2num(t));
        end

        % this function sets the color scale
        function ColorScale(obj, handles)
            global CamSon;
            CamSon.SendCamCommand(handles)
        end
        
        % this function starts the image acquring
        function ImageAcquire(obj,what, handles)
            global CamSon;
            CamSon.Aquisition(what, handles)
        end
        
        % this function sets the binning for the image
        function SetBinning(obj,bin)
            global CamSon;
            CamSon.SetBinning(bin);
        end

        %fhis function does the Zoom in ImageFig 

         function zoom(obj,handles)
            global CamSon;
            CamSon.Zoom(handles)
         end

         
         % this function returns the current binning number
        function Bin = GetBinning(obj)
            global CamSon;
            Bin = CamSon.GetBinning('GetAOIBinning');
            CamSon.Binning = Bin;
        end
        
        function SoftwareTrigger(CamSon)
            CamSon.SendCamCommand('Command','AcquireExternalTrigger');
        end

        function PrepareRead(CamSon, NumberOfImages)
            CamSon.SendCamCommand('Command','AcquireExternalTrigger');
        end

        function I = Read(n, detectionDuration)
            global CamSon;
            I = CamSon.Read(n, detectionDuration);
        end
%         
%         function stopRead(CamSon)
%             CamSon.stopAquisition();
%         end
%         
        % this function saves the last image
        function ImageSaveImage(obj,what, handles)
            global CamSon;
            CamSon.SaveImage(what, handles);
        end
        
        % this function uploads an image
        function ImageUpload(obj,what,handels)
            global CamSon;
            CamSon.ImageUpload(what, handels)
        end
        
        % this function calls for the CPP functions for the camera
        function ImageCPP(obj, what, handles)
            global CamSon;
            CamSon.ImageCPP(what, handles);
        end
        
        % this function replots the image
        function Replot(obj, handles)
            global CamSon
            CamSon.plotImage(handles)
        end
    end
end