classdef (Sealed) CameraClassBasler <  handle
    
    properties (Access = private)
        camera
        Frame = 1; 
    end
    
    properties (Access = public)
        IsAcquiring
        ROI_DEFULT = [0 0 1936 1216];
        ROI
        Binning = 1
        ExposureTime
        imageSize
        y %height
        x %width
        minx
        miny
        stride
        trigger
        fps
        vid
        src
        Image_data
        CPPB_on
        CPP_count
        CPP_go
        CPP
        CPP_rect_Position
        CPP_rect
%         location = 'G:\My Drive\NV Lab\Setup 2\Results'
        location = 'D:\Setup 6\Results'
        file_name = 'temp'
    end

    
    methods (Static)  %create object
        function obj = getInstance()
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = CameraClass;
            end
            obj = localObj;
        end
    end
%% SetUp of the camera and all the function to operate the camera
    methods  %% This method does all the SetUp of the camera
        function [varargout] = SendCamCommand(obj, command, varargin)
            switch command
                case 'InitialiseLibrary'
                    try
                        obj.vid = videoinput('gentl', 1, 'Mono12');
                    catch
                        try
                           obj.vid = videoinput('gentl', 2, 'Mono12');

                        catch
                            warning(('Couldent find any camera.'));
                            return
                        end
                    end
                    obj.src = getselectedsource(obj.vid);
                    obj.vid.ReturnedColorspace = 'grayscale';
                    obj.src.ExposureAuto = 'Off';
                    obj.src.ExposureTime = 50;

                % from here we do all the SET options
                
                case 'SetFrameCount'
                    obj.vid.FramesPerTrigger = varargin{1};

                case 'SetAOILeft'
                    ROIdouble = double(obj.vid.ROIPosition);
                    if varargin{1} < obj.ROI_DEFULT(3)
                        ROIdouble(1) = varargin{1};
                        obj.minx = varargin{1};
                        if ROIdouble(3) ~= ROIdouble(3) - ROIdouble(1)
                            ROIdouble(3) = ROIdouble(3) - ROIdouble(1);
                        end
                    else
                        disp('cant put this value')
                    end
%                     obj.vid.ROIPosition = ROIdouble;
                    
                case 'SetAOIWidth'
                    ROIdouble = double(obj.vid.ROIPosition);
                    if varargin{1}  <= obj.ROI_DEFULT(3)
                        ROIdouble(3) = varargin{1} - ROIdouble(1);
                        obj.x = varargin{1};
                    else
                        disp('cant put this value')
                    end
%                     obj.vid.ROIPosition = ROIdouble;

                case 'SetAOITop'
                    ROIdouble = double(obj.vid.ROIPosition);
                    if varargin{1} < obj.ROI_DEFULT(4)
                        ROIdouble(2) = varargin{1};
                        obj.miny = varargin{1};
                        if ROIdouble(4) ~= ROIdouble(4) - ROIdouble(2)
                            ROIdouble(4) = ROIdouble(4) - ROIdouble(2);
                        end
                    else
                        disp('cant put this value')
                    end
%                     obj.vid.ROIPosition = ROIdouble;

                case 'SetAOIHeight'
                    ROIdouble = double(obj.vid.ROIPosition);
                    if varargin{1} <= obj.ROI_DEFULT(4)
                        obj.y = varargin{1};
                        ROIdouble(4) = varargin{1} - ROIdouble(2);
                    else
                        disp('cant put this value')
                    end
%                     obj.vid.ROIPosition = ROIdouble;

                case 'SetAOIBinning'
            % This is the program
            %binning which does a running sum but keeps thr same ration
            %(ROI)
%                     obj.src.BinningHorizontal = varargin{1};
%                     obj.src.BinningVertical  = varargin{1};
%                     obj.src.BinningVerticalMode = 'Sum';
%                     obj.Binning = varargin{1};

%             This is the sum binning. which sums and shrinks the ROI accordingly
                      obj.src.BinningHorizontal = 1;
                      obj.src.BinningVertical  = 1;
                      obj.src.BinningVerticalMode = 'Sum';
                      obj.Binning = varargin{1};
                case 'SetExposureTime'
                    obj.src.ExposureAuto = 'Off';
                    obj.src.ExposureTime = varargin{1};
                    obj.ExposureTime = varargin{1};
                
                % from here we do all the GET options
                
                case 'GetFrameCount'
                    varargout = num2cell(obj.vid.FramesPerTrigger);
                case 'GetAOILeft'
%                     ROIP = [obj.vid.ROIPosition];
                    varargout = num2cell(obj.minx);
                case 'GetAOIWidth'
%                     ROIP = [obj.vid.ROIPosition];
                    varargout = num2cell(obj.x);
                case 'GetAOITop'
%                     ROIP = [obj.vid.ROIPosition];
                    varargout = num2cell(obj.miny);
                case 'GetAOIHeight'
%                     ROIP = [obj.vid.ROIPosition];
                    varargout = num2cell(obj.y);
                case 'GetExposureTime'
                    varargout = num2cell(obj.src.ExposureTime);
                case 'GetAOIBinning'
%                     varargout = num2cell(obj.src.BinningVertical);
                      varargout = num2cell(obj.Binning);
                    
                % from here we do all the command options

                case 'Command'
                    switch varargin{1}
                        case 'Acquire'
%                               triggerconfig(obj.vid, 'immediate');
                            start(obj.vid);
                            obj.IsAcquiring = true;

                            bin = obj.Binning;
                            if bin>1
                                real_vid = getdata(obj.vid);
                                [h,w] = size(real_vid);
                                row2=0;
                                obj.Image_data = zeros(fix(h/bin),fix(w/bin));
                                for row=1:bin:(w-bin)
                                    row2 = row2+1;
                                    col2=0;
                                    for col=1:bin:(h-bin)
                                          if row < h && col < w 
                                              col2 = col2+1;
                                              obj.Image_data(row2,col2) = sum(real_vid(row:row+bin-1,col:col+bin-1),'all');
                                          end
                                    end
                                end
                                obj.x = fix(w/bin);
                                obj.y = fix(h/bin);
                            else
                                obj.Image_data = getdata(obj.vid);
                            end
                            hadel_temp = varargin{2};
                            obj.plotImage(hadel_temp);
                            if hadel_temp.bAcqCont.Value && obj.IsAcquiring
%                                 obj.Frame = obj.Frame +1;
                                obj.SendCamCommand('Command',varargin{1}, hadel_temp);
                            end
                        case 'StopAcq'
                            stop(obj.vid);
                            obj.IsAcquiring = false;
%                             obj.Image_data = getdata(obj.vid);
                        case 'AcquireExternalTrigger'
                            obj.src.TriggerMode = 'On';
                            obj.src.TriggerActivation = 'RisingEdge';
                            triggerconfig(obj.vid, 'hardware', 'DeviceSpecific', 'DeviceSpecific');
                            obj.src.TriggerSource = 'Line1';
                    end
                
                case 'Colorspace'
                    obj.vid.ReturnedColorspace = varargin{2};

                case 'Save'
                    obj.location = 'C:\Users\owner\Desktop';
                    obj.file_name = 'lion';
                    lion = getdata(obj.vid);
                    save('C:\Users\owner\Desktop', 'lion');

                case 'ChangeFileName'
                    obj.file_name = varargin{1};
                    
                % the last option that we try                
                case 'ColorScale'
                    obj.src.ReturnedColorspace = varargin;
                
                
                otherwise
                    disp('cant find:')
                    disp(command)
            end
        end
        
    end
%%    
    methods
        function setup(obj)
            if ~exist("obj_from_ImageNVC",'var')
                obj.ImageStart()
            else
                obj = obj_from_ImageNVC;
            end
        end
        function stopRead(obj)
            stop(obj.vid)
        end
        
        function ImageStart(obj,handles)
            global gCam;
            obj.SendCamCommand('InitialiseLibrary');
            obj.SendCamCommand('SetTriggerMode','immediate');
            obj.SendCamCommand('SetFrameCount',1);
            obj.src.ExposureTime = obj.SendCamCommand('GetExposureTime'); %IN SECONDS
            obj.src.BinningVertical = 1;
            obj.src.BinningHorizontal = obj.src.BinningVertical;
            if  obj.src.BinningVertical~=0
                obj.SendCamCommand('SetAOIBinning', 1);
            end
            obj.ROI_DEFULT = double(obj.vid.ROIPosition);
            obj.x = obj.SendCamCommand('GetAOIWidth');
            obj.y = obj.SendCamCommand('GetAOIHeight');
            obj.miny = obj.SendCamCommand('GetAOILeft');
            obj.minx = obj.SendCamCommand('GetAOITop');
            if exist('handles', 'var')
                handles.minX.String = obj.minx;
                handles.minY.String = obj.miny;
                handles.maxX.String = obj.y;
                handles.maxY.String = obj.x;
            end
            obj.ROI = [obj.ROI_DEFULT(3),obj.ROI_DEFULT(4)];
            obj.x = obj.ROI_DEFULT(3);
            obj.y = obj.ROI_DEFULT(4);
            obj.minx = 0;
            obj.miny = 0;
            gCam = obj;
            assignin('base','obj_from_ImageNVC',obj);
            disp("camera is on")
        end
        
        %from here it is the SET functions        
        
        function SetCamROI(obj, what, handles, ROI)
            switch what
                case 'SetAll'
                    handles.axes1.YLim
                    handles.axes1.XLim
                    obj.vid.ROIPosition = double([handles.axes1.XLim(1)...
                                            handles.axes1.YLim(1) ...
                                            handles.axes1.XLim(2) - handles.axes1.XLim(1) ...
                                            handles.axes1.YLim(2) - handles.axes1.YLim(1)]);
                    obj.miny = obj.SendCamCommand('GetAOILeft');
                    obj.minx = obj.SendCamCommand('GetAOITop');
                    obj.x = obj.SendCamCommand('GetAOIWidth') + obj.minx;
                    obj.y = obj.SendCamCommand('GetAOIHeight')+obj.miny;
                    handles.minX.String = obj.minx;
                    handles.minY.String = obj.miny;
                    handles.maxX.String = obj.y;
                    handles.maxY.String = obj.x ;
                case 'setDEF'
                    obj.SendCamCommand('SetAOILeft',obj.ROI_DEFULT(1));
                    obj.SendCamCommand('SetAOITop',obj.ROI_DEFULT(2));
                    obj.SendCamCommand('SetAOIWidth',obj.ROI_DEFULT(3));
                    obj.SendCamCommand('SetAOIHeight',obj.ROI_DEFULT(4));
                    handles.minX.String = obj.minx;
                    handles.minY.String = obj.miny;
                    handles.maxX.String = obj.y;
                    handles.maxY.String = obj.x;
                    plotImage(obj, handles)
                case 'setMinX'
                    obj.SendCamCommand('SetAOILeft',ROI(1));
                    plotImage(obj, handles)
                case 'setMaxX'
                    obj.SendCamCommand('SetAOIWidth',ROI(3));
                    plotImage(obj, handles)
                case 'setMinY'
                    obj.SendCamCommand('SetAOITop',ROI(2));
                    plotImage(obj, handles)
                case 'setMaxY'
                    obj.SendCamCommand('SetAOIHeight',ROI(4));
                    plotImage(obj, handles)
            assignin('base','obj_from_ImageNVC',obj);
            end
        end
        
        function SetBinning(obj,bin)
            temp = 0;
            if obj.IsAcquiring
                stop(obj.vid);
                temp = 1;
            end
            obj.SendCamCommand('SetAOIBinning',bin);
            if temp
                start(obj.vid);
            end
            assignin('base','obj_from_ImageNVC',obj);
        end
        
        function SetExposureTime(obj,t)
            global gCam;
            gCam.SendCamCommand('SetExposureTime',t);
            assignin('base','obj_from_ImageNVC',obj);
        end
        
        function [ExposureTime] = getExposureTime(obj)
            ExposureTime = obj.SendCamCommand('GetExposureTime'); 
        end
        
        %from here iis the GET functions
        
        function [minX]=GetMinX(obj)
            minX = obj.SendCamCommand('GetAOITop');
        end
        
        function [minY]=GetMinY(obj)
            minY = obj.SendCamCommand('GetAOILeft');
        end
        
        function [x]=GetWidth(obj)
            x= obj.SendCamCommand('GetAOIHeight');
        end
        
        function [y]=GetHeight(obj)
            y=obj.SendCamCommand('GetAOIWidth');
        end
        
        function Bin = getbinning(obj)
            Bin= obj.SendCamCommand('GetAOIBinning');
            obj.Binning=Bin;
        end
        
        function Aquisition(obj,what, handles)
            obj.SendCamCommand('Command',what, handles);
        end
        
        function PrepareRead(obj, NumberOfImages)
            % obj.SendCamCommand('Command',what)
        end
        
        function I = Read(obj,n, detectionDuration)
            I = zeros(obj.y, obj.x, n);
            for i = 1:n
                start(obj.vid);
                I(:,:,i) = getdata(obj.vid);
            end
        end

        function SaveImage(obj,what,handles)
            switch what
                case 'Save'
                    obj.location = 'C:\Users\owner\Desktop';
                    obj.file_name = 'G:\My Drive\NV Lab\Setup 2\Results\test.mat';
                    data = obj.Image_data;
                    save(obj.file_name, 'data');

                case 'ChangeFileName'
                    obj.file_name = handles; 
                
                case 'Edit'
                    figure
                    imagesc([obj.minx,obj.x],[obj.miny,obj.y] ...
                        ,obj.Image_data(:,:,1,obj.Frame))
%                     plot(obj.Image_data(:,:,1,obj.Frame))
            assignin('base','obj_from_ImageNVC',obj);
            end
        end
        
        function ColorScale(obj, handles)
            if handles.colorGray.Value == 1
                obj.SendCamCommand(what,'grayscale')
            elseif handles.colorJet.Value == 1
                obj.SendCamCommand(what,'rgb')
            end
        end
        
        %this is the Zoom function

        function Zoom(obj,handles)
            zoom on
            assignin('base','obj_from_ImageNVC',obj);
        end

        function ImageCPP(obj, what, handles)
           switch what
               case 'Run'
                obj.CPP_go = true;
                obj.CPP_count = [0  1];
                
            case 'Stop'
                obj.CPP_go = false;
                set(handles.bCPPBox, 'Value', 0);
            case 'Box'
                if get(handles.bCPPBox, 'Value')
                    set(handles.bZoom, 'Value', 0);
                    obj.CPP_go = true;
                    obj.CPP_count = [0  1];
                    obj.CPP = images.roi.Rectangle(gca,'Position', ...
                        [100 100 200 200] ...
                        ,'StripeColor','r');
                    obj.CPP
                else
                    obj.CPP_go = false;
                end
           assignin('base','obj_from_ImageNVC',obj);
           end
        end
      

        function ImageUpload(obj,what,handels)
            switch what
                case 'UploadPrevious'
                    if obj.Frame > 1
                        obj.Frame = obj.Frame - 1;
                        plotImage(obj, handels)
                    end
                case 'Upload'

                case 'UploadNext'
                    if obj.Frame < length(obj.Image_data)
                        obj.Frame = obj.Frame + 1;
                        plotImage(obj, handels)
                    end
                case 'Delete'

            end
        end

        function plotImage(obj, handles)
            zoom off
            try
                obj.CPP_rect_Position = obj.CPP.Position; 
            end
            Ixlim = [obj.minx obj.x];
            Iylim = [obj.miny obj.y];
            obj.CPP_rect_Position;
            if isnan(obj.Image_data)
                obj.Image_data = getdata(obj.vid);
            end

%             if obj.Frame >= obj.Image_data(4)
%                 if obj.Image_data(4) <= 0
%                     obj.Frame = 1;
%                 else
%                     obj.Frame = obj.Image_data(4);
%                 end
%             end
            
            % set color scheme
            if exist('handles','var')
                if get(handles.colorJet, 'Value')
                    colormap(jet);
                else
                    colormap(gray);
                end
            end
            imagesc(Ixlim, Iylim, obj.Image_data(:,:,1,1));
            daspect([1 1 1]);
            
            % display colorbar and adjust color axis limits

            colorbar('location', 'EastOutside');
            [cmin cmax] = caxis;
            if get(handles.bMinThresh, 'Value')
                cmin = eval(get(handles.MinThresh, 'String'));
            end

            if get(handles.bMaxThresh, 'Value')
                cmax = eval(get(handles.MaxThresh, 'String'));
            end
            
            caxis(handles.axes1, [cmin cmax]);
            
            % If necessary, restore CPP Box position
            if obj.CPP_go
                if obj.CPPB_on
                    Current_Frame_CCP = mean(obj.Image_data(obj.CPP_rect_Position(1):obj.CPP_rect_Position(3)+obj.CPP_rect_Position(1), ...
                        obj.CPP_rect_Position(2):obj.CPP_rect_Position(2) + obj.CPP_rect_Position(4),1,obj.Frame),'all');
                else
                    Current_Frame_CCP = mean(obj.Image_data(:,:,1,obj.Frame),'all');
                end
                    obj.CPP_count(1) = (obj.CPP_count(1)*(obj.CPP_count(2)) + Current_Frame_CCP)/(obj.CPP_count(2)+1);  
                    obj.CPP_count(2) = obj.CPP_count(2) + 1;
                    handles.CPP.String = obj.CPP_count(1);
            end
            if get(handles.bCPPBox, 'Value')
                obj.CPP = images.roi.Rectangle(gca,'Position', ...
                        obj.CPP_rect_Position ...
                        ,'StripeColor','r');
            end
            
% %             If necessary, restore Track Box position
%             if isfield(gTrack, 'box') && gTrack.box.on
%                 gTrack.box.rect = imrect(handles.axes1, gTrack.box.pos);
%             end

        end
    end
end

