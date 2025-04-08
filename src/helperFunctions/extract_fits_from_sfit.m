function map_fits = extract_fits_from_sfit(sfits_path, save_path, output_name)
% This function extracts cfits from an sfit file into a map container s.t.
% the keys are the Fit names while the values are the cfits
% inputs should be strings!! "" 
% char '' IS NOT SUPPORTED!!
%
%   map_fits = extract_fits_from_sfit(sfits_path) creates the map from 
%   sfits_path which has to be the full path!
%
%   map_fits = extract_fits_from_sfit(sfits_path, save_path) creates the 
%   map from sfits_path, and saves the map to .mat file in save_path, with 
%   the file name being <sfit file name>.mat where <sfit file name>.sfit is
%   the file name
%
%   map_fits = extract_fits_from_sfit(sfits_path, save_path, output_name) 
%   creates the map from sfits_path, and saves the map to .mat file in 
%   save_path, such that the mat file name will be output_name
%
    v = load(sfits_path, '-mat');
    fits_from_sfit = v.savedSession.AllFitdevsAndConfigs;

    map_fits = containers.Map('KeyType','char','ValueType','any');
    for fit_idx = 1:numel(fits_from_sfit)
        fit_name = fits_from_sfit{fit_idx}.Fitdev.FitName;
        fit_obj = fits_from_sfit{fit_idx}.Fitdev.Fit;
        map_fits(fit_name) = fit_obj;
    end

    if nargin == 2
        %%% output file name of <map>.mat
        if nargin == 3
            full_path_output_file = [save_path, output_name, ".mat"];
        else
            regex_split_sfits_path = regexp(sfits_path, "\", 'split');
%             name_sfits_file = regex_split_sfits_path(end);
            name_output_mat = string(regex_split_sfits_path{end}(1:end-5));
            full_path_output_file = [save_path, name_output_mat, ".mat"];
        end
        %%% check that file doesn't exists
        if isfile(full_path_output_file)
            fprintf("the file:\n%s\n",full_path_output_file)
            disp("already exists, use a different output_name")
        else
             save(full_path_output_file, 'map_fits');
        end
    end
end