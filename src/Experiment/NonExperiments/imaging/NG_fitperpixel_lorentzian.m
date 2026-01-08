function [FitDataMatrix,Delta]=NG_fitperpixel_lorentzian(averaged_meas,freq,Nhyp,Npeak,params_all) %averaged_meas/ref is rows x columns x freq
m = length(averaged_meas(1,:,1));
% n = length(averaged_meas(1,:,1));
n = length(averaged_meas(1,1,:));
x = freq;
FitDataMatrix=[];
%     FitDataMatrix(m,n).YPRIME=[];
%     FitDataMatrix(m,n).PARAMS=[];
%     FitDataMatrix(m,n).RESNORM=[];
%     FitDataMatrix(m,n).RESIDUAL=[];
%     FitDataMatrix(m,n).CONF=[];
FitDataMatrix(m,n).YPRIME= zeros(1,size(averaged_meas,1));
FitDataMatrix(m,n).PARAMS=zeros(1,length(params_all));
FitDataMatrix(m,n).RESNORM=0;
FitDataMatrix(m,n).RESIDUAL=zeros(size(averaged_meas,1),1);
FitDataMatrix(m,n).CONF=zeros(length(params_all),2);
badpixels = zeros(m,n);
badpixelcounter=0;
for i=1:m %running over all rows
    for j=1:n %for each row running over all columns
        %ym=squeeze(measb(i,j,:));
        %yr=squeeze(refb(i,j,:));
        ym=squeeze(averaged_meas(:,i,j));
        y=ym'; 
        % y = averaged_meas./averaged_ref; %added by rotem 16.03.22
                 % plot(x,y)
          y = smooth(y,0.04,'loess')';
         %figure;plot(x,y')
        %set start point to be the fit data from last pixel.
        % if i==1 && j==1
        %  start_a1=(yMin+yMax)/2;
        %  start_b1=(xMin+xMax)/2;
        % start_c1=(widthMin+widthMax)/2;
        %else
        %start_a1=FitDataMatrix(i,j-1,1);
        % start_b1=FitDataMatrix(i,j-1,2);
        %start_c1=FitDataMatrix(i,j-1,3);
        
        %end
        %         fitOptions = fitoptions(fitType);
        %         fitOptions.Lower =([yMin, xMin, widthMin]);
        %         fitOptions.Upper =([yMax, xMax, widthMax]);
        %         fitOptions.StartPoint =repmat([start_a1, start_b1, start_c1], [1,gaussNum]);
        %
        %P0=[];
        %BOUNDS=[];
        % fitting
        % myfit = fit(x',y',fitType,fitOptions)
        [YPRIME, PARAMS, RESNORM, RESIDUAL,CONF,delta]=lorentzian_fit(x,y,2.5,Nhyp,Npeak,params_all,'print');
       Delta(i,j)=delta;
% [YPRIME, PARAMS, RESNORM, RESIDUAL,CONF]=lorentzian_fit(x',y,2.5,Nhyp,Npeak,params_all,'print'); %added by rotem 16.03.22

%         if (j==1 && i==1)
%             [YPRIME, PARAMS, RESNORM, RESIDUAL,CONF]=lorentzian_fit(x,y,2.5,Nhyp,Npeak,params_all,'print');
%         else
%             if j>1
%                 [YPRIME, PARAMS, RESNORM, RESIDUAL,CONF]=lorentzian_fit(x,y,2.5,Nhyp,Npeak,FitDataMatrix(i,j-1).PARAMS,'print');
%             else
%                 [YPRIME, PARAMS, RESNORM, RESIDUAL,CONF]=lorentzian_fit(x,y,2.5,Nhyp,Npeak,FitDataMatrix(i-1,j).PARAMS,'print');
%             end
%         end
Nparams= Npeak*3;
FreqParams = PARAMS(1:3:Nparams);
%         FreqParams = PARAMS([1,4,7,10,13,16,19,22]);
        % new addition to overcome rediculus fitting - delete in needed 16/12/18
        if (mean(mean(CONF))>2*10^3 || min(FreqParams)<2.74*10^3 || max(FreqParams) > 3.05*10^3)
            %                 if j>1
            badpixels(i,j)=1;
            badpixelcounter = badpixelcounter+1
            if i>1
                [YPRIME, PARAMS, RESNORM, RESIDUAL,CONF]=lorentzian_fit(x',y,0.003024,Nhyp,Npeak,FitDataMatrix(i-1,j).PARAMS,'print');
            end
            %                     else
            %                     [YPRIME, PARAMS, RESNORM, RESIDUAL,CONF]=lorentzian_fit(x,y,0.003024,Nhyp,Npeak,FitDataMatrix(i-1,length(m)).PARAMS,'print')
            %                 end
        end
        FitDataMatrix(i,j).YPRIME=YPRIME;
        FitDataMatrix(i,j).PARAMS=PARAMS;
        FitDataMatrix(i,j).RESNORM=RESNORM;
        FitDataMatrix(i,j).RESIDUAL=RESIDUAL;
        FitDataMatrix(i,j).CONF=CONF;
        l=[i,j];
        disp(l)

    end
%     close(figure(11))
     % figure(11)
     % plot(x,YPRIME,'r')
     % hold on
     % plot(x,y,'b')
     % hold off
     end

end
% new addition to overcome rediculus fitting - delete if needed 16/12/18

%end