classdef IQfastSwitchNiDaq < handle
    %Control I and Q using niDaq and I /Q switches    
    properties        
       amplitudeScale %from -1 to 1 relative to the maximal amplitude       
       angle 
    end
    properties (Access = private)        
       maxAoutput = 0.5 %in volts
       angleShift = -135; %use to tile to the regular IQ frame
       I
       Q
    end
    methods
        % Constructor
        function obj = IQfastSwitchNiDaq()            
            obj.I = NiDaqSingleVoltageChannel('I2 voltage daq controlled', 'ao2', -obj.maxAoutput, obj.maxAoutput);
            obj.Q = NiDaqSingleVoltageChannel('Q2 voltage daq controlled', 'ao3', -obj.maxAoutput, obj.maxAoutput);
            obj.amplitudeScale = 0;
            obj.angle = 0;
        end
    end    
    methods
        function scalePower(obj,newAmplitudeScale,newAngle) 
            %change the power using the amplitudeScale and angle, with
            %respect to the maximal allowed output.
            %If newAmplitudeScale & newAngle are given - amplitudeScale and angle will be
            %updated in obj. Else, the values from amplitudeScale and angle
            %will be used.
            if nargin == 1
                newAmplitudeScale = obj.amplitudeScale;                
                newAngle = obj.angle;
            else
                obj.angle = newAngle;
                obj.amplitudeScale = newAmplitudeScale;
            end
            power = obj.maxAoutput * newAmplitudeScale;%in V
            theta = (newAngle + obj.angleShift)*pi/180;
            
            
            obj.setPower(power*cos(theta),power*sin(theta))            
        end
        function setPower(obj,Ival,Qval)
            %sets the I and Q output V 
           if sqrt(Ival^2+Qval^2) > obj.maxAoutput
               error('IQ output exeeds allowed value!')
           end
           obj.I.setValue(Ival)
           obj.Q.setValue(Qval)
        end
        function close(obj)
            
        end
    end 
end