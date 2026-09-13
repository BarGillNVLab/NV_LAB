function mainExp()
%MAINEXP Starts the lab GUI, with the experiment column on the right.
%   Everything main() offers - stage control, scanning, image result,
%   lasers, SPCM and save/load - plus microwave controls, and a collapsible
%   column for choosing an experiment, editing its parameters, previewing
%   its pulse sequence and running it, building a sequence by hand, or
%   running anything in helperFunctions\.
%
%   main() is unchanged and still opens the image-only window.
%
%   See also MAIN, GUICONTROLLERMAINEXP

% Folders added to the repository since this machine last saved its MATLAB
% path would otherwise be invisible, and fail as "Unrecognized function".
PathHelper.addSourceFoldersToPath();

Setup.init;
GuiControllerMainExp().start;
end
