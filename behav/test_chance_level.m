clear all
clc
close all
%%
load('../../results/behav/pps_processed/LSZ_practice_5_violet/behav_data_PPS_LSZ_practice_5_violet_20260309.mat');
behav_data(1) = [];
%% simulate trajectories by sampling
% do_two_stage = 0;
simu_option = 'one_stage';
behav_data_simulated_onestage = simulate_behav_data(behav_data, EXP_CONFIG, simu_option);

simu_option = 'two_stage';
behav_data_simulated_twostage = simulate_behav_data(behav_data, EXP_CONFIG, simu_option);

simu_option = 'fix_zero';
behav_data_simulated_fixzero = simulate_behav_data(behav_data, EXP_CONFIG, simu_option);
%% simulate trajectories by permuting trial index and time point of signs
do_permute_sign = 0;
behav_data_simulated_permute = util_pps.simulate_trajectories_permute(behav_data, EXP_CONFIG, do_permute_sign);

do_permute_sign = 1;
behav_data_simulated_permutesign = util_pps.simulate_trajectories_permute(behav_data, EXP_CONFIG, do_permute_sign);

%% 
nPermute = 100;
[p_reward_fixzero, p_reward_permute, p_reward_permute_sign] = ...
    deal(zeros(nPermute, 1));
[p_collide_fixzero, p_collide_permute, p_collide_permute_sign] = ...
    deal(zeros(nPermute, 1));
[p_reward_good_fixzero, p_reward_good_permute, p_reward_good_permute_sign] = ...
    deal(zeros(nPermute, 1));
for n = 1:nPermute
    simu_option = 'fix_zero';
    [~, p_reward_fixzero(n), p_collide_fixzero(n), p_reward_good_fixzero(n)] = simulate_behav_data(behav_data, EXP_CONFIG, simu_option);

    do_permute_sign = 0;
    [~, simu_stats] = util_pps.simulate_trajectories_permute(behav_data, EXP_CONFIG, do_permute_sign);  
    p_reward_permute(n)         = simu_stats.p_rewarded;
    %p_collide_permute(n)        = simu_stats.p_collide;
    p_reward_good_permute(n)    = simu_stats.p_rewarded_good; 

    do_permute_sign = 1;
    [~, simu_stats] = util_pps.simulate_trajectories_permute(behav_data, EXP_CONFIG, do_permute_sign);
    p_reward_permute_sign(n) = simu_stats.p_rewarded;
    %p_collide_permute_sign(n) = simu_stats.p_collide;
    p_reward_good_permute_sign(n) = simu_stats.p_rewarded_good; 
end
%% visualization of results
figure; 
subplot(3,1,1);hold on
histogram(p_reward_permute);
histogram(p_reward_permute_sign);
histogram(p_reward_fixzero);
legend('Permute','Permute-sign','Fix-zero')

p_real = sum([behav_data(:).rewarded] == 1) / numel(behav_data);
line([p_real, p_real], [0, numel(behav_data) / 10],'linestyle','--','color','red');

subplot(3,1,2); hold on
histogram(p_collide_permute);
histogram(p_collide_permute_sign);
histogram(p_collide_fixzero);
legend('Permute','Permute-sign','Fix-zero')

p_real = sum([behav_data(:).reached_bottom] == 0) / numel(behav_data);
line([p_real, p_real], [0, numel(behav_data) / 10],'linestyle','--','color','red');

subplot(3,1,3);hold on
histogram(p_reward_good_permute);
histogram(p_reward_good_permute_sign);
histogram(p_reward_good_fixzero);
legend('Permute','Permute-sign','Fix-zero')

% p_real = sum([behav_data(:).rewarded] == 1) / numel(behav_data);
% line([p_real, p_real], [0, numel(behav_data) / 10],'linestyle','--','color','red');
%%

figure;

delta_hori_cm     = {behav_data(:).delta_hori_cm};
delta_hori_cm_all       = cat(1,delta_hori_cm{:});
delta_hori_cm_nonzero   = delta_hori_cm_all(abs(delta_hori_cm_all) > 0);
frac_zero               = sum(delta_hori_cm_all == 0) / numel(delta_hori_cm_all);
delta_hori_cm_abs = cellfun(@sum,cellfun(@abs, delta_hori_cm,'UniformOutput',false));
subplot(3,2,1);
histogram(delta_hori_cm_nonzero); title(sprintf('Fraction zero = %.2f',frac_zero))
subplot(3,2,2);
histogram(delta_hori_cm_abs,[0:5:80]);




delta_hori_cm     = {behav_data_simulated_fixzero(:).delta_hori_sampled};
delta_hori_cm_all       = cat(1,delta_hori_cm{:});
delta_hori_cm_nonzero   = delta_hori_cm_all(abs(delta_hori_cm_all) > 0);
frac_zero               = sum(delta_hori_cm_all == 0) / numel(delta_hori_cm_all);
delta_hori_cm_abs = cellfun(@sum,cellfun(@abs, delta_hori_cm,'UniformOutput',false));
subplot(3,2,3);
histogram(delta_hori_cm_nonzero); title(sprintf('Fraction zero = %.2f',frac_zero))
subplot(3,2,4);
histogram(delta_hori_cm_abs,[0:5:80]);


delta_hori_cm     = {behav_data_simulated_permutesign(:).delta_hori_sampled};
delta_hori_cm_all       = cat(1,delta_hori_cm{:});
delta_hori_cm_nonzero   = delta_hori_cm_all(abs(delta_hori_cm_all) > 0);
frac_zero               = sum(delta_hori_cm_all == 0) / numel(delta_hori_cm_all);
delta_hori_cm_abs = cellfun(@sum,cellfun(@abs, delta_hori_cm,'UniformOutput',false))
subplot(3,2,5);
histogram(delta_hori_cm_nonzero);  title(sprintf('Fraction zero = %.2f',frac_zero))
subplot(3,2,6);
histogram(delta_hori_cm_abs,[0:5:80]);
%% helper functions





function [behav_data_simulated, p_rewarded, p_collided, p_rewarded_good] = simulate_behav_data(behav_data, EXP_CONFIG, simu_option)
%%% Get change of x in the original data
delta_hori_cm = {behav_data(:).delta_hori_cm};
delta_hori_cm_abs = cellfun(@abs, delta_hori_cm,'UniformOutput',false);

%%%% fraction of moved trials
delta_hori_cm_sum_abs = cellfun(@sum, delta_hori_cm_abs);
idx_move_trials = delta_hori_cm_sum_abs > 0;

p_move = sum(idx_move_trials) / numel(idx_move_trials);

% idx_collide             = [behav_data(:).reached_bottom] == 0;
% p_collide               = sum(idx_collide) / numel(behav_data);

%idx_good = idx_move_trials & ~idx_collide;

delta_hori_cm_all       = cat(1,delta_hori_cm{:}); % distribution of delta_x in all trials
delta_hori_cm_move      = cat(1,delta_hori_cm{idx_move_trials}); % distribution of delta_x in moved trials
delta_hori_cm_nonzero   = delta_hori_cm_all(abs(delta_hori_cm_all) > 0);
%%%% number of time point
frame_idx_all = {behav_data(:).frame_idx};
nFrame = cellfun(@numel, frame_idx_all);
n_time_steps        = max(nFrame); 


behav_data_simulated     = struct();
nTrial = numel(behav_data);

switch simu_option
    case 'two_stage'
        dist_delta_hori = delta_hori_cm_move;
        p_move_use = p_move;
    case 'one_stage'
        dist_delta_hori = delta_hori_cm_all;
        p_move_use = 1;
    case 'fix_zero'
        dist_delta_hori = delta_hori_cm_nonzero;
end
for n = 1:nTrial
    x_start = behav_data(n).initial_x_rel_cm;
    switch simu_option
        case {'two_stage','one_stage'}
            [x_trajectory, rewarded, collided, delta_hori_sampled] = ...
                simulate_trajectories(x_start, dist_delta_hori, n_time_steps, EXP_CONFIG, p_move_use);
        case 'fix_zero'
            delta_x_original = behav_data(n).delta_hori_cm;
            [x_trajectory, rewarded, collided, delta_hori_sampled] = ...
                simulate_trajectories_fixZero(x_start, delta_x_original, dist_delta_hori, EXP_CONFIG);
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

end
    
p_rewarded = sum([behav_data_simulated(:).rewarded] == 1) / numel(behav_data_simulated);
p_collided = sum([behav_data_simulated(:).collided] == 1) / numel(behav_data_simulated);

nRewarded = sum([behav_data_simulated(:).rewarded] == 1);
nGood     = sum(([behav_data_simulated(:).moved] == 1) & ([behav_data_simulated(:).collided] == 0));
p_rewarded_good =  nRewarded / nGood;
end



function [x_trajectory, rewarded, collided, moved, delta_hori_sampled] = simulate_trajectories(x_start, dist_delta_hori, n_time_steps, EXP_CONFIG, p_move)
if rand(1,1) < p_move 
    % a trial with wheel movement
    delta_hori_sampled = randsample(dist_delta_hori, n_time_steps);
    moved = 1;
else % just no movement
    delta_hori_sampled = zeros(n_time_steps, 1);
    moved = 0;
end

x_trajectory = x_start +  cumsum(delta_hori_sampled);


collided = 0;
rewarded = 0;
%%% touch screen?
idx_touch_edge = find(abs(x_trajectory) >= EXP_CONFIG.SCREEN_WIDTH_CM / 2, 1, 'first');
if ~isempty(idx_touch_edge)
    %%% collided on the screen edge
    collided = 1;
    x_trajectory = x_trajectory(1:idx_touch_edge);
end
%%% rewarded?
end_x = x_trajectory(end);
if end_x >= EXP_CONFIG.tolerant_space_cm(1) & end_x <= EXP_CONFIG.tolerant_space_cm(2)
   rewarded = 1;
end

end

function [x_trajectory, rewarded, collided, delta_hori_sampled] = simulate_trajectories_fixZero(x_start, delta_x_original, dist_delta_hori, EXP_CONFIG)

idx_move = abs(delta_x_original) > 0;
delta_hori_sampled =  zeros(size(delta_x_original));
delta_hori_sampled(idx_move)  = randsample(dist_delta_hori, sum(idx_move));


x_trajectory = x_start +  cumsum(delta_hori_sampled);

collided = 0;
rewarded = 0;
%%% touch screen?
idx_touch_edge = find(abs(x_trajectory) >= EXP_CONFIG.SCREEN_WIDTH_CM / 2, 1, 'first');
if ~isempty(idx_touch_edge)
    %%% collided on the screen edge
    collided = 1;
    x_trajectory = x_trajectory(1:idx_touch_edge);
end
%%% rewarded?
end_x = x_trajectory(end);
if end_x >= EXP_CONFIG.tolerant_space_cm(1) & end_x <= EXP_CONFIG.tolerant_space_cm(2)
   rewarded = 1;
end

end