clear all
clc
close all

subjectCode  = 'LSZ_practice_5_violet';
data_folder = fullfile('../../results/behav/pps_processed/',subjectCode);
global PPS_global
generate_PPS_global();
%eval(sprintf('session_list_all = PPS_global.%s.session_list.new_params;',subjectCode));
nPermute = 100;
colors_list = get(groot, 'defaultAxesColorOrder');
%%
exp_date_list = {'20260422';'20260423';'20260424';'20260428';'20260429';'20260430';'20260501'};
nSession = numel(exp_date_list);
nRow            = floor(sqrt(nSession));
nCol            = ceil(nSession / nRow); 
[p_reward_moved_nowalk, p_rewarded_moved_nowalk_sem, z_score_nowalk] = deal(zeros(nSession, 1));
[p_reward_moved_walk, p_rewarded_moved_walk_sem, z_score_walk] = deal(zeros(nSession, 1));
for n = 1:nSession
    exp_date = exp_date_list{n};
    load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s', subjectCode, exp_date)));

    random_bias_all = [behav_data(:).ball_random_bias];
    random_std_all  = [behav_data(:).ball_random_std];
    random_bias_abs_all = abs(random_bias_all);

    random_bias_list    = unique(random_bias_abs_all);
    random_std_list     = unique(random_std_all);

    random_bias_list(random_bias_list == 0) = []; % remove the no random walk condition
    random_std_list(random_std_list == 0) = [];

    nBias = numel(random_bias_list);
    nStd  = numel(random_std_list);

    idx_no_random_walk = random_bias_all == 0;
    
   
   
    p_reward_moved_nowalk(n) = sum([behav_data(idx_no_random_walk).is_moved] & [behav_data(idx_no_random_walk).rewarded]) / sum([behav_data(idx_no_random_walk).is_moved]);
    p_rewarded_moved_nowalk_sem(n) = sqrt(p_reward_moved_nowalk(n) * (1 - p_reward_moved_nowalk(n)) / ...
                sum([behav_data(idx_no_random_walk).is_moved]));
    z_score_nowalk(n) = util_pps.compute_z_score_condition(behav_data, p_reward_moved_nowalk(n), idx_no_random_walk, nPermute, EXP_CONFIG);
    
    
    idx_random_walk = ~idx_no_random_walk;
    p_reward_moved_walk(n) = sum([behav_data(idx_random_walk).is_moved] & [behav_data(idx_random_walk).rewarded]) / sum([behav_data(idx_random_walk).is_moved]);
    p_rewarded_moved_walk_sem(n) = sqrt(p_reward_moved_walk(n) * (1 - p_reward_moved_walk(n)) / ...
                sum([behav_data(idx_random_walk).is_moved]));
    z_score_walk(n) = util_pps.compute_z_score_condition(behav_data, p_reward_moved_walk(n), idx_random_walk, nPermute, EXP_CONFIG);
    
end
%%
figure
subplot(2,1,1)
errorbar([1:nSession], p_reward_moved_nowalk, p_rewarded_moved_nowalk_sem, 'LineWidth',2); hold on
errorbar([1:nSession], p_reward_moved_walk, p_rewarded_moved_walk_sem, 'LineWidth',2);
box off
xlabel('Session index');
ylabel('P(reward|moved)');
legend('No random walk','Random walk')
set(gca,'fontsize', 18)
subplot(2,1,2)
plot([1:nSession], z_score_nowalk, '-o', 'LineWidth',2); hold on
plot([1:nSession],z_score_walk, '-o', 'LineWidth',2 );
line([1, nSession], [1.645, 1.645], 'linestyle','--','color','black');

box off
xlabel('Session index');
ylabel('Zscore')
legend('No random walk','Random walk')
set(gca,'fontsize', 18)
% subplot(nRow, nCol, n)
%  for i = 1:nBias
%     plot(random_std_list, z_score(i,:),'-o'); hold on
%    % plot(random_std_list, random_walk_percent(i,:),'-o'); hold on
%  end
     %legend(random_bias_list)
    % line([random_std_list(1) - 5, random_std_list(end)+5],[1.65, 1.65],'linestyle','--','color','black');
    % line([random_std_list(1) - 5, random_std_list(end)+5],[z_score_nowalk, z_score_nowalk],'linestyle','-','color','blue');

%% Percentage of random walk
