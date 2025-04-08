classdef ViewHelmholtzError < ViewVBox

    methods
        function obj = ViewHelmholtzError(parent, controller)
            obj@ViewVBox(parent, controller);
            
            obj.height = 60;   % minimum
            obj.width = 600;    % minimum
        end
    end 


end