clear all
clc
close all
%%%% This script loads preprocessed data for each animal and plots the
%%%% learning trajectores of some behavioral features:
%%% (1) percent of correct (2) percent of movement (3) correlation between
%%% initial position and delta_x
%%
subjectCode = 'LSZ_practice_5_violet';
save_folder = fullfile('../../results/behav/pps_processed',subjectCode);
fig_save_folder = fullfile('../../figures/behav/subject_timecourses/', subjectCode);
if ~isfolder(fig_save_folder)
    mkdir(fig_save_folder);
end
fig_save_name_percent       = fullfile(fig_save_folder,sprintf('%s_timecourse_percentages.png', subjectCode));
fig_save_name_movement      = fullfile(fig_save_folder,sprintf('%s_timecourse_movement.png', subjectCode));
fig_save_name_corr_position = fullfile(fig_save_folder,sprintf('%s_timecourse_corrposition.png', subjectCode));
global PPS_global
generate_PPS_global();

eval(sprintf('session_list = PPS_global.%s.session_list;',subjectCode));
behav_results_summary = struct();
for n = 1:numel(session_list)
    load(fullfile(save_folder,sprintf('behav_stats_PPS_%s_%s',subjectCode,session_list{n})));

    behav_results_summary(n).subjectCode = subjectCode;
    behav_results_summary(n).sessionStr = session_list{n};

    %%%%% probabilities across the whole session
    behav_results_summary(n).chance_level_null = 100 * EXP_CONFIG(1).chance_level_null;
    behav_results_summary(n).chance_level_random = 100 * EXP_CONFIG(1).chance_level_random;

    behav_results_summary(n).percent_good   = behav_results.percent_pps.p_good;
    behav_results_summary(n).percent_reward = behav_results.percent_pps.p_reward;

    behav_results_summary(n).percent_reward_initialIN = behav_results.percent_pps.p_reward_initialIN;
    behav_results_summary(n).percent_reward_initialOut = behav_results.percent_pps.p_reward_initialOUT;

    
    behav_results_summary(n).reward_out_in_ratio = behav_results.percent_pps.p_initialOUT_reward ...
                                                    / behav_results.percent_pps.p_initialIN_reward;
                                                   
    p_initialIN = behav_results.percent_pps.p_intialIN;
    behav_results_summary(n).reward_out_in_ratio_normalized =  behav_results.percent_pps.p_initialOUT_reward ...
                                                    / (1 + behav_results.percent_pps.p_initialIN_reward) /...
                                                    ( (100 - p_initialIN) / (1 + p_initialIN) );

    behav_results_summary(n).reward_rate        = behav_results.percent_pps.reward_rate; 

    %%%%% prbabilities of each time bin
    behav_results_summary(n).percent_good_timebin   = [behav_results.percent_pps_timebin(:).p_good];
    behav_results_summary(n).percent_reward_timebin = [behav_results.percent_pps_timebin(:).p_reward];

    behav_results_summary(n).percent_reward_initialIN_timebin = [behav_results.percent_pps_timebin(:).p_reward_initialIN];
    behav_results_summary(n).percent_reward_initialOut_timebin = [behav_results.percent_pps_timebin(:).p_reward_initialOUT];

   behav_results_summary(n).reward_out_in_ratio_timebin = [behav_results.percent_pps_timebin(:).p_initialOUT_reward] ...
                                                    ./ (1 + [behav_results.percent_pps_timebin(:).p_initialIN_reward]);
                                                   
    p_initialIN = [behav_results.percent_pps_timebin(:).p_intialIN];
    behav_results_summary(n).reward_out_in_ratio_normalized_timebin =  behav_results_summary(n).reward_out_in_ratio_timebin ./...
                                                    ( (100 - p_initialIN) / p_initialIN );


    behav_results_summary(n).reward_rate_timebin    = [behav_results.percent_pps_timebin(:).reward_rate]; 
    

    behav_results_summary(n).percent_goal_directed_all = ...
                        behav_results.percent_move.percent_goal_directed_all;
    behav_results_summary(n).percent_static_all = ...
                        behav_results.percent_move.percent_static_all;

    behav_results_summary(n).percent_goal_directed_initialIN = ...
                        behav_results.percent_move.percent_goal_directed_initialIN;
    behav_results_summary(n).percent_static_initialIN = ...
                        behav_results.percent_move.percent_static_initialIN;

    behav_results_summary(n).percent_goal_directed_initialOUT = ...
                        behav_results.percent_move.percent_goal_directed_initialOUT;
    behav_results_summary(n).percent_static_initialOUT = ...
                        behav_results.percent_move.percent_static_initialOUT;

    behav_results_summary(n).corr_sum_delta_good_r = behav_results.corr_initial_delta.sum_delta_good_r;
    behav_results_summary(n).corr_sum_delta_good_p = behav_results.corr_initial_delta.sum_delta_good_p;

    behav_results_summary(n).corr_sum_abs_delta_good_r = behav_results.corr_initial_delta.sum_abs_delta_good_r;
    behav_results_summary(n).corr_sum_abs_delta_good_p = behav_results.corr_initial_delta.sum_abs_delta_good_p;


    behav_results_summary(n).corr_sum_delta_rewarded_r = behav_results.corr_initial_delta.sum_delta_rewarded_r;
    behav_results_summary(n).corr_sum_delta_rewarded_p = behav_results.corr_initial_delta.sum_delta_rewarded_p;

    behav_results_summary(n).corr_sum_abs_delta_rewarded_r = behav_results.corr_initial_delta.sum_abs_delta_rewarded_r;
    behav_results_summary(n).corr_sum_abs_delta_rewarded_p = behav_results.corr_initial_delta.sum_abs_delta_rewarded_p;

end
%% time course of probabilities
nSession =  numel(session_list);
figure
set(gcf,'Units','inches','Position', [0,0,8,12])
subplot(3,1,1); hold on
%%% percent_reward_time bin
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, 'percent_reward_timebin', session_list);
ylabel('Percent rewarded');
yyaxis right
h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, 'percent_reward_initialOut_timebin', session_list);
chance_level_null   = [behav_results_summary(:).chance_level_null];
h(3) = plot([1:nSession], chance_level_null,'linewidth',1.5,'linestyle','--','color','black');
legend(h, 'All trials','Initial Out trials','Null level')


%%%% reward rate time bin
subplot(3,1,2)
fig_pps.plot_sessions_timecourse(behav_results_summary, 'reward_rate_timebin', session_list);
ylabel('Reward rate (uL/s)')

subplot(3,1,3); hold on
%%%% ratio time bin
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, 'reward_out_in_ratio_timebin', session_list);
ylabel('Ratio')
%%%% normalized ratio time bin
yyaxis right
h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, 'reward_out_in_ratio_normalized_timebin', session_list);
legend(h, 'Raw','Normalized')
title('Initial Out/In ratio (rewarded trials)')

sgtitle(subjectCode,'interpreter','none','fontsize',18,'fontweight','bold')

saveas(gcf, fig_save_name_percent)
close
%% time course of percent move
figure
set(gcf,'Units','inches','Position', [0,0,8,12])
subplot(3,1,1); hold on
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, 'percent_goal_directed_all', session_list);
yyaxis right
h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, 'percent_static_all', session_list);
title('All good trials')
legend('Goal directed','Static')

subplot(3,1,2); hold on
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, 'percent_goal_directed_initialIN', session_list);
yyaxis right
h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, 'percent_static_initialIN', session_list);
title('InitialIN good trials')
legend('Goal directed','Static')


subplot(3,1,3); hold on
h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, 'percent_goal_directed_initialOUT', session_list);
yyaxis right
h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, 'percent_static_initialOUT', session_list);
title('InitialOUT good trials')
legend('Goal directed','Static');

sgtitle(subjectCode,'interpreter','none','fontsize',18,'fontweight','bold')
saveas(gcf, fig_save_name_movement)
close
%% time course of correlations
figure
set(gcf,'Units','inches','Position', [0,0,8,12])
subplot(2,1,1); hold on
%%% corr_sum_delta_good
%%% corr_sum_delta_rewarded
h(1) = plot_corr_timecourse(behav_results_summary, 'corr_sum_delta_good', session_list);
h(2) = plot_corr_timecourse(behav_results_summary, 'corr_sum_delta_rewarded', session_list);
legend(h(1:2),'Good trials','Rewarded trials');
ylabel('Correlation coefficients')
title('Corr. (initial difference, sum-delta-x)')
subplot(2,1,2); hold on
%%% corr_sum_abs_delta_good
%%% corr_sum_abs_delta_rewarded
h(1) = plot_corr_timecourse(behav_results_summary, 'corr_sum_abs_delta_good', session_list);
h(2) = plot_corr_timecourse(behav_results_summary, 'corr_sum_abs_delta_rewarded', session_list);
legend(h(1:2),'Good trials','Rewarded trials');
ylabel('Correlation coefficients')
title('Corr. (initial distance, sum-abs-delta-x)')

sgtitle(subjectCode,'interpreter','none','fontsize',18,'fontweight','bold')
saveas(gcf, fig_save_name_corr_position)
close
%% helper functions
function h = plot_corr_timecourse(behav_results_summary, fieldname, session_list)
nSession = numel(session_list);
eval(sprintf('r_all = [behav_results_summary(:).%s_r];',  fieldname));
eval(sprintf('p_all = [behav_results_summary(:).%s_p];',  fieldname));

h = plot([1:nSession], r_all, '-o','LineWidth',2);
for n = 1:numel(p_all)
    text(n, r_all(n) + 0.01, util_pps.p2star(p_all(n)),'fontsize',16);
end
set(gca,'xtick',[1:nSession],'xticklabels',session_list)
set(gca,'fontsize',16);
box off
end
