clear all
clc
close all

subjectCode  = 'GD_1_red';
data_folder = fullfile('../../results/behav/pps_processed/',subjectCode);
global PPS_global
generate_PPS_global();
eval(sprintf('session_list_all = PPS_global.%s.session_list.new_params;',subjectCode));

nPermute = 100;

%exp_date_list = {'20260415';'20260422';'20260423';'20260424';'20260428';'20260429';'20260430';'20260501'};
exp_date_list = {'20260506';'20260511';'20260512'};
for i = 1:numel(exp_date_list)
    exp_date = exp_date_list{i};
    load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s', subjectCode, exp_date)));
    % behav_data(1) = [];

    ball_opacity_all = [behav_data(:).ball_opacity];
    ball_opacity_list = unique(ball_opacity_all);
    n_condition = numel(ball_opacity_list);
    [p_moved, p_rewarded_moved, p_moved_sem,p_rewarded_moved_sem, z_score] = deal(zeros(n_condition, 1));
    for n = 1:n_condition
        idx =  ball_opacity_all == ball_opacity_list(n);


        p_moved(n)     = sum([behav_data(idx).is_moved]) / sum(idx);
        p_rewarded_moved(n) = sum([behav_data(idx).is_moved] & [behav_data(idx).rewarded]) / sum([behav_data(idx).is_moved]);

        p_moved_sem(n) = sqrt(p_moved(n) * (1 - p_moved(n)) / sum(idx));
        p_rewarded_moved_sem(n) = sqrt(p_rewarded_moved(n) * (1 - p_rewarded_moved(n)) / ...
            sum([behav_data(idx).is_moved]));

        % z-score per condition
        z_score(n) =  util_pps.compute_z_score_condition(behav_data, p_rewarded_moved(n), idx, nPermute, EXP_CONFIG);
        % p_reward_moved_permute = zeros(nPermute, 1);
        % for t = 1:nPermute
        %     idx_run = find(idx);
        %     do_permute_sign = 0;
        %     do_moved        = 1;
        %     [~, simu_stats]       = util_pps.simulate_trajectories_permute(behav_data,idx_run, EXP_CONFIG, do_permute_sign, do_moved);
        %     p_reward_moved_permute(t)    = simu_stats.p_rewarded;
        % end
        % z_score(n) = (p_rewarded_moved(n) - mean(p_reward_moved_permute)) / std(p_reward_moved_permute);
    end

    %errorbar([1:n_condition],p_moved,p_moved_sem,'linewidth',2); hold on;
    subplot(2,1,1)
    %errorbar(ball_opacity_list, p_rewarded_moved, p_rewarded_moved_sem,'linewidth',2); hold on
    plot(ball_opacity_list, p_rewarded_moved, '-o', 'linewidth',2); hold on
    %set(gca,'xtick',[1:n_condition],'xticklabels',ball_opacity_list)
    %legend('p-moved','p-rewarded-moved');
    %xlim([0.5, n_condition + 0.5]);
    set(gca,'fontsize',18);
    xlabel('opacity'); ylabel('P(reward|moved)');

    subplot(2,1,2)
    plot(ball_opacity_list, z_score, '-o', 'linewidth',2); hold on
    set(gca,'fontsize',18);
    xlabel('opacity'); ylabel('Z-score');
    line([ball_opacity_list(1), ball_opacity_list(end)], [1.645, 1.645], 'linestyle','--','color','black')

end
%%

exp_date_list = {'20260506'};
%exp_date_list = {'20260415';'20260422';'20260423';'20260424';'20260428';'20260429';'20260430';'20260501'};

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
%init_x_list = [-12,12];
init_x_list =unique(init_x_all); 
ball_opacity_all    = [behav_data_all(:).ball_opacity];
ball_opacity_list   = unique(ball_opacity_all);
nTrial              =  arrayfun(@(x)sum(ball_opacity_all == x), ball_opacity_list);
ball_opacity_list(nTrial < 100) = [];



colors_list = get(groot, 'defaultAxesColorOrder');
figure; 
subplot(1,2,1)
for i = 1:numel(ball_opacity_list)
    for j  = 1:numel(init_x_list)
    is_plot             = ball_opacity_all == ball_opacity_list(i) & idx_moved & init_x_all == init_x_list(j);
    idx_plot            = find(is_plot);
   
    plotOptions.color = colors_list(i,:);
    h(i) = fig_pps.plot_ball_trajectories(behav_data_all, idx_plot, EXP_CONFIG, plotOptions);
    end
    legend_str_list{i} = sprintf('opacity = %.2f', ball_opacity_list(i));
end
legend(h, legend_str_list)

subplot(1,2,2)
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