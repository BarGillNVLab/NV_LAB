classdef IQSwitchKeysight < IQSwitch
    %Control I and Q using keysight E3631A power supplier and I /Q switches    
    
    properties (Constant)
        NEEDED_FIELDS = {'IChannel', 'QChannel'}
    end
    
    properties (Access = private)        
       powerSupply
       IChannel
       QChannel
       com = 1
    end
    methods
        % Constructor
        function obj = IQSwitchKeysight(IChannel, QChannel)            
            obj.IChannel = IChannel; % 'P6V';
            obj.QChannel = QChannel; % 'N25V';
            obj.powerSupply = E3631A_power_supplier.getInstance(obj.com);
        end
    end    
    methods
        function setIValue(obj, newValue)
           obj.powerSupply.setVoltage(obj.IChannel, newValue);
        end
        
        function setQValue(obj, newValue)
           obj.powerSupply.setVoltage(obj.QChannel, newValue);
        end
        
        
        function connect(obj)
            obj.powerSupply.connect;
        end
        
        function close(obj)
            obj.powerSupply.close; 
        end
    end
    
    methods (Static)
        function obj = create(jsonStruct)
            missingField = FactoryHelper.usualChecks(jsonStruct, IQSwitchKeysight.NEEDED_FIELDS);
            if ~isnan(missingField)
                EventStation.anonymousError(['While trying to create an I2/Q2 part,', ...
                    'could not find "%s" field. Aborting'], ...
                    missingField);
            end
            
            IChannel = jsonStruct.IChannel;
            QChannel = jsonStruct.QChannel;
            obj = IQSwitchNidaqControlled(IChannel, QChannel);
            
        end
    end
end