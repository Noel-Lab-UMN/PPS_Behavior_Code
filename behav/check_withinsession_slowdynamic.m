clear all
clc
close all
%%%%%% This script checks within-session flutuation of
%%%%%% motivation/engagment level/performance, and try to identify "engaged_period"
global PPS_global
generate_PPS_global();
%%
subjectCode = 'GD_2_blue';
save_folder = fullfile('../../results/behav/pps_processed',subjectCode);

eval(sprintf('session_list = PPS_global.%s.session_list.all;',subjectCode));

sessionStr = '20260408';

load(fullfile(save_folder, sprintf('behav_data_PPS_%s_%s',subjectCode, sessionStr)));

%%
% p_reward, p_reward_moved, sum_abs_moved, corr_ideal_trajectory
% [sum_abs_moved, corr_trajectory] =
nTrial = numel(behav_data);

is_reward = [behav_data(:).rewarded];
is_moved = [behav_data(:).is_moved];
sum_abs_movement = [behav_data(:).sum_abs_wheel_movement_cm];

doPlot = false;
corr_trajectory = util_pps.compute_trajectory_correlation(behav_data, [1:nTrial], doPlot);

corr_trajectory(isnan(corr_trajectory)) = 0;
win_size = 50; % 20 balls
step_size = 5;

nStep = ceil((nTrial - win_size) / step_size);

[p_reward_step, p_reward_moved_step, sum_abs_movement_step, corr_trajectory_step] = deal(zeros(nStep, 1));

[idx_start,idx_end] = deal(zeros(nStep,1));

idx_keep = find([behav_data(:).reached_bottom] & [behav_data(:).is_moved]);
[~,~,x_ideal_all, x_empirical_all] = util_pps.compute_trajectory_correlation(behav_data, idx_keep, doPlot);
[corr_long_trajectory_step, diff_long_trajectory_step] = deal(zeros(nStep,1));
for n = 1:nStep
    idx_start(n) = (n-1) * step_size + 1;
    if n < nStep
        idx_end(n) = (n-1) * step_size + win_size;
    else
        idx_end(n) = nTrial;
    end
    idx = [idx_start(n):idx_end(n)];
    p_reward_step(n) = sum(is_reward(idx)) / numel(idx);
    p_reward_moved_step(n) = sum(is_reward(idx)) / sum(is_moved(idx));

    sum_abs_movement_step(n) = mean(sum_abs_movement(idx));

    corr_trajectory_step(n) = mean(corr_trajectory(idx));

    idx_segment = ismember(idx_keep, idx);
    if any(idx_segment)
        x_ideal_segment         = cat(1,x_ideal_all{idx_segment});
        x_empirical_segment     = cat(1,x_empirical_all{idx_segment});
    
        corr_long_trajectory_step(n) = corr(x_ideal_segment, x_empirical_segment);
        diff_long_trajectory_step(n) = mean(abs(x_ideal_segment - x_empirical_segment));
    else
        corr_long_trajectory_step(n) = 0;
        diff_long_trajectory_step(n) = NaN;
    end
        
end




%%
figure;
subplot(3,1,1)
plot(idx_start, p_reward_step); hold on; plot(idx_start, p_reward_moved_step);
subplot(3,1,2)
plot(idx_start, sum_abs_movement_step);
subplot(3,1,3)
plot(idx_start,  corr_trajectory_step);

figure
plot(cat(1, x_ideal_all{:}));hold on
plot(cat(1, x_empirical_all{:}))
%%
sum_abs_movement = sum_abs_movement_step;
move = sum_abs_movement_step;

params = util_pps.fit_engagement_hmm_EM(move, 100);

engagedProb = params.gamma(:,2);
engagedState = engagedProb > 0.5;

figure;
plot(move, 'k'); hold on;
plot(find(engagedState), move(engagedState), 'ro');
xlabel('Trial');
ylabel('Wheel movement');
legend('Movement', 'Engaged');