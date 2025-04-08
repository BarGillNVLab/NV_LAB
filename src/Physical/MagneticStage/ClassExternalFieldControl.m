classdef (Sealed) ClassExternalFieldControl < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Dependent = true)
        stage_names_
        stage_types_ %linear or rotation
        stage_lower_limit_
        stage_upper_limit_
    end
    
    properties (Access = private)       
        stopFlag = 0;        
        GUI
        stages = {}; % 
        stage_names
        stage_types = {}
        softLimitsMax = []
        softLimitsMin = []
        stage_lower_limit
        stage_upper_limit
    end
    
    methods (Static, Access = public)
        function obj = GetInstance(varargin)
            %input varargin{1} can contain the GUI handle (or be empty)
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = ClassExternalFieldControl;             
            end
            obj = localObj;
            if nargin && ~isempty(varargin{1}) % insert a new handle
                obj.GUI=varargin{1};
            end
            %%% open GUI if needed. If GUI is closed (the obj was clled not
            %%% from the GUI), the GUI will in turn call it again but this
            %%% time with it's handle
            if isempty(obj.GUI) || ~nnz(findall(0,'Type','Figure') == obj.GUI.figure) %the latter tests if the GUI is open
                MagneticFieldGUI;
            else
                obj.Initialize;
            end
        end
    end
    
    methods
        function obj = ClassExternalFieldControl            
                    
        end
        function x = get.stage_names_(obj)
            x = obj.stage_names;
        end
        function x = get.stage_types_(obj)
            x = obj.stage_types;
        end
        function x = get.stage_lower_limit_(obj)
            x = obj.stage_lower_limit;
        end
        function x = get.stage_upper_limit_(obj)
            x = obj.stage_upper_limit;
        end
        
        function Initialize(obj) % read this from file
            setup = JsonInfoReader.getJson().magneticStages;
            try
                for k = 1:length(setup)
                    if isempty(obj.stages) || k > length(obj.stages)
                        obj.stages{k} = eval(sprintf('%s(%s);', setup(k).controllClass, setup(k).connactName));
                        obj.stage_types{k} = obj.stages{k}.type;
                    end
                end
                obj.stage_names = {setup(:).axisName};
                if isempty(obj.softLimitsMax)
                    obj.softLimitsMax = inf * ones(1,length(obj.stages));
                end
                if isempty(obj.softLimitsMin)
                    obj.softLimitsMin = -inf * ones(1,length(obj.stages));
                end
                if isempty(obj.stage_upper_limit)
                    obj.stage_upper_limit = inf * ones(1,length(obj.stages));
                end
                if isempty(obj.stage_lower_limit)
                    obj.stage_lower_limit = -inf * ones(1,length(obj.stages));
                end
                
            catch err
                obj.Close
                rethrow(err)
            end
        end
        function Close(obj)
            for k=1:length(obj.stages)
                try
                    obj.stages{k}.Close
                catch err
                    warning(err.message)
                end
            end
            obj.stages = []; %% added by rotem 2023.04.13 - for initialization obj.stages needs to be empty, so we empty it after closing for re-initialization
        end
        function Reset(obj)
            obj.Close;
            obj.Initialize;           
            obj.quaryPos;          
        end
        function Home(obj)
            obj.Close;
            obj.Initialize;           
            for k=1:length(obj.stage_names)
                obj.stages{obj.IndexFromName(obj.stage_names{k})}.Home(obj.stage_names{k});
            end
            obj.quaryPos;
        end
        function index = IndexFromName(obj,index)
            switch class(index)
                case 'double'
                    %nothing to do
                case 'char'                    
                    index = find(strcmp(obj.stage_names,index));
                    if isempty(index)
                        error('Unknown stage type %s', index)
                    end
                case 'cell'
                    cell_index = index;
                    index = zeros(1,length(index));
                    for k = 1:length(index)
                        index(k) = IndexFromName(obj,cell_index{k});
                    end
                otherwise
                    error('Input type must be char or double, %s entered',class(index))
            end
        end
        function name = NameFromIndex(obj, index)
            %Give the name of the stage (a cell array), as used by the GUI, from an
            %index.
            name = cell(1,length(index));
            if any(index > length(name))
                error('Unknown index for magnetic stage system')
            end
            for k = 1:length(name)
                name{k} = obj.stage_names{index(k)};
            end
        end
        function SetSoftLimitsMax(obj, index, newVal)
            index = obj.IndexFromName(index);
            obj.softLimitsMax(index) = newVal;
        end
        function SetSoftLimitsMin(obj, index, newVal)
            index = obj.IndexFromName(index);
            obj.softLimitsMin(index) = newVal;          
        end
    end
    methods
        function pos = quaryPos(obj, what) 
            if nargin == 1
                what = 1:length(obj.stage_names_); % This has the same order as given by IndexFromName
            end
            index = obj.IndexFromName(what);
            %name = obj.NameFromIndex(index);
            pos = zeros(1,length(index));
            for k = 1:length(index)
                pos(k) = obj.stages{index(k)}.Position;
                eval(sprintf('obj.GUI.Value%s.String = %s;',num2str(index(k)),num2str(pos(k),4)));                
            end  
        end
        function Step(obj,which,stepSize)
            index = obj.IndexFromName(which);             
            currentPos = obj.stages{index}.Position;
            if isnumeric(stepSize)
                obj.SetPosition(index, currentPos + stepSize);
            elseif isa(stepSize,'struct') && isfield(stepSize,'linear') && isfield(stepSize,'rotation')
                switch obj.stage_types{index}
                    case 'linear'
                        obj.Step(index,stepSize.linear)
                    case 'rotation'
                        obj.Step(index,stepSize.rotation)
                    otherwise
                        error('Unknown stage type')
                end
            end
        end
        function SetPosition(obj,index, newPos)
            obj.stopFlag = 0;
            index = obj.IndexFromName(index);
            [OK, newPos] = obj.testInput(newPos, index);%%%!!!!!!!!!!
            if OK                
                timeOut = obj.stages{index}.Timeout(newPos);
                obj.stages{index}.Move(newPos);                
                dt = tic;
                while ~obj.stages{index}.OnTarget || obj.stopFlag == 1
                    pause(0.2)
                    if toc(dt) > timeOut
                        obj.Stop(index);                        
                        error('timeOut')
                    end
                end                
            end
            obj.quaryPos(index);
        end        
        function [OK, value] = testInput(obj, value, index)
            OK = 1;
            %%% Test / cunvert input type 
            index = obj.IndexFromName(index);
            if isa(value,'char')
                value = str2double(value);
            end
            if ~isa(value, 'double')
                OK = 0;
            end
            %%% test values 
            if isempty(value) || isnan(value)% test input is a number
                OK = 0;
            elseif isfield(obj.stages{index},'maxPosition') &&...
                    isfield(obj.stages{index},'minPosition') && ... % test value is within the range allowed by the stage
                    (value > obj.stages{index}.maxPosition ||...
                    value < obj.stages{index}.minPosition)
                OK = 0 ;
            end
            if value > obj.softLimitsMax(index) || value < obj.softLimitsMin(index)
                OK = 0;
            end
            if OK == 0
                warning('Value could not be changed - out of bounds or invalid input type')
            end
        end
        
        function Stop(obj,index)
            obj.stopFlag = 1;
            if nargin == 1
                index = 1:length(obj.stages);
            else
                index = obj.IndexFromName(index);
            end
            for k = index
                obj.stages{k}.Stop;
            end
            warning('Stage stoped by the User')
        end        
    end
    
end