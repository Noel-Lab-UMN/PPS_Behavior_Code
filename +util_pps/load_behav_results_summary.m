function behav_results_summary = load_behav_results_summary(save_folder, subjectCode, session_list)

behav_results_summary = struct();
for n = 1:numel(session_list)
    load(fullfile(save_folder, sprintf('behav_stats_PPS_%s_%s',subjectCode,session_list{n})));
    load(fullfile(save_folder, sprintf('behav_data_PPS_%s_%s',subjectCode,session_list{n})));
    behav_results_summary(n).subjectCode = subjectCode;
    behav_results_summary(n).sessionStr = session_list{n};

    behav_results_summary(n).p_moved =  behav_results.percent_pps.p_moved;
    %%%% percentage of rewarded
    behav_results_summary(n).p_reward_real              = behav_results.percent_pps.p_reward;
    behav_results_summary(n).p_reward_moved             = behav_results.percent_pps.p_reward_moved; 
    behav_results_summary(n).p_reward_initialOUT_left   = behav_results.percent_pps.p_reward_initialOUT_left;
    behav_results_summary(n).p_reward_initialOUT_right  = behav_results.percent_pps.p_reward_initialOUT_right;
    
    %%%%% base line MAD: half of reward zone
    behav_results_summary(n).MAD_baseline = EXP_CONFIG(1).tolerant_space_cm(2) / 2;

    %%% Mean absoulate distance to the center
    %%% check how centralized the end points are
    [MAD_rewarded, MAD_reachbottom, MAD_moved_rewarded, MAD_moved_reachbottom] = compute_MAD(behav_data);
    behav_results_summary(n).MAD_reward_real        = MAD_rewarded;
    behav_results_summary(n).MAD_reachbottom_real   = MAD_reachbottom;
    behav_results_summary(n).MAD_moved_rewarded       = MAD_moved_rewarded;
    behav_results_summary(n).MAD_moved_reachbottom   = MAD_moved_reachbottom;

    %%%%% median  and  68% percentile of sum_abs_delta_x
    %%%%% Reflect how active the animals are
    sum_abs_delta_hori = [behav_data(:).sum_abs_delta_hori_cm];
    behav_results_summary(n).sum_abs_delta_hori_median = median(sum_abs_delta_hori);
    behav_results_summary(n).sum_abs_delta_hori_prctile = prctile(sum_abs_delta_hori, [16, 84]);

    %%%% load the chance levels
    behav_results_summary(n).p_reward_permute       = 100 * behav_results.permute_chance_level.p_reward_permute;
    behav_results_summary(n).p_reward_permute_sign  = 100 * behav_results.permute_chance_level.p_reward_permute_sign;
    behav_results_summary(n).p_reward_permute_moved = 100 * behav_results.permute_chance_level.p_reward_permute_moved;

    behav_results_summary(n).MAD_reward_permute       = behav_results.permute_chance_level.MAD_rewarded_permute;
    behav_results_summary(n).MAD_reward_permute_sign  = behav_results.permute_chance_level.MAD_rewarded_permute_sign;
    behav_results_summary(n).MAD_reward_permute_moved  = behav_results.permute_chance_level.MAD_rewarded_permute_moved;

    behav_results_summary(n).MAD_reachbottom_permute       = behav_results.permute_chance_level.MAD_reachbottom_permute;
    behav_results_summary(n).MAD_reachbottom_permute_sign  = behav_results.permute_chance_level.MAD_reachbottom_permute_sign;
    behav_results_summary(n).MAD_reachbottom_permute_moved  = behav_results.permute_chance_level.MAD_reachbottom_permute_moved;
    
    %%%% p values relative to the chance level
    behav_results_summary(n).pval_reward = sum(behav_results_summary(n).p_reward_real < behav_results_summary(n).p_reward_permute) / ...
                                            numel(behav_results_summary(n).p_reward_permute);
    behav_results_summary(n).pval_reward_sign = sum(behav_results_summary(n).p_reward_real < behav_results_summary(n).p_reward_permute_sign) / ...
                                            numel(behav_results_summary(n).p_reward_permute_sign);
    behav_results_summary(n).pval_MAD = sum(behav_results_summary(n).MAD_reward_real > behav_results_summary(n).MAD_reward_permute) / ...
                                            numel(behav_results_summary(n).MAD_reward_permute);
    behav_results_summary(n).pval_MAD_sign = sum(behav_results_summary(n).MAD_reward_real > behav_results_summary(n).MAD_reward_permute_sign) / ...
                                            numel(behav_results_summary(n).MAD_reward_permute_sign);
    %%%% z-score relative to the chance level
    behav_results_summary(n).zscore_reward = (behav_results_summary(n).p_reward_real - mean(behav_results_summary(n).p_reward_permute)) / ...
                                                std(behav_results_summary(n).p_reward_permute);
    behav_results_summary(n).zscore_reward_sign = (behav_results_summary(n).p_reward_real - mean(behav_results_summary(n).p_reward_permute_sign)) / ...
                                                std(behav_results_summary(n).p_reward_permute_sign);
    behav_results_summary(n).zscore_reward_moved = (behav_results_summary(n).p_reward_moved - mean(behav_results_summary(n).p_reward_permute_moved)) / ...
                                                std(behav_results_summary(n).p_reward_permute_moved);

    behav_results_summary(n).zscore_MAD = (behav_results_summary(n).MAD_reward_real - mean(behav_results_summary(n).MAD_reward_permute)) / ...
                                                std(behav_results_summary(n).MAD_reward_permute);
    behav_results_summary(n).zscore_MAD_sign = (behav_results_summary(n).MAD_reward_real - mean(behav_results_summary(n).MAD_reward_permute_sign)) / ...
                                                std(behav_results_summary(n).MAD_reward_permute_sign);
    behav_results_summary(n).zscore_MAD_moved = (behav_results_summary(n).MAD_moved_rewarded - mean(behav_results_summary(n).MAD_reward_permute_moved)) / ...
                                                std(behav_results_summary(n).MAD_reward_permute_moved);



end
end


function [MAD_rewarded, MAD_reachbottom, MAD_moved_rewarded, MAD_moved_reachbottom] = compute_MAD(behav_data)
idx_reach_bottom    = [behav_data(:).reached_bottom] == 1;
idx_rewarded        = [behav_data(:).rewarded] == 1;
idx_moved           = [behav_data(:).is_moved]; 

%%% how centralized the ending position is

%%% rewarded
x_end_rewarded  = [behav_data(idx_rewarded).end_x_rel_cm];
MAD_rewarded    = mean(abs(x_end_rewarded));
%%% non-rewarded but non-collided
x_end_reachbottom  = [behav_data(idx_reach_bottom).end_x_rel_cm];
MAD_reachbottom    = mean(abs(x_end_reachbottom));

%%% moved rewarded
x_end_moved_rewarded  = [behav_data(idx_rewarded & idx_moved).end_x_rel_cm];
MAD_moved_rewarded    = mean(abs(x_end_moved_rewarded));

%%% moved reached bottom
x_end_moved_reachbottom  = [behav_data(idx_reach_bottom & idx_moved).end_x_rel_cm];
MAD_moved_reachbottom    = mean(abs(x_end_moved_reachbottom));

end