function  permute_chance_level = get_chance_level_permute(behav_data, EXP_CONFIG, nPermute)


[p_reward_permute, MAD_rewarded_permute, MAD_reachbottom_permute] = ...
    deal(zeros(nPermute, 1));

[p_reward_permute_sign, MAD_rewarded_permute_sign, MAD_reachbottom_permute_sign] = ...
    deal(zeros(nPermute, 1));

[p_reward_permute_moved, MAD_rewarded_permute_moved, MAD_reachbottom_permute_moved] = ...
    deal(zeros(nPermute, 1));

idx_run = [1:numel(behav_data)];

for n = 1:nPermute
 
    do_permute_sign = 0;
    do_moved        = 0;
    [~, simu_stats]             = util_pps.simulate_trajectories_permute(behav_data, idx_run, EXP_CONFIG, do_permute_sign, do_moved);
    p_reward_permute(n)         = simu_stats.p_rewarded;
    MAD_rewarded_permute(n)     = simu_stats.MAD_rewarded;
    MAD_reachbottom_permute(n)  = simu_stats.MAD_reachbottom;
    
    
    do_permute_sign = 1;
    do_moved        = 0;
    [~, simu_stats]   = util_pps.simulate_trajectories_permute(behav_data, idx_run, EXP_CONFIG, do_permute_sign, do_moved);

    p_reward_permute_sign(n)         = simu_stats.p_rewarded;
    MAD_rewarded_permute_sign(n)     = simu_stats.MAD_rewarded;
    MAD_reachbottom_permute_sign(n)  = simu_stats.MAD_reachbottom;


    do_permute_sign = 0;
    do_moved        = 1;
    [~, simu_stats]                   = util_pps.simulate_trajectories_permute(behav_data, idx_run, EXP_CONFIG, do_permute_sign, do_moved);
    p_reward_permute_moved(n)         = simu_stats.p_rewarded;
    MAD_rewarded_permute_moved(n)     = simu_stats.MAD_rewarded;
    MAD_reachbottom_permute_moved(n)  = simu_stats.MAD_reachbottom;
    


end


permute_chance_level.p_reward_permute       = p_reward_permute;
permute_chance_level.p_reward_permute_sign  = p_reward_permute_sign;
permute_chance_level.p_reward_permute_moved = p_reward_permute_moved;

permute_chance_level.MAD_rewarded_permute   = MAD_rewarded_permute;
permute_chance_level.MAD_rewarded_permute_sign = MAD_rewarded_permute_sign;
permute_chance_level.MAD_rewarded_permute_moved = MAD_rewarded_permute_moved;

permute_chance_level.MAD_reachbottom_permute = MAD_reachbottom_permute;
permute_chance_level.MAD_reachbottom_permute_sign = MAD_reachbottom_permute_sign;
permute_chance_level.MAD_reachbottom_permute_moved = MAD_reachbottom_permute_moved;
end