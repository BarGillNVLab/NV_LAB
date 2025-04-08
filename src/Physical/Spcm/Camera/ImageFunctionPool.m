function ImageFunctionPool(what,hObject, eventdata, handles)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%% edited by Lion Edelman, April 2023 %%%%%%%%%%%%%%%%%%%
%%%%%%%%%% Written by Linh Pham, July 2008 %%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%% based off code written by Jeronimo Maze %%%%%%%%%%%%%%
%%%%%%%%%% Harvard University, Cambridge, USA  %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
global gCam
gCam = CameraClass_Father;
switch what
    
    % INITIALIZATION FUNCTIONS
    
    % this function defines the camera object
    case 'Start'
        gCam.ImageStart(handles);
    
    % REGION OF INTEREST FUNCTIONS
    case {'setMinX', 'setMaxX', 'setMinY', 'setMaxY'}
        gCam.SetROI(what,handles);
    case 'setROIDefault'
        gCam.SetROI('ROI_DEFUlT',handles);
    
    % ACQUISITION FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% CHECK WHAT THIS MEANS
    case 'AcquireExternalTrigger' 
        gCam.ImageAcquire('AcquireExternalTrigger',handles);
    case 'AvgMultiExp'
        ImageFillUpForm('FillAvgExp',handles, 0);
    % IMAGE PANEL FUNCTIONS
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    case 'Replot'
        gCam.Replot(handles);
    case 'Acquire'
        gCam.ImageAcquire('Acquire',handles);
    case 'RunExp'
        gCam.ImageAcquire('RunExp',handles);
    case 'StopAcq'
        gCam.ImageAcquire('StopAcq', handles);
    case 'LaserShutter'
        ImageFillUpForm('FillShutterPB', handles, 0);
    
    case 'ColorScale'
        gCam.ColorScale(handles)

    % EXPOSURE FUNCTIONS
    case 'setExposeTime'
        gCam.SetExposeTime(handles.ExposeTime.String);
    
    case 'setBinning'
        if handles.bBin1.Value == 1
            gCam.SetBinning(1);
        end

        if handles.bBin2.Value == 1
            gCam.SetBinning(2);
        end
        
        if handles.bBin3.Value == 1
            gCam.SetBinning(3);
        end

        if handles.bBin4.Value == 1
            gCam.SetBinning(4);
        end
        

    % ZOOM PANEL FUNCTIONS
    case 'Zoom On'
        gCam.zoom(handles); %%needs to be changed!!!!!!
    case 'Zoom Out'
        gCam.SetROI('setDEF', handles);
    case 'SetRange'
        gCam.SetROI('SetAll',handles)
        
    % CPP FUNCTIONS
    case 'RunCPP'
        gCam.ImageCPP('Run', handles);
    case 'StopCPP'
        gCam.ImageCPP('Stop', handles);
    case 'SetCPPBox'
        gCam.ImageCPP('Box', handles);
        
    % SAVE IMAGE PANEL FUNCTIONS
    case 'Save'
        gCam.ImageSaveImage('Save', handles);
    case 'ChangeFileName'
        gCam.ImageSaveImage('ChangeFileName',handles);
    case 'Edit'
        gCam.ImageSaveImage('Edit', handles);
        
    % UPLOAD IMAGE PANEL FUNCTIONS
    case 'UploadPrevious'
        gCam.ImageUpload('UploadPrevious', handles);
    case 'Upload'
        gCam.ImageUpload('Upload', handles);
    case 'UploadNext'
        gCam.ImageUpload('UploadNext', handles);
    case 'Delete'
        gCam.ImageUpload('Delete', handles);
    case 'RePlot'
        gCam.RePlot(handles);      
    
    
    
    otherwise
        warning(('Couldent find the command.'));
end


