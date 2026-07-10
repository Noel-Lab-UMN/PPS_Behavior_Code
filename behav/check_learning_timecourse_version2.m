clear all
clc
close all
%%%% This script loads preprocessed data for each animal and plots the
%%%% learning trajectores of some behavioral features:
%%%% (1) percent correct relative to chance level
%%%% (2) MAD
%%%% (3) percent correct conditioned on initial left/right. any bias?
global PPS_global
generate_PPS_global();
%%
subjectCode = 'GD_1_red';
save_folder = fullfile('../../results/behav/pps_processed',subjectCode);
fig_save_folder = fullfile('../../figures/behav/subject_timecourses/', subjectCode);
if ~isfolder(fig_save_folder)
    mkdir(fig_save_folder);
end



eval(sprintf('session_list = PPS_global.%s.session_list.new_params;',subjectCode));

behav_results_summary = util_pps.load_behav_results_summary(save_folder, subjectCode, session_list);
plotOptions.session_list = session_list;
%% plot time course of reward with chance levels from permutation
figure
colors_list = get(groot, 'defaultAxesColorOrder');
%%% percentage of reward
subplot(2,4,1);hold on 
plotOptions.errorbar_option = 'none';
plotOptions.fieldname_avg = 'p_moved';
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);

% fieldname = 'p_reward_real';
% h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, fieldname, session_list, errorbar_option);

plotOptions.fieldname_avg = 'p_reward_moved';
h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
set(gca,'fontsize',18);
ylabel('Percent rewarded')
legend(h,'Moved','Rewarded|Moved')



%%%  z-score relative to the chance level
subplot(2,4,1+4);hold on
plotOptions.fieldname_avg = 'zscore_p_reward';
plotOptions.errorbar_option = 'none';
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
set(h(1),'color', 'black');
title(subjectCode,'Interpreter','none')

plotOptions.fieldname_avg = 'zscore_p_reward_moved';
h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
nSession = numel(session_list);
line([0.5, nSession+0.5], [1.645, 1.645],'linestyle','--','color','black')
set(h(2),'color', 'blue');
ylabel('Z-score')
legend('All trials','Moved trials')
sgtitle(subjectCode,'Interpreter','none','fontweight','bold','fontsize',20)
%%% plot MAD with chance levels from permutation



subplot(2,4,2)
plotOptions.fieldname_avg = 'target_distance_moved';
plotOptions.errorbar_option = 'sem';
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
hold on


plotOptions.fieldname_avg = 'target_distance_rewarded';
plotOptions.errorbar_option = 'sem';
h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
set(gca,'fontsize',18);
legend('Moved','Rewarded')
ylabel('MAD to center')



subplot(2,4,2+4); hold on
plotOptions.fieldname_avg = 'zscore_target_distance_moved';
plotOptions.errorbar_option = 'none';
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
%set(h(1),'color', [0.5,0.5,0.5]);

plotOptions.fieldname_avg   = 'zscore_target_distance_rewarded';
plotOptions.errorbar_option = 'none';
h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);

nSession = numel(session_list);
line([0.5, nSession+0.5], [-1.645, -1.645],'linestyle','--','color','black')

%set(h(2),'color', [0.1,0.1,0.1]);
ylabel('Z-score')
legend(h,'Moved','Rewarded')


subplot(2,4,3); hold on
plotOptions.fieldname_avg = 'corr_trajectory_moved';
plotOptions.errorbar_option = 'sem';
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
%set(h(1),'color', [0.5,0.5,0.5]);

% plotOptions.fieldname_avg   = 'corr_trajectory_rewarded';
% plotOptions.errorbar_option = 'sem';
% h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
legend('Moved');
ylabel('Corr. trajectories')


subplot(2,4,3+4); hold on
plotOptions.fieldname_avg = 'corr_trajectory_rewarded';
plotOptions.errorbar_option = 'sem';
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
set(h(1),'color',colors_list(2,:));
legend('Rewarded');
ylabel('Corr. trajectories')

subplot(2,4,4); hold on
plotOptions.fieldname_avg = 'GD_ratio_moved';
plotOptions.errorbar_option = 'sem';
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
%set(h(1),'color', [0.5,0.5,0.5]);

plotOptions.fieldname_avg   = 'GD_ratio_rewarded';
plotOptions.errorbar_option = 'sem';
h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
ylabel('Goal-directed Ratio')
legend('Moved','Rewarded')


subplot(2,4,4+4); hold on
plotOptions.fieldname_avg = 'extra_movement_moved';
plotOptions.errorbar_option = 'sem';
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
%set(h(1),'color', [0.5,0.5,0.5]);

plotOptions.fieldname_avg   = 'extra_movement_rewarded';
plotOptions.errorbar_option = 'sem';
h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
ylabel('Extra movement ratio')
legend('Moved','Rewarded')

sgtitle(subjectCode,'Interpreter','none','fontweight','bold','fontsize',20)



%%



