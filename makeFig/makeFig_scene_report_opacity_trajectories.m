clear all
clc
close all
figure_folder = '../../figures/scene_report';
%%

colors_list = get(groot, 'defaultAxesColorOrder');
%colors_list  = gem;
subjectCode  = 'LSZ_practice_5_violet'; 

exp_date_list = {'20260415'};



data_folder = fullfile('../../results/behav/pps_processed/',subjectCode);

behav_data_all = [];

for  n = 1:numel(exp_date_list)
    exp_date = exp_date_list{n};
    load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s', subjectCode, exp_date)));
    behav_data_all = [behav_data_all, behav_data];
end
plotOptions = struct();
idx_rewarded = [behav_data_all(:).rewarded] == 1;
idx_moved = [behav_data_all(:).is_moved] == 1;

init_x_all  = round([behav_data_all(:).initial_x_rel_cm]);
%
init_x_list =unique(init_x_all); 
ball_opacity_all    = [behav_data_all(:).ball_opacity];
ball_opacity_list   = unique(ball_opacity_all);
 nTrial              =  arrayfun(@(x)sum(ball_opacity_all == x), ball_opacity_list);
 ball_opacity_list(nTrial < 100) = [];



%%
%%% highest opacity
figure; set(gcf,'Units','inches','position',[0, 0,10,8]);
save_name = fullfile(figure_folder,'opacity_trajectory_1.svg');

legend_str_list =[]; h =[];
k = 1;
for i = numel(ball_opacity_list)
    for j  = 1:numel(init_x_list)
    is_plot             = ball_opacity_all == ball_opacity_list(i) & idx_rewarded & init_x_all == init_x_list(j);
    idx_plot            = find(is_plot);
    if isempty(idx_plot)
        continue
    end
    plotOptions.color = colors_list(i,:);
    
    h(k) = fig_pps.plot_ball_trajectories(behav_data_all, idx_plot, EXP_CONFIG, plotOptions);
    end
    legend_str_list{k} = sprintf('opacity = %.2f', ball_opacity_list(i));
    k = k+1;
end
legend(h, legend_str_list,'location','southeast');
title('Example session', 'Interpreter','none')
print(save_name, '-dsvg')
%%
%%%% highest and lowest
figure;set(gcf,'Units','inches','position',[0, 0,10,8]);
save_name = fullfile(figure_folder,'opacity_trajectory_2.svg');
legend_str_list =[]; h =[];
k = 1;
for i = [1,numel(ball_opacity_list)]
    for j  = 1:numel(init_x_list)
    is_plot             = ball_opacity_all == ball_opacity_list(i) & idx_rewarded & init_x_all == init_x_list(j);
    idx_plot            = find(is_plot);
    if isempty(idx_plot)
        continue
    end
    plotOptions.color = colors_list(i,:);
    
    h(k) = fig_pps.plot_ball_trajectories(behav_data_all, idx_plot, EXP_CONFIG, plotOptions);
    end
    legend_str_list{k} = sprintf('opacity = %.2f', ball_opacity_list(i));
    k = k+1;
end
legend(h, legend_str_list,'location','southeast');
title('Example session', 'Interpreter','none')
print(save_name, '-dsvg')

%%%% all opacity
figure;set(gcf,'Units','inches','position',[0, 0,10,8]); 
save_name = fullfile(figure_folder,'opacity_trajectory_3.svg');
for i = 1:numel(ball_opacity_list)
    for j  = 1:numel(init_x_list)
    is_plot             = ball_opacity_all == ball_opacity_list(i) & idx_rewarded & init_x_all == init_x_list(j);
    idx_plot            = find(is_plot);
    if isempty(idx_plot)
        continue
    end
    plotOptions.color = colors_list(i,:);
    
    h(i) = fig_pps.plot_ball_trajectories(behav_data_all, idx_plot, EXP_CONFIG, plotOptions);
    end
    legend_str_list{i} = sprintf('opacity = %.2f', ball_opacity_list(i));
end
legend(h, legend_str_list,'location','southeast');
title('Example session', 'Interpreter','none')
print(save_name, '-dsvg')