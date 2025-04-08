classdef ExpMagneticFieldESR < ExpESR
    %%% An experiment that can change the magnet position and run an ESR
    %%% experiment, at the moment for system 1.
    % Yonatan Hovav Nov. 2018
    % This experiment can run an ESR sweep, just like the ESR experiment.
    %In addition, it can:
    %(1) move a singe field stage (X,Y,Z,theta in system 1), and run an ESR
    %experiment on it. Averages will be set to one.
    %(2) to be added: with the MW off, run a 2D image of the signal of the two stages.
    %This can be used with high fields to see the decay in FL signal when
    %not allinged.
    % todo: add soft limits!
    % simplify: Only move in 1 D, and wright in advane what this direction
    % is. This will make everything much simpler.
    %signal_ has the 1D signal
    %stage_signal has the 2D_signal
    
    properties (Constant)
        NAME_MF_SCAN = 'MagneticFieldESR'
    end
    properties
        scan_values
        scan_axis
        soft_lim_max = inf
        soft_lim_min = -inf
        peak_min_contrast = 0.1
        
        %stage_soft_limits_high = struct('X', [], 'Y', [], 'Z', [], 'Theta', [])
        %stage_soft_limits_low = struct('X', [], 'Y', [], 'Z', [], 'Theta', [])
    end
    properties (Dependent = true)
        stage_ESR_
        stage_ESR_centers_
        stage_ESR_FL_
        fit_params_
    end
    properties (Access = private)
        stage
        stage_ESR = []
        stage_ESR_centers = []
        stage_ESR_FL = []
%         fig_handle_stage
%         stage_figure_handles = {}
        fit_params = struct('A',[],'C',[])
        num_peaks = 1;
        ESRstopFlag
        
    end
    methods
        function x = get.fit_params_(obj)
            x = obj.fit_params;
        end
        function x = get.stage_ESR_(obj)
            x = obj.stage_ESR;
        end
        %         function x = get.stage_ESR_fit_(obj)
        %             x = obj.stage_ESR_fit;
        %         end
        %         function x = get.stage_ESR_gof_(obj)
        %             x = obj.stage_ESR_gof;
        %         end
        function x = get.stage_ESR_centers_(obj)
            x = obj.stage_ESR_centers;
        end
        function x = get.stage_ESR_FL_(obj)
            x = obj.stage_ESR_FL;
        end
        function obj = ExpMagneticFieldESR % Defult values go here
            obj@ExpESR([], [],ExpMagneticFieldESR.NAME_MF_SCAN);
            obj.stage = ClassExternalFieldControl.GetInstance();
            obj.averages = 1;
            obj.repeats = 200;
            % set initial positions
        end
        
        function LoadExperiment(obj)
            if min(obj.scan_values) < obj.soft_lim_min || max(obj.scan_values) > obj.soft_lim_max
                error('values are not in solt lim range')
            end
            obj.LoadExperiment@ESR()
            %%% prepare the plot            
        end
        function Run(obj)
            %initialize
            Ckcps = 1e-3/(obj.detectionDuration*1e-6); %k counts per second
            obj.LoadExpeMriment;
            obj.ESRstopFlag = 0;
            obj.SetAmplitude(obj.amplitude(1),1)
            if obj.numChannels >1
                if length(obj.amplitude)<2
                    error('amplitude must have a value for the second MW channel')
                end
                obj.SetAmplitude(obj.amplitude(2),2)
            end
            if isempty(obj.mirrorSweepAround)
                measurDim = 1;
            else
                measurDim = 2; % add another dim for the mirror sweep
            end
            obj.stage_ESR = ones(length(obj.scan_values),length(obj.frequency),measurDim);
            obj.stage_ESR_FL = NaN*ones(length(obj.scan_values),measurDim);
            obj.stage_ESR_centers = NaN*ones(length(obj.scan_values),obj.num_peaks,measurDim);
            obj.fit_params.A = NaN*ones(length(obj.scan_values),measurDim);
            obj.fit_params.C = NaN*ones(length(obj.scan_values),measurDim);
            ESR = zeros(length(obj.frequency),measurDim);
            FL = zeros(1,measurDim);
            try
                for k = 1:length(obj.scan_values)
                    %move to the desired point
                    if obj.ESRstopFlag
                        break
                    end
                    obj.stage.SetPosition(obj.scan_axis, obj.scan_values(k))
                    fprintf('Stage %s at position %s\n',obj.scan_axis, num2str(obj.scan_values(k),3))
                    obj.Run@ESR; % run an ESR sweep, based on ESR
                    %% Get FL and ESR signals from the raw data
                    
                    for m = 1:measurDim %first point - MW on, second point MW off
                        temp = obj.signal_(:,:,(m-1)*2+1)./obj.signal_(:,:,(m-1)*2+2);%frequency, averages, dim
                        ESR(:,m) = squeeze(mean(temp,2));
                        FL(m) =  mean(mean(obj.signal_(:,:,(m-1)*2+2))) * Ckcps; %MW off + convert to kcps
                    end
                    %                     if measurDim >2
                    %                         ESR(:,2) = ESR(end:-1:1,2); %sweep order - to mirror the frequency correctly
                    %                     end
                    obj.stage_ESR(k,:,:) = ESR;
                    obj.stage_ESR_FL(k,:) = FL;
                    %                     for m = 1:measurDim
                    %                         obj.stage_ESR(:,k,m) = signal(1+measurDim*(m-1),:)./signal(2+measurDim*(m-1),:);
                    %                     end
                    %                     %% fit the data and plot
                    for m = 1:measurDim
                        if m == 1
                            f = obj.frequency;
                        elseif m == 2
                            f = obj.mirrorFrequency_;
                        else
                            error('unknowm dimention')
                        end
                        [obj.stage_ESR_centers(k,:,m),obj.fit_params.A(k,m),obj.fit_params.C(k,m)] = obj.LorenzianCenter(f,obj.stage_ESR(k,:,m)); %find center frequency
                    end
                    
                    obj.PlotESR(k) %plot results, based on the ESR results
                end
                obj.CloseExperiment()
            catch err
                try
                    obj.CloseExperiment()
                catch err2
                    warning(err2.message)
                end
                rethrow(err)
            end
        end
        
        function [centers,A,C] = LorenzianCenter(obj,x,y)
            %find obj.num_peaks peaks in the spectra and fit it to a
            %Lorentzian line shape to find the center. Will return a center
            %matrix with obj.num_peaks centers. If less are found - NaN
            %will be used.
%            smoothBy = 10; %consider changing to a variable
            [xData, yData] = prepareCurveData(x',smooth(1-y));
            %[pks,locs] = findpeaks(yData,xData,'NPeaks',obj.num_peaks,'SortStr','descend'); % finds the N
            [pks,I] = min(y); % finds the N
            locs = x(I);
            %reorder with respect to their frequency
            %[locs,I] = sort(locs);
            %pks = pks(I);
%            for k = 1:length(pks) %remove picks below limit
%                if pks(k)<obj.peak_min_contrast
%                    pks = [pks(1:k-1),pks(k+1:end)];
%                    locs = [locs(1:k-1),locs(k+1:end)];
%                end
%            end
            % Set up fittype and options.
            centers = NaN*ones(1,obj.num_peaks);
            A = NaN*ones(1,obj.num_peaks);
            C = NaN*ones(1,obj.num_peaks);
            if ~isempty(pks)
                % Fit model to data.
                ft = fittype( 'a*C2/((x-x0)^2+C2)', 'independent', 'x', 'dependent', 'y' );
                opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
                opts.Display = 'Off';                
                    %freqRange = [0.8*min(x),locs(1:end-1)+diff(locs)/2,1.2*max(x)];%prevents fitting the same pick twice                
                    %indexToFit = [1 ,round(1.5*find(x == locs(1:end-1))+0.5*find(x == locs(2:end))) ,length(x)];                
                for k = 1:length(pks) % fit the different found peaks. limit by the frequency of the prev. pick
                    opts.StartPoint = [10 pks(k) locs(k)];%C, a,x0
                    %opts.Lower = [0.1 obj.peak_min_contrast freqRange(k)];%C, a,x0; Limit X to within a few MHz
                    %opts.Upper = [200 0.5 freqRange(k+1)];%C a,x0
                    opts.Lower = [0.1 0 0.8*min(x)];%C, a,x0; Limit X to within a few MHz
                    opts.Upper = [200 0.5 1.2*max(x)];%C a,x0
                    %[fitresult, ~] = fit( xData(indexToFit(k):indexToFit(k+1)),...
                    %    yData(indexToFit(k):indexToFit(k+1)), ft, opts );
                    [fitresult, ~] = fit( xData,yData, ft, opts);
                    centers(k) = fitresult.x0;
                    A(k) = fitresult.a;
                    C(k) = fitresult.C2;
                end
            end
        end
        % plot - fitting the maximal peaks
        %         function PlotESR(obj,index)
        %             % plot fitted data
        %             if nargin<2
        %                 index = size(obj.stage_ESR_,1);
        %             end
        %             %plot center frequency values
        %             plot(obj.stage_figure_handles.centerFit,...
        %                 obj.scan_values(1:index),...
        %                 reshape(obj.stage_ESR_centers(1:index,:,:),index,[]))
        %             xlabel(obj.stage_figure_handles.centerFit,'scan values')
        %             ylabel(obj.stage_figure_handles.centerFit,'ESR centers (MHz)')
        %             axis tight
        %             % plot the abs value of the signal
        %             plot(obj.stage_figure_handles.backround,...
        %                 obj.scan_values(1:index),...
        %                 obj.stage_ESR_FL(1:index,:))
        %             xlabel(obj.stage_figure_handles.backround,'scan values')
        %             ylabel(obj.stage_figure_handles.backround,'Backround counts (kcps)')
        %             axis tight
        %             %Show the last ESR sweep, and the maximal points
        %             axis tight
        %             measurDim = size(obj.signal_,3)/2; %number of data typed: [MW on, MW off] * 1 for regular sweep or *2 for mirror sweep
        %             S = zeros(length(obj.frequency),measurDim);
        %             Sfit = zeros(length(obj.frequency),measurDim);
        %             for k = 1:measurDim %first point - MW on, second point MW off
        %                 Stemp = obj.signal_(:,:,(k-1)*2+1)./obj.signal_(:,:,(k-1)*2+2);
        %                 S(:,k) = squeeze(mean(Stemp,2));
        %                 for l = 1:obj.num_peaks
        %                     % we have assumed that the ESR can be fitted by
        %                     % individual lorentzian shapes
        %                     a = obj.last_fit_params.a(l,k);
        %                     c = obj.last_fit_params.C(l,k);
        %                     x0 = obj.stage_ESR_centers(index,l,k);
        %                     if ~isnan(a) && ~isnan(c) && ~isnan(x0)
        %                         Sfit(:,k) = Sfit(:,k) + a*c./((obj.frequency'-x0).^2+c);
        %                     end
        %                 end
        %                 Sfit = 1 - Sfit;
        %             end
        %             plot(obj.stage_figure_handles.fitToLast,...
        %                 obj.frequency,...
        %                 S,...
        %                 obj.frequency,...
        %                 Sfit,':')
        %             axis tight
        %         end
        % A simple fit
        function PlotESR(obj,index)
            % plot fitted data
            if nargin<2
                index = size(obj.stage_ESR_,1);
            end
            %create figure handle
            if isempty(obj.figHandle) || ~isfield(obj.figHandle,'main') || ~isvalid(obj.figHandle.main)
                obj.figHandle = {};
                obj.figHandle.main = figure('NAME_MF_SCAN','Magnetic field sweep ESR','Position', [200 200 1400,400]);
                obj.gui.stopButton = uicontrol('Parent',obj.figHandle.main,'Style','pushbutton','String','Stop','Position',[0.0 0.5 100 20],'Visible','on','Callback',@obj.PushBottonCallback);
                obj.figHandle.sp1 = subplot(1,4,1);
                obj.figHandle.sp2 = subplot(1,4,2);
                obj.figHandle.sp3 = subplot(1,4,3);
                obj.figHandle.sp4 = subplot(1,4,4);               
            else
                figure(obj.figHandle.main)
            end
            measurDim = size(obj.stage_ESR_,3);
            %plot ESR fits
            set(gcf,'CurrentAxes',obj.figHandle.sp1)
            if size(obj.stage_ESR_centers,3) == 1
                yyaxis left
                plot(obj.scan_values,squeeze(obj.stage_ESR_centers(:,1,:)),'-b')
                ylabel('Fitted frequency')
                yyaxis right
                plot(obj.scan_values, obj.fit_params.A(:,:),'--b');
                ylabel('Fitted Contrast')
            else
                yyaxis left
                plot(obj.scan_values,squeeze(obj.stage_ESR_centers(:,1,1)),'-b',...
                    obj.scan_values,2*obj.mirrorSweepAround - squeeze(obj.stage_ESR_centers(:,1,2)),'-r');
                ylabel('Fitted frequency')
                yyaxis right
                plot(obj.scan_values, obj.fit_params.A(:,1),'--b', ...
                    obj.scan_values, obj.fit_params.A(:,2),'--r');
                ylabel('Fitted Contrast')
            end
            axis tight
            xlabel('stage position')
            title('Solid - Frequncy, Dashed - Contrast');
            
            %plot colorbar of ESR (frequency and mirrord)
            set(gcf,'CurrentAxes',obj.figHandle.sp2)
            %plot ESR            
            if size(obj.stage_ESR_,3) > 1
                S = sum(obj.stage_ESR_,3) - (measurDim - 1);
            else
                S = obj.stage_ESR_(:,:,1);
            end                
            imagesc(obj.frequency,obj.scan_values,S)
            xlabel('frequency')
            ylabel('stage position')
            colorbar            
            % plot the abs value of the signal
            set(gcf,'CurrentAxes',obj.figHandle.sp3)
            plot(obj.scan_values(1:index),obj.stage_ESR_FL(1:index,:))
            xlabel('scan values')
            ylabel('Backround counts (kcps)')            
            axis tight
            %plot the last ESR and its fit
            Sfit = zeros(length(obj.frequency),measurDim);
            for k = 1:measurDim %first point - MW on, second point MW off                
                a = obj.fit_params.A(index,k);
                c = obj.fit_params.C(index,k);
                x0 = squeeze(obj.stage_ESR_centers(index,1,k));
                if ~isnan(a) && ~isnan(c) && ~isnan(x0)
                    if k ==1
                        Sfit(:,k) = Sfit(:,k) + a*c./((obj.frequency'-x0).^2+c);
                    else
                        Sfit(:,k) = Sfit(:,k) + a*c./((obj.mirrorFrequency_'-x0).^2+c);
                    end
                end                                
            end
            Sfit = 1 - Sfit;
            set(gcf,'CurrentAxes',obj.figHandle.sp4)
            plot(obj.frequency,squeeze(obj.stage_ESR_(index,:,:)),obj.frequency,Sfit,'--')
            xlabel('Frequency (MHz)')
            ylabel('FL (norm)')
            axis tight
        end
        function PlotResults(obj,index)
            %previent ESR from plotting
        end
        function PushBottonCallback(obj,PushButton, EventData)
           obj.stopFlag = 1; %to stop the ESR experiment
           obj.ESRstopFlag = 1; %to stop the field sweep experiment
           
        end
    end
end