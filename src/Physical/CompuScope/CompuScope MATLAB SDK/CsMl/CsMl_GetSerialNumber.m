function [retval, serial_number] = CsMl_GetSerialNumber(handle, board_number)
% [retval, serial_number] = CsMl_GetSerialNumber(handle)
%
% CsMl_GetSerialNumber returns a string which contains the serial number of
% the system associated with CompuScope system handle represented by
% handle. The handle is a value that uniquely identifies a CompuScope
% system. The handle must previously have been obtained by calling 
% CsMl_GetSystem.  board_number represents the board index within a system. 
% If no % board number is given, the default value is 1.  An invalid board 
% number will cause an error. If the call succeeds, retval will be positive.  
% If the call fails, retval will be a negative number, which represents an 
% error code.  A descriptive error string may be obtained by calling 
% CsMl_GetErrorString.  
% 
% If the call was successful, the serial number is returned in 
% serial_number. The format of serial_number is a string that contains
% 'baseboard serial number / addon serial number'.
% 

if nargin < 2
    board_number = 1;
end;
[retval, serial_number] = CsMl(44, handle, board_number);

    