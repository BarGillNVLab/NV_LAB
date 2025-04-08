classdef (Abstract) IQSwitch < handle
    %IQSWITCH Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Abstract, Constant)
        MAX_AMPLITUDE   % in volts
        ANGLE_SHIFT     % in degrees
    end
    
    properties
       amplitudeScale %from -1 to 1 relative to the maximal amplitude       
       angle 
    end
    
    methods
        function obj = IQSwitch
            % Initialize values
            obj.amplitudeScale = 0;
            obj.angle = 0;
        end
        
        function scalePower(obj, newAmplitudeScale, newAngle) 
            % Change the power using the amplitudeScale and angle, with
            % respect to the maximal allowed output.
            % If newAmplitudeScale & newAngle are given - amplitudeScale
            % and angle will be updated in obj. Otherwise, the values from
            % amplitudeScale and angle will be used.
            if nargin > 1
                obj.angle = newAngle;
                obj.amplitudeScale = newAmplitudeScale;
            end
            power = obj.amplitudeScale * obj.MAX_AMPLITUDE; %in V
            theta = (obj.angle + obj.ANGLE_SHIFT) * pi/180;
            
            obj.setPower(power*cos(theta), power*sin(theta))            
        end
        
        function setPower(obj, Ival, Qval)
            % Sets the I and Q output voltage
            newAmplitude = sqrt(Ival^2+Qval^2);
            if newAmplitude > obj.MAX_AMPLITUDE
                error('IQ output exeeds allowed value!')
            end
            obj.setIValue(Ival)
            obj.setQValue(Qval)
        end
    end
    
    methods (Abstract)
        % Here go the specifics of controlling each of the channels
        setIValue(obj, newVal)
        setQValue(obj, newVal)
    end
    
end

