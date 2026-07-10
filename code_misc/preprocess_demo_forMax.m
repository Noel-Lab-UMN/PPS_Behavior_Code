clear all
clc
close all
%%
subjectCode = 'LSZ_practice_3_green';
exp_date = '20260305';
meta_folder = fullfile('../../meta_data/', [subjectCode,'_',exp_date]);
EXP_CONFIG = util_pps.read_json_config(meta_folder, subjectCode, exp_date);
behav_data = util_pps.read_csv_behav_data(meta_folder, EXP_CONFIG);
    
doPlot = 1;
%%%% Probability of getting reward
[percent_pps,percent_pps_timebin] = get_probs_pps(behav_data, doPlot, EXP_CONFIG);

