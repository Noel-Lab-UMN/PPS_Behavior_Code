clear all
clc
close all
%%%% This script processes the raw behavior data of goal-directed PPS,
%%%% makes figures about some behavioral features, saves preprocessed data
%%%% and figures for individual sessions
global PPS_global
generate_PPS_global()
%% experiment date and subject code
subjectCode = 'GD_4_mint';
do_replace    = false; 
doPlot      = false;

eval(sprintf('session_list = PPS_global.%s.session_list.initial;',subjectCode));
%session_list = {'20260422';'20260423';'20260424'};


save_folder = fullfile('../../results/behav/pps_processed',subjectCode);
if ~isfolder(save_folder)
    mkdir(save_folder)
end

 for n = 1:numel(session_list)

    exp_date    = session_list{n};
    
    results_save_name       = fullfile(save_folder,['behav_stats_PPS_',subjectCode,'_',exp_date,'.mat']);
    data_save_name          = fullfile(save_folder,['behav_data_PPS_',subjectCode,'_',exp_date,'.mat']);
    %fig_stats_save_name = fullfile(save_folder,['fig_stats_PPS_',subjectCode,'_',exp_date,'.png']);
    
    if isfile(results_save_name) & isfile(data_save_name) & ~do_replace 
        continue
    end
    %% read the json file and the csv file
    meta_folder = fullfile(sprintf('../../meta_data_local/%s',subjectCode), [subjectCode,'_',exp_date]);
    EXP_CONFIG = util_pps.read_json_config(meta_folder, subjectCode, exp_date);
    behav_data = util_pps.read_csv_behav_data(meta_folder, EXP_CONFIG);
    
    if strcmp(subjectCode, 'LSZ_practice_5_violet') & ismember(exp_date, {'20260422';'20260423';'20260424'})
        %%%% In these sessions, I accidentally set gain to 1 for some
        %%%% trials. Remove these trials because I don't think they are
        %%%% useful for any analysis
        idx_high_gain = [behav_data(:).wheel_gain] == 1;
        behav_data(idx_high_gain) = [];
    end

    save(data_save_name,'behav_data','EXP_CONFIG');
    %% Distribution of initial x and distribution of end x. Also trajectories
    if doPlot
        fig_pps.plot_PPS_trajectories(behav_data, EXP_CONFIG)
        fig_pps.plot_delta_x_y_position(behav_data, EXP_CONFIG)
    end
    




    %%%% Probability of getting reward
    
    [percent_pps,percent_pps_timebin] = util_pps.get_probs_pps(behav_data, doPlot, EXP_CONFIG);

  
    %%%% Percent of goal-directed, anti-goal-directed, and static
    percent_move = util_pps.get_percent_movement(behav_data, doPlot, EXP_CONFIG);

    %%%% correlation between initial positions and delta_x 
    corr_initial_delta = util_pps.get_corr_initial_position_delta_x(behav_data, doPlot, EXP_CONFIG);
    
    %%%% get "chance level"
    nPermute = 100;
    permute_chance_level = util_pps.get_chance_level_permute(behav_data, EXP_CONFIG, nPermute);

    behav_results.percent_pps           = percent_pps;
    behav_results.percent_pps_timebin   = percent_pps_timebin;
    behav_results.percent_move          = percent_move;
    behav_results.corr_initial_delta    = corr_initial_delta;
    behav_results.permute_chance_level  = permute_chance_level;
    
    save(results_save_name,'behav_results','EXP_CONFIG');

   
    


  
 end
%% helper functions 



% function plot_data_group(x, y)
%     %%% plot y against x, divide data into a few groups
%     edges = linspace(0, 90, 10);
%     [~,~,idx_bin] = histcounts(x,edges);
%     idx_bin_list = unique(idx_bin);
% 
%     CI_level = 68;
% 
%     y_median = arrayfun(@(n)median(y(idx_bin == n)), idx_bin_list);
%     y_CI_low = arrayfun(@(n)prctile(y(idx_bin == n), (100 - CI_level) /2 ),  idx_bin_list);
%     y_CI_high = arrayfun(@(n)prctile(y(idx_bin == n), 100 - (100 - CI_level) /2 ),  idx_bin_list);
% 
%     errorbar((edges(2:end) + edges(1:end-1)) / 2, y_median, y_median - y_CI_low, y_CI_high - y_median)
% end

