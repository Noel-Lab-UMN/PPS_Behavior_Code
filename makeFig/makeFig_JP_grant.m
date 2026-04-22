clear all
clc
close all
%%
subjectCode     = 'LSZ_practice_5_violet';
early_example   = '20260309';
late_example    = '20260403';

late_example_lists = {'20260330';'20260331';...
    '20260401';'20260402';'20260403';'20260406';'20260407';'20260408';'20260409'};

data_folder = sprintf('../../results/behav/pps_processed/%s',subjectCode);
%%

figure;

subplot(1,3,1); hold on
date_str = early_example;
% data_folder = sprintf('../../results/behav/pps_processed/%s',subjectCode);
load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s',subjectCode,date_str)));

idx_moved       = [behav_data(:).is_moved];
idx_rewarded    = [behav_data(:).rewarded];
idx_reach_bottom = [behav_data(:).reached_bottom];
init_x          = [behav_data(:).initial_x_rel_cm];
init_x_list     = unique(init_x);
nTrial_init_x   = arrayfun(@(n) sum(init_x == init_x_list(n)), [1:numel(init_x_list)]); 
init_x_list(nTrial_init_x == 1) = [];

plotOptions.titleStr = '';
plotOptions.color = 'black';
plotOptions.style = 'avg';
plotOptions.doExample = 'true';
idx_base_moved      = idx_moved & idx_reach_bottom;
idx_base_rewarded   = idx_rewarded;  
for n = 1:numel(init_x_list)
    idx_plot = find(init_x == init_x_list(n) & idx_base_moved);
    h(1) = fig_pps.plot_ball_trajectories(behav_data, idx_plot, EXP_CONFIG, plotOptions);
end

plotOptions.color = 'red';
plotOptions.style = 'avg';
plotOptions.doExample = 'true';
for n = 1:numel(init_x_list)
    idx_plot = find(init_x == init_x_list(n) & idx_base_rewarded);
    h(2) = fig_pps.plot_ball_trajectories(behav_data, idx_plot, EXP_CONFIG, plotOptions);
end
ylim([-5,60])
legend(h, 'Moved','Rewarded')
title('Early-training example')
set(gca,'fontsize',18)

subplot(1,3,2); hold on
date_str = late_example;

load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s',subjectCode,date_str)));
idx_moved       = [behav_data(:).is_moved];
idx_rewarded    = [behav_data(:).rewarded];
idx_reach_bottom = [behav_data(:).reached_bottom];
init_x          = [behav_data(:).initial_x_rel_cm];
init_x_list     = unique(init_x);
nTrial_init_x   = arrayfun(@(n) sum(init_x == init_x_list(n)), [1:numel(init_x_list)]); 
init_x_list(nTrial_init_x == 1) = [];

plotOptions.titleStr = '';
plotOptions.color = 'black';
plotOptions.style = 'avg';

idx_base_moved      = idx_moved & idx_reach_bottom;
idx_base_rewarded   = idx_rewarded;  
for n = 1:numel(init_x_list)
    idx_plot = find(init_x == init_x_list(n) & idx_base_moved);
    h(1) = fig_pps.plot_ball_trajectories(behav_data, idx_plot, EXP_CONFIG, plotOptions);
end

plotOptions.color = 'red';
plotOptions.style = 'avg';
for n = 1:numel(init_x_list)
    idx_plot = find(init_x == init_x_list(n) & idx_base_rewarded);
    h(2) = fig_pps.plot_ball_trajectories(behav_data, idx_plot, EXP_CONFIG, plotOptions);
end
ylim([-5,60])
legend(h, 'Moved','Rewarded')
title('Late-training example')
set(gca,'fontsize',18)


subplot(1,3,3); hold on
N_good = numel(late_example_lists);
[p_reward_permute_moved, p_reward_permute_moved_norm] = deal(zeros(N_good,1));
for n = 1:N_good
    date_str = late_example_lists{n};
    load(fullfile(data_folder, sprintf('behav_stats_PPS_%s_%s',subjectCode,date_str)));

    p_reward_permute_moved(n) = behav_results.percent_pps.p_reward_moved;
    chance_level_avg(n) = 100 * mean(behav_results.permute_chance_level.p_reward_permute_moved);
    p_reward_permute_moved_norm(n) = p_reward_permute_moved(n) - chance_level_avg(n);

    plot(1, p_reward_permute_moved_norm(n),'.','color',[0.5,0.5,0.5],'MarkerSize',10)
end
clear h
h(1) = errorbar(mean(p_reward_permute_moved_norm), std(p_reward_permute_moved_norm) / sqrt(N_good),'.','markersize',20, 'linewidth',2,...
    'Color','blue');
title('Late-training sessions')

line([0,2],[0,0],'color','black','linestyle','--')
text(2,0,'Chance level','fontsize',18)
legend(h, sprintf('N = %d',N_good))

ylim([-5,40])
ylabel('Percentage of rewarded trials (corrected)')
set(gca,'xtick',[]);
set(gca,'fontsize',18)