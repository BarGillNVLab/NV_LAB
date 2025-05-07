classdef StartStop < GuiComponent
    %VIEWSTAGESCANPANELPLOT panel for coloring the image
    %   Detailed explanation goes here
    
    properties
        startbtn                % start button
        stopbtn                 %stop button
        contchx                 %continues checkbox


%         initialroi             % updates only when acquiring a new image

    end
    
    methods
        function obj = StartStop(parent, controller)
            obj@GuiComponent(parent, controller);
            panel = uix.Panel('Parent', parent.component, 'Title', 'Image acquision', 'Padding', 5);
            vboxMain = uix.VBox('Parent', panel, 'Spacing', 5, 'Padding', 0);
            obj.component = vboxMain;
            obj.startbtn = uicontrol(obj.PROP_BUTTON_BIG_GREEN{:}, 'Parent',vboxMain, 'String', 'Acquire');
            obj.stopbtn = uicontrol(obj.PROP_BUTTON_BIG_RED{:}, 'Parent',vboxMain, 'String', 'Stop');
            obj.contchx = uicontrol(obj.PROP_CHECKBOX{:}, 'Parent',vboxMain, 'String', 'continuous');
            vboxMain.Heights = [50 50 20];

            %%% callbacks
            obj.startbtn.Callback = @(h,e) obj.StartCallback;
            obj.stopbtn.Callback = @(h,e) obj.StopCallback;
            obj.contchx.Callback = @(h,e) obj.continueCallback;
            

            obj.height = 100;
            obj.width = 140;
            obj.refresh;
            
            
        end

        function refresh(obj)
            obj.contchx = false;
            obj.stopbtn.Enable = 'off';
        end

    
        function StartCallback(obj)
            cameracpture = getObjByName(CameraCapture.NAME);
            if obj.contchx 
                set(obj.startbtn, 'Enable', 'off');
            end
            cameracpture.startAcquision;
%             obj.initialroi = cameracpture.mcameraimageparams.roi;
        end

        function continueCallback(obj)
            if obj.contchx ==0
                obj.contchx =1;
            else
                obj.contchx =0;
            end
            cameracpture = getObjByName(CameraCapture.NAME);
            if obj.contchx ==1
                
                cameracpture.measurementType = 2;
                obj.stopbtn.Enable = 'on';
            else
                cameracpture.measurementType = 1;
                obj.stopbtn.Enable = 'off';
            end
        end
        function StopCallback(obj)
            cameracpture = getObjByName(CameraCapture.NAME);
            cameracpture.mCurrentlyAcquiring = false;
            set(obj.startbtn, 'Enable', 'on');
        end


            
    end
    
end