function behav_results_summary = load_behav_results_summary(save_folder, subjectCode, session_list)

behav_results_summary = struct();
for n = 1:numel(session_list)
    load(fullfile(save_folder, sprintf('behav_stats_PPS_%s_%s',subjectCode,session_list{n})));
    load(fullfile(save_folder, sprintf('behav_data_PPS_%s_%s',subjectCode,session_list{n})));
    behav_results_summary(n).subjectCode = subjectCode;
    behav_results_summary(n).sessionStr = session_list{n};

    behav_results_summary(n).p_moved =  behav_results.percent_pps.p_moved;
    %%%% percentage of rewarded
    behav_results_summary(n).nRewarded  = sum([behav_data(:).rewarded]);
    behav_results_summary(n).p_reward_real              = behav_results.percent_pps.p_reward;
    behav_results_summary(n).p_reward_moved             = behav_results.percent_pps.p_reward_moved; 
    %behav_results_summary(n).p_reward_initialOUT_left   = behav_results.percent_pps.p_reward_initialOUT_left;
    %behav_results_summary(n).p_reward_initialOUT_right  = behav_results.percent_pps.p_reward_initialOUT_right;
    
    %%%%% base line MAD: half of reward zone
    behav_results_summary(n).target_distance_baseline = EXP_CONFIG(1).tolerant_space_cm(2) / 2;

    %%% Mean absoulate distance to the center
    %%% check how centralized the end points are
    %[MAD_rewarded, MAD_reachbottom, MAD_moved_rewarded, MAD_moved_reachbottom] = util_pps.compute_MAD(behav_data);
    behav_results_summary(n).target_distance_rewarded               = behav_results.target_distance.distance_rewarded;
    behav_results_summary(n).target_distance_moved                  =  behav_results.target_distance.distance_moved;
    behav_results_summary(n).target_distance_median_rewarded        = behav_results.target_distance.distance_median_rewarded;
    behav_results_summary(n).target_distance_MAD_rewarded           = behav_results.target_distance.distance_MAD_rewarded;

    behav_results_summary(n).target_distance_median_moved        = behav_results.target_distance.distance_median_moved;
    behav_results_summary(n).target_distance_MAD_moved           = behav_results.target_distance.distance_MAD_moved;


    %%%% ratio of GD movement, amount of extra movement
    behav_results_summary(n).GD_ratio_moved = behav_results.movement_stats.GD_ratio_moved;
    behav_results_summary(n).extra_movement_moved = behav_results.movement_stats.extra_movement_moved;

    behav_results_summary(n).GD_ratio_rewarded = behav_results.movement_stats.GD_ratio_rewarded;
    behav_results_summary(n).extra_movement_rewarded = behav_results.movement_stats.extra_movement_rewarded;

    % %%%%% correlation between ideal and empirical trajectories
    behav_results_summary(n).corr_trajectory_moved = behav_results.correlation_trajectory.r_all_moved;
    behav_results_summary(n).corr_trajectory_rewarded = behav_results.correlation_trajectory.r_all_rewarded;


   


    % %%%%% median  and  68% percentile of sum_abs_delta_x
    % %%%%% Reflect how active the animals are
    % sum_abs_delta_hori = [behav_data(:).sum_abs_delta_hori_cm];
    % behav_results_summary(n).sum_abs_delta_hori_median = median(sum_abs_delta_hori);
    % behav_results_summary(n).sum_abs_delta_hori_prctile = prctile(sum_abs_delta_hori, [16, 84]);

    %%%%%% compute z-scores relative to chance level
    behav_results_summary(n).zscore_p_reward = ...
         compute_zscore(behav_results_summary(n).p_reward_real,  behav_results.permute_chance_level.p_reward_permute_all);
       
    behav_results_summary(n).zscore_p_reward_moved = ...
        compute_zscore(behav_results_summary(n).p_reward_moved,  behav_results.permute_chance_level.p_reward_moved_permute_moved);

    behav_results_summary(n).zscore_target_distance_moved = ...
        compute_zscore(behav_results_summary(n).target_distance_median_moved, behav_results.permute_chance_level.target_dist_moved_permute_moved);


    behav_results_summary(n).zscore_target_distance_rewarded = ...
        compute_zscore(behav_results_summary(n).target_distance_median_rewarded, behav_results.permute_chance_level.target_dist_rewarded_permute_moved);







end
end


function zscore = compute_zscore(x_real, x_null)
    zscore = (x_real - mean(x_null)) / std(x_null);
end


