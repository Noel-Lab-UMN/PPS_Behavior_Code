clear all
clc
close all
global PPS_global
generate_PPS_global();
%%% Do 1-4 for both LSZ_practice_5_violet and GD_1_red
%%% Show z-score of all animals?

figure_folder = '../../figures/scene_report';
data_folder = '../../results/behav/pps_processed';

colors_list = get(groot, 'defaultAxesColorOrder');
%% 1. Time course of p_reward &  2. Time course of z_score 
doThis = 1;
if doThis
    subjectCode = 'GD_1_red';
    %data_folder = fullfile('../../results/behav/pps_processed',subjectCode);
    
    switch subjectCode
        case 'LSZ_practice_5_violet'
            eval(sprintf('session_list = PPS_global.%s.session_list.initial;',subjectCode));
            sgtitle_str = 'Example animal 1';
           
        case 'GD_1_red'
            eval(sprintf('session_list = PPS_global.%s.session_list.initial;',subjectCode));
            sgtitle_str = 'Example animal 2';
    end
    save_name = fullfile(figure_folder,sprintf('timecourses_%s', subjectCode));
    behav_results_summary = util_pps.load_behav_results_summary(fullfile(data_folder, subjectCode), subjectCode, session_list);
    plotOptions.session_list = session_list;
    
    figure;
    set(gcf,'Units','inches','position',[0, 0,8,8]);
    subplot(2,1,1)
    plotOptions.fieldname_avg = 'p_reward_moved';
    plotOptions.errorbar_option = 'none';
    h = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
    set(h,'color',colors_list(1,:));
    ylabel('P(reward|moved)');xlabel('Date')
    
    subplot(2,1,2)
    plotOptions.fieldname_avg = 'zscore_p_reward_moved';
    plotOptions.errorbar_option = 'none';
    h = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
    set(h,'color', colors_list(2,:));
    ylabel('Z-score');xlabel('Date')
    
    
    sgtitle(sgtitle_str,'fontweight','bold','fontsize',20)
    print(save_name, '-dsvg');
    close gcf
end
%% 3. Distribution to illustrate z-score, early and late training
doThis = 0;
if doThis
subjectCode = 'LSZ_practice_5_violet';
switch subjectCode
    case 'LSZ_practice_5_violet'
        dateStr_early   = '20260309';
        dateStr_late    = '20260408';
        
    case 'GD_1_red'
        dateStr_early   = '20260401';
        dateStr_late    = '20260430';
end

dateStr_list    = {dateStr_early; dateStr_late};
titleStr_list   = {'Early-training example session';'Late-training example session'};
save_name_list  = {sprintf('zscore_dist_early_%s',subjectCode);sprintf('zscore_dist_late_%s',subjectCode)};
for i = 1:2
    figure;
    set(gcf,'Units','inches','position',[0, 0,5,4]);
    
    load(fullfile(fullfile(data_folder, subjectCode), sprintf('behav_stats_PPS_%s_%s',subjectCode, dateStr_list{i})));
    
    p_null = behav_results.permute_chance_level.p_reward_permute_moved;
    h = histogram(p_null,'FaceColor',[0.5, 0.5, 0.5]); hold on
    p_real = behav_results.percent_pps.p_reward_moved / 100;
    line([p_real, p_real],[0, max(h.Values)], 'color','red','linewidth', 2);
    z_score = (p_real -  mean(p_null)) / std(p_null);

    box off
    set(gca, 'fontsize', 18);
    
    xlabel('P(reward|moved)')
    legend('Null','Real','Orientation','horizontal','Location','north')
    title({titleStr_list{i}; sprintf('Z-score = %.2f', z_score)},'fontsize',14);
    ylim([0, 1.3 * max(h.Values)])
   


    save_name = fullfile(figure_folder, save_name_list{i});
    print(save_name, '-dsvg');
    close gcf
end
end
%% 4. Example trajectories
doThis = 0;
if doThis
subjectCode = 'GD_1_red';
switch subjectCode
    case 'LSZ_practice_5_violet'
        dateStr_early   = '20260309';
        dateStr_late    = '20260408';
        init_x_list     = [-12, 12]; 
        
    case 'GD_1_red'
        dateStr_early   = '20260401';
        dateStr_late    = '20260430';
        init_x_list     = [-15, 15];
end

dateStr_list    = {dateStr_early; dateStr_late};
titleStr_list   = {'Early-training example session';'Late-training example session'};
save_name_list  = {sprintf('trajectories_early_%s',subjectCode);sprintf('trajectories_late_%s',subjectCode)};
for i = 1:2
    figure;
    set(gcf,'Units','inches','position',[0, 0,5,4]);
    date_str    = dateStr_list{i};
    % data_folder = sprintf('../../results/behav/pps_processed/%s',subjectCode);
    load(fullfile(fullfile(data_folder, subjectCode), sprintf('behav_data_PPS_%s_%s',subjectCode,date_str)));
    
    idx_moved       = [behav_data(:).is_moved];
    idx_rewarded    = [behav_data(:).rewarded];
    idx_reach_bottom = [behav_data(:).reached_bottom];
    init_x           = round([behav_data(:).initial_x_rel_cm]);
    % init_x_list     = unique(init_x);
    % nTrial_init_x   = arrayfun(@(n) sum(init_x == init_x_list(n)), [1:numel(init_x_list)]); 
    % init_x_list(nTrial_init_x == 1) = [];
    
    plotOptions.titleStr = '';
    plotOptions.color = 'black';
    plotOptions.style = 'avg';
    plotOptions.doExample = false;
    idx_base_moved      = idx_moved & idx_reach_bottom;
    idx_base_rewarded   = idx_rewarded;  
    for n = 1:numel(init_x_list)
        idx_plot = find(init_x == init_x_list(n) & idx_base_moved);
        h(1) = fig_pps.plot_ball_trajectories(behav_data, idx_plot, EXP_CONFIG, plotOptions);
    end
    
    plotOptions.color = 'red';
    plotOptions.style = 'avg';
    plotOptions.doExample = false;
    for n = 1:numel(init_x_list)
        idx_plot = find(init_x == init_x_list(n) & idx_base_rewarded);
        h(2) = fig_pps.plot_ball_trajectories(behav_data, idx_plot, EXP_CONFIG, plotOptions);
    end
    ylim([-5,60])
    legend(h, 'Moved','Rewarded','Orientation','horizontal')
     set(gca,'fontsize',18)
    title(titleStr_list{i},'fontsize',14)
   

    save_name = fullfile(figure_folder, save_name_list{i});
    print(save_name, '-dsvg');
    close gcf

end
end
%% 5. time course of target distance and 6. corr. trajectory

doThis = 1;
if doThis
    subjectCode = 'GD_1_red';
    %data_folder = fullfile('../../results/behav/pps_processed',subjectCode);
    
    switch subjectCode
        case 'LSZ_practice_5_violet'
            eval(sprintf('session_list = PPS_global.%s.session_list.initial;',subjectCode));
            sgtitle_str = 'Example animal 1';
           
        case 'GD_1_red'
            eval(sprintf('session_list = PPS_global.%s.session_list.initial;',subjectCode));
            sgtitle_str = 'Example animal 2';
    end
    save_name = fullfile(figure_folder,sprintf('timecourses_%s_moremetrics', subjectCode));
    behav_results_summary = util_pps.load_behav_results_summary(fullfile(data_folder, subjectCode), subjectCode, session_list);
    plotOptions.session_list = session_list;
    %%%
    figure;
    set(gcf,'Units','inches','position',[0, 0,8,8]);
    subplot(2,1,1)
    plotOptions.fieldname_avg = 'target_distance_rewarded';
    plotOptions.errorbar_option = 'sem';

    [h, corr_stats_target] = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
    set(h,'color',colors_list(3,:));
    ylabel('Target distance');xlabel('Date')
    
    subplot(2,1,2)
    plotOptions.fieldname_avg = 'corr_trajectory_rewarded';
    plotOptions.errorbar_option = 'sem';
    [h, corr_stats_corr] = fig_pps.plot_sessions_timecourse(behav_results_summary, plotOptions);
    set(h,'color',colors_list(4,:));
    ylabel('Corr. trajectories');xlabel('Date')
    
    
    sgtitle(sgtitle_str,'fontweight','bold','fontsize',20)
    print(save_name, '-dsvg');
    %close gcf
end

%% 6. plot all animals 
doThis = 1;
if doThis
subjectCode_list = PPS_global.subjectCode_list_of_interest;

nPlot = 5;
for  n = 1:numel(subjectCode_list)
    %data_folder = fullfile('../../results/behav/pps_processed',subjectCode);
    subjectCode = subjectCode_list{n};

    eval(sprintf('session_list = PPS_global.%s.session_list.initial;',subjectCode));
    session_list_use = session_list(end-nPlot + 1:end);
    
    behav_results_summary = util_pps.load_behav_results_summary(fullfile(data_folder, subjectCode), subjectCode, session_list_use);

    if n == 1
        behav_results_summary_all = behav_results_summary;
    else
        behav_results_summary_all = [behav_results_summary_all,behav_results_summary];
    end
end

figure;
save_name = fullfile(figure_folder,'all_animals_metrics');
set(gcf,'unit','inches','position',[0,0,12,8])

subplot(2,2,1);hold on
for n = 1:numel(subjectCode_list)
    idx = strcmp({behav_results_summary_all(:).subjectCode}, subjectCode_list{n});
    data_plot = [behav_results_summary_all(idx).p_reward_moved];
    
    plot(n*ones(size(data_plot)), data_plot, '.','color',colors_list(1,:),'markersize',5);
    errorbar(n, mean(data_plot), std(data_plot), '.','color',colors_list(1,:),'markersize',15, 'LineWidth', 1.5);
end
set(gca,'xtick',[1:6])
xlim([0.5, 6.5]);
xlabel('Animal index');
ylabel('P(reward|moved)');
set(gca,'fontsize',18)

subplot(2,2,2);hold on
for n = 1:numel(subjectCode_list)
    idx = strcmp({behav_results_summary_all(:).subjectCode}, subjectCode_list{n});
    data_plot = [behav_results_summary_all(idx).zscore_p_reward_moved];
    
    plot(n*ones(size(data_plot)), data_plot, '.','color',colors_list(2,:),'markersize',5);
    errorbar(n, mean(data_plot), std(data_plot), '.','color',colors_list(2,:),'markersize',15, 'LineWidth', 1.5);
end
set(gca,'xtick',[1:6])
xlim([0.5, 6.5]);
xlabel('Animal index');
ylabel('Z-score');
set(gca,'fontsize',18)
line([0.5 6.5],[1.645,1.645],'linestyle','--','color','black')


subplot(2,2,3);hold on
for n = 1:numel(subjectCode_list)
    idx = strcmp({behav_results_summary_all(:).subjectCode}, subjectCode_list{n});
    data_plot = cellfun(@mean, {behav_results_summary_all(idx).target_distance_rewarded});

    
    plot(n*ones(size(data_plot)), data_plot, '.','color',colors_list(3,:),'markersize',5);
    errorbar(n, mean(data_plot), std(data_plot), '.','color',colors_list(3,:),'markersize',15, 'LineWidth', 1.5);
end
set(gca,'xtick',[1:6])
xlim([0.5, 6.5]);
xlabel('Animal index');
ylabel('Target distance');
set(gca,'fontsize',18)


subplot(2,2,4);hold on
for n = 1:numel(subjectCode_list)
    idx = strcmp({behav_results_summary_all(:).subjectCode}, subjectCode_list{n});
    data_plot = cellfun(@mean, {behav_results_summary_all(idx).corr_trajectory_rewarded});

    
    plot(n*ones(size(data_plot)), data_plot, '.','color',colors_list(4,:),'markersize',5);
    errorbar(n, mean(data_plot), std(data_plot), '.','color',colors_list(4,:),'markersize',15, 'LineWidth', 1.5);
end
set(gca,'xtick',[1:6])
xlim([0.5, 6.5]);
xlabel('Animal index');
ylabel('Corr. trajectories');
set(gca,'fontsize',18)

 print(save_name, '-dsvg');
 %close gcf
end