function LoadNIDAQmx
id = 'MATLAB:loadlibrary:TypeNotFound';     % This warning id should be suppressed here

if ~libisloaded('mynidaqmx')
    disp('Matlab: Loading nicaiu.dll')
%     libPath = 'C:\Windows\SysWOW64\nicaiu.dll'; % Not working, but 32bit
%     version supports 64
    libPath = 'C:\Windows\System32\nicaiu.dll';
    headerPath = 'C:\Program Files (x86)\National Instruments\Shared\ExternalCompilerSupport\C\include\nidaqmx.h';
    
    warning('off', id)
    funclist = loadlibrary(libPath, headerPath, 'alias', 'mynidaqmx');
    warning('on', id)
    %funclist = libfunctions('myni','-full')
    %libfunctionsview('myni')
end
disp('Matlab: NI DAQ dll loaded')

end