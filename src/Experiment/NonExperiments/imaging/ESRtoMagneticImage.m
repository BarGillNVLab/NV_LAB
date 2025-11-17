function ESRtoMagneticImage(signal, reference, frequency)
    I_helm = [0,0,2]; pixBin = 1;
    Date='diffrent_try\';
    Temperature='tape';
    path= 'G:\'; %  saving path
    averaged_meas=signal;
    averaged_ref=reference;
    freq=frequency;
    % averaged_meas = permute(averaged_meas, [3 2 1]);
    % averaged_ref = permute(averaged_ref, [3 2 1]);
    %Average ESR over all the pixels
     ref = squeeze(mean(mean(averaged_ref(:,:,:),1),2));
    means = squeeze(mean(mean(averaged_meas(:,:,:),1),2));
    
    % Normailzing data: mean/refrence y axis of ESR plot
    y=means./ref;
    % y=squeeze(mean(mean(new_array(:,:,:),1),2));
    % x axis of ESR plot
    x=freq;
    % [x,y]=deleting_extra_frequency_data(Temperature);
    % x=importdata(fullfile(path,'x.mat'));
    % y=importdata(fullfile(path,'y.mat'));
    % plot ESR
    figure(11);
    plot(x,y,'*');
    
    %smooth curve by removing Hyperfine
     y1 = smooth(y,0.1,'loess')';
    % Flip the y data and shift by 2 so that contrast will be positive
    figure;
    plot(x,(-y1+2))
    
    %Find the peak value location and width of peak. define MinPeakHeight by
    %looking at the contrast of ESR sothat findpeak function choose peak of ESR
    %not noise.
    [pks,locs,w] = findpeaks((-y1+2),'MinPeakHeight',1.008);
    
    % Plot the values of peak to see on ESR
    hold on
    plot (x(locs),pks,'*r')
    
    % y = (P1/(x-P2)^2+P3)+P4 function used for fitting (lorenzian function)
    % where P1 = location of peak, P2 = width of peak, P3 = contrast and in the
    % last coulmn give offset
    
    Nhyp=2;
    Npeak =2;
    p0=zeros(1,Npeak+1);
    for i=1:1:Npeak
        p0(2*i-(2-i))=x(locs(i));%peak location
        p0(2*i-(2-i)+1)= w(1,i); %width
        p0(2*i-(2-i)+2)= pks(1,i);%contrast
    end
    p0(Npeak*3+1)=1.01;  %offset
    
    
    %x1=[2780:0.1:2970];
    % fitting tha average ESR data 
    [yprime,params_all,resnorm,residual,conf] = lorentzian_fit(x,y,2,Nhyp,Npeak,p0);
    
    %For two dips only
    % find the frequency where we get ESR dips to extract average magnetic
    % field parallel to NV axis by using B// = (f+ - f-)./(2*Y_b), Y_b =
    % Reduced gyromagnetic ratio
    %dips1 = params_all(1:3:Npeak*3);% MegaHz
    % Y_b = 28;% MegaHz/milliTesla
    % B_parallel = (dips1(1,2)-dips1(1,1))./(2*Y_b);%milliTesla
    % ZFS = (dips1(1,2)+dips1(1,1))./(2); % MegaHz
    % B_parallel = B_parallel*10; % Gauss
    
    %% seprate the ESR data pixel by pixel and the fit at each pixel to find B at each pixel
    
    [m,n] = size(averaged_meas(:,:,1));
    binned_meas = sepblockfun(averaged_meas(1:m-mod(m,pixBin),1:n-mod(n,pixBin),:),[pixBin,pixBin,1],@mean);
     binned_ref  = sepblockfun(averaged_ref(1:m-mod(m,pixBin),1:n-mod(n,pixBin),:),[pixBin,pixBin,1],@mean);
    
    % fit pixel by pixel
    [FitDataMatrix,Delta] = NG_fitperpixel_lorentzian(binned_meas,binned_ref,freq,Nhyp,Npeak,params_all);
    
    
    
    %% extract ESR dips for each pixel
    [m,n] = size(FitDataMatrix);
    dips = zeros(m,n,Npeak);
    Num_params=Npeak*3;
    for i = 1:1:m
        for j = 1:1:n
            dips(i,j,:) = FitDataMatrix(i,j).PARAMS(1:3:Num_params);
        end
    end
    
    %% calculating the magnetic field:
    
    
    Diamond_nature_angle =45;       % in degrees. Magnomite - 45
    theta = 0;                      % the rotation angle of the diamond in degrees
    theta_x=0;
    theta_y=0;
      
    pixSize = 0.024;%  0.133;in um
    camBin = 2;
    
    if Npeak == 8
        [B] = MagneticFieldCalculate3(dips, I_helm, theta + Diamond_nature_angle,theta_x, theta_y);
    %      pixSize = 0.024;%0.133;% in um
    %     camBin = 3;
        x = linspace(0,pixSize*pixBin*camBin*m,m);
        y = linspace(0,pixSize*pixBin*camBin*n,n);
       
    
        figure_title = {'Bx [\muT]', 'By [\muT]', 'Bz [\muT]'};
        for i = 1:3
        figure(24+i);
        imagesc(y,x,B(:,:,i));
        title(figure_title{i},'fontsize',16,'fontname','Ariel');
        xlabel('X-axis_{um}','fontsize',14);
        ylabel('Y-axis_{um}','fontsize',14);
        colorbar;
        end
    
    elseif Npeak == 4
        [B_z] = MagneticFieldCalculate111_4peaks(dips, I_helm, theta,theta_x,theta_y);
    %       pixSize = 0.0303;% in um
        x = linspace(0,pixSize*pixBin*m,m);
        y = linspace(0,pixSize*pixBin*n,n);
    
        figure(31);
    
        imagesc(x,y,B_z);
        title('Bz (\muT)','fontsize',16,'fontname','Ariel');
        xlabel(' \mum','fontsize',16, 'fontname','Ariel');
        ylabel(' \mum','fontsize',16,'fontname','Ariel');
        set (gca, 'fontsize',16,'fontname','Ariel');
        colorbar;
    %     range = 2;
    %     caxis([mean(mean(B_z))-range,mean(mean(B_z))+range]);
    
    elseif Npeak == 2
    % [B_z] = MagneticFieldCalculate_Z(I_helm, theta,theta_x,theta_y,Delta);
     [B_z] = MagneticFieldCalculate_Z(dips, I_helm, theta,theta_x,theta_y,Delta);
    %  [m, n, ~] = size(Delta); MHz_TO_uT = 1/2.8 * 1e2;
    % B_meas_NV = zeros(m, n, 1);
    % B_meas_NV(:,:,1) = Delta(:,:);
    % B_meas_NV(:,:,1) = (dips(:,:,2) - dips(:,:,1));
     % B_meas_NV(:,:,1) = (dips(2) - dips(1));
    % ZFS_(:,:,1) = ((dips(:,:,2) + dips(:,:,1)))./2;
    % B_meas_NV = B_meas_NV/2 * MHz_TO_uT;                            % convert MHz to uT on each NV axis
    
    % B_z= B_meas_NV/cosd(54.74)   ;
        pixSize = 0.030; %0.024;% 0.133;% in um
        camBin = 3;
        x = linspace(0,pixSize*pixBin*camBin*m,m);
        y = linspace(0,pixSize*pixBin*camBin*n,n);
    
        figure;
    %     imagesc(x,y,B_z);
        imagesc(B_z);
        sss=' ';
        title(['B_z at',sss,Temperature,char(176),'C'],'fontsize',16,'fontname','Ariel');
        % xlabel(' \mum','fontsize',16, 'fontname','Ariel');
        % ylabel(' \mum','fontsize',16,'fontname','Ariel');
        set (gca, 'fontsize',16,'fontname','Ariel');
        colorbar; colormap parula;
        % caxis ([3070 3150]);
    %     range = 10;
    %     caxis([mean(mean(B_z))-range,mean(mean(B_z))+range]);
    
    
    
    %     figure(32);
    %     imagesc(y,x,ZFS_(:,:,1));
    %     title('D (Mega Hz)','fontsize',16,'fontname','Ariel');
    %     xlabel(' \mum','fontsize',16, 'fontname','Ariel');
    %     ylabel(' \mum','fontsize',16,'fontname','Ariel');
    %     set (gca, 'fontsize',16,'fontname','Ariel');
    %     colorbar;
    %save the B_z as Temperaturedeg.mat in 'path'
         save(fullfile(path,strcat(Temperature,'.mat')), 'B_z');
    
    end
end
        
    