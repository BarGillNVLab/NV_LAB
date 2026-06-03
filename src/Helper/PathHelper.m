classdef PathHelper
    %PATHHELPER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods (Static)
        function nvLabFolderPath = getPathToNvLab()
            googleDriveFolder = sprintf('%s\\Google Drive\\', getenv('USERPROFILE'));
            
            % until all setups upgrade to google file stream: Yachel 29.09.21
            setupNumber = str2double(JsonInfoReader.getJson.setupNumber);
            if setupNumber==3 || setupNumber==4 || setupNumber==7 || setupNumber==1 || setupNumber==5 || setupNumber == 8 || setupNumber == 6|| setupNumber == 10
                googleDriveFolder = 'G:\My Drive\';
            end
            
            nvLabFolderName = 'NV Lab';
            nvLabFolderPath = PathHelper.recuresiveFindFolder(googleDriveFolder, nvLabFolderName);
            
            if ~ischar(nvLabFolderPath); EventStation.anonymousError('Can''t find NV Lab folder!!'); end
        end
        
        function modeString = SetupMode
            % Determines whether to use beta or prod(uction)
            % folder for saving and loading, according to json
            jsonStruct = JsonInfoReader.getJson();
            if jsonStruct.debugMode
                modeString = 'beta';
            else
                modeString = 'prod';
            end
        end
        
        function folderString = recuresiveFindFolder(startingPositionPath, folderNameToSearchString)
            % Recursively finds and returns the full path of a folder
            % within another (== starting position)
            startingPositionPath = PathHelper.appendBackslashIfNeeded(startingPositionPath);
            folderString = nan;  % if nothing will be found later on
            
            listing = dir(startingPositionPath);
            relevant = listing([listing.isdir]);  % looking only for folders
            relevant = relevant(~strcmp({relevant.name}, '.'));
            relevant = relevant(~strcmp({relevant.name}, '..'));
            % ^ The first 2 items are "." and "..", ignore them
            
            % Base case 1: no more folders deeper down
            if isempty(relevant); return; end  
            
            isHere = find(strcmp({relevant.name}, folderNameToSearchString));
            % "isHere" is now either a number (index) or empty, so we can use "if"
            if isHere  
                % Base case 2: found the folder
                folderString = PathHelper.joinToFullPath(startingPositionPath, relevant(isHere).name);
                folderString = PathHelper.appendBackslashIfNeeded(folderString);
                return
            else  % start the recursion
                for folderIndex = 1 : length(relevant)
                    newBaseFolder = [startingPositionPath relevant(folderIndex).name];
                    folderString = PathHelper.recuresiveFindFolder(newBaseFolder, folderNameToSearchString);
                    if ischar(folderString); return; end
                end
            end
            
        end
        
        function filePath = removeDotSuffix(filePathMaybeWithDotSuffix)
            % Accepts either char arrays, or cell arrays thereof
            filePath = filePathMaybeWithDotSuffix;
            hasDots = contains(filePath, '.');
            
            if ~hasDots
                % We're done.
                return
            end
            
            fileNameTruncate = @(x) x(1 : StringHelper.findLast(x, '.') - 1); % Takes anyhing before the final dot
            if iscell(filePath)
                filePath(hasDots) = cellfun(fileNameTruncate, filePath(hasDots), 'UniformOutput', false);
            else
                filePath = fileNameTruncate(filePath);
            end
            
        end
        
        function folderAndFile = splitFullPathToFolderAndFile(fullPath)
            % fullPath      - string. For exapmle: 'C:\reem\file.txt'
            % folderAndFile - cell with two strings: 'folder' and 'file'. 
            %                 For example: {'C:\reem\','file.txt'}
            %
            % See also MATLAB native function "fileparts"
            
            pathSplitted = strsplit(fullPath, '\\');
            fileName = pathSplitted(end);
            folderName = fullPath(1 : find(fullPath=='\', 1, 'last'));
            folderName = PathHelper.appendBackslashIfNeeded(folderName);  % clean it
            folderAndFile = [folderName, fileName];
        end
        
        function out = isFileExists(fileFullPath)
            out = exist(fileFullPath, 'file') == 2; 
            % 2 is for files. 7 for folders. 0 means not exists
        end
        
        function out = isFolderExists(folderFullPath)
            out = exist(folderFullPath, 'file') == 7; 
            % 2 is for files. 7 for folders. 0 means not exists
        end
        
        function string = appendBackslashIfNeeded(inputFolder)
            %%% Checks the input and appends a backslash if needed
            %
            % inputFolder - string
            %
            string = inputFolder;
            if ~endsWith(string, '\')
                string = [string '\'];
            end
        end
        
        function folderName = getFolderFromFullPathFile(inputFileString)
            %%% Retreives the folder from a file
            %
            % inputFileString - string
            %
            folderAndFile = PathHelper.splitFullPathToFolderAndFile(inputFileString);
            [folderName, ~] = folderAndFile{:};
        end
        
        function fileName = getFileNameFromFullPathFile(inputFileString)
            %%% Retreives the filename from a full path
            %
            % inputFileString - string
            %
            folderAndFile = PathHelper.splitFullPathToFolderAndFile(inputFileString);
            [~, fileName] = folderAndFile{:};
        end
        
        function varargout = getAllFilesInFolder(inputFolder, optionalSuffix)
            %%% Returns names of all relevant files in a folder
            %
            % FILENAMES = getAllFilesInFolder(INPUTFOLDER) returns all
            % files in folder, with their full path
            %
            % [FOLDER, FILENAMES] = getAllFilesInFolder(INPUTFOLDER)
            % returns FILENAMES without prepending the path
            %
            % __ = getAllFilesInFolder(INPUTFOLDER, SUFFIX) returns only
            % files that end with SUFFIX
            %
            %
            % INPUTFOLDER - cell of strings
            % SUFFIX - string (char array)
            % FILENAMES - struct array
            %
            
            narginchk(1,2)
            nargoutchk(1,2)
            
            inputFolder = PathHelper.appendBackslashIfNeeded(inputFolder);
            
            if ~exist('optionalSuffix', 'var')
                allFilesInFolder = dir(inputFolder);
                allFilesInFolder = allFilesInFolder(3 : end);   % the first two are "." and ".."
            else
                searchString = [inputFolder, '*', optionalSuffix];
                allFilesInFolder = dir(searchString);
            end
            
            if isempty(allFilesInFolder)
                fileNames = {};
                inputFolder = '';   % It's irrelevant
            else
                fileNames = extractfield(allFilesInFolder, 'name');
                isIni = endsWith(fileNames, '.ini');    % This file comes from Google Drive, but we don't want it
                fileNames = fileNames(~isIni);
            end
            
            switch nargout
                case 1
                    varargout{1} = strcat(inputFolder, fileNames);
                case 2
                    varargout{1} = inputFolder;
                    varargout{2} = fileNames;
            end
            
        end
        
        function fullpath = joinToFullPath(folder, fileName)
            % Converts a folder with a filename to one file fullpath
            % for example:
            % folder = 'c:\reem'       (ending backslash is optional)
            % filename = 'myfile.txt'
            % fullpath ----> 'c:\reem\myfile.txt'
            %
            % See also MATLAB's native function "fullfile" 
            
            folder = PathHelper.appendBackslashIfNeeded(folder);
            fullpath = sprintf('%s%s', folder, fileName);
        end
    end
end

