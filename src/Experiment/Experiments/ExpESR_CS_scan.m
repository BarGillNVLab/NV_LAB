classdef ExpESR_CS_scan < handle
    % 2-D ESR (move to each point in the range of [x,y] and perform ESR)
    
    %     properties (Constant)
    %         NAME = 'ESRScan'
    %     end
    
    properties
        ESR_object %ESR Object
        ESR_CS_object
        stage
        x % [from, to, num of points]
        y % [from, to, num of points]
        z_fixed % Fixed point
        data
    end
    methods
        function obj = ExpESR_CS_scan() % Defult values go here
            %obj@Experiment(ExpESRScan.NAME);
            %obj.isTracking = false;
            obj.ESR_CS_object = ExpESR_CS;
            obj.ESR_object = ExpESR;
            
            obj.ESR_object.isTracking = false;
            obj.ESR_object.averages = 1;
            obj.ESR_object.frequency = [2600:1:3200]; %galya
            obj.ESR_object.amplitude = -2;
            obj.ESR_object.repeats = 800;
            
            
            obj.ESR_CS_object.window_start = 2632;
            obj.ESR_CS_object.window_end = 3144;
            obj.ESR_CS_object.nChannels = 3;
            obj.ESR_CS_object.MWChannel = {'MW' , 'MW2', 'MW3'};
%             obj.ESR_CS_object.Raster = data;
            obj.ESR_CS_object.freq_range =linspace(2600,3200,601); %glaya
            obj.ESR_CS_object.isTracking = false;
            obj.ESR_CS_object.averages = 1;
            obj.ESR_CS_object.frequency = [2600:1:3200];%glaya
            obj.ESR_CS_object.amplitude = [-2,-2,-2];
            obj.ESR_CS_object.repeats = 800;
            
            %obj.stage = getObjByName('Stage (Fine) - PI P562'); -- old
            %code by Galya
            obj.stage = getObjByName(ClassStage.getStages{1}.name);
            % set the default vectors as the scan parameters from the gui.
            obj.x = [obj.stage.scanParams.from(1), obj.stage.scanParams.to(1), obj.stage.scanParams.numPoints(1)];
            obj.y = [obj.stage.scanParams.from(2), obj.stage.scanParams.to(2), obj.stage.scanParams.numPoints(2)];
            obj.z_fixed = obj.stage.scanParams.fixedPos(3);
        end
        
        
        function run(obj)
            x_vec = linspace(obj.x(1), obj.x(2), obj.x(3)); %
            y_vec = linspace(obj.y(1), obj.y(2), obj.y(3));
            if isempty(obj.ESR_object.mirrorSweepAround) || obj.ESR_object.numChannels>1
                n = 2; %MW on , MW off
            else
                n = 4; % [MW on , MW off] * 2 --> for the second channel /mirror frequency
            end
            obj.data = zeros([obj.x(3), obj.y(3), n, length(obj.ESR_object.frequency) ,obj.ESR_object.averages]);
            obj.stage.move('z', obj.z_fixed);
            for i = 1:length(x_vec)
                for j = 1:length(y_vec)
                    obj.stage.move(['x', 'y'], [x_vec(i), y_vec(j)]);
                    fprintf('(%.2f, %.2f): ', x_vec(i), y_vec(j));
                    obj.ESR_object.restart();
                    obj.data(i,j,:,:,:) = obj.ESR_object.signal;
                    obj.SaveExperiment('\\DiskStation\Camera Data\Setup5_CS\Scan_2nd\Reference_meas_2\Raster_esr');
                    %save('C:\Users\OWNER\Google Drive\NV Lab\Rotem\temp_ESR_Scan.mat','-struct', 's');
                    freq =  obj.ESR_object.frequency;
                    meas = obj.ESR_object.signal(1,:);
                    ref =  obj.ESR_object.signal(2,:);
                    target_data = (ref-meas)/mean(ref);%(averaged_ref-averaged_meas)/mean(averaged_ref);
                    target_data = target_data-mean(target_data);
                    
                    [~, num_pks, guess] = getFitGuess(freq,target_data, 0.002);
                    
                    if num_pks==8
                        [final_fit, params, ~, ~, conf] = lorentzian_fit(freq,target_data, 2, 2, ...
                            num_pks, guess);
                        [peak_locs, fit_err] = getFitVals(params, conf, 'Peak');
                        fit_flag = true;
                    else
                        final_fit = [];
                        peak_locs = [];
                        fit_flag = false;
                    end
                    
                    data = mock_diamond2;
                    data.peak_locs = peak_locs';
                    data.sig = meas;
                    data.ref = ref;
                    traget = target_data;
                    data.target = target_data;
                    data.smp_freqs = freq;
                    data.num_pts = length(freq);
                    obj.ESR_CS_object.Raster = data;
                    obj.ESR_CS_object.restart;
                    obj.ESR_CS_object.SaveExperiment(sprintf('\\\\DiskStation\\Camera Data\\Setup5_CS\\Scan_2nd\\Reference_meas_2\\ARF1_3freq_%d%d', i ,j));
                   obj.ESR_CS_object.restart;
                    obj.ESR_CS_object.SaveExperiment(sprintf('\\\\DiskStation\\Camera Data\\Setup5_CS\\Scan_2nd\\Reference_meas_2\\ARF1_3freq_2nd_%d%d', i ,j));%glaya

                    if (obj.ESR_object.emergencyStopFlag == 1)
                        break;
                    end
                end
                if (obj.ESR_object.emergencyStopFlag == 1)
                    break;
                end
            end
        end
    end
    
    %     methods (Access = protected)
    %         function params = alternateSignal(obj)
    %             params = 0;
    %         end
    %
    %         function wrapUp(obj)
    %         end
    %
    %         function perform(obj)
    %         end
    %
    %         function prepare(obj)
    %         end
    %     end
    
    methods
        function exp = SaveExperiment(obj, fileName)
            % Save all properties as exp.propertyName, and adds a exp.date
            % field. If file name is given - sames using filename. Elese -
            % open a GUI interface
            % saves using
            names = fields(obj);
            for k = 1:length(names)
                command = sprintf('exp.%s = obj.%s;',names{k},names{k});
                eval(command);
            end
            exp.date = datestr(now,'yyyy-mm-dd_HH-MM-SS');
            eval(sprintf('save(''%s'',''exp'');',fileName));
        end
    end
end