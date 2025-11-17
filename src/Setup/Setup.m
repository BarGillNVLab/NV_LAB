classdef Setup < handle
    %SETUP responsible for initiation of "real world physics" objects
    %   this class generates everything the controller 
    %       needs, physically speaking.
    
    properties
    end
    
    properties (Hidden, Constant)
        NEEDED_FIELDS = {'lasers', 'Daq', 'pulseGenerator', 'setupNumber', 'spcm'}; % 'stages' deleted - Yachel
    end
    
    methods (Static)
        function obj = getInstance()
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = Setup;
            end
            obj = localObj;
        end
        
        function init()
            Setup.getInstance;
        end
    end
    
    methods (Access = private) 
        function obj = Setup()
            obj@handle();          
            
            %%% Get the json %%%
            jsonStruct = JsonInfoReader.getJson();
            
            %%% Check missing fields %%%
            missingField = FactoryHelper.usualChecks(jsonStruct, Setup.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'Can''t find the reserved word "%s" in the main section of the file "setupInfo.json"', ...
                    missingField);
            end
            
            obj.displaySetupMode();	% Show the user what Setup is being run
            PulseGenerator.create(jsonStruct.pulseGenerator);

            %%%% init important objects %%%%
            %%%% NEW: instantiate correct DAQ class %%%%
            if isfield(jsonStruct, 'Daq')
                switch lower(jsonStruct.Daq.type)
                    case 'nidaq'
                        daq.create(jsonStruct.Daq);
                    case 'arduinodaq'
                        daq.create(jsonStruct.Daq);
                    otherwise
                        error('Unknown Daq type: %s', jsonStruct.Daq.type);
                end
            else
                error('No Daq field found in JSON.');
            end

            
            Spcm.create(jsonStruct.spcm);
            ImageScanResult.init;
            StageScanner.init;
            SaveLoad.init;
            SignalGenerator.create(jsonStruct.signalGenerators);	% the first call to getSG() also inits them
            % MW.create(jsonStruct.microwave); % moved into FrequencyGenerator.getFG
            LaserGate.getLasers;        % the first call to getLasers() also inits them
			ClassStage.getStages;       % the first call to getStages() also inits them
            Tracker.init;
            % Joystick.init should be also here. For the moment, it is found in the appropriate stage
        end
    end
       
    methods (Static, Access = private)
        
        function displaySetupMode()
            % Find setup number and make sure it is of proper class
            setupNum = JsonInfoReader.setupNumber;
            
            % Find working mode
            mode = PathHelper.SetupMode;
            switch mode
                case 'beta'
                    mode = 'develeoper';
                case 'prod'
                    mode = 'production';
            end
            
            % Display
            
            fprintf('...\nInitializing Setup %s in %s mode...\n', setupNum, mode)
            
        end
    end
    
end

