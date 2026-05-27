clear all
clc
close all
global PPS_global
generate_PPS_global();


subjectCode  = 'LSZ_practice_5_violet'; 

switch subjectCode
    case 'LSZ_practice_5_violet'
        exp_date_list = {'20260413';'20260414';'20260422';'20260423';'20260424';'20260428';'20260429';'20260430';'20260501'};
    case 'GD_1_red'
        exp_date_list = {'20260505';'20260511';'20260512';'20260513'};
end

data_folder = fullfile('../../results/behav/pps_processed/',subjectCode);

eval(sprintf('session_list_all = PPS_global.%s.session_list.new_params;',subjectCode));

nPermute = 100;
colors_list = get(groot, 'defaultAxesColorOrder');
%
plotIndividual = false;
result_summary = struct();
for i = 1:numel(exp_date_list)
    exp_date = exp_date_list{i};
    load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s', subjectCode, exp_date)));
    % behav_data(1) = [];

    y_vel_all = [behav_data(:).ball_y_speed];
    y_vel_list = unique(y_vel_all);
    n_condition = numel(y_vel_list);
    [p_moved, p_rewarded_moved, p_moved_sem,p_rewarded_moved_sem, z_score] = deal(zeros(1,n_condition));
    for n = 1:n_condition
        idx =  y_vel_all == y_vel_list(n);


        p_moved(n)     = sum([behav_data(idx).is_moved]) / sum(idx);
        p_rewarded_moved(n) = sum([behav_data(idx).is_moved] & [behav_data(idx).rewarded]) / sum([behav_data(idx).is_moved]);

        p_moved_sem(n) = sqrt(p_moved(n) * (1 - p_moved(n)) / sum(idx));
        p_rewarded_moved_sem(n) = sqrt(p_rewarded_moved(n) * (1 - p_rewarded_moved(n)) / ...
            sum([behav_data(idx).is_moved]));

        % z-score per condition
        z_score(n) =  util_pps.compute_z_score_condition(behav_data, p_rewarded_moved(n), idx, nPermute, EXP_CONFIG);
      
    end
    if plotIndividual
    %errorbar([1:n_condition],p_moved,p_moved_sem,'linewidth',2); hold on;
    subplot(2,1,1)
    errorbar(y_vel_list, p_rewarded_moved, p_rewarded_moved_sem,'linewidth',2); hold on
    
    set(gca,'fontsize',18);
    xlabel('y-vel (cm/s)'); ylabel('P(reward|moved)');
    box off

    subplot(2,1,2)
    plot(y_vel_list, z_score, '-o', 'linewidth',2); hold on
    set(gca,'fontsize',18);
    xlabel('y-vel (cm/s)'); ylabel('Z-score');
    line([y_vel_list(1), y_vel_list(end)], [1.645, 1.645], 'linestyle','--','color','black')
    box off
    end
    result_summary(i).exp_date          = exp_date;
    result_summary(i).y_vel_list        = y_vel_list;
    result_summary(i).p_rewarded_moved  = p_rewarded_moved;
    result_summary(i).z_score           = z_score; 
end
sgtitle(subjectCode,'fontweight','bold','fontsize',18,'interpreter','none')


%%
y_vel_all = [result_summary(:).y_vel_list];
p_rewarded_moved_all = [result_summary(:).p_rewarded_moved];
z_score_all = [result_summary(:).z_score];
y_vel_list = unique(y_vel_all);

p_reward_avg    = arrayfun(@(x)mean(p_rewarded_moved_all(y_vel_all == x)), y_vel_list);
p_reward_std    = arrayfun(@(x)std(p_rewarded_moved_all(y_vel_all == x)), y_vel_list);

zscore_avg      = arrayfun(@(x)mean(z_score_all(y_vel_all == x)), y_vel_list);
zscore_std      = arrayfun(@(x)std(z_score_all(y_vel_all == x)), y_vel_list);

figure
subplot(2,1,1); hold on
errorbar(y_vel_list, p_reward_avg, p_reward_std,'LineWidth',2);
plot(y_vel_all, p_rewarded_moved_all,'.','MarkerSize',10,'color',[0.5,0.5,0.5]);
xlabel('y-velocity (cm/s)'); ylabel('P(reward|moved)');
box off
set(gca,'fontsize',18)


subplot(2,1,2); hold on
errorbar(y_vel_list, zscore_avg, zscore_std,'LineWidth',2,'color','black');
plot(y_vel_all, z_score_all,'.','MarkerSize',10,'color',[0.5,0.5,0.5])
line([y_vel_list(1), y_vel_list(end)], [1.645, 1.645], 'linestyle','--','color','black');
xlabel('y-velocity (cm/s)'); ylabel('Z-score');
box off
set(gca,'fontsize',18)

sgtitle(subjectCode,'fontweight','bold','fontsize',18,'interpreter','none')
%%
subjectCode  = 'LSZ_practice_5_violet'; 

switch subjectCode
    case 'LSZ_practice_5_violet'
        exp_date_list = {'20260414'};
        init_x_list = [-12,12];
    case 'GD_1_red'
        exp_date_list = {'20260505'};
        init_x_list = [-15,15];
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
y_vel_all    = [behav_data_all(:).ball_y_speed];
y_vel_list   = unique(y_vel_all);
nTrial              =  arrayfun(@(x)sum(y_vel_all == x), y_vel_list);
y_vel_list(nTrial < 100) = [];




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
for i = 1:numel(y_vel_list)
    for j  = 1:numel(init_x_list)
    is_plot             = y_vel_all == y_vel_list(i) & idx_rewarded & init_x_all == init_x_list(j);
    idx_plot            = find(is_plot);
    if isempty(idx_plot)
        continue
    end
    plotOptions.color = colors_list(i,:);
    
    h(i) = fig_pps.plot_ball_trajectories(behav_data_all, idx_plot, EXP_CONFIG, plotOptions);
    end
    legend_str_list{i} = sprintf('opacity = %.2f', y_vel_list(i));
end
legend(h, legend_str_list);
title(subjectCode, 'Interpreter','none')