clear all
clc
close all

subjectCode  = 'LSZ_practice_5_violet';
data_folder = fullfile('../../results/behav/pps_processed/',subjectCode);
global PPS_global
generate_PPS_global();
eval(sprintf('session_list_all = PPS_global.%s.session_list.new_params;',subjectCode));
%% 1. performance conditioned on y_speed
doThis = 1;

if doThis
    plotIndividual = true;
    baseline_y_vel = 30; 
    %exp_date_list   = {'20260413';'20260414';'20260422';'20260423';'20260424';'20260428';'20260429';'20260430';'20260501'};

    exp_date_list   = session_list_all;
    nSession        = numel(exp_date_list);
    % nRow            = floor(sqrt(nSession));
    % nCol            = ceil(nSession / nRow); 
    
    behav_summary   = struct();
    k = 1;
for i = 1:nSession
    exp_date = exp_date_list{i};
    load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s', subjectCode, exp_date)));
    behav_data(1) = [];
    
    ball_y_speed_all = [behav_data(:).ball_y_speed];
    ball_y_speed_list = unique(ball_y_speed_all);
    
    n_condition = numel(ball_y_speed_list);
    [p_moved, p_rewarded_moved, p_moved_sem,p_rewarded_moved_sem] = deal(zeros(n_condition, 1));
    for n = 1:n_condition
        idx =  ball_y_speed_all == ball_y_speed_list(n);
        
        
        p_moved(n)     = sum([behav_data(idx).is_moved]) / sum(idx);
        p_rewarded_moved(n) = sum([behav_data(idx).is_moved] & [behav_data(idx).rewarded]) / sum([behav_data(idx).is_moved]);
    
        p_moved_sem(n) = sqrt(p_moved(n) * (1 - p_moved(n)) / sum(idx));
        p_rewarded_moved_sem(n) = sqrt(p_rewarded_moved(n) * (1 - p_rewarded_moved(n)) / ...
                        sum([behav_data(idx).is_moved]));

      
        
        behav_summary(k).exp_date   = exp_date;
        behav_summary(k).y_vel      = ball_y_speed_list(n);

        behav_summary(k).p_moved        =   p_moved(n);
        %behav_summary(k).p_moved_norm   = p_moved(n) * behav_summary(k).y_vel / 
        behav_summary(k).p_moved_sem    = p_moved_sem(n);
        behav_summary(k).p_rewarded_moved = p_rewarded_moved(n);
        behav_summary(k).p_rewarded_moved_sem = p_rewarded_moved_sem(n);
        

        k = k+1;


    end
    if plotIndividual
        if i == 1
            figure;
         end
        %subplot(nRow,nCol,i);
        %errorbar([1:n_condition],p_moved,p_moved_sem,'linewidth',2); hold on;
        plot(ball_y_speed_list,p_rewarded_moved,'-o','linewidth',2); hold on
        %set(gca,'xtick',[1:n_condition],'xticklabels',ball_y_speed_list);
        legend('p-moved','p-rewarded-moved');
        %xlim([0.5, n_condition + 0.5]);
        set(gca,'fontsize',18);
        xlabel('y-speed'); ylabel('Proportion');
        title(exp_date_list{i})
    end

end
%sgtitle(sprintf('Ball y-vel, %s', subject_code),'fontsize',20,'fontweight','bold','interpreter','none');
%%% For every session, normalize the p_reward_move with the value at 30
%%% cm/s

for i = 1:nSession
    idx_session     = strcmp({behav_summary(:).exp_date}, exp_date_list{i});
    idx_baseline    = idx_session & [behav_summary(:).y_vel] == baseline_y_vel;
    p_baseline      =  behav_summary(idx_baseline).p_rewarded_moved;
    
    idx_session = find(idx_session);
    for k = 1:numel(idx_session)
        idx = idx_session(k);
        behav_summary(idx).p_rewarded_moved_norm =  behav_summary(idx).p_rewarded_moved / p_baseline;
    end

end

% figure;
% for i = 1:nSession
%     idx_session     = strcmp({behav_summary(:).exp_date}, exp_date_list{i});
%     plot([behav_summary(idx_session).y_vel], [behav_summary(idx_session).p_rewarded_moved_norm], '-o'); hold on
% end
% y_vel_all   = [behav_summary(:).y_vel];
% y_vel_list  = unique(y_vel_all);
% p_reward_norm_all = [behav_summary(:).p_rewarded_moved_norm];
% p_reward_avg = arrayfun(@(x)mean(p_reward_norm_all(y_vel_all == x)), y_vel_list);
% p_reward_std = arrayfun(@(x)std(p_reward_norm_all(y_vel_all == x)), y_vel_list);
% errorbar(y_vel_list, p_reward_avg, p_reward_std,'Color','black','LineWidth',2)
end

%% 2. performance conditioned on opacity
doThis = 1;
if doThis
     figure;
    exp_date_list = {'20260415';'20260422';'20260423';'20260424';'20260428';'20260429';'20260430';'20260501'};
    for i = 1:numel(exp_date_list)
        exp_date = exp_date_list{i};
        load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s', subjectCode, exp_date)));
        behav_data(1) = [];
        
        ball_opacity_all = [behav_data(:).ball_opacity];
        ball_opacity_list = unique(ball_opacity_all);
        n_condition = numel(ball_opacity_list);
        [p_moved, p_rewarded_moved, p_moved_sem,p_rewarded_moved_sem] = deal(zeros(n_condition, 1));
        for n = 1:n_condition
            idx =  ball_opacity_all == ball_opacity_list(n);
            
            
            p_moved(n)     = sum([behav_data(idx).is_moved]) / sum(idx);
            p_rewarded_moved(n) = sum([behav_data(idx).is_moved] & [behav_data(idx).rewarded]) / sum([behav_data(idx).is_moved]);
        
            p_moved_sem(n) = sqrt(p_moved(n) * (1 - p_moved(n)) / sum(idx));
            p_rewarded_moved_sem(n) = sqrt(p_rewarded_moved(n) * (1 - p_rewarded_moved(n)) / ...
                            sum([behav_data(idx).is_moved]));
        
        end
        
        %errorbar([1:n_condition],p_moved,p_moved_sem,'linewidth',2); hold on;
        errorbar(ball_opacity_list,p_rewarded_moved,p_rewarded_moved_sem,'linewidth',2); hold on
        %set(gca,'xtick',[1:n_condition],'xticklabels',ball_opacity_list)
        legend('p-moved','p-rewarded-moved');
        %xlim([0.5, n_condition + 0.5]);
        set(gca,'fontsize',18);
        xlabel('opacity'); ylabel('Proportion')
        title('Opacity')
    end
end
%% 3. performance conditioned on jitter/no-jitter
%%% Note: The plan was also to use a list of gains but I changed the wrong
%%% parameter. So only one gain. But there are jittered/no-jittered trials
%%% to compare
doThis = 0;
if doThis
    exp_date = '20260417';
    load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s', subject_code, exp_date)));
    behav_data(1) = [];
    
    jitter_all = [behav_data(:).wheel_jitter];
    jitter_list = unique(jitter_all);
    
    n_condition = numel(jitter_list);
    [p_moved, p_rewarded_moved, p_moved_sem,p_rewarded_moved_sem] = deal(zeros(n_condition, 1));
    for n = 1:n_condition
        idx = jitter_all == jitter_list(n);
    
        p_moved(n)     = sum([behav_data(idx).is_moved]) / sum(idx);
        p_rewarded_moved(n) = sum([behav_data(idx).is_moved] & [behav_data(idx).rewarded]) / sum([behav_data(idx).is_moved]);
    
        p_moved_sem(n) = sqrt(p_moved(n) * (1 - p_moved(n)) / sum(idx));
        p_rewarded_moved_sem(n) = sqrt(p_rewarded_moved(n) * (1 - p_rewarded_moved(n)) / ...
                        sum([behav_data(idx).is_moved]));
    end
    figure
    errorbar([1:n_condition],p_moved,p_moved_sem,'linewidth',2); hold on;
    errorbar([1:n_condition],p_rewarded_moved,p_rewarded_moved_sem,'linewidth',2);
    set(gca,'xtick',[1:n_condition],'xticklabels',jitter_list)
    legend('p-moved','p-rewarded-moved');
    xlim([0.5, n_condition + 0.5]);
    set(gca,'fontsize',18);
    xlabel('jitter'); ylabel('Proportion')
    title('Wheel jittering')
end
%% 4. performance conditioned on random walk
doThis = 0;
if doThis
    exp_date = '20260416';
    load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s', subject_code, exp_date)));
    behav_data(1) = [];
    
    random_walk_bias_all    = [behav_data(:).ball_random_bias];
    random_walk_std_all     = [behav_data(:).ball_random_std];
    
    figure;
    plot(random_walk_bias_all, random_walk_std_all,'.')
    
    idx_no_random = random_walk_bias_all == 0 & random_walk_std_all == 0;
    
    % random walk v.s. no random walk
    idx_list = {idx_no_random; ~idx_no_random};
    [p_moved, p_rewarded_moved, p_moved_sem, p_rewarded_moved_sem] = deal(zeros(2, 1));
    for n = 1:2
        idx = idx_list{n};
        p_moved(n)     = sum([behav_data(idx).is_moved]) / sum(idx);
        p_rewarded_moved(n) = sum([behav_data(idx).is_moved] & [behav_data(idx).rewarded]) / sum([behav_data(idx).is_moved]);
    
        p_moved_sem(n) = sqrt(p_moved(n) * (1 - p_moved(n)) / sum(idx));
        p_rewarded_moved_sem(n) = sqrt(p_rewarded_moved(n) * (1 - p_rewarded_moved(n)) / ...
                        sum([behav_data(idx).is_moved]));
    end
    figure;
    subplot(1,2,1); hold on
    errorbar([1:2],p_moved,p_moved_sem,'linewidth',2); hold on;
    errorbar([1:2],p_rewarded_moved,p_rewarded_moved_sem,'linewidth',2);
    set(gca,'xtick',[1:n_condition],'xticklabels',{'No random walk';'Random walk'});
    legend('p-moved','p-rewarded-moved');
    set(gca,'fontsize', 18);
    xlim([0.5, 2.5]);
    ylabel('Proportion')
    
    % random walk condition, different bins
    bias_edge   = [0, 2, 6];
    std_edge    = [10, 20, 30, 40];
    n_bias      = numel(bias_edge)-1;
    n_std       = numel(std_edge)-1; 
    idx_array   = cell(n_bias, n_std);
    
    
    
    plot_style_list = {'--^','-o'};
    color_list = {[0, 0.4470, 0.7410]; [0.8500, 0.3250, 0.0980]; [0.9290, 0.6940, 0.1250]};
    
    subplot(1,2,2);hold on
    [p_moved, p_rewarded_moved, p_free_reward] = deal(zeros(n_bias, n_std));
    [p_moved_sem, p_rewarded_moved_sem, p_free_reward_sem] = deal(zeros(n_bias, n_std));
    for i = 1:n_bias
        for j = 1:n_std
           
            idx_bias = abs(random_walk_bias_all) > bias_edge(i) & abs(random_walk_bias_all) <= bias_edge(i+1); 
            idx_std =  random_walk_std_all > std_edge(j) & random_walk_std_all <= std_edge(j+1);
            idx = idx_bias & idx_std;
            
            p_moved(i,j)     = sum([behav_data(idx).is_moved]) / sum(idx);
            p_rewarded_moved(i,j) = sum([behav_data(idx).is_moved] & [behav_data(idx).rewarded]) / sum([behav_data(idx).is_moved]);
            
            p_free_reward(i,j) = sum(~[behav_data(idx).is_moved] & [behav_data(idx).rewarded]) / sum(idx);
            
            p_moved_sem(i,j) = sqrt(p_moved(i,j) * (1 - p_moved(i,j)) / sum(idx));
            p_rewarded_moved_sem(i,j) = sqrt(p_rewarded_moved(i,j) * (1 - p_rewarded_moved(i,j)) / ...
                        sum([behav_data(idx).is_moved]));
    
            p_free_reward_sem(i,j) = sqrt(p_free_reward(i,j) * (1 - p_free_reward(i,j)) / ...
                sum(idx));
    
    
        end
        
        h(i) = errorbar([1:n_std],p_moved(i,:), p_moved_sem(i,:), plot_style_list{i}, 'color', color_list{1}, 'LineWidth',2);
        errorbar([1:n_std],p_rewarded_moved(i,:),p_rewarded_moved_sem(i,:), plot_style_list{i}, 'color', color_list{2},'LineWidth',2);
        errorbar([1:n_std],p_free_reward(i,:), p_free_reward_sem(i,:), plot_style_list{i}, 'color', color_list{3},'LineWidth',2);
    
        set(gca,'xtick',[1:n_std],'xticklabels',std_edge)
    end
    set(gca,'fontsize',18)
    xlim([0.5, n_std + 0.5])
    
    xlabel('Proportion');
    ylabel('Random walk std')
    legend(h,{'Small bias';'Large bias'})
    
    sgtitle('Random walk','fontsize',18,'fontweight','bold')
end