classdef Joystick < BaseObject
    %JOYSTICK Class for represnting physical joystick
    
    properties (Constant)
        NAME = 'joystick';
        
        % Against glitches
        NUM_OF_POINTS = 3;      % int. number of points to check before making a decision.
        SEPERTAION_TIME = 1;    % double. minimum time (in seconds) between checking of buttons.
    end
    
    properties
        % stick
        mStageName
        isEnabled
        
        % buttons
        binaryButtonState
        index
        clicked
        timer
    end
    
    methods
        function obj = Joystick(stageName)
            obj@BaseObject(Joystick.NAME);
            obj.mStageName = stageName;
            obj.isEnabled = false;      % By default
        end
        
        function buttonAction(obj)
            % Checks if the joystick buttons are pressed and executes commands.
            
            stage = getObjByName(obj.mStageName);
            if isempty(stage); throwBaseObjException(obj.mStageName); end
            
            % For convenience
            nPoints = obj.NUM_OF_POINTS;
            tSeperation = obj.SEPERTAION_TIME;
            
            
            if ~isequal(size(obj.binaryButtonState), [1 nPoints])
                obj.binaryButtonState = zeros(1, nPoints);
                obj.index = 0;
                obj.clicked = 0;
                obj.timer = 0;
            end
            
            if obj.clicked
                % Wait after previous button press & initialize parameters
                if (toc(obj.timer) < tSeperation)
                    return
                else
                    obj.clicked = 0;
                    obj.binaryButtonState = zeros(1, nPoints);
                end
            end
            
            obj.binaryButtonState(obj.index+1) = stage.ReturnJoystickButtonState();
            obj.index = mod(obj.index+1, nPoints);
            decision = mode(obj.binaryButtonState);
            
            if (decision ~= 0)
                obj.timer = tic;
                obj.clicked = 1;
            end
            
            switch decision
                case 1
                    fprintf('Button 1 is pressed\n');
                case 2
                    fprintf('Button 2 is pressed\n');
                case 3
                    fprintf('Buttons 1 & 2 are pressed\n');
                case 4
                    fprintf('Button 3 is pressed\n');
                case 5
                    fprintf('Buttons 1 & 3 are pressed\n');
                case 6
                    fprintf('Buttons 2 & 3 are pressed\n');
                case 7
                    fprintf('All buttons pressed\n');
                otherwise
            end
        end
    end
    
    methods (Static)
        function init(stageName)
            jstick = getObjByName(Joystick.NAME);
            if isempty(jstick)
                % There is no joystick yet, so we create it
                jstick = Joystick(stageName);
                addBaseObject(jstick);
            end
        end
    end
    
end

