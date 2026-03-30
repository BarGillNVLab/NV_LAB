classdef ExpMagneticFieldAlignment < ExpESR
    %%% An experiment that can change the magnet position and run an ESR.
    % Yachel Ben Shalom June. 2021
    % This experiment can run an ESR sweep, just like the ESR experiment.
    % In addition, it can:
    %(1) move a singe field stage, and run an ESR experiment on it. Averages will be set to one.
    % This can be used with high fields to see the decay in FL signal when not allinged.
    properties (Constant)
        MY_NAME = 'Magnetic Field Alignment';
    end
    
    properties
        axesAvaliable
        axesTypes
        axesLowerLimits
        axesUpperLimits

        scanValues
        scanAxis
        peak_min_contrast = 0.1
        currESR
        
        stage_ESR_centers_public = struct('L',[],'R',[])
        stage_FL_public = []
        
        esr_sig_measurments = []
        
        widthPlot   % bollean. If to plot the resonance width in the left figure instead of the contrast. Usefull alignment tool by looking on the off-resonance deep.
    end
    
    properties (Access = private)
        stage
        stage_ESR = []
        stage_ESR_centers = []
        stage_ESR_FL = []
        fit_params = struct('A',[],'C',[])
        num_peaks = 1;
        scanStopFlag
        figHandle
        gui
        measurDim
    end
    
    methods
        function obj = ExpMagneticFieldAlignment
            obj@ExpESR([],ExpMagneticFieldAlignment.MY_NAME);
            obj.stage = ClassExternalFieldControl.GetInstance();
            obj.axesAvaliable = obj.stage.stage_names_;
            obj.axesTypes = obj.stage.stage_types_;
            obj.axesLowerLimits = obj.stage.stage_lower_limit_;
            obj.axesUpperLimits = obj.stage.stage_upper_limit_;
            
            obj.MWChannel = {'MW'};
            obj.averages = 1;
            obj.repeats = 100;
        end
    end
    
    %%  get and set methods
    methods
        function set.scanAxis(obj, axis)
            if ~sum(strcmp(obj.axesAvaliable, axis))
                error('no type of axis ''%s'' to scan', axis)
            end
            obj.scanAxis = axis;
        end
    end
    
    %% main methodsm.ru
    methods
        function runScan(obj)
            obj.checkLimits;
            if isempty(obj.mirrorSweepAround)
                obj.measurDim = 1;
            else
                obj.measurDim = 2; % add another dim for the mirror sweep
            end
            obj.currESR = 0;
            obj.scanStopFlag = 0;
            
            N = length(obj.scanValues);
            obj.stage_ESR = ones(N, length(obj.frequency),  obj.measurDim);
            obj.stage_ESR_FL = NaN(N,  obj.measurDim);
            obj.stage_ESR_centers = NaN(N, obj.num_peaks,  obj.measurDim);
            obj.fit_params.A = NaN(N, obj.measurDim);
            obj.fit_params.C = NaN(N, obj.measurDim);
            obj.stage_ESR_centers_public.L = zeros(length(obj.scanValues),  1);
            obj.stage_ESR_centers_public.R = zeros(length(obj.scanValues),  1);
            obj.stage_FL_public = zeros(length(obj.scanValues),  1);
            obj.esr_sig_measurments = zeros(length(obj.scanValues), length(obj.frequency), obj.measurDim);
            ESR = zeros(length(obj.frequency),  obj.measurDim);
            FL = zeros(1,  obj.measurDim);
            
            try
                for k = 1:length(obj.scanValues)
                    if obj.scanStopFlag
                        break
                    end
                    
                    %restart tracking between ESRs (to avoid popups waiting for confirmation) added by rotem 20.04.22
                    tracker = getObjByName(Tracker.NAME);
                    trackablePos = tracker.getTrackable(TrackablePosition.NAME);
                    trackablePos.resetTrack;
                    
                    % move to the desired point
                    obj.stage.SetPosition(obj.scanAxis, obj.scanValues(k));
                    if obj.currESR == 0
                        obj.run;            % run an ESR sweep, based on ESR
                    else
                        obj.restart;          
                    end
                    
                    % Get FL and ESR signals from the raw data
                    for m = 1: obj.measurDim
%                         ESR(:, m) = obj.signal(2*(m-1)+1,:) ./ obj.signal(2*(m-1)+2,:);
                        % ESR object already has all the data, no need to
                        % calculater it, added a switch case - 30/03/2022
                        % Ty Zabelotsky
                        switch m
                            case 1
                                ESR(:, m) = obj.signalParam.value;
                                obj.esr_sig_measurments(k,:,m) = obj.signalParam.value;
                            case 2
                                ESR(:, m) = obj.signalParam2.value;
                                obj.esr_sig_measurments(k,:,m) = obj.signalParam2.value;
                        end
                        FL(m) = mean(obj.signal(:));
                    end
                    obj.stage_ESR(k,:,:) = ESR;
                    obj.stage_ESR_FL(k,:) = FL;
                    
                    for m = 1:obj.measurDim
                        if m == 1
                            f = obj.frequencyInternal;
                        else
                            f = obj.mirrorFrequency;
                        end
                        [obj.stage_ESR_centers(k,:,m), obj.fit_params.A(k,m), obj.fit_params.C(k,m)] = obj.LorenzianCenter(f, obj.stage_ESR(k,:,m)); %find center frequency
                        switch m
                            case 1
                                obj.stage_ESR_centers_public.L(k) = obj.stage_ESR_centers(k,:,m);
                                obj.stage_FL_public(k) = FL(m);
                            case 2
                                obj.stage_ESR_centers_public.R(k) = obj.stage_ESR_centers(k,:,m);
%                                 obj.stage_FL_public.R(k) = FL(m);
                        end 
                    end
                    obj.currESR = k;
                    obj.plotResults; % plot results, based on the ESR results
                end
            catch err
                err2warning(err);
                fprintf('Experiment failed at trial %d, attempting again.\n', trial);
                try
                    spcm.stopExperimentCount;
                catch
                end
            end
        end
        
    end
    
    methods
        function [centers, A ,C] = LorenzianCenter(obj, x, y)
            %find obj.num_peaks peaks in the spectra and fit it to a
            %Lorentzian line shape to find the center. Will return a center
            %matrix with obj.num_peaks centers. If less are found - NaN
            %will be used.
            
            [xData, yData] = prepareCurveData(x', smooth(1-y));
            [pks,I] = min(y); % finds the N
            locs = x(I);

            % Set up fittype and options.
            centers = NaN(1,obj.num_peaks);
            A = NaN(1,obj.num_peaks);
            C = NaN(1,obj.num_peaks);
            if ~isempty(pks)
                % Fit model to data.
                ft = fittype( 'a*C2/((x-x0)^2+C2)', 'independent', 'x', 'dependent', 'y' );
                opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
                opts.Display = 'Off';                
                for k = 1:length(pks) % fit the different found peaks. limit by the frequency of the prev. pick
                    opts.StartPoint = [10 pks(k) locs(k)];      %C, a, x0
                    opts.Lower = [0.1 0 0.8*min(x)];            %C, a, x0; Limit X to within a few MHz
                    opts.Upper = [200 0.5 1.2*max(x)];          %C, a, x0
                    [fitresult, ~] = fit(xData, yData, ft, opts);
                    centers(k) = fitresult.x0;
                    A(k) = fitresult.a;
                    C(k) = fitresult.C2;
                end
            end
        end
        
        function checkLimits(obj)
            i = find(strcmp(obj.scanAxis, obj.axesAvaliable));
            if ~prod(obj.axesLowerLimits(i) <= obj.scanValues) || ~prod(obj.scanValues <= obj.axesUpperLimits(i))
                error('scan values out of range')
            end
        end

    end
    
    %% plot
    
    methods (Access = {?Experiment, ?ViewExperimentPlot})
        function plotResults(obj)
            obj.plotResults@Experiment;
            index = obj.currESR;
            
            %create figure handle
            if isempty(obj.figHandle) || ~isfield(obj.figHandle,'main') || ~isvalid(obj.figHandle.main)
                obj.figHandle = {};
                obj.figHandle.main = figure('Name', 'Magnetic field sweep ESR', 'Position', [200 200 1400,400]);
                obj.gui.stopButton = uicontrol('Parent', obj.figHandle.main, 'Style', 'pushbutton', 'String', 'Stop', 'Position', [0.0 0.5 100 20], 'Visible', 'on', 'Callback', @obj.PushBottonCallback);
                obj.figHandle.sp1 = subplot(1,4,1);
                obj.figHandle.sp2 = subplot(1,4,2);
                obj.figHandle.sp3 = subplot(1,4,3);
                obj.figHandle.sp4 = subplot(1,4,4);               
            else
                figure(obj.figHandle.main);
            end
            
            %plot ESR fits
            if obj.currESR == 0; return; end
            set(gcf, 'CurrentAxes', obj.figHandle.sp1)
            if obj.signal 
            if obj.widthPlot
                lorenzParam = obj.fit_params.C;
                lorenzParamName = 'Fitted width';
            else
                lorenzParam = obj.fit_params.A;
                lorenzParamName = 'Fitted Contrast';
            end
            if obj.measurDim == 1
                yyaxis left
                plot(obj.scanValues, squeeze(obj.stage_ESR_centers(:,1,:)),'-b', 'Color', [0 0.4470 0.7410]);
                ylabel('resonance');
                yyaxis right
                plot(obj.scanValues, lorenzParam(:,:),'-b', 'Color', [0.8500 0.3250 0.0980]);
                ylabel(lorenzParamName);
            else
                yyaxis left
                hold on;
                %plot(obj.scanValues, squeeze(obj.helm_ESR_centers(:,1,1)), '-b',  'Color', [0 0.4470 0.7410]);
                %plot(obj.scanValues, squeeze(obj.helm_ESR_centers(:,1,2)), '--b', 'Color', [0 0.4470 0.7410]);
                plot(obj.scanValues, squeeze(obj.stage_ESR_centers(:,1,1)), '-b',  'Color', [0 0.4470 0.7410]);
                plot(obj.scanValues, (2*obj.mirrorSweepAround-squeeze(obj.stage_ESR_centers(:,1,2))), '--b', 'Color', [0 0.4470 0.7410]);
                ylabel('resonance')
%                 axis tight


                yyaxis right
                plot(obj.scanValues, lorenzParam(:,1), '-b',  'Color', [0.8500 0.3250 0.0980]);
                plot(obj.scanValues, lorenzParam(:,2), '--b', 'Color', [0.8500 0.3250 0.0980]);
                ylabel(lorenzParamName)
                hold off;
            end
            axis tight
            xlabel('scan values')
            title('Solid - normal, Dashed - Mirrored');
            grid on
            
            %plot ESR            
            set(gcf,'CurrentAxes',obj.figHandle.sp2)
            if size(obj.stage_ESR,3) > 1
                S = sum(obj.stage_ESR,3) - (obj.measurDim - 1);
            else
                S = obj.stage_ESR(:,:,1);
            end                
            imagesc(obj.frequencyInternal,obj.scanValues,S)
            xlabel('frequency')
            ylabel('scan values')
            colorbar            
            
            % plot the abs value of the signal
            set(gcf,'CurrentAxes',obj.figHandle.sp3)
            plot(obj.scanValues(1:index),obj.stage_ESR_FL(1:index,:))
            xlabel('scan values')
            ylabel('Backround counts (kcps)')            
            axis tight
            
            %plot the last ESR and its fit
            Sfit = zeros(length(obj.frequencyInternal), obj.measurDim);
            for k = 1:obj.measurDim %first point - MW on, second point MW off                
                a = obj.fit_params.A(index,k);
                c = obj.fit_params.C(index,k);
                x0 = squeeze(obj.stage_ESR_centers(index,1,k));
                if ~isnan(a) && ~isnan(c) && ~isnan(x0)
                    if k ==1
                        Sfit(:,k) = Sfit(:,k) + a*c./((obj.frequencyInternal'-x0).^2+c);
                    else
                        Sfit(:,k) = Sfit(:,k) + a*c./((obj.freqMirrored'-x0).^2+c);
                    end
                end                                
            end
            Sfit = 1 - Sfit;
            set(gcf,'CurrentAxes',obj.figHandle.sp4)
            plot(obj.frequencyInternal,squeeze(obj.stage_ESR(index,:,:)),obj.frequencyInternal,Sfit,'--')
            xlabel('Frequency (MHz)')
            ylabel('FL (norm)')
            axis tight
            end
        end
        
        function PushBottonCallback(obj, PushButton, EventData)
           obj.scanStopFlag = 1;    %to stop the field sweep experiment
        end
    end
    
    methods (Access = protected)
        function wrapUp(obj)
            % Things that need to happen when the experiment is done; a
            % counterpart for obj.prepare.
            % In the future, it will also analyze results and fit from it
            % the resonance frequency/ies
            
            obj.wrapUpInternal()
        end
    end
end