function [behav_data_simulated, simu_stats] = simulate_trajectories_permute(behav_data, EXP_CONFIG, do_permute_sign, do_moved)

if do_moved
    is_moved = [behav_data(:).is_moved];
    idx_sample = find(is_moved);
else
    idx_sample = [1:numel(behav_data)];
end

nTrial = numel(idx_sample);
for n = 1:nTrial
    i = idx_sample(n);
    x_start = behav_data(i).initial_x_rel_cm;
    idx_sample_trial = randsample(idx_sample, 1);
    
    reached_bottom = behav_data(idx_sample_trial).reached_bottom;

    delta_hori_sampled = behav_data(idx_sample_trial).delta_hori_cm;
    if do_permute_sign
        % if any(delta_hori_sampled < 0)
        %     pause
        % end
        delta_hori_sampled_abs  = abs(delta_hori_sampled);
        delta_hori_sampled_sign = sign(delta_hori_sampled); 
        delta_hori_sampled_sign_permute = delta_hori_sampled_sign;
        
        idx_to_permute = find(delta_hori_sampled_abs > 0);
        idx_permuted = idx_to_permute(randperm(numel(idx_to_permute)));
        delta_hori_sampled_sign_permute(idx_to_permute) = delta_hori_sampled_sign(idx_permuted);

        delta_hori_sampled = delta_hori_sampled_abs .* delta_hori_sampled_sign_permute;
        
    end
    x_trajectory = x_start + cumsum(delta_hori_sampled);

    collided = 0;
    rewarded = 0;
    %%% touch screen?
    idx_touch_edge = find(abs(x_trajectory) >= EXP_CONFIG(1).SCREEN_WIDTH_CM / 2, 1, 'first');
    if ~isempty(idx_touch_edge)
        %%% collided on the screen edge
        collided = 1;
        x_trajectory = x_trajectory(1:idx_touch_edge);
    end
    %%% rewarded?
    end_x = x_trajectory(end);
    if end_x >= EXP_CONFIG(1).tolerant_space_cm(1) & end_x <= EXP_CONFIG(1).tolerant_space_cm(2) & reached_bottom
       rewarded = 1;
    end

    
    behav_data_simulated(n).x_start = x_start;
    behav_data_simulated(n).x_trajectory = x_trajectory;
    behav_data_simulated(n).delta_hori_sampled = delta_hori_sampled;
    behav_data_simulated(n).rewarded = rewarded;
    behav_data_simulated(n).collided = collided;

    if sum(abs(delta_hori_sampled)) > 0
        behav_data_simulated(n).moved = 1;
    else
        behav_data_simulated(n).moved = 0;
    end
    
    behav_data_simulated(n).x_end = x_trajectory(end);

end

idx_reach_bottom    = [behav_data_simulated(:).collided] == 0;
idx_rewarded        = [behav_data_simulated(:).rewarded] == 1;

p_rewarded = sum(idx_rewarded) / nTrial;
p_collided = sum(~idx_reach_bottom) / nTrial;

nRewarded = sum(idx_rewarded);
nGood     = sum(([behav_data_simulated(:).moved] == 1) & ([behav_data_simulated(:).collided] == 0));
p_rewarded_good =  nRewarded / nGood;

%%% how centralized the ending position is

%%% rewarded
x_end_rewarded  = [behav_data_simulated(idx_rewarded).x_end];
MAD_rewarded    = mean(abs(x_end_rewarded));
%%% non-rewarded but non-collided
x_end_reachbottom  = [behav_data_simulated(idx_reach_bottom).x_end];
MAD_reachbottom    = mean(abs(x_end_reachbottom));

simu_stats.p_rewarded           = p_rewarded;
simu_stats.p_collided           = p_collided;
simu_stats.p_rewarded_good      = p_rewarded_good;
simu_stats.MAD_rewarded         = MAD_rewarded;
simu_stats.MAD_reachbottom      = MAD_reachbottom;
end
