clear all
clc
close all

%% any correlation between activity level and p_reward and MAD_center?
subjectCode = 'LSZ_practice_3_green'; save_folder = fullfile('../../results/behav/pps_processed',subjectCode);
eval(sprintf('session_list = PPS_global.%s.session_list.two_centers;',subjectCode));
behav_results_summary_green = load_behav_results_summary(save_folder, subjectCode, session_list);

subjectCode = 'LSZ_practice_4_orange'; save_folder = fullfile('../../results/behav/pps_processed',subjectCode);
eval(sprintf('session_list = PPS_global.%s.session_list.two_centers;',subjectCode));
behav_results_summary_orange = load_behav_results_summary(save_folder, subjectCode, session_list);

subjectCode = 'LSZ_practice_5_violet'; save_folder = fullfile('../../results/behav/pps_processed',subjectCode);
eval(sprintf('session_list = PPS_global.%s.session_list.two_centers;',subjectCode));
behav_results_summary_violet = load_behav_results_summary(save_folder, subjectCode, session_list);

subjectCode = 'GD_1_red'; save_folder = fullfile('../../results/behav/pps_processed',subjectCode);
eval(sprintf('session_list = PPS_global.%s.session_list.all;',subjectCode));
behav_results_summary_gd1_red = load_behav_results_summary(save_folder, subjectCode, session_list);

subjectCode = 'GD_2_blue'; save_folder = fullfile('../../results/behav/pps_processed',subjectCode);
eval(sprintf('session_list = PPS_global.%s.session_list.all;',subjectCode));
behav_results_summary_gd2_blue = load_behav_results_summary(save_folder, subjectCode, session_list);

p_reward_green      = [behav_results_summary_green(:).p_reward_real];
p_reward_orange     = [behav_results_summary_orange(:).p_reward_real];
p_reward_violet     = [behav_results_summary_violet(:).p_reward_real];
p_reward_red        = [behav_results_summary_gd1_red(:).p_reward_real];
p_reward_blue       = [behav_results_summary_gd2_blue(:).p_reward_real];

delta_x_green       = [behav_results_summary_green(:).sum_abs_delta_hori_median];
delta_x_orange      = [behav_results_summary_orange(:).sum_abs_delta_hori_median];
delta_x_violet      = [behav_results_summary_violet(:).sum_abs_delta_hori_median];
delta_x_red         = [behav_results_summary_gd1_red(:).sum_abs_delta_hori_median];
delta_x_blue        = [behav_results_summary_gd2_blue(:).sum_abs_delta_hori_median];

MAD_reward_green    = [behav_results_summary_green(:).MAD_reward_real];
MAD_reward_orange   = [behav_results_summary_orange(:).MAD_reward_real];
MAD_reward_violet   = [behav_results_summary_violet(:).MAD_reward_real];
MAD_reward_red      = [behav_results_summary_gd1_red(:).MAD_reward_real];
MAD_reward_blue     = [behav_results_summary_gd2_blue(:).MAD_reward_real];

figure; 
subplot(1,3,1); hold on;
plot(delta_x_green, p_reward_green, '.', 'markersize',20, 'color','green');
plot(delta_x_orange, p_reward_orange, '.','markersize',20,'color', [1.0, 0.5, 0.0]);
plot(delta_x_violet, p_reward_violet,'.', 'markersize',20, 'color',[144,133,167] / 255)
plot(delta_x_red, p_reward_red,'.', 'markersize',20, 'color','red');
plot(delta_x_blue, p_reward_blue,'.', 'markersize',20, 'color','blue');
set(gca, 'fontsize',20);
xlabel('Median(sum-abs-delta-x)'); ylabel('Percentage rewarded');
legend('Green','Orange','Violet','GD1-Red','GD2-Blue')

subplot(1,3,2); hold on;
plot(p_reward_green, MAD_reward_green, '.', 'markersize',20, 'color','green');
plot(p_reward_orange, MAD_reward_orange, '.','markersize',20,'color', [1.0, 0.5, 0.0]);
plot(p_reward_violet, MAD_reward_violet,'.', 'markersize',20, 'color',[144,133,167] / 255)
plot(p_reward_red, MAD_reward_red, '.', 'markersize',20, 'color', 'red')
plot(p_reward_blue, MAD_reward_blue, '.', 'markersize',20, 'color', 'blue')
set(gca, 'fontsize',20);
xlabel('Percentage rewarded'); ylabel('MAD to center')
legend('Green','Orange','Violet','GD1-Red','GD2-Blue')

subplot(1,3,3); hold on;
plot(delta_x_green, MAD_reward_green, '.', 'markersize',20, 'color','green');
plot(delta_x_orange, MAD_reward_orange, '.','markersize',20,'color', [1.0, 0.5, 0.0]);
plot(delta_x_violet, MAD_reward_violet,'.', 'markersize',20, 'color',[144,133,167] / 255)
plot(delta_x_red, MAD_reward_red, '.', 'markersize',20, 'color', 'red');
plot(delta_x_blue, MAD_reward_blue, '.', 'markersize',20, 'color', 'blue');
set(gca, 'fontsize',20);
xlabel('Median(sum-abs-delta-x)'); ylabel('MAD to center')
legend('Green','Orange','Violet','GD1-Red','GD2-Blue')