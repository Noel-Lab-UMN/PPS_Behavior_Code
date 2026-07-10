clear all
clc
close all
global PPS_global
generate_PPS_global();
%% load and organize results

%subjectCode  = 'GD_1_red'; 
subjectCode = 'LSZ_practice_5_violet';
%plotIndividual = false;

parameter_option = 'randomwalk';

switch parameter_option
    case 'opacity'
        x_label_str = 'Opacity';
        switch subjectCode
            case 'LSZ_practice_5_violet'
                exp_date_list = {'20260415';'20260422';'20260423';...
                    '20260424';'20260428';'20260429';'20260430';'20260501'};
            case 'GD_1_red'
                exp_date_list = {'20260506'};
        end
    case 'y_vel'
        x_label_str = 'y-vel';
        switch subjectCode
            case 'LSZ_practice_5_violet'
                exp_date_list = {'20260413';'20260414';'20260422';'20260423';...
                    '20260424';'20260428';'20260429';'20260430';'20260501'};
            case 'GD_1_red'
                exp_date_list = {'20260505'};

        end
    case 'wheel_gain'
        x_label_str = 'wheel gain';
        switch subjectCode
            case 'LSZ_practice_5_violet'
                exp_date_list = {'20260417';'20260420';'20260422';'20260423';...
                    '20260424';'20260428';'20260429';'20260430';'20260501'};
            case 'GD_1_red'
                exp_date_list = {'20260507'};

        end
    case 'wheel_jitter'
        x_label_str = 'wheel jitter';
        switch subjectCode
            case 'LSZ_practice_5_violet'
                exp_date_list = {'20260417';'20260420';'20260422';'20260423';...
                    '20260424';'20260428';'20260429';'20260430';'20260501'};
            case 'GD_1_red'
                exp_date_list = {'20260507'};

        end    
    case 'randomwalk'
        x_label_str = 'randomwalk';
        switch subjectCode
            case 'LSZ_practice_5_violet'
                exp_date_list = {'20260422';'20260423';...
                    '20260424';'20260428';'20260429';'20260430';'20260501'};
            case 'GD_1_red'
                error('no random walk condition for this animal');
        end

end



data_folder = fullfile('../../results/behav/pps_processed/',subjectCode);

eval(sprintf('session_list_all = PPS_global.%s.session_list.new_params;',subjectCode));

nPermute = 100;
colors_list = get(groot, 'defaultAxesColorOrder');
%
result_summary = struct();
for i = 1:numel(exp_date_list)
    exp_date = exp_date_list{i};
    load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s', subjectCode, exp_date)));
    % behav_data(1) = [];
    switch parameter_option
        case 'opacity'
            condition_all_session = [behav_data(:).ball_opacity];
            trained_condition = 1;
        case 'y_vel'
            condition_all_session = [behav_data(:).ball_y_speed];
            trained_condition = 40;
        case 'wheel_gain'
            condition_all_session = [behav_data(:).wheel_gain];
            trained_condition = 0.1;
        case 'wheel_jitter'
             wheel_jitter = [behav_data(:).wheel_jitter];
             has_wheel_jitter = abs(wheel_jitter) > 0;

             condition_all_session = has_wheel_jitter;
             trained_condition = 0;
        case 'randomwalk'
            random_std_all  = [behav_data(:).ball_random_std];
            has_random_walk_all = abs(random_std_all) > 0;
            % 0 or 1 indicate whether there is any random walk
            % too complicated if we look at all combinations of random walk
            % bias and random walk std
            condition_all_session = has_random_walk_all; 
            trained_condition = 0;
    end
    condition_list_session = unique(condition_all_session);
    if strcmp(parameter_option ,'wheel_gain')
        condition_list_session(~ismember(condition_list_session, [0.05, 0.1, 0.2])) = [];
    end
    is_trained = zeros(size(condition_list_session));
    is_trained(condition_list_session == trained_condition) = 1;
  % if strcmp(parameter_option ,'wheel_jitter')
  %     condition_list_session(~ismember(condition_list_session,  [0, 0.1, 0.15, 0.25])) = [];
  % 
  %   end
    
    n_condition = numel(condition_list_session);

    [p_moved, p_rewarded_moved, p_moved_sem,p_rewarded_moved_sem] = deal(zeros(1, n_condition));

    [zscore_p_reward, zscore_target_moved, zscore_target_reward] =  deal(zeros(1, n_condition));
    
    [target_distance_rewarded, target_distance_moved, target_distance_rewarded_mad,target_distance_moved_mad] ...
            = deal(zeros(1, n_condition));

    [corr_trajectory_moved, corr_trajectory_rewarded, corr_trajectory_moved_sem, corr_trajectory_rewarded_sem] ...
            = deal(zeros(1, n_condition));

    for n = 1:n_condition
        idx =  condition_all_session == condition_list_session(n);
        
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
        target_distance_rewarded(n) = mean(target_distance.distance_rewarded);
        target_distance_moved(n)    = mean(target_distance.distance_moved);
        %target_distance_rewarded_mad(n) = target_distance.distance_MAD_rewarded;
        %target_distance_moved_mad(n)    = target_distance.distance_MAD_moved;


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
    result_summary(i).condition_list_session    = condition_list_session;
    result_summary(i).is_trained                = is_trained; 
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
untrained_above_chance = ...
    arrayfun(@(n)any(result_summary(n).zscore_p_reward(~boolean(result_summary(n).is_trained)) > 1.625), [1:numel(exp_date_list)]);
trained_above_chance = ...
    arrayfun(@(n)any(result_summary(n).zscore_p_reward(boolean(result_summary(n).is_trained)) > 1.625), [1:numel(exp_date_list)]);
fprintf('%s: %d/%d sessions have untrained condition above chance \n', parameter_option, sum(untrained_above_chance), numel(exp_date_list));
fprintf('%s: %d/%d above-chance sessions have untrained condition above chance \n', parameter_option, sum(untrained_above_chance), sum(trained_above_chance));

%% make figures
condition_list_all = [result_summary(:).condition_list_session];

p_rewarded_moved_all            = [result_summary(:).p_rewarded_moved];
zscore_p_reward_all             = [result_summary(:).zscore_p_reward];
target_distance_moved_all       = [result_summary(:).target_distance_moved];
target_distance_rewarded_all    = [result_summary(:).target_distance_rewarded];
zscore_target_moved_all         = [result_summary(:).zscore_target_moved];
zscore_target_reward_all        = [result_summary(:).zscore_target_reward];

corr_trajectory_moved_all  = [result_summary(:).corr_trajectory_moved];

corr_trajectory_rewarded_all  = [result_summary(:).corr_trajectory_rewarded];


condition_list = unique(condition_list_all);

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

figure
for m = 1:size(metrics,1)
    eval(sprintf('y_all  = %s_all;',metrics{m,1}))
    y_label_str  = metrics{m,2};
    do_sig = metrics{m,3};

    y_avg = arrayfun(@(x) mean(y_all(condition_list_all == x), 'omitnan'), condition_list);
    y_std = arrayfun(@(x) std(y_all(condition_list_all == x), 'omitnan'),  condition_list);

    subplot(3,3,m); hold on

    % thin lines connecting points from the same session
    for i = 1:numel(result_summary)
        x_sess = result_summary(i).condition_list_session;
        eval(sprintf('y_sess = result_summary(i).%s;',metrics{m,1}));


        plot(x_sess, y_sess, '-', ...
            'Color', [0.7 0.7 0.7], ...
            'LineWidth', 0.5);
    end

    % group average ± std
    errorbar(condition_list, y_avg, y_std, ...
        'LineWidth', 2, ...
        'Color', 'black');

    if strcmp(metrics{m,1}, 'zscore_p_reward')
        line([condition_list(1), condition_list(end)], ...
             [1.645, 1.645], ...
             'LineStyle', '--', ...
             'Color', 'black');
    end

      if ismember(metrics{m,1}, {'zscore_target_moved','zscore_target_reward'})
        line([condition_list(1), condition_list(end)], ...
             -[1.645, 1.645], ...
             'LineStyle', '--', ...
             'Color', 'black');
    end

    xlabel(x_label_str);
    ylabel(y_label_str);
    box off
    set(gca, 'fontsize', 18)
end

sgtitle(subjectCode, 'fontweight', 'bold', 'fontsize', 18, 'interpreter', 'none')
