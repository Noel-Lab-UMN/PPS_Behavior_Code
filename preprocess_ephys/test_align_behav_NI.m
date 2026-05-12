clear all
clc
close all
%%
subjectCode = 'LSZ_practice_5_Violet';
dateStr = '20260430';
dateStr_e = sprintf('%s_%s_%s',dateStr(5:6),dateStr(7:8), dateStr(1:4));

meta_folder = sprintf('%s_%s_behav',subjectCode, dateStr);

% behav_csv_list = dir(fullfile(behav_folder, sprintf('sync_log_pps_behav_%s_%s_*',subjectCode, dateStr)));
% passive_csv_list = dir(fullfile(behav_folder, sprintf('sync_log_pps_passive_%s_%s_*',subjectCode, dateStr)));
EXP_CONFIG = util_pps.read_json_config(meta_folder, subjectCode, dateStr);

[behav_data, prbs_behav_rising] = util_pps.read_csv_behav_data(meta_folder, EXP_CONFIG);

[passive_data, prbs_passive_rising] = util_pps.read_csv_passive_data(meta_folder, subjectCode, dateStr);
%%
file_meta       = sprintf('%s_%s_g0_t0.nidq.meta', subjectCode, dateStr_e);
file_bin        = sprintf('%s_%s_g0_t0.nidq.bin', subjectCode, dateStr_e);


NI_timing = util_pps.read_binary_sync(file_meta, file_bin);
%% get the slope and intercept
nTrial_behav    = numel(behav_data);
nTrial_passive  = numel(passive_data);
nTrial_NI       = numel(NI_timing.trial_onset);

nPrbs_behav     = numel(prbs_behav_rising);
nPrbs_passive   = numel(prbs_passive_rising);
nPrbs_NI        = numel(NI_timing.prbs_rising); 

%%
if nTrial_behav + nTrial_passive == nTrial_NI

end

if nPrbs_behav + nPrbs_passive == nPrbs_NI
end


x = [behav_data(:).t_global_s_onset];
y = NI_timing.trial_onset(1:nTrial_behav);
p = polyfit(x, y, 1);


