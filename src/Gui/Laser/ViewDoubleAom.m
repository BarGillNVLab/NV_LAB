classdef ViewDoubleAom < ViewVBox & EventListener
    % VIEWDOUBLEAOM A GUI component that handles a layout with two AOMs,
    % which can be switched fast from one to another
    
    properties (Constant)
        DEFAULT_DECIMAL_DIGITS = 2
    
        CHANNEL_ONE = 1
        CHANNEL_TWO = 2
    end
    
    properties
        %%%% UI related %%%
        % AOM 1
        radioChoose1            % radio button
        edtPowerPercentage1     % edit-text
        sliderPower1            % slider
        % AOM 2
        radioChoose2            % radio button
        edtPowerPercentage2     % edit-text
        sliderPower2            % slider
        
        %%%% the laser part name (to send requests and to listen to) %%%%
        mLaserPartName
    end
    
    methods
        
        %% constructor
        function obj = ViewDoubleAom(parent, controller, doubleAom)
            % parent - gui component
            % controller - the main GUI controller
            % doubleAom - object of derived from AomDouble[NiDaqControlled)]
            % (Class exists is in the folder Physical\Laser)
            
            %%%% init variables %%%%
            nameToListen = {doubleAom.aomOne.name, doubleAom.aomTwo.name, doubleAom.swapSwitch.name};
            padding = 0;
            spacing = 3;
            
            %%%% Constructors %%%%
            obj@EventListener(nameToListen);
            obj@ViewVBox(parent, controller, padding, spacing);
            
            %%%% the laser physics object %%%%
            obj.mLaserPartName = doubleAom.name;
            
            
            % UI components init
            widths = ViewLaserPart.WIDTHS;  % a bit of extra width before start of line, for graphical purposes
            rowHeight = ViewLaserPart.ROW_HEIGHT;
            
            partRow1 = uix.HBox('Parent', obj.component, 'Spacing', 5, ...
                    'UserData', obj.CHANNEL_ONE);
                obj.radioChoose1 = uicontrol(obj.PROP_RADIO{:}, 'Parent', partRow1, ...
                        'String', 'AOM 1', ...
                        'Callback', @obj.radioChooseCallback);
                obj.edtPowerPercentage1 = uicontrol(obj.PROP_EDIT{:}, 'Parent', partRow1, ...
                        'Callback', @obj.edtPowerPercentageCallback);
                obj.sliderPower1 = uicontrol(obj.PROP_SLIDER{:}, 'Parent', partRow1, ...
                        'Callback', @obj.sliderPowerCallback, ...
                        'Min', doubleAom.minValue, 'Max', doubleAom.maxValue);
                partRow1.Widths = widths;
                
            partRow2 = uix.HBox('Parent', obj.component, 'Spacing', 5, ...
                    'UserData', obj.CHANNEL_TWO);
                obj.radioChoose2 = uicontrol(obj.PROP_RADIO{:}, 'Parent', partRow2, ...
                        'String', 'AOM 2', ...
                        'Callback', @obj.radioChooseCallback);
                obj.edtPowerPercentage2 = uicontrol(obj.PROP_EDIT{:}, 'Parent', partRow2, ...
                        'Callback', @obj.edtPowerPercentageCallback);
                obj.sliderPower2 = uicontrol(obj.PROP_SLIDER{:}, 'Parent', partRow2, ...
                        'Callback', @obj.sliderPowerCallback, ...
                        'Min', doubleAom.minValue, 'Max', doubleAom.maxValue);
                partRow2.Widths = widths;
            
            %%%% UI components set values  %%%%
            obj.width = -1;
            obj.height = 2*rowHeight + spacing + 2*padding;
            
            obj.refresh();
        end
        
        
        %% Callbacks
        %%%% These methods actually request stuff from the physics. Carefull! %%%%
        function edtPowerPercentageCallback(obj, src, ~)
            aom = obj.getChannelFromHandle(src);
            newValue = src.String;
            newValue = str2double(regexp(newValue, '^-?\d+\.?\d*', 'match', 'once'));
            % ^ Leave only number (of form ###.### maybe proceeded by a minus sign)
            aom.value = round(newValue, obj.DEFAULT_DECIMAL_DIGITS);    % Now round it, before sending it onwards
        end
        
        function sliderPowerCallback(obj, src, ~)
            aom = obj.getChannelFromHandle(src);
            newValue = src.Value;
            aom.value = round(newValue, obj.DEFAULT_DECIMAL_DIGITS);	% Now round it, before sending it onwards
        end
        
        function radioSelection(obj, channelNum)
            % Manually defining radiobuttons (and not using uibuttongroup),
            % due to display options
            switch channelNum
                case obj.CHANNEL_ONE
                    obj.radioChoose1.Value = 1;
                    obj.radioChoose2.Value = 0;
                case obj.CHANNEL_TWO
                    obj.radioChoose1.Value = 0;
                    obj.radioChoose2.Value = 1;
                otherwise
                EventStation.anonymousWarning('Something went wrong with the double AOM');
            end
        end
        
        function radioChooseCallback(obj, src, ~)
            [~, channelNum] = obj.getChannelFromHandle(src);
            obj.radioSelection(channelNum);
            obj.laserPart.activeChannel = channelNum;
        end
        
    end
    
    methods (Access = protected)
        function refresh(obj)
            lPart = obj.laserPart;
            mValues = lPart.values;
            
            aomOneValue = round(mValues(1), ViewLaserPart.SIGNIFICANT_DIGITS);
            obj.edtPowerPercentage1.String = strcat(num2str(aomOneValue), NiDaq.UNITS);
            obj.sliderPower1.Value = aomOneValue;
            
            aomTwoValue = round(mValues(2), ViewLaserPart.SIGNIFICANT_DIGITS);
            obj.edtPowerPercentage2.String = strcat(num2str(aomTwoValue), NiDaq.UNITS);
            obj.sliderPower2.Value = aomTwoValue;

            obj.radioSelection(lPart.activeChannel)
        end
        
		function laserPartObject = laserPart(obj)
			% Get the laser part
			laserPartObject = getObjByName(obj.mLaserPartName);
            if isempty(laserPartObject); throwBaseObjException(obj.mLaserPartName); end
        end
        
        function [channel, channelNum] = getChannelFromHandle(obj, handle)
            channelNum = handle.Parent.UserData;
            switch channelNum
                case obj.CHANNEL_ONE
                    channel = obj.laserPart.aomOne;
                case obj.CHANNEL_TWO
                    channel = obj.laserPart.aomTwo;
            end
        end
    end  % Access = protected
    
    %% Overridden from EventListener
    methods
        function onEvent(obj, event) %#ok<INUSD>
            % We don't need the event details. we can ask the details directly from the laser!
            obj.refresh();
        end
    end
    
end

