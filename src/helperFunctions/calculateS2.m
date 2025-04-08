function [S2_time,S2_value,S2_err] = calculateS2(x,y,err)

%%assuming that the first index of the x and y vectors corresponds o R0 time and value (accordingly)

t_R0 = x(1);
R0 = y(x==t_R0);
S2_value = []; S2_time = [];
S2_err = []; 


for i =1:length(x)

    t_R1 = x(i);

    if ismember(t_R1*2,x)
        R1 = y(x==t_R1);
        t_R2 = t_R1*2; R2 = y(x==t_R2);
        S2_value = [S2_value, (1/2)*(R2 - 4*R1 + 3*R0)];
        S2_time = [S2_time, t_R1];
        if nargin == 3
            R0_err = err(x==t_R0);
            R1_err = err(x==t_R1);
            R2_err = err(x==t_R2);
            S2_err = [S2_err,(1/2)*sqrt(R2_err^2 + 4^2 *R1_err^2 + 3^2*R0_err)];
        end
    end
end



end