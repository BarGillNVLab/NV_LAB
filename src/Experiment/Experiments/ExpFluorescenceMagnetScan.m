classdef ExpFluorescenceMagnetScan < Experiment
    %%% An experiment that changes the magnet's position and counts photons.
    % Ty Zabelotsky and Yachel Ben Shalom September. 2021
    % This experiment is used for magnetic field alignment.
    % Currently the experiment only supports XYZ scans, but should be easy
    % to implement R Theta and Phi
    
    properties (Constant)
        AXIS = 'XYZ';
    end
    
    properties
        measureDim            % boolean
        
        axesAvaliable
        axesTypes
        axesLowerLimits
        axesUpperLimits
        
        firstAxis               % 'X', 'Y' or 'Z'
        secondAxis              % 'X', 'Y' or 'Z'
        firstAxisPoints
        secondAxisPoints
        pointIntegrationTime    % in sec
        
        id                      % (1*3) cell array stage address
        stage                   % (1*3) cell array stage object itself
        spcm                    % spcm object
        
        data                    % output data of the scanning
        dataStd                 % output std data of the scanning
        
        mode                    % string. Either 'continuous' or 'tracked'
                                % ('tracked' is to be implemented in the future, if needed)
    end
    
    methods
        function obj = ExpFluorescenceMagnetScan
            obj.stage = ClassExternalFieldControl.GetInstance();
            obj.axesAvaliable = obj.stage.stage_names_;
            obj.axesTypes = obj.stage.stage_types_;
            obj.axesLowerLimits = obj.stage.stage_lower_limit_;
            obj.axesUpperLimits = obj.stage.stage_upper_limit_;
            
            obj.averages = 1;
            obj.repeats = 1;
            
            obj.firstAxis = 'X';
            obj.secondAxis = 'Y';
            
            obj.pointIntegrationTime = 1; % in sec
            
            obj.mode = 'continuous';
        end
    end
    
    %%  get and set methods
    methods
        function set.firstAxis(obj, axis)
            if ~sum(strcmp(obj.axesAvaliable, axis))
                error('no type of axis ''%s'' to scan', axis)
            end
            obj.firstAxis = axis;
        end
        
        function set.secondAxis(obj, axis)
            if ~sum(strcmp(obj.axesAvaliable, axis))
                error('no type of axis ''%s'' to scan', axis)
            end
            obj.secondAxis = axis;
        end
    end

    methods (Access = protected)
        %% Overridden from Experiment
        function prepare(obj)
            % Initialize devices (SPCM, PulseGenerator, etc.)
            
            % Sequence
            %%% Useful parameters for what follows
            
            %%% Create
            S = Sequence;
            switch obj.mode
                case 'continuous'
                    S.addEvent(obj.pointIntegrationTime, {'greenLaser','detector'});
                case 'tracked'
                    % to be implemented in the future
            end
            
            % Initialize

            obj.prepareInternal(S)
            
            % Set parameter, for saving
            if isempty(obj.secondAxis)
                obj.measurDim = 1;
                obj.mCurrentXAxisParam.value = obj.firstAxisPoints;
            else
                obj.measurDim = 2;
                obj.mCurrentXAxisParam.value = obj.firstAxisPoints;
                obj.mCurrentYAxisParam.value = obj.secondAxisPoints;
            end
        end
        
        function perform(obj)
            
            if isempty(obj.secondAxis)
                obj.measurDim = 1;
                obj.mCurrentXAxisParam = ExpParamDoubleVector(obj.firstAxis, [], [], 'mm', obj.NAME);
                obj.mCurrentYAxisParam = [];
                obj.signalParam = ExpResultDoubleVector('FL', [], [], 'kcps', obj.NAME);
            else
                obj.measurDim = 2;
                obj.mCurrentXAxisParam = ExpParamDoubleVector(obj.firstAxis, [], [], 'mm', obj.NAME);
                obj.mCurrentYAxisParam = ExpParamDoubleVector(obj.secondAxis, [], [], 'mm', obj.NAME);
                obj.signalParam = ExpResultDoubleVector('FL', [], [], 'kcps', obj.NAME);
            end
            
            pg = getObjByName('pulseGenerator');
            pg.on('greenLaser');
            
            obj.spcm = getObjByName('spcm');
            if obj.measurDim == 1
                N = length(obj.firstAxisPoints);
                obj.data = zeros(1, N);
                obj.dataStd = zeros(1, N);
                currentStage = obj.stage{obj.AXIS == obj.firstAxis};
                for i = 1:N
                    currentStage.Move(obj.firstAxisPoints(i));
                    while ~currentStage.OnTarget
                        pause(obj.pointIntegrationTime);
                    end
                    [obj.data(i), obj.dataStd(i)]  = obj.getData;
                end
                
            elseif obj.measurDim == 2
                N = length(obj.firstAxisPoints);
                M = length(obj.secondAxisPoints);
                obj.data = zeros(N, M);
                currentStage1 = obj.stage{obj.AXIS == obj.firstAxis};
                currentStage2 = obj.stage{obj.AXIS == obj.secondAxis};
                for i = 1:N
                    currentStage1.Move(obj.firstAxisPoints(i));
                    for j = 1:M
                        currentStage2.Move(obj.secondAxisPoints(j));
                        while ~(currentStage1.OnTarget && currentStage2.OnTarget)
                            pause(obj.pointIntegrationTime);
                        end
                        [obj.data(i,j), obj.dataStd(i,j)]  = obj.getData;
                    end
                    fprintf('%.0f%% ', 100*i/N);
                end
                fprintf('\n');
            end 
            
            % Saving results in the Experiment parameters
            obj.signalParam.value = obj.data;
            obj.signalParam.sterr = obj.dataStd;

            pg.off('greenLaser');
        end
    end

    methods
        %% Helper functions
        function [volt, std] = getData(obj)
            if isempty(obj.spcm); throwBaseObjException(Spcm.NAME); end
            obj.spcm.setSPCMEnable(true);
            obj.spcm.prepareReadByTime(obj.pointIntegrationTime);
            try
                [volt, std] = obj.spcm.readFromTime;
                pause(obj.pointIntegrationTime);
                obj.spcm.clearTimeRead;
            catch err
                try
                    obj.spcm.clearTimeRead;
                catch
                end
                rethrow(err);
            end
        end
    end
end     
