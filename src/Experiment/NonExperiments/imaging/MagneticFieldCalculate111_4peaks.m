function [B_z] = MagneticFieldCalculate111_4peaks(dips, I_helm, theta,theta_x,theta_y)
% when aligned to 111

% dips - matrix of the data (m*n*8)
% B_calc_XYZ - the expected magnetic field in helmholtz system
% theta - the rotae angle of the diamond in the helmholtz system
% note 1: order of dips is from inside out
% note 2: all the vector is column vectors and the matrices multiply to right


% convertion consts:
Fx=15.06*exp(0.2138*I_helm(1))-14.54*exp(-1.681*I_helm(1));
Fy=14.92*exp(0.2006*I_helm(2))-14.85*exp(-1.557*I_helm(2));
Fz=10.49*exp(0.2878*I_helm(3))-9.407*exp(-2.177*I_helm(3));  %field in Gauss

HELM_RATIO=[Fx, Fy, Fz];

MHz_TO_uT = 1/2.8 * 1e2;

Rotate = rotz(-theta)';
RotateBack = Rotate';
Rotate_X = rotx(-theta_x)';
RotateBack_X = Rotate_X';
Rotate_Y = rotx(-theta_y)';
RotateBack_Y = Rotate_Y';


XYZtoNV = 1/sqrt(3) * [1  1 -1 -1                               % transformation matrix from XYZ system to NV system
                       1 -1  1 -1
                       1 -1 -1  1];
NVtoXYZ = 3/4 * XYZtoNV';                                       % transformation matrix from NV system to XYZ system


% calculate the expected magnetic field in NV system:
% B_calc_XYZ = I_helm .* HELM_RATIO + HELM_OFFSET;
B_calc_XYZ =  HELM_RATIO; %in Gauss
B_calc_NV = B_calc_XYZ * Rotate * Rotate_X * Rotate_Y * XYZtoNV ;
% signs = sign(B_calc_NV);                                        % the sings of the magnetic field on eact orientation
% [~,order] = sort(abs(B_calc_NV));                               % the order of the magnetic field size from small to big

% calculate the magnetic field in lab system:
[m, n, ~] = size(dips);
B_meas_NV = zeros(m, n, 1);

B_meas_NV(:,:,1) = (dips(:,:,4) - dips(:,:,1)); % out of 4 peak locations should subtract first and last- 111

B_z = B_meas_NV/2 * MHz_TO_uT;                            % convert distance to uT on each NV axis

end

