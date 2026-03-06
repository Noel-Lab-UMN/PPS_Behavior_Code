clear all
clc
close all
%%
global PPS_global
generate_PPS_global();

subject_name = 'LSZ_practice_5_violet';
eval(sprintf('session_list = PPS_global.%s.session_list;', subject_name));

idx_end = find(strcmp(session_list,'20260303'));

session_list = session_list(1:idx_end);

for n = 1:numel(session_list)
    data_folder = fullfile('../../meta_data/',sprintf('%s_%s',subject_name,session_list{n}));

    json_file_list = dir(fullfile(data_folder,'*.json'));
    csv_file_list = dir(fullfile(data_folder,'*.csv'));
    for i = 1:numel(json_file_list)
        old_name = fullfile(data_folder, json_file_list(i).name);
        time_str = old_name(end-8:end-5);
        new_name = fullfile(data_folder, [json_file_list(i).name(1:end-9),session_list{n},'_', time_str,'.json']);
        movefile(old_name,new_name);
    end

    for i = 1:numel(csv_file_list)
        old_name = fullfile(data_folder, csv_file_list(i).name);
        time_str = old_name(end-7:end-4);
        new_name = fullfile(data_folder, [csv_file_list(i).name(1:end-8),session_list{n},'_', time_str,'.csv']);
        movefile(old_name,new_name);
    end

end


