%% Creating a file which save all the inputs we give to ESR experiment
% create a path to save the data


mkdir '\\DiskStation\Camera Data\bindu_data_save_try\NewCode\Newcode4A1';
p='\\DiskStation\Camera Data\bindu_data_save_try\NewCode\Newcode4A1';
avg =10; % no of averages
%open a txt file to save experiment parameters
fileID = fopen([p '\data.txt'], 'w');
%   power=LaserDriverFunctionPool('GetPower');
MW_amp=a.amplitude;
Repeats=a.repeats;
averages=a.averages;
Exposure_time=a.detectionDuration;
%     fprintf(fileID,'power=');
%     fprintf(fileID,'%6.2f %12.8f\n\n', power);
% fprintf(fileID,'\n\n');
%whatever comments you'd like to add:
% fprintf(fileID,'Laser power ~250(mill) , binning in camera 3*3, Helmholtz 3v');

fprintf(fileID,'MW_amp=');
fprintf(fileID,'%6.2f %12.8f\n\n', MW_amp);
fprintf(fileID,'\n\n');

fprintf(fileID,'Objective = 60X binning = 3');
fprintf(fileID,'\n\n');

fprintf(fileID,'Repeats=');
fprintf(fileID,'%6.2f %12.8f\n', Repeats);
fprintf(fileID,'\n\n');

fprintf(fileID,'averages=');
fprintf(fileID,'%6.2f %12.8f\n', averages);
fprintf(fileID,'\n\n');

fprintf(fileID,'Exposure_time=');
fprintf(fileID,'%6.2f %12.8f\n', Exposure_time);
fprintf(fileID,'\n\n');

fprintf(fileID,'Number_of_loops=');
fprintf(fileID,'%6.2f %12.8f\n', avg);
fprintf(fileID,'\n\n');

% fprintf(fileID,'Helmeholtz_x:');
% fprintf(fileID,'%6.2f %12.8f\n',I_helm(1));
% fprintf(fileID,'\n\n');
%
% fprintf(fileID,'Helmeholtz_y:');
% fprintf(fileID,'%6.2f %12.8f\n',I_helm(2));
% fprintf(fileID,'\n\n');

fprintf(fileID,'Helmeholtz_z:');
fprintf(fileID,'%6.2f %12.8f\n',I_helm(3));
fprintf(fileID,'\n\n');

% fclose(fileID);
% Running the ESR to save the data
% a=ESR;
for x=1:avg
    a = ESR;
    % a.frequency =[2815:2:2831,2832:0.5:2860,2861:2:2882,2883:0.5:2908,2909:2:2930];%2A
    a.frequency =[2785:3:2809,2810:0.5:2835,2838:6:2909,2910:0.5:2935,2938:3:2954];%4A
    a.amplitude=-5;
    a.repeats=20;
    a.averages=1;
    a.Run;
    s_meas = [p, '/ESR_meas_average_number_',num2str(x)];
    %     s_ref = [p, '/ESR_ref_average_number_',num2str(x)];
    %     s_freq=[p,'/freq'];
    %     freq = a.frequency;

         averaged_meas = squeeze(a.averaged_meas); % squeeze added 28/4/19 by Idan
         averaged_ref = squeeze(a.averaged_ref); % squeeze added 28/4/19 by Idan
%    averaged_meas = squeeze(a.signalParam.value); % squeeze added 28/4/19 by Idan

    notSaved=1;
    while (notSaved)
        try
            %             save(s_ref,'averaged_ref','-v7.3');
            save(s_meas,'averaged_meas','-v7.3');
            %             save(s_freq,'freq','-v7.3');
            notSaved = 0;
        catch ME
            notSaved = 1
        end
    end

    x
end

%  combining all averages together
path = p;
% ESR_single_ref = load([path,'\ESR_ref_average_number_1.mat']);
ESR_single_meas = load([path,'\ESR_meas_average_number_1.mat']);
% averaged_ref = (ESR_single_ref.averaged_ref);
averaged_meas =  (ESR_single_meas.averaged_meas);
for x=1:avg
    ESR_single_meas = load([path,'\ESR_meas_average_number_',num2str(x),'.mat']);
    %     ESR_single_ref = load([path,'\ESR_ref_average_number_',num2str(x),'.mat']);
    %     averaged_ref = (x-1)/x*averaged_ref+1/x*(ESR_single_ref.averaged_ref);
    averaged_meas = squeeze(ESR_single_meas.value);
    averaged_meas =  (x-1)/x*averaged_meas+1/x*(averaged_meas);
    x
end

% averaged_ref = averaged_ref/(k-1);
% averaged_meas = averaged_meas/(k-1);

freq = a.frequency;
save([path,'\freq'],'freq','-v7.3');
save([path,'\ESR_meas_average'],'averaged_meas','-v7.3');
% save([path,'\ESR_ref_average'],'averaged_ref','-v7.3');

