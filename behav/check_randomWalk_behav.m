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

    p_reward_moved_nowalk = sum([behav_data(idx_no_random_walk).is_moved] & [behav_data(idx_no_random_walk).rewarded]) / sum([behav_data(idx_no_random_walk).is_moved]);
    z_score_nowalk = util_pps.compute_z_score_condition(behav_data, p_reward_moved_nowalk, idx_no_random_walk, nPermute, EXP_CONFIG);

    [p_reward_moved, p_reward_free, z_score, random_walk_percent] = deal(zeros(1, nStd));
    
    for i = 1:nBias
        for j = 1:nStd
            idx = find(random_bias_abs_all == random_bias_list(i) & ...
                random_std_all == random_std_list(j));

            %%% p_reward_moved
            p_reward_moved(i,j) = sum([behav_data(idx).is_moved] & [behav_data(idx).rewarded]) / sum([behav_data(idx).is_moved]);
            %%% z-score
           % z_score(i) = util_pps.compute_z_score_condition(behav_data, p_reward_moved(i), idx, nPermute, EXP_CONFIG);
            %%% p_reward_free
            p_reward_free(i,j) = sum(~[behav_data(idx).is_moved] & [behav_data(idx).rewarded]) / sum(~[behav_data(idx).is_moved]);

            rwp = zeros(numel(idx),1);
            for t = 1:numel(idx)
                idx_move = behav_data(idx(t)).delta_hori_cm ~= 0;
                
                rwp(t) = mean( abs(behav_data(idx(t)).x_random_walk(idx_move)) ./ abs(behav_data(idx(t)).delta_hori_cm(idx_move)), 'omitnan');
            end
            random_walk_percent(i,j) = median(rwp,'omitnan');
        end
    end
    %%%
    subplot(nRow, nCol, n)
     for i = 1:nBias
       % plot(random_std_list, z_score,'-o'); hold on
        plot(random_std_list, random_walk_percent(i,:),'-o'); hold on
     end
     %legend(random_bias_list)
    % line([random_std_list(1) - 5, random_std_list(end)+5],[1.65, 1.65],'linestyle','--','color','black');
    % line([random_std_list(1) - 5, random_std_list(end)+5],[z_score_nowalk, z_score_nowalk],'linestyle','-','color','blue');
end
%% Percentage of random walk
