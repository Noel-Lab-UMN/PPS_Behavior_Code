clear all
clc
close all
%%%% How performance changed when animal moved to different stages? i.e.
%%%% add more parameters, move to recording rig
global PPS_global
generate_PPS_global();

%%
figure_folder_meta = '/Users/liushizhao/projects_local/PPS/figures/behav/subject_timecourses';
subjectCode = 'GD_5_grey';
figure_folder = fullfile(figure_folder_meta, subjectCode);
figure_save_name = fullfile(figure_folder,sprintf('timecourse_by_stage_%s.png',subjectCode));


if ~isfolder(figure_folder)
    mkdir(figure_folder);
end

data_folder = fullfile('../../results/behav/pps_processed',subjectCode);

eval(sprintf('session_list = PPS_global.%s.session_list;',subjectCode));
session_list_all = session_list.all;
session_list_newparams = session_list.new_params;
if isfield(session_list, 'recording_rig')
    session_list_recording_rig = session_list.recording_rig;
else
    session_list_recording_rig = [];
end
%%
behav_results_summary = util_pps.load_behav_results_summary(data_folder, subjectCode, session_list_all);

%%
figure;
set(gcf,'units','normalized','position',[0,0,1,1]);
plot_field_list = {'nRewarded';'p_moved'; 'p_reward_moved';'zscore_p_reward_moved';'corr_trajectory_rewarded';'target_distance_rewarded'};
y_lim_list = {[0, 400],[0, 1], [0,1], [0, 12], [0.5, 1], [3, 8]};
for k = 1:numel(plot_field_list)
    subplot(3,2,k); hold on
    plot_field = plot_field_list{k}; % 'p_moved', 'p_reward_moved','zscore_p_reward_moved','nRewarded';
    
    colors_list = get(groot, 'defaultAxesColorOrder');
    plotOptions.errorbar_option = 'none';
    plotOptions.fieldname_avg = plot_field;
    plotOptions.doFitting       = false;
    plotOptions.session_list = session_list_all; % all as black
    plotOptions.doXticklabel = true;
    h(1) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
    set(h(1),'color', 'black','Markersize',10);
    
    plotOptions.session_list = session_list_newparams; % new params
    plotOptions.doXticklabel = false;
    h(2) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
    set(h(2),'LineStyle', 'none','color', 'blue','Markersize',10);
    
    if ~isempty(session_list_recording_rig)
        plotOptions.session_list = session_list_recording_rig; % recording rig
        h(3) = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
        set(h(3),'LineStyle', 'none' ,'color', 'blue','MarkerFaceColor', 'red','Markersize',10);
        
    end
    
    ylabel(plot_field,'Interpreter','none');
    ylim(y_lim_list{k});
    if ~isempty(session_list_recording_rig)
        legend('All sessions','Generalization','Recording rig','Location','northwest');
    else
        legend('All sessions','Generalization','Location','northwest');
    end
end
sgtitle(subjectCode,'Interpreter','none','fontweight','bold','fontsize',18);

saveas(gcf, figure_save_name);
close gcf
%%
% doThis = 1;
% %%%% This part checks distribution of target ending position and compares
% %%%% the behavioral rig and the recording rig. 
% %%%% I do this because the target ending position in recording rig looks
% %%%% a bit werid when eyeballing it. i.e. for some trials, I felt the
% %%%% animals should get rewarded, but the did not.
% 
% %%%%% One thing to check is whether the animal is really at the center. May
% if doThis
% 
% 
% 
% end