function [zscore_p_reward, zscore_target_moved, zscore_target_reward] = compute_z_score_condition(behav_data, real_values, idx, nPermute, EXP_CONFIG)
if  any(~ismember(idx,[0,1]))
    idx_run = idx;
else
    idx_run = find(idx);
end

%%%% real p_reward, target_moved, target_reward
p_reward_real       = real_values.p_reward_moved;
target_moved_real   = real_values.target_moved;
target_reward_real  = real_values.target_reward;


do_moved        = 1;

[p_reward_moved_permute, target_moved_permute, target_reward_permute] = deal(zeros(nPermute, 1));
for t = 1:nPermute
    
    behav_data_simulated       = util_pps.simulate_trajectories_permute(behav_data,idx_run, EXP_CONFIG, do_moved);


    doTimebin = false;
    doPlot = false;
    [percent_pps,~] = util_pps.get_probs_pps(behav_data_simulated, doTimebin, doPlot, EXP_CONFIG);


    p_reward_moved_permute(t)    = percent_pps.p_reward_moved;

    target_distance =  util_pps.compute_target_distance(behav_data_simulated);
    target_moved_permute(t) = target_distance.distance_median_moved;
    target_reward_permute(t) = target_distance.distance_median_rewarded;

end
zscore_p_reward = (p_reward_real - mean(p_reward_moved_permute)) / std(p_reward_moved_permute);
zscore_target_moved   = (target_moved_real - mean(target_moved_permute)) / std(target_moved_permute);
zscore_target_reward    = (target_reward_real - mean(target_reward_permute)) / std(target_reward_permute);


end