function behav_data_simulated = simulate_trajectories_permute(behav_data, idx_run, EXP_CONFIG, do_moved)
%%%% idx_run can be a subset of trials, so that we can permute and compute
%%%% z-score for each condition.
if do_moved
    is_moved = [behav_data(:).is_moved];
    idx_moved = find(is_moved);
    idx_sample = intersect(idx_moved, idx_run);
else
    idx_sample = idx_run;
end

nTrial = numel(idx_sample);
for n = 1:nTrial
    i = idx_sample(n); % index of original trial

    x_start = behav_data(i).initial_x_rel_cm;
 
    idx_sample_trial = randsample(setdiff(idx_sample,i), 1); % index of sampled trial
    

    reached_bottom = behav_data(idx_sample_trial).reached_bottom;

    %%%% 05/18: also consider wheel jittering. I guess the rationale is to
    %%%% isolate (and only permute) movement from animal's "true intention", i.e. delta_tick
    %%%% times average gain of the wheel
    if isfield(behav_data(i), 'delta_cm_no_jitter')
        delta_hori_sampled = behav_data(idx_sample_trial).delta_cm_no_jitter;
    else
        delta_hori_sampled = behav_data(idx_sample_trial).delta_hori_cm;
    end
   
    % if do_permute_sign
    %     % if any(delta_hori_sampled < 0)
    %     %     pause
    %     % end
    %     delta_hori_sampled_abs  = abs(delta_hori_sampled);
    %     delta_hori_sampled_sign = sign(delta_hori_sampled); 
    %     delta_hori_sampled_sign_permute = delta_hori_sampled_sign;
    % 
    %     idx_to_permute = find(delta_hori_sampled_abs > 0);
    %     idx_permuted = idx_to_permute(randperm(numel(idx_to_permute)));
    %     delta_hori_sampled_sign_permute(idx_to_permute) = delta_hori_sampled_sign(idx_permuted);
    % 
    %     delta_hori_sampled = delta_hori_sampled_abs .* delta_hori_sampled_sign_permute;
    % 
    % end
    % 

    
    %%%% 05/07: also consider random walk
    x_random_walk = zeros(size(delta_hori_sampled)); % make sure array size is consistent
    if isfield(behav_data(i), 'x_random_walk')
         x_random_walk_original = behav_data(i).x_random_walk;
        if numel(delta_hori_sampled) > numel(x_random_walk_original)
            % first random walk, then non;
            x_random_walk(1:numel(x_random_walk_original)) = x_random_walk_original;
        else
            % just use part of it
            x_random_walk = x_random_walk_original(1:numel(delta_hori_sampled));
        end
       
    end
    %%%% 05/18: also consider wheel jittering
    x_jitter_only = zeros(size(delta_hori_sampled)); % make sure array size is consistent
    if isfield(behav_data(i), 'delta_cm_no_jitter')
        x_jitter_only_original = behav_data(i).jitter_only;
        if numel(delta_hori_sampled) > numel(x_random_walk_original)
            % first jitter, then non;
            x_jitter_only(1:numel(x_jitter_only_original))  = x_jitter_only_original;
        else
            x_jitter_only = x_jitter_only_original(1:numel(delta_hori_sampled));
        end
    end

    %%%% only the "intended movement" is from the randomly sampled trial,
    %%%% others are from the original trial
    x_trajectory = x_start + cumsum(delta_hori_sampled) + cumsum(x_random_walk) + cumsum(x_jitter_only);


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
    %%% why include reached_bottom of the sample trial: in this case, it is
    %%% very likely the target did not reach the reward zone along the
    %%% y-axis, so we should treat it as not-rewarded
    if end_x >= EXP_CONFIG(1).tolerant_space_cm(1) & end_x <= EXP_CONFIG(1).tolerant_space_cm(2) & reached_bottom
       rewarded = 1;
    end

    
    behav_data_simulated(n).x_start = x_start;
    behav_data_simulated(n).x_trajectory = x_trajectory;
    behav_data_simulated(n).end_x_rel_cm = x_trajectory(end);
   
    behav_data_simulated(n).delta_hori_sampled = delta_hori_sampled;
    behav_data_simulated(n).rewarded = rewarded;
    behav_data_simulated(n).collided = collided;

    if sum(abs(delta_hori_sampled)) > EXP_CONFIG(1).MOVEMENT_THRESHOLD
        behav_data_simulated(n).is_moved = 1;
    else
        behav_data_simulated(n).is_moved = 0;
    end
    
  
    behav_data_simulated(n).reached_bottom = reached_bottom & ~collided;
    %behav_data_simulated(n).x_end = x_trajectory(end);

end

% idx_reach_bottom    = [behav_data_simulated(:).collided] == 0;
% idx_rewarded        = [behav_data_simulated(:).rewarded] == 1;
% 
% p_rewarded = sum(idx_rewarded) / nTrial;
% p_collided = sum(~idx_reach_bottom) / nTrial;
% 
% nRewarded = sum(idx_rewarded);
% nGood     = sum(([behav_data_simulated(:).moved] == 1) & ([behav_data_simulated(:).collided] == 0));
% p_rewarded_good =  nRewarded / nGood;

% %%% rewarded
% x_end_rewarded  = [behav_data_simulated(idx_rewarded).x_end];
% MAD_rewarded    = mean(abs(x_end_rewarded));
% %%% non-rewarded but non-collided
% x_end_reachbottom  = [behav_data_simulated(idx_reach_bottom).x_end];
% MAD_reachbottom    = mean(abs(x_end_reachbottom));


% %%%% prob of getting rewarded
% doTimebin = false;doPlot = false;
% [percent_pps, ~] = util_pps.get_probs_pps(behav_data_simulated, doTimebin, doPlot, EXP_CONFIG);
% %%% how centralized the ending position iss
% target_MAD_simulated = util_pps.compute_MAD(behav_data_simulated);


% 
% simu_stats.p_rewarded           = percent_pps.p_reward;
% simu_stats.p_reward_moved       = percent_pps.p_reward_moved;
% 
% simu_stats.MAD_rewarded         = target_MAD_simulated.rewarded;
% simu_stats.MAD_moved            = target_MAD_simulated.moved;
% simu_stats.MAD_reachbottom      = target_MAD_simulated.reachbottom;
end
