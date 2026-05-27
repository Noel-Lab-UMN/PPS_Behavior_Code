function  permute_chance_level = get_chance_level_permute(behav_data, EXP_CONFIG, nPermute)


[p_reward_permute_all, p_reward_moved_permute_all] =  deal(zeros(nPermute, 1));

[target_dist_rewarded_permute_all, target_dist_moved_permute_all] = deal(zeros(nPermute, 1));

% [p_reward_permute_sign, MAD_rewarded_permute_sign, MAD_reachbottom_permute_sign] = ...
%     deal(zeros(nPermute, 1));

[p_reward_permute_moved, p_reward_moved_permute_moved] = deal(zeros(nPermute, 1));
[target_dist_rewarded_permute_moved, target_dist_moved_permute_moved] = deal(zeros(nPermute, 1));

idx_run = [1:numel(behav_data)];

for n = 1:nPermute
 
    %do_permute_sign = 0;
    do_moved        = false;
    behav_data_simulated                = util_pps.simulate_trajectories_permute(behav_data, idx_run, EXP_CONFIG, do_moved);

    doTimebin = false;
    doPlot = false;
    [percent_pps,~] = util_pps.get_probs_pps(behav_data_simulated, doTimebin, doPlot, EXP_CONFIG);
    target_distance =  util_pps.compute_target_distance(behav_data_simulated);

 
    p_reward_permute_all(n)         = percent_pps.p_reward;
    p_reward_moved_permute_all(n)   = percent_pps.p_reward_moved;

    target_dist_rewarded_permute_all(n)     = target_distance.distance_median_rewarded;
    target_dist_moved_permute_all(n)        = target_distance.distance_median_moved;
    %MAD_reachbottom_permute_all(n)  = target_distance.distance_median_reachbottom;

   


    do_moved        = true;
    behav_data_simulated                    = util_pps.simulate_trajectories_permute(behav_data, idx_run, EXP_CONFIG, do_moved);


    doTimebin = false;
    doPlot = false;
    [percent_pps,~] = util_pps.get_probs_pps(behav_data_simulated, doTimebin, doPlot, EXP_CONFIG);
    target_distance =  util_pps.compute_target_distance(behav_data_simulated);

    p_reward_permute_moved(n)           = percent_pps.p_reward;
    p_reward_moved_permute_moved(n)     = percent_pps.p_reward_moved;


    target_dist_rewarded_permute_moved(n)     = target_distance.distance_median_rewarded;
    target_dist_moved_permute_moved(n)        = target_distance.distance_median_moved;
   % MAD_reachbottom_permute_moved(n)  = target_distance.distance_median_reachbottom;


    
    % do_permute_sign = 1;
    % do_moved        = 0;
    % [~, simu_stats]   = util_pps.simulate_trajectories_permute(behav_data, idx_run, EXP_CONFIG, do_permute_sign, do_moved);
    % 
    % p_reward_permute_sign(n)         = simu_stats.p_rewarded;
    % MAD_rewarded_permute_sign(n)     = simu_stats.MAD_rewarded;
    % MAD_reachbottom_permute_sign(n)  = simu_stats.MAD_reachbottom;


    %do_permute_sign = 0;

    


end


permute_chance_level.p_reward_permute_all           = p_reward_permute_all;
permute_chance_level.p_reward_moved_permute_all     = p_reward_moved_permute_all;

permute_chance_level.target_dist_rewarded_permute_all       = target_dist_rewarded_permute_all;
permute_chance_level.target_dist_moved_permute_all          = target_dist_moved_permute_all;
%permute_chance_level.MAD_reachbottom_permute_all    = MAD_reachbottom_permute_all;


permute_chance_level.p_reward_permute_moved         = p_reward_permute_moved;
permute_chance_level.p_reward_moved_permute_moved   = p_reward_moved_permute_moved;

permute_chance_level.target_dist_rewarded_permute_moved     = target_dist_rewarded_permute_moved;
permute_chance_level.target_dist_moved_permute_moved        = target_dist_moved_permute_moved; 
%permute_chance_level.MAD_reachbottom_permute_moved  = MAD_reachbottom_permute_moved;

end