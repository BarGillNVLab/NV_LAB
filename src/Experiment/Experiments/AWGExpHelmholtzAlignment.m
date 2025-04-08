classdef AWGExpHelmholtzAlignment < AWGExpESR
    %%% An experiment that can change the helmholtz field and run an ESR
    %%% experiment
    % Yachel Ben Shalom Apr. 2021
    % This experiment can run an ESR sweep, just like the ESR experiment.
    %In addition, it can:
    %(1) move a singe field helm (Btheta, Bphi, Brho, Bx, By, Bz), and run an ESR
    %experiment on it. Averages will be set to one.
    %This can be used with high fields to see the decay in FL signal when
    %not allinged.
    
    properties (Constant)
        SCAN_AXES = ["Bx", "By", "Bz", "Brho", "Btheta", "Bphi"];
        MY_NAME = 'Magnetic Field Alignment';
    end
    
    properties
        scan_values
        scan_axis
        peak_min_contrast = 0.1
        currESR
        widthPlot   % bollean. If to plot the resonance width in the left figure instead of the contrast. Usefull alignment tool by looking on the off-resonance deep.
    end
    
    properties (Access = private)
        helm
        helm_ESR = []
        helm_ESR_centers = []
        helm_ESR_FL = []
        fit_params = struct('A',[],'C',[])
        num_peaks = 1;
        scanStopFlag
        figHandle
        gui
        measurDim
    end
    
    methods
        function obj = AWGExpHelmholtzAlignment
            obj@AWGExpESR(ExpMagneticFieldAlignment.MY_NAME);
%             obj@AWGExpESR();
            obj.helm = getObjByName('Helmholtz');
            if isempty(obj.helm)
                obj.helm = helmholtz;
            end
            obj.averages = 1;
            obj.repeats = 100;
            obj.widthPlot = 0;
        end
    end
    
    %%  get and set methods
    methods
        function set.scan_axis(obj, axis)
            if ~sum(strcmp(obj.SCAN_AXES, axis))
                error('no type of axis ''%s'' to scan', axis)
            end
            obj.scan_axis = axis;
        end
    end
    
    %% main methodsm.ru
    methods
        function runScan(obj)
            obj.helm.checkLimits(obj.scan_axis, obj.scan_values);
            if isempty(obj.mirrorSweepAround)
                obj.measurDim = 1;
            else
                 obj.measurDim = 2; % add another dim for the mirror sweep
            end
            obj.currESR = 0;
            
            N = length(obj.scan_values);
            obj.helm_ESR = ones(N, length(obj.frequency),  obj.measurDim);
            obj.helm_ESR_FL = NaN(N,  obj.measurDim);
            obj.helm_ESR_centers = NaN(N, obj.num_peaks,  obj.measurDim);
            obj.fit_params.A = NaN(N,  obj.measurDim);
            obj.fit_params.C = NaN(N, obj.measurDim);
            ESR = zeros(length(obj.frequency),  obj.measurDim);
            FL = zeros(1,  obj.measurDim);
            
            try
                obj.helm.output('ON');
                for k = 1:length(obj.scan_values)
                    if obj.scanStopFlag
                        break
                    end
                    
                    % move to the desired point
                    obj.helm.set(obj.scan_axis, obj.scan_values(k));
                    if obj.currESR == 0
                        obj.run;            % run an ESR sweep, based on ESR
                    else
                        obj.restart;          
                    end
                    
                    % Get FL and ESR signals from the raw data
                    for m = 1: obj.measurDim
                        switch m
                            case 1
                                ESR(:, m) = obj.signalParam.value;
                            case 2
                                ESR(:, m) = obj.signalParam2.value;
                        end
                        FL(m) = mean(obj.signal(:));
                    end
                    obj.helm_ESR(k,:,:) = ESR;
                    obj.helm_ESR_FL(k,:) = FL;
                    
                    [f0, width, contrast] = ESRfit(obj);
                    obj.helm_ESR_centers(k,:,:) = f0;
                    obj.fit_params.C(k,:) = width;
                    obj.fit_params.A(k,:) = contrast;

                        obj.currESR = k;
                    obj.plotResults; %plot results, based on the ESR results
                end
                obj.helm.output('OFF');
            catch err
                err2warning(err);
%                 fprintf('Experiment failed at trial %d, attempting again.\n', trial);
                fprintf('Experiment failed\n')
                try
                    obj.helm.output('OFF');
                    spcm.stopExperimentCount;
                catch
                end
            end
        end
    end
    
    % methods
    %     function [centers, A ,C] = LorenzianCenter(obj, x, y)
    %         %find obj.num_peaks peaks in the spectra and fit it to a
    %         %Lorentzian line shape to find the center. Will return a center
    %         %matrix with obj.num_peaks centers. If less are found - NaN
    %         %will be used.
    % 
    %         [xData, yData] = prepareCurveData(x', smooth(1-y));
    %         [pks,I] = min(y); % finds the N
    %         locs = x(I);
    % 
    %         % Set up fittype and options.
    %         centers = NaN(1,obj.num_peaks);
    %         A = NaN(1,obj.num_peaks);
    %         C = NaN(1,obj.num_peaks);
    %         if ~isempty(pks)
    %             % Fit model to data.
    %             ft = fittype( 'a*C2/((x-x0)^2+C2)', 'independent', 'x', 'dependent', 'y' );
    %             opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
    %             opts.Display = 'Off';                
    %             for k = 1:length(pks) % fit the different found peaks. limit by the frequency of the prev. pick
    %                 opts.StartPoint = [10 pks(k) locs(k)];      %C, a, x0
    %                 opts.Lower = [0.1 0 0.8*min(x)];            %C, a, x0; Limit X to within a few MHz
    %                 opts.Upper = [200 0.5 1.2*max(x)];          %C, a, x0
    %                 [fitresult, ~] = fit(xData, yData, ft, opts);
    %                 centers(k) = fitresult.x0;
    %                 A(k) = fitresult.a;
    %                 C(k) = fitresult.C2;
    %             end
    %         end
    %     end
    % end
    
    %% plot
    
    methods (Access = {?Experiment, ?ViewExperimentPlot})
        function plotResults(obj)
            obj.plotResults@Experiment;
            index = obj.currESR;
            
            %create figure handle
            if isempty(obj.figHandle) || ~isfield(obj.figHandle, 'main') || ~isvalid(obj.figHandle.main)
                obj.figHandle = {};
                obj.figHandle.main = figure('Name', 'Magnetic field sweep ESR', 'Position', [200 200 1400,400]);
                obj.gui.stopButton = uicontrol('Parent', obj.figHandle.main, 'Style', 'pushbutton', 'String', 'Stop', 'Position', [0.0 0.5 100 20], 'Visible', 'on', 'Callback', @obj.PushBottonCallback);
                obj.figHandle.sp1 = subplot(1,4,1);
                obj.figHandle.sp2 = subplot(1,4,2);
                obj.figHandle.sp3 = subplot(1,4,3);
                obj.figHandle.sp4 = subplot(1,4,4);               
            else
                figure(obj.figHandle.main)
            end
            
            %plot ESR fits
            if obj.currESR == 0; return; end
            set(gcf, 'CurrentAxes', obj.figHandle.sp1);
            hold on;
            if obj.widthPlot
                lorenzParam = obj.fit_params.C;
                lorenzParamName = 'Fitted width';
            else
                lorenzParam = obj.fit_params.A;
                lorenzParamName = 'Fitted Contrast';
            end
            if obj.measurDim == 1
                yyaxis left
                plot(obj.scan_values, squeeze(obj.helm_ESR_centers(:,1,:)), '-b', 'Color', [0 0.4470 0.7410]);
                ylabel(lorenzParamName);
                yyaxis right
                plot(obj.scan_values, lorenzParam(:,:), '-b', 'Color', [0.8500 0.3250 0.0980]);
                ylabel(lorenzParamName);
            else
                yyaxis left
                plot(obj.scan_values, squeeze(obj.helm_ESR_centers(:,1,1)), '-b',  'Color', [0 0.4470 0.7410]);
                plot(obj.scan_values, squeeze(obj.helm_ESR_centers(:,1,2)), '--b', 'Color', [0 0.4470 0.7410]);
                ylabel('Fitted frequency')
                yyaxis right
                plot(obj.scan_values, lorenzParam(:,1), '-b',  'Color', [0.8500 0.3250 0.0980]);
                plot(obj.scan_values, lorenzParam(:,2), '--b', 'Color', [0.8500 0.3250 0.0980]);
                ylabel('Fitted Contrast')
            end
            axis tight
            xlabel('scan values');
            title('Solid - normal, Dashed - Mirrored');
            grid on
            
            %plot ESR            
            set(gcf,'CurrentAxes',obj.figHandle.sp2)
            if size(obj.helm_ESR,3) > 1
                S = sum(obj.helm_ESR,3) - (obj.measurDim - 1);
            else
                S = obj.helm_ESR(:,:,1);
            end                
            imagesc(obj.frequency,obj.scan_values,S)
            xlabel('frequency')
            ylabel('scan values')
            colorbar            
            
            % plot the abs value of the signal
            set(gcf,'CurrentAxes',obj.figHandle.sp3)
            plot(obj.scan_values(1:index),obj.helm_ESR_FL(1:index,:))
            xlabel('scan values')
            ylabel('Backround counts (kcps)')            
            axis tight
            
            if sum(obj.signal(:)) ~= 0
                [~, ~, ~, ~, ~, fitObj] = ESRfit(obj);
                [freq, signal, sterr, signal_2, sterr_2] = extractESRdata(obj);
                set(gcf,'CurrentAxes',obj.figHandle.sp4)
                hold off
                fi = obj.frequency(1):0.01:obj.frequency(end);
                if obj.measurDim == 1
                    plot(fi, fitObj(fi), 'color', [0, 0.4470, 0.7410], 'LineWidth', 2, 'DisplayName', 'Normal');
                    hold on
                    errorbar(freq, signal, sterr, '.', 'color', 'b', 'MarkerSize', 7);
                else
                    fitObj1 = fitObj{1}; fitObj2 = fitObj{2};
                    plot(fi, fitObj1(fi), 'color', [0, 0.4470, 0.7410], 'LineWidth', 2, 'DisplayName', 'Normal');
                    hold on
                    errorbar(freq, signal, sterr, '.', 'color', 'b', 'MarkerSize', 7);
                    plot(fi, fitObj2(fi), 'color', [0.8500, 0.3250, 0.0980], 'LineWidth', 2, 'DisplayName', 'Mirrored');
                    errorbar(freq, signal_2, sterr_2, '.', 'color', 'r', 'MarkerSize', 7);
                end

                xlabel('Frequency (MHz)')
                ylabel('FL (norm)')
                axis tight
            end
        end
        
        function PushBottonCallback(obj, PushButton, EventData)
           obj.scanStopFlag = 1;    %to stop the field sweep experiment
        end
    end
end