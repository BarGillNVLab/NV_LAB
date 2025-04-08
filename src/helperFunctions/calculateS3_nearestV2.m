function [S3_time,S3_value,S3_err] = calculateS3_nearestV2(x,y,err)

%%assuming that the first index of the x and y vectors corresponds o R0 time and value (accordingly)

t_R0 = x(1);
R0 = y(x==t_R0);
S3_value = []; S3_time = [];
S3_err = [];

for i =1:length(x)

    t_R1 = x(i);
    R1 = y(x==t_R1);


    if ismember(t_R1*2,x)
        t_R2 = t_R1*2; R2 = y(x==t_R2);

        if  ismember(t_R1*3,x)
            t_R3 = t_R1*3; R3 = y(x==t_R3);
%            S3_value = [S3_value,(R2 -(5/2)*R1 + (5/3)*R0-(1/6)*R3)];
            S3_value = [S3_value,-1*(-(3/2)*R2 +3*R1 -(11/6)*R0+(1/3)*R3)];
            S3_time = [S3_time, t_R1];

        elseif (t_R1*3<x(end) ) && (~ismember(t_R1*3,x))
            j =  dsearchn( x',t_R1*3);
            t_R3 = x(j); R3 = y(x==t_R3);
%            S3_value = [S3_value,(R2 -(5/2)*R1 + (5/3)*R0-(1/6)*R3)]; %oldS3 formula 
           S3_value = [S3_value,-1*(-(3/2)*R2 +3*R1 -(11/6)*R0+(1/3)*R3)]; %New "sigma 3" from JADER paper (https://arxiv.org/abs/2305.19359) 
            S3_time = [S3_time, t_R1];
        end
    end
    if nargin == 3
        R0_err = err(x==t_R0);
        R1_err = err(x==t_R1);
        R2_err = err(x==t_R2);
        R3_err = err(x==t_R3);
        %S3_err = [S3_err,sqrt(R2_err^2 +(5/2)^2*R1_err^2 +(5/3)^2*R0_err^2+(1/6)^2* R3_err^2)];
       S3_err = [S3_err,sqrt((3/2)^2*R2_err^2 +9*R1_err^2 +(11/6)^2*R0_err^2+(1/3)^2* R3_err^2)];% new sigma3
    end

end



