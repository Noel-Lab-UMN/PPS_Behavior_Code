clear all
clc
close all
%%
dateStr = '0423';
load_session = 'passive'; % passive or task
switch dateStr
    case '0420'
        data_folder = '../../test_0420_binary_files';
        task_file_name = 'LSZ_practice_5_violet_test_04_20_2026_g0_t0';
        passive_file_name = 'LSZ_practice_5_violet_test_replay_04_20_2026_g0_t0';
    case '0421'
        data_folder = '../../test_0421_binary_files';
        task_file_name = 'LSZ_5_violet_pps_behav_04_21_2026_g1_t0';
        passive_file_name = 'LSZ_5_violet_pps_passive_04_21_2026_g0_t0';
    case '0422'
        data_folder = '../../test_0422_binary_files';
        task_file_name = 'LSZ_practice_5_violet_pps_behav_04_22_2026_g1_t0';
        passive_file_name = 'LSZ_practice_5_violet_pps_passive_04_22_2026_g0_t0';
    case '0423'
        data_folder = '../../test_0423_binary_files';
        passive_file_name = 'test_0423_passive_g0_t0';

end




switch load_session
    case 'task'
        file_meta       = fullfile(data_folder,[task_file_name,'.nidq.meta']);
        file_bin        = fullfile(data_folder,[task_file_name,'.nidq.bin']);
    case 'passive'
        file_meta    = fullfile(data_folder,[passive_file_name,'.nidq.meta']);
        file_bin     = fullfile(data_folder,[passive_file_name,'.nidq.bin']);
end



meta = ReadMeta(file_meta);  % You need to download this helper
n_channels = str2double(meta.nSavedChans);     % e.g., 385
fs = str2double(meta.niSampRate);              % Sample rate (e.g., approx 30000 Hz)

fid = fopen(file_bin, 'r');
data_type = 'int16';
raw = fread(fid, [n_channels, Inf], data_type);  % Read all data
fclose(fid);

digital_data                    = raw(end, :);                  % Last channel = digital lines
clear raw
digital_ch1                     = bitget(digital_data, 1);      % seems very continous...up down up down... from the very beginning
digital_ch2                     = bitget(digital_data, 2);      % looks like PRBS but starts HIGH
digital_ch3                     = bitget(digital_data, 3);    
digital_ch4                     = bitget(digital_data, 4); 
clear digital data
%%
%%%% ch2: prbs
%%%% ch3: trial onset
%%%% ch4: exp start onset?
[NI.ch1_sec, NI.ch1]            = find_trigger_times(digital_ch1, fs);
[NI.ch2_sec, NI.ch2]            = find_trigger_times(digital_ch2, fs);
[NI.ch3_sec, NI.ch3]            = find_trigger_times(digital_ch3, fs);
[NI.ch4_sec, NI.ch4]            = find_trigger_times(digital_ch4, fs);

NI.prbs                = NI.ch2_sec;
NI.trial_onset         = NI.ch3_sec;
NI.exp_onset           = NI.ch4_sec;
%% load csv file and try to synchronize
switch load_session
    case 'task'
        file_list = dir(fullfile(data_folder,'sync_log_pps_behav*.csv'));

    case 'passive'
        file_list = dir(fullfile(data_folder,'sync_log_pps_passive*.csv'));
end
[CSV.prbs, CSV.trial_onset] = deal(cell(numel(file_list),1));
for i = 1:numel(file_list)
    raw_data = readtable(fullfile(data_folder, file_list(i).name));
   
    %%% read prbs time
    rising_edges = find(diff(raw_data.prbs_val) == 1) + 1;
    CSV.prbs{i} = raw_data.t_global_s(rising_edges);

    %%% read trial onset time
    slot = raw_data.("slot1");        % string array or cellstr
    slot = string(slot);           % ensure it's string type
    slot = erase(slot, "'");
    valid = strlength(strtrim(slot)) > 0;

    slot1_onset_idx = find(valid & ~[false; valid(1:end-1)]);

    CSV.trial_onset{i} = raw_data.t_global_s(slot1_onset_idx);



end
%%
if ~isempty(NI.exp_onset)

end
% 
% CSV.prbs                = cat(1, CSV.prbs{:});
% CSV.trial_onset         = cat(1, CSV.trial_onset{:}); 

%%
figure;

histogram(diff(NI.trial_onset) - diff(CSV.trial_onset{1}));
p_trial_on = polyfit(NI.trial_onset, CSV.trial_onset{1}, 1)
% subplot(3,1,2)
% histogram(diff(NI.prbs)- diff(CSV.prbs_aligned));
