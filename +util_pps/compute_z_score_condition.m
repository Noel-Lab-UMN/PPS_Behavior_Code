function z_score = compute_z_score_condition(behav_data, p_reward_real, idx, nPermute, EXP_CONFIG)
if  any(~ismember(idx,[0,1]))
    idx_run = idx;
else
    idx_run = find(idx);
end
do_permute_sign = 0;
do_moved        = 1;

p_reward_moved_permute = zeros(nPermute, 1);
for t = 1:nPermute
    
    [~, simu_stats]       = util_pps.simulate_trajectories_permute(behav_data,idx_run, EXP_CONFIG, do_permute_sign, do_moved);
    p_reward_moved_permute(t)    = simu_stats.p_rewarded;
end
z_score = (p_reward_real - mean(p_reward_moved_permute)) / std(p_reward_moved_permute);

end