classdef LaserSourceOnefiveKatana05 < LaserPartAbstract & SerialControlled
    %LASERSOURCEONEFIVEKATANA05 laser source RS232 controller
    
    properties
        canSetEnabled = true;
        canSetValue = true;  
    end
    
    properties (Constant)
        %%%% Commands %%%%
        COMMAND_ON = 'leg=1'
        COMMAND_OFF = 'leg=0'
        COMMAND_ON_QUERY = 'leg?'
        
        COMMAND_POWER_TAKE_CONTROL = 'lps=1'
        COMMAND_POWER_GIVE_CONTROL = 'lps=0'
        COMMAND_POWER_FORMAT_SPEC = 'lp=%4.2f'
        COMMAND_POWER_QUERY = 'lp?'
        
        NEEDED_FIELDS = {'port'};
    end
    
    methods (Access = private)
        % constructor
        function obj = LaserSourceOnefiveKatana05(name, port)
            obj@LaserPartAbstract(name);
            obj@SerialControlled(port);

            obj.minValue = 0;
            obj.maxValue = 10;
            obj.units = 'mA';
            
            obj.baudRate = 38400;
            obj.dataBits = 8;
            obj.stopBits = 1;
            obj.terminator = 'LF';
            
            obj.commDelay = 0.05;
            obj.keepConnected = true;
            try
                obj.connect;
            catch err
                % We can't communicate with the laser, so what's the point?
                obj.delete
                rethrow(err)
            end
        end
    end
    
    methods    
        function connect(obj)
            obj.open;
            obj.query(obj.COMMAND_POWER_TAKE_CONTROL);
        end
        
        function disconnect(obj)
            obj.open;
            obj.query(obj.COMMAND_POWER_GIVE_CONTROL);
            obj.close;
        end

        function delete(obj)
            try
                if strcmp(obj.status, 'closed')
                    obj.disconnect;
                end
            catch err
                msg = sprintf('Could not disconnect %s upon deletion!', obj.name);
                obj.sendWarning(msg)
                err2warning(err)
            end
        end
    end
    
    %% Interact with physical laser. Be careful!
    methods (Access = protected)
        function setEnabledRealWorld(obj, newBoolValue)
            % Validating value is assumed to have been done
            errToken = '(Error 100)'; % switch is off
            if newBoolValue
                err = obj.query(obj.COMMAND_ON, errToken);
            else
                err = obj.query(obj.COMMAND_OFF, errToken);
            end
            if ~isempty(err)
                errMsg = sprintf('Can''t change the state of %s, because the key switch is off', obj.name);
                obj.sendError(errMsg);
            end
        end
        
        function setValueRealWorld(obj, newValue)
            % Validating value is assumed to have been done
            commandPower = sprintf(obj.COMMAND_POWER_FORMAT_SPEC, newValue);
            obj.query(commandPower);
        end
        
        function val = getValueRealWorld(obj)
            regex = 'lp=(\d+\.\d+)\n'; % a number of the form ##.### followed by new-line
            val = str2double(obj.query(obj.COMMAND_POWER_QUERY, regex));
        end
        
        function val = getEnabledRealWorld(obj)
            regex = 'status: ([01])\n';  % either 0 or 1 followed by new-line
            str = obj.query(obj.COMMAND_ON_QUERY, regex);
            switch str
                case '0'
                    val = false;
                case '1'
                    val = true;
                otherwise
                    val = -1;
            end
            
            % Clear memory. Needed because of Katana bug
            if obj.bytesAvailable > 1
                obj.readAll;
            end
        end
    end
    
    %% Factory
    methods (Static)
        function obj = create(name, jsonStruct)
            missingField = FactoryHelper.usualChecks(jsonStruct, LaserSourceOnefiveKatana05.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(...
                    'While trying to create a source part for laser "%s", could not find "%s" field. Aborting', ...
                    name, missingField);
            end
            
            port = jsonStruct.port;
            obj = LaserSourceOnefiveKatana05(name, port);
        end
    end
    %%
    % All available commands, obtained by sending the command 'h':
    % Laser Configuration: SER ANREGE Laser
    % 1. Laser emmision Green on/off: leg=0 (off), leg=1 (on), leg? (status)
    % 3. Laser Green Trigger Source Internal/External frequency: ltg=0 (Int), ltg=1 (Ext), ltg? (status)
    % 8. Green laser external trigger Level: ltlg=xx.xxx (float format), ltlg? (status)
    % 9. Store laser configuration Green: lestg
    % 10. Green Laser Set Temperature: 76.000 deg.C; Actual Temperature=75.990 deg.C
    % 11. Setting the Green Laser Temperature: let=xx.xx
    % 42. Repetition rate (frequency) setting green laser: ltg_freq=xxxxxx in Hz, ltg_freq?(status)
    % 43. Laser power value seting over RS232: lp=xx.xx (from 0-10.0), lp?(status)
    % 44. Laser power seting over RS232/Knob on front panel: lps=1(over RS232), lps=0(knob), lps?(status)
    
end

