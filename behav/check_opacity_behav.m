clear all
clc
close all
global PPS_global
generate_PPS_global();
%%

subjectCode  = 'GD_5_grey'; 
%plotIndividual = true;
% switch subjectCode
%     case 'LSZ_practice_5_violet'
%         exp_date_list = {'20260415';'20260422';'20260423';'20260424';'20260428';'20260429';'20260430';'20260501'};
%     case 'GD_1_red'
%         exp_date_list = {'20260506'};
% end



data_folder = fullfile('../../results/behav/pps_processed/',subjectCode);

eval(sprintf('exp_date_list = PPS_global.%s.session_list.new_params;',subjectCode));

nPermute = 100;
colors_list = get(groot, 'defaultAxesColorOrder');
%
result_summary = struct();
for i = 1:numel(exp_date_list)
    exp_date = exp_date_list{i};
    load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s', subjectCode, exp_date)));
    % behav_data(1) = [];

    ball_opacity_all = [behav_data(:).ball_opacity];
    ball_opacity_list = unique(ball_opacity_all);
    n_condition = numel(ball_opacity_list);
    [p_moved, p_rewarded_moved, p_moved_sem,p_rewarded_moved_sem] = deal(zeros(1, n_condition));

    [zscore_p_reward, zscore_target_moved, zscore_target_reward] =  deal(zeros(1, n_condition));
    
    [target_distance_rewarded, target_distance_moved, target_distance_rewarded_mad,target_distance_moved_mad] ...
            = deal(zeros(1, n_condition));

    [corr_trajectory_moved, corr_trajectory_rewarded, corr_trajectory_moved_sem, corr_trajectory_rewarded_sem] ...
            = deal(zeros(1, n_condition));

    for n = 1:n_condition
        idx =  ball_opacity_all == ball_opacity_list(n);
        
        % p_reward per condition
        doTimebin = false; doPlot = false; 
        [percent_pps, ~] = util_pps.get_probs_pps(behav_data(idx), doTimebin, doPlot, EXP_CONFIG);
        p_moved(n)              = percent_pps.p_moved;
        p_rewarded_moved(n)     = percent_pps.p_reward_moved;
        p_moved_sem(n)          = percent_pps.p_moved_sem;
        p_rewarded_moved_sem(n) = percent_pps.p_reward_moved_sem;
        % 
       
        % target distance
        target_distance =  util_pps.compute_target_distance(behav_data(idx));
        target_distance_rewarded(n) = target_distance.distance_median_rewarded;
        target_distance_moved(n)    = target_distance.distance_median_moved;
        target_distance_rewarded_mad(n) = target_distance.distance_MAD_rewarded;
        target_distance_moved_mad(n)    = target_distance.distance_MAD_moved;


        % correlation of trajectory per condition
        correlation_stats               = util_pps.get_trajectory_correlation_stats(behav_data(idx));
        corr_trajectory_moved(n)        = correlation_stats.r_avg_moved;
        corr_trajectory_rewarded(n)     = correlation_stats.r_avg_rewarded;
        corr_trajectory_moved_sem(n)    = correlation_stats.r_sem_moved;
        corr_trajectory_rewarded_sem(n) = correlation_stats.r_sem_rewarded;

        
        % % z-score per condition
        real_values.p_reward_moved   = p_rewarded_moved(n);
        real_values.target_moved    = target_distance_moved(n);
        real_values.target_reward   = target_distance_rewarded(n);
        [zscore_p_reward(n), zscore_target_moved(n), zscore_target_reward(n)] =  util_pps.compute_z_score_condition(behav_data, real_values, idx, nPermute, EXP_CONFIG);

    end

    % if plotIndividual
    %     subplot(2,1,1)
    %     errorbar(ball_opacity_list, p_rewarded_moved, p_rewarded_moved_sem,'linewidth',2); hold on
    % 
    %     set(gca,'fontsize',18);
    %     xlabel('opacity'); ylabel('P(reward|moved)');
    %     box off
    % 
    %     subplot(2,1,2)
    %     plot(ball_opacity_list, z_score, '-o', 'linewidth',2); hold on
    %     set(gca,'fontsize',18);
    %     xlabel('opacity'); ylabel('Z-score');
    %     line([ball_opacity_list(1), ball_opacity_list(end)], [1.645, 1.645], 'linestyle','--','color','black')
    %     box off
    % end
    result_summary(i).exp_date                  = exp_date;
    result_summary(i).ball_opacity_list         = ball_opacity_list;
    result_summary(i).p_rewarded_moved          = p_rewarded_moved;
    result_summary(i).target_distance_rewarded  = target_distance_rewarded;
    result_summary(i).target_distance_moved     = target_distance_moved;
    result_summary(i).corr_trajectory_moved     = corr_trajectory_moved;
    result_summary(i).corr_trajectory_rewarded  = corr_trajectory_rewarded; 
    result_summary(i).zscore_p_reward           = zscore_p_reward; 
    result_summary(i).zscore_target_moved       = zscore_target_moved;
    result_summary(i).zscore_target_reward      = zscore_target_reward; 

end
%sgtitle(subjectCode,'fontweight','bold','fontsize',18,'interpreter','none')


ball_opacity_all = [result_summary(:).ball_opacity_list];

p_rewarded_moved_all            = [result_summary(:).p_rewarded_moved];
zscore_p_reward_all             = [result_summary(:).zscore_p_reward];
target_distance_moved_all       = [result_summary(:).target_distance_moved];
target_distance_rewarded_all    = [result_summary(:).target_distance_rewarded];
zscore_target_moved_all         = [result_summary(:).zscore_target_moved];
zscore_target_reward_all        = [result_summary(:).zscore_target_reward];

corr_trajectory_moved_all  = [result_summary(:).corr_trajectory_moved];

corr_trajectory_rewarded_all  = [result_summary(:).corr_trajectory_rewarded];


ball_opacity_list = unique(ball_opacity_all);

metrics = {
    'p_rewarded_moved',      'P(reward|moved)',        false;
    'zscore_p_reward',               'Z-score (p-reward)',                true;
    'target_distance_moved', 'Target distance (moved)',        false;
    'zscore_target_moved',               'Z-score (target distance moved)',                true;
    'target_distance_rewarded', 'Target distance (rewarded)',        false;
    'zscore_target_reward',               'Z-score (target distance rewarded)',                true;
    'corr_trajectory_moved', 'Trajectory correlation (moved)', false;
    'corr_trajectory_rewarded', 'Trajectory correlation (rewarded)', false;

};
%%
figure
for m = 1:size(metrics,1)
    eval(sprintf('y_all  = %s_all;',metrics{m,1}))
    y_label_str  = metrics{m,2};
    do_sig = metrics{m,3};

    y_avg = arrayfun(@(x) mean(y_all(ball_opacity_all == x), 'omitnan'), ball_opacity_list);
    y_std = arrayfun(@(x) std(y_all(ball_opacity_all == x), 'omitnan'),  ball_opacity_list);

    subplot(3,3,m); hold on

    % thin lines connecting points from the same session
    for i = 1:numel(result_summary)
        x_sess = result_summary(i).ball_opacity_list;
        eval(sprintf('y_sess = result_summary(i).%s;',metrics{m,1}));


        plot(x_sess, y_sess, '-', ...
            'Color', [0.7 0.7 0.7], ...
            'LineWidth', 0.5);
    end

    % group average ± std
    errorbar(ball_opacity_list, y_avg, y_std, ...
        'LineWidth', 2, ...
        'Color', 'black');

    if do_sig
        line([ball_opacity_list(1), ball_opacity_list(end)], ...
             [1.645, 1.645], ...
             'LineStyle', '--', ...
             'Color', 'black');
    end

    xlabel('Opacity');
    ylabel(y_label_str);
    box off
    set(gca, 'fontsize', 18)
end

sgtitle(subjectCode, 'fontweight', 'bold', 'fontsize', 18, 'interpreter', 'none')


%%
subjectCode  = 'GD_5_grey'; 

switch subjectCode
    case 'LSZ_practice_5_violet'
        exp_date_list = {'20260415'};
        %exp_date_list = {'20260415';'20260422';'20260423';'20260424';'20260428';'20260429';'20260430';'20260501'};
        init_x_list = [-12,12];
    case 'GD_1_red'
        exp_date_list = {'20260506'};
        init_x_list = [-15,15];
    case {'GD_4_mint';'GD_5_grey'}
        exp_date_list = {'20260528'};
        init_x_list = [-15,-10,10, 15];
end

%exp_date_list = {'20260415';'20260422';'20260423';'20260424';'20260428';'20260429';'20260430';'20260501'};
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
% init_x_list =unique(init_x_all); 
ball_opacity_all    = [behav_data_all(:).ball_opacity];
ball_opacity_list   = unique(ball_opacity_all);
nTrial              =  arrayfun(@(x)sum(ball_opacity_all == x), ball_opacity_list);
ball_opacity_list(nTrial < 100) = [];




figure; 
% subplot(1,2,1)
% for i = 1:numel(ball_opacity_list)
%     for j  = 1:numel(init_x_list)
%     is_plot             = ball_opacity_all == ball_opacity_list(i) & idx_moved & init_x_all == init_x_list(j);
%     idx_plot            = find(is_plot);
% 
%     plotOptions.color = colors_list(i,:);
%     h(i) = fig_pps.plot_ball_trajectories(behav_data_all, idx_plot, EXP_CONFIG, plotOptions);
%     end
%     legend_str_list{i} = sprintf('opacity = %.2f', ball_opacity_list(i));
% end
% legend(h, legend_str_list)
% 
% subplot(1,2,2)
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
legend(h, legend_str_list);
title(subjectCode, 'Interpreter','none')