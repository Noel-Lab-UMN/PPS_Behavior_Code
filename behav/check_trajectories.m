clear all
clc
close all
%%
subjectCode = 'GD_3_pink';
save_folder = fullfile('../../results/behav/pps_processed',subjectCode);
fig_save_folder = fullfile('../../figures/behav/subject_timecourses/', subjectCode);
if ~isfolder(fig_save_folder)
    mkdir(fig_save_folder);
end

global PPS_global
generate_PPS_global();

eval(sprintf('session_list = PPS_global.%s.session_list.initial;',subjectCode));
session_list = session_list(end - 10:end);

nSession = numel(session_list);
nRow = floor(sqrt(nSession));
nCol = ceil(nSession/nRow);
figure
for k  = 1:nSession
    subplot(nRow,nCol,k)
    date_str = session_list{k};
    data_folder = sprintf('../../results/behav/pps_processed/%s',subjectCode);
    
    load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s',subjectCode,date_str)));
    
    %behav_data(1) = [];
    %%%%
    idx_moved       = [behav_data(:).is_moved];
    idx_rewarded    = [behav_data(:).rewarded];
    idx_reach_bottom = [behav_data(:).reached_bottom];
    init_x          = [behav_data(:).initial_x_rel_cm];
    init_x_list     = unique(init_x);
    nTrial_init_x   = arrayfun(@(n) sum(init_x == init_x_list(n)), [1:numel(init_x_list)]); 
    init_x_list(nTrial_init_x == 1) = [];

    %%%%
    
    
    plotOptions.titleStr = '';
    plotOptions.color = 'black';
    plotOptions.style = 'avg';
    plotOptions.doExample = false; 
    idx_base_moved      = idx_moved & idx_reach_bottom;
    idx_base_rewarded   = idx_rewarded;  
    for n = 1:numel(init_x_list)
        idx_plot = find(init_x == init_x_list(n) & idx_base_moved);
        fig_pps.plot_ball_trajectories(behav_data, idx_plot, EXP_CONFIG, plotOptions);
    end
    
    plotOptions.color = 'red';
    plotOptions.style = 'avg';
    for n = 1:numel(init_x_list)
        idx_plot = find(init_x == init_x_list(n) & idx_base_rewarded);
        fig_pps.plot_ball_trajectories(behav_data, idx_plot, EXP_CONFIG, plotOptions);
    end
    title(session_list{k});
end
sgtitle(subjectCode, 'fontsize', 20,'fontweight','bold','interpreter','none');