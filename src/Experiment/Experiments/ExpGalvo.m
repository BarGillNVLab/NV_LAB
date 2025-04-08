classdef ExpGalvo < Experiment
    % Galvo automated dumb and simple calibration test
    
    properties (Constant)
        NAME = 'GalvoCalib'
        GALVO = 'Stage (Fine) - Galvo'
        X = 1
        Y = 2
        TITLE = 3
        MEAS = 2
        MOVE = 1
        RGB = 255
        AXIS_NAME = ['x' 'y']
        XLABEL = 'move to positions [um]'
        YLABEL = 'measured positions [um]'
    end
    
    properties
        % All of the parameters must have a set function, and when they are
        % changed, the parameter obj.changeFlag needs to be set to true
        % (unless the change is minor and the experiment can continue
        % running);
        
        myGalvo                 % a stage obj
        galvoCurPos             % in microns, [X Y]
        positions               % in microns
        
    end
    
    properties (Hidden, Access = private)
%         freqMirrored        % set in private function
        
    end
    
    methods
        
        function obj = ExpGalvo()
            % constructor
            obj@Experiment(ExpGalvo.NAME);
           
            obj.myGalvo = getObjByName(GALVO);
            
            %
            
        end
    end
    
    %% Setters
    methods
    
        function set.myGalvo(obj, newVal)
            % TODO: add a checker for generic stage or name in the future
            % If we got here, then newVal is OK.
            obj.myGalvo = newVal;
            obj.changeFlag = true;
        end
        
        function set.galvoCurPos(obj, newVal)
            % If we got here, then newVal is OK.
            obj.galvoCurPos = newVal;
            obj.changeFlag = true;
        end
        
    end
    
    %% Helper functions
    methods
        
        function zeroCenter(obj)
           obj.myGalvo.MoveXY(obj.X, 0);
           obj.myGalvo.MoveXY(obj.Y, 0);
           obj.galvoCurPos = [obj.myGalvo.Pos(obj.X) obj.myGalvo.Pos(obj.Y)];
        end
        
        function actualPositions = testAxis(obj, positions, axis)
            % moves and reads position in positions
            actualPositions = [];
            for pos = positions
                obj.myGalvo.MoveXY(axis, pos);
                actualPositions = [actualPositions obj.myGalvo.Pos(axis)];
            end
        end
        
        function plotOneByOne(obj, exp)
            i = 1;
            for e = exp
                figure(i)
                plot(exp{obj.MOVE}, obj.MEAS, '.b')
                title(exp{obj.TITLE})
                xlabel(obj.XLABEL)
                ylabel(obj.YLABEL)
                i = i + 1;
            end
        end
        
        function plotAllInOne(obj, exp)
            hold on
            for e = exp
                plot(exp{obj.MOVE}, exp{obj.MEAS}, '.')
            end
%             title('some title') TODO
            xlabel(obj.XLABEL)
            ylabel(obj.YLABEL)
            hold off
%             legend TODO
        end
    end
    
    %% Overridden from Experiment
    methods (Access = protected)
        
    end
end