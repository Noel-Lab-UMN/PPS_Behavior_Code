clear all
clc
close all
%%% This script examines a bug in pps_passive_replay: long pause between
%%% ball fall into reward zone and reward delivery, but only happened to
%%% later trials
%%
dateStr = '20260331';
animalID = 'test';
csv_folder = fullfile('../../meta_data',sprintf('%s_%s', animalID, dateStr));
csv_file_list = dir(fullfile(csv_folder, '*.csv'));

csv_file_original = '../experiment/synthetic_PPS_trajectory_habituation.csv';
T = readtable(fullfile(csv_folder,csv_file_list(2).name));
T_original = readtable(csv_file_original);

%%
reward_state = T.reward_state;
t_global_s = T.t_global_s;
frameidx= T.frame_idx;
reward_idx = find(reward_state(1:end-1) == 0 & reward_state(2:end) == 1) + 1;


plot(t_global_s(reward_idx) - t_global_s(reward_idx-1),'-o'); hold on
yyaxis right
plot(frameidx(reward_idx))
