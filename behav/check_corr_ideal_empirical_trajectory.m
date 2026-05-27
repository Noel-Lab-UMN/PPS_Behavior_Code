clear all
close all
clc
global PPS_global
generate_PPS_global()
%%
doThis = 1;
if doThis
    subjectCode = 'LSZ_practice_5_violet';
    
    doPlot = false;
    %exp_date    = '20260408';
    eval(sprintf('session_list = PPS_global.%s.session_list.initial;',subjectCode));
    
    save_folder = fullfile('../../results/behav/pps_processed/', subjectCode);
    
    nSession = numel(session_list);
    [r_single_moved, r_avg_moved, r_sem_moved] = deal(zeros(nSession, 1));
    [r_single_rewarded, r_avg_rewarded, r_sem_rewarded] = deal(zeros(nSession, 1));
    for i_session = 1:nSession
        exp_date = session_list{i_session};
        load(fullfile(save_folder, sprintf('behav_data_PPS_%s_%s',subjectCode,exp_date)));
    
    
        idx = find([behav_data(:).reached_bottom] & [behav_data(:).is_moved]);
        [r_all, r_single_moved(i_session)] = compute_trajectory_correlation(behav_data, idx, doPlot);
        
        r_avg_moved(i_session) = mean(r_all);
        r_sem_moved(i_session) = std(r_all) / sqrt(numel(r_all));
       
        
        idx = find([behav_data(:).rewarded]);
    
        [r_all, r_single_rewarded(i_session)] = compute_trajectory_correlation(behav_data, idx, doPlot);
        
        r_avg_rewarded(i_session) = mean(r_all);
        r_sem_rewarded(i_session) = std(r_all) / sqrt(numel(r_all));
     
       
    end
    %%%%
    figure;
    %subplot(2,1,1); hold on
    errorbar(r_avg_moved, r_sem_moved);
    box off
    xlabel('Session index');
    ylabel('r-individual')
    title(subjectCode,'Interpreter','none')
    set(gca,'fontsize',18)
end
%errorbar(r_avg_rewarded, r_sem_rewarded);

% subplot(2,1,2)
% plot(r_single_moved, '-o'); hold on
% plot(r_single_rewarded, '-o');
%% 
doThis = 1;
if doThis
    subjectCode = 'LSZ_practice_5_violet';
    
    save_folder = fullfile('../../results/behav/pps_processed/', subjectCode);

    doPlot = true;
    exp_date    = '20260310';
    load(fullfile(save_folder, sprintf('behav_data_PPS_%s_%s',subjectCode,exp_date)));


    idx = find([behav_data(:).reached_bottom] & [behav_data(:).is_moved]);
    [r_all, r_single_moved] = compute_trajectory_correlation(behav_data, idx, doPlot);
end
sgtitle(sprintf('%s, %s',subjectCode,  exp_date),'interpreter','none','fontsize',18,'fontweight','bold')
%%



