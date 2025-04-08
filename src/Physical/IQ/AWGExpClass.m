classdef AWGExpClass < ExpClass
    % A subclass that uses the AWG.
    properties (Access = protected)
        AWG
        maxOutputV = 0.5; % maximal output of a single channel. This is assinged to 1 in the waveform
        maxTotalOutputV = 0.5; %maximal total output        
    end
    properties
       trigDelay 
       trigDuration
       IQtiltAngle %deg.
    end
    methods
        function obj = AWGExpClass
            obj.trigDelay = 0.072;
            obj.trigDuration = 0.1;
            obj.IQtiltAngle = 45;%
        end
        function set.trigDelay(obj,newVal)
            OK1 = obj.TestMaxLength(newVal,1);
            OK2 = obj.TestLim(newVal,-10,1e4);%limits in  mus
            if OK1 && OK2 %&& obj.lastDelay ~= newVal
                obj.trigDelay = newVal;
                obj.changeFlag = 1;
            end
        end
        function set.trigDuration(obj,newVal)
            OK1 = obj.TestMaxLength(newVal,1);
            OK2 = obj.TestLim(newVal,0.01,0.1);%limits in  mus
            if OK1 && OK2 %&& obj.lastDelay ~= newVal
                obj.trigDuration = newVal;
                obj.changeFlag = 1;
            end
        end
        function set.IQtiltAngle(obj,newVal)
            OK1 = obj.TestMaxLength(newVal,1);
            OK2 = obj.TestLim(newVal,0,360);%limits in  mus
            if OK1 && OK2 %&& obj.lastDelay ~= newVal
                obj.IQtiltAngle = newVal;
                obj.changeFlag = 1;
            end
        end
        function Initialize(obj)                        
            %%%% initialize the AWG
            % connect to the AWG.
            try
                AWGtype = GetDataFile('AWGtype');
                switch AWGtype
                    case {'KEYSIGHT 33600A'}
                        AWGvisa = GetDataFile('AWGvisa');
                        obj.AWG = AgilentAWGclass.getInstance(AWGvisa);
                        disp('Connecting to KEYSIGHT 33600A AWG')                       
                        obj.AWG.runMode ='trigLastPulse'; %set the AWG run mode
                        %obj.AWGprivate.setRunMode('single'); %set the AWG run mode
                        %obj.AWGprivate.setRunMode('mix'); %set the AWG run mode
                    otherwise
                        error('Unknown AWG type or no data in file')
                end
            catch err
                try
                    obj.AWG.CloseConnection();
                catch
                end
                obj.AWG=-1;
                error('AWG connection failed: %s',err.message)
            end             
            %%%
            Initialize@ExpClass(obj);
        end


        function CloseExperiment(obj)
            try 
                obj.AWG.CloseConnection();
            catch err
                warning('AWG connection was not closed: %s',err.message);
            end
            CloseExperiment@ExpClass(obj);          
        end

        function uploadWaveforms(obj,waveform1,waveform2)
           % converts a waveform with values ranging from -1 to 1 into a waveform with maximal output given by maxOutputV and maxTotalOutputV
           class1 = class(waveform1);
           class2 = class(waveform2);
           if ~ strcmp(class1,class2)
               error('waveform class mismatch!');
           end
           if length(waveform1) ~= length(waveform2)
               error('length mismatch in waveforms!')
           end
           switch class1
               case 'cell'                  
                   V1 = {};
                   V2 = {};
                   for index = 1:length(waveform1)
                       [V1{index},V2{index}] =  obj.WaveformsToV(waveform1{index},waveform2{index});
                   end
               case {'single','double'}
                   if max(waveform1)>1 || max(waveform2)>1
                       error('Maximal output exeeded');
                   elseif min(waveform1)<-1 || min(waveform2)<-1
                       error('miniimal output exeeded');
                   end
                   V1 = waveform1*obj.maxOutputV;
                   V2 = waveform2*obj.maxOutputV;
                   Vtotal = sqrt(V1.^2 + V2.^2);
                   if max(Vtotal) > obj.maxTotalOutputV
                       error('Maximal allowed V exeeded!')
                   end
                   % upload to awg
                   
               otherwise
                   error('Unknown type')
           end
           
        end
    end
end