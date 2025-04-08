classdef exposure < GuiComponent & EventListener

    % creating the gui features for setup 2
    %this class is for creating the of the camera
     
     properties
        edtexposuretime        % 1x1 input text
        cbxbinned               % 1x5 radio button
        lblMin              % min exposure time 
        lblMax              % max exposure time
        avgexpo             % average exposures checkbox
        numexpoavg           % number of exposures averaged edit box
        delaytime             %delay time edit box
        autoadjustment         % automatic adjustment of the exposure time radio button
        camera

        exposurelimits
     end


     properties (Constant)
        MINEXPOSURETIME = 9.2394e-06;
        MaXEXPOSURETIME = 1.9842e04;

     end

     methods
        function obj = exposure(parent, controller, camera)
            obj@GuiComponent(parent, controller);
            obj@EventListener(Camera.NAME);
             %%%% panel init %%%%
            obj.camera = camera;
            obj.exposurelimits = obj.camera.EXPOSURE_TIME_LIMITS;
            MINEXPOSURETIME = obj.exposurelimits(1);
            MaXEXPOSURETIME = obj.exposurelimits(2);
            exposure = uix.Panel('Parent', parent.component, 'Title', 'Exposure', 'Padding', 5);
            vmain = uix.VBox('Parent', exposure, 'Spacing', 6, 'Padding', 0);
            hboxMain = uix.HBox('Parent', vmain, 'Spacing', 0, 'Padding', 0);
            leftBox = uix.VBox('parent', hboxMain,'Spacing', 6, 'Padding', 0);


            uicontrol(obj.PROP_LABEL{:}, 'Parent', leftBox, 'String', 'expose time [ms] :'); % expose time label
            minmax = uix.HBox('parent', leftBox,'Spacing', 1, 'Padding', 0);
            %expose time
            % Add the label for "min" left side
            obj.lblMin = uicontrol(obj.PROP_LABEL{:}, 'Parent', minmax, 'String', [num2str(MINEXPOSURETIME), '<']);
            % Add the editable text box in the center
            obj.edtexposuretime = uicontrol(obj.PROP_EDIT{:}, 'Parent', minmax,'Callback',@obj.SetExposureCallback);
            % Add the label for "max" on the right
            obj.lblMax = uicontrol(obj.PROP_LABEL{:}, 'Parent', minmax, 'String', [num2str(MaXEXPOSURETIME)]);  

            minmax.Widths = [125 -1 100];
            minmaxheight = 25;
            minmaxwidth = 280;
                

            obj.avgexpo = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', leftBox, 'String', 'Average exposures','Callback',@obj.AverageExposuresCallback);  % average exposure checkbox

            avgexpogrid = uix.Grid('parent', leftBox,'Spacing', 0);
            uicontrol(obj.PROP_LABEL{:}, 'Parent', avgexpogrid, 'String', 'number');
            uicontrol(obj.PROP_LABEL{:}, 'Parent', avgexpogrid, 'String', 'delay [ms]');

            obj.numexpoavg = uicontrol(obj.PROP_EDIT{:},'Parent', avgexpogrid,'Enable','off','Callback',@obj.NframesCallback);
            obj.delaytime = uicontrol(obj.PROP_EDIT{:},'Parent', avgexpogrid,'Enable','off','Callback',@obj.TimeDelayCallback);
            
            avgexpogrid.Widths = [100 -1];
            avgexpogrid.Heights = [25 25];
            avgexpogridwidth = 150;

            
                  % [fromLeft, fromBottom, width, height]);
           leftBox.Heights = [25 minmaxheight 20 sum(avgexpogrid.Heights)];
           leftBoxwidth = max([minmaxwidth avgexpogridwidth]) + 10;
           leftboxheight = sum(leftBox.Heights)+5*length(leftBox.Heights);
            
           uix.Empty('parent', hboxMain);
           dummywidth = 10;

           binning = uix.VBox('parent', hboxMain,'Spacing', 3, 'Padding', 0);
           binninggroup = uibuttongroup('Parent', binning, 'SelectionChangedFcn',@obj.callbackBinningSelection);

           rbHeight = 20; % "rb" stands for "radio button"
           rbWidth = 80;
           paddingFromLeft = 10;
            % Number of checkboxes
            numCheckboxes = 5;
            obj.cbxbinned = gobjects(1,numCheckboxes); 

            % Create checkboxes 
            for i = 1:numCheckboxes
                j=i;
                if i == numCheckboxes; j = 8;end
                obj.cbxbinned(i) = uicontrol(obj.PROP_RADIO{:}, 'Parent', binninggroup,...
                    'String', ['binned', num2str(j), 'x', num2str(j)], 'Position', [paddingFromLeft 25+(numCheckboxes-i)*rbHeight rbWidth rbHeight],'Tag', num2str(j));
            end
            binning.Heights = 140;
            binningwidth = 100;

            hboxMain.Widths = [leftBoxwidth dummywidth binningwidth];
            hboxMainheight = max(leftboxheight, binning.Heights)+5;

            
            obj.autoadjustment = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent', vmain, ...
                'String', 'Adjusting Exposure Time Automatically');

            vmain.Heights = [hboxMainheight 20];
            vmainwidth = sum(hboxMain.Widths);

            
            obj.width = vmainwidth;
            obj.height = sum(vmain.Heights) + 20;


            obj.refresh;
        end

        % callback functions

        function SetExposureCallback(obj)
            imageParams = obj.camera.imgparams;
            expo = imageParams.exposuretime;
            viewMexposure = obj.edtexposuretime;
            if ~ValidationHelper.isStringValueANumber(viewMexposure.String)
                viewMexposure.String = expo;
                obj.sendError('Only numbers can be accepted! Reverting.');
            end
            exposurein = str2double(viewMexposure.String);
            lowerBound = obj.exposurelimits(1);
            upperBound = obj.exposurelimits(2);
            if ~ValidationHelper.isInBorders(exposurein, lowerBound, upperBound)
                warningMsg = sprintf( ...
                    'exposure time is not in bounds! Reverting.\n(bounds: [%d, %d])', ...
                    lowerBound, ...
                    upperBound);
                exposurein = expo;
                obj.sendWarning(warningMsg);
            end
             [viewMexposure.String, t] = StringHelper.formatNumber(exposurein);
             obj.camera.setExposureTime(t);
        end

        function AverageExposuresCallback(obj)
            if obj.avgexpo ==0
                obj.avgexpo =1;
                obj.numexpoavg.Enable = 'on';
                obj.delaytime.Enable = 'on';
            else
                obj.avgexpo =0;
                obj.numexpoavg.Enable = 'off';
                obj.delaytime.Enable = 'off';
            end
            imageParams = obj.camera.imgparams;
            imageParams.Avarage_exposures = obj.avgexpo;
        end

        function NframesCallback(obj)
            imageParams = obj.camera.imgparams;
            nfram = imageParams.nframes;
            nexposures = obj.numexpoavg;
            if ~ValidationHelper.isStringValueANumber(nexposures.String)
                nexposures.String = nfram;
                obj.sendError('Only numbers can be accepted! Reverting.');
            end
            newNframes = str2double(nexposures.String);
            [nexposures.String, imageParams.nframes] = StringHelper.formatNumber(newNframes);
        end

        function TimeDelayCallback(obj)
            imageParams = obj.camera.imgparams;
            timedelay = imageParams.timedelay;
            timedt = obj.delaytime;
            if ~ValidationHelper.isStringValueANumber(timedt.String)
                timedt.String = timedelay;
                obj.sendError('Only numbers can be accepted! Reverting.');
            end
            newdelay = str2double(timedt.String);
            [timedt.String, imageParams.timedelay] = StringHelper.formatNumber(newdelay);
        end

        %binning
        function callbackBinningSelection(obj, ~, event) %#ok<INUSL>
            binnum = event.NewValue.Tag;
            binnum = str2double(binnum);
            obj.camera.setBinning(binnum);
        end



        function refresh(obj)
            obj.edtexposuretime.String = obj.camera.imgparams.exposuretime*1e-3;
            
        end
     end

     % overridden from EventListener
     methods
         % When events happen, this function jumps.
         % event is the event sent from the EventSender
         function onEvent(obj, event)
             if event.isError ...
                     || isfield(event.extraInfo, Camera.EVENT_CAMERA_PARAMS_CHANGED)
                 obj.refresh();
             end
         end
     end
     

end

