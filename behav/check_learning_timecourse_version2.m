clear all
clc
close all
%%%% This script loads preprocessed data for each animal and plots the
%%%% learning trajectores of some behavioral features:
%%%% (1) percent correct relative to chance level
%%%% (2) MAD
%%%% (3) percent correct conditioned on initial left/right. any bias?
%%
subjectCode = 'GD_3_pink';
save_folder = fullfile('../../results/behav/pps_processed',subjectCode);
fig_save_folder = fullfile('../../figures/behav/subject_timecourses/', subjectCode);
if ~isfolder(fig_save_folder)
    mkdir(fig_save_folder);
end

global PPS_global
generate_PPS_global();

eval(sprintf('session_list = PPS_global.%s.session_list.initial;',subjectCode));

behav_results_summary = util_pps.load_behav_results_summary(save_folder, subjectCode, session_list);

%% plot time course of reward with chance levels from permutation
figure
%%% percentage of reward
subplot(2,2,1);hold on 
errorbar_option = 'none';

fieldname = 'p_moved';
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, fieldname, session_list, errorbar_option);

fieldname = 'p_reward_real';
h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, fieldname, session_list, errorbar_option);

fieldname = 'p_reward_moved';
h(3) = fig_pps.plot_sessions_timecourse(behav_results_summary, fieldname, session_list, errorbar_option);

% fieldname = 'p_reward_permute';
% errorbar_option = 'CI_68';
% h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, fieldname, session_list, errorbar_option);
% 
% fieldname = 'p_reward_permute_sign';
% errorbar_option = 'CI_68';
% h(3) = fig_pps.plot_sessions_timecourse(behav_results_summary, fieldname, session_list, errorbar_option);

%set(h(2),'color', [0.1,0.1,0.1]);
set(gca,'fontsize',18);
ylabel('Percent rewarded')
legend('Moved','Rewarded','Rewarded-Moved')
%%%  z-score relative to the chance level
subplot(2,2,3);hold on
fieldname = 'zscore_reward';
errorbar_option = 'none';
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, fieldname, session_list, errorbar_option);
set(h(1),'color', [0.5,0.5,0.5]);
title(subjectCode,'Interpreter','none')
fieldname = 'zscore_reward_moved';
errorbar_option = 'none';
h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, fieldname, session_list, errorbar_option);
set(h(2),'color', [0.1,0.1,0.1]);
ylabel('Z-score')
legend('All trials','Moved trials')
sgtitle(subjectCode,'Interpreter','none','fontweight','bold','fontsize',20)
%%% plot MAD with chance levels from permutation

subplot(2,2,2)
fieldname = 'MAD_reward_real';
errorbar_option = 'none';
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, fieldname, session_list, errorbar_option);

% hold on
% fieldname = 'MAD_reward_permute';
% errorbar_option = 'CI_68';
% h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, fieldname, session_list, errorbar_option);
% 
% fieldname = 'MAD_reward_permute_sign';
% errorbar_option = 'CI_68';
% h(3) = fig_pps.plot_sessions_timecourse(behav_results_summary, fieldname, session_list, errorbar_option);
% set(h(3),'color', [0.1,0.1,0.1]);
set(gca,'fontsize',18);
legend('Reward')
ylabel('MAD to center')

subplot(2,2,4); hold on
fieldname = 'zscore_MAD';
errorbar_option = 'none';
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, fieldname, session_list, errorbar_option);
set(h(1),'color', [0.5,0.5,0.5]);

fieldname = 'zscore_MAD_moved';
errorbar_option = 'none';
h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, fieldname, session_list, errorbar_option);

set(h(2),'color', [0.1,0.1,0.1]);
ylabel('Z-score')
legend(h,'Reward','Reward moved')

sgtitle(subjectCode,'Interpreter','none','fontweight','bold','fontsize',20)



%%



