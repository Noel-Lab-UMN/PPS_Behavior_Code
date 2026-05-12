clear all
clc
close all


subjectCode  = 'GD_1_red';
data_folder = fullfile('../../results/behav/pps_processed/',subjectCode);
global PPS_global
generate_PPS_global();
eval(sprintf('session_list_all = PPS_global.%s.session_list.new_params;',subjectCode));

colors_list = get(groot, 'defaultAxesColorOrder');
%%


nPermute = 100;

%exp_date_list = {'20260417';'20260420';'20260422';'20260423';'20260424';'20260428';'20260429';'20260430';'20260501'};
exp_date_list = {'20260507'};
nSession = numel(exp_date_list);
nRow            = floor(sqrt(nSession));
nCol            = ceil(nSession / nRow); 
figure
for n = 1:numel(exp_date_list)
    exp_date = exp_date_list{n};
    load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s', subjectCode, exp_date)));
    
    wheel_gain_all = [behav_data(:).wheel_gain];
    wheel_jitter_all = [behav_data(:).wheel_jitter];
    wheel_gain_list = unique(wheel_gain_all);
    wheel_jitter_list = unique(wheel_jitter_all);

    if strcmp(exp_date ,'20260424')
        wheel_gain_list(wheel_gain_list == 0.25) = [];
    end
    [p_rewarded_moved, p_rewarded_moved_sem, z_score] = deal(zeros(numel(wheel_gain_list), 2));
   
    %%%% jittering vs. no jittering %%%% different gain
    for i = 1:numel(wheel_gain_list)
        idx_nojitter =  wheel_gain_all == wheel_gain_list(i) & wheel_jitter_all == 0;
        idx_jitter = wheel_gain_all == wheel_gain_list(i) & wheel_jitter_all > 0;
       
    
        p_rewarded_moved(i,1) = sum([behav_data(idx_nojitter).is_moved] & [behav_data(idx_nojitter).rewarded]) / sum([behav_data(idx_nojitter).is_moved]);
        p_rewarded_moved(i,2) = sum([behav_data(idx_jitter).is_moved] & [behav_data(idx_jitter).rewarded]) / sum([behav_data(idx_jitter).is_moved]);
    
            
       p_rewarded_moved_sem(i,1) = sqrt(p_rewarded_moved(i,1) * (1 - p_rewarded_moved(i,1)) / ...
                sum([behav_data(idx_nojitter).is_moved]));
       p_rewarded_moved_sem(i,2) = sqrt(p_rewarded_moved(i,2) * (1 - p_rewarded_moved(i,2)) / ...
                sum([behav_data(idx_jitter).is_moved]));
    
       % z-score per condition
       z_score(i,1) =  util_pps.compute_z_score_condition(behav_data, p_rewarded_moved(i,1), idx_nojitter, nPermute, EXP_CONFIG);
       z_score(i,2) =  util_pps.compute_z_score_condition(behav_data, p_rewarded_moved(i,2), idx_jitter, nPermute, EXP_CONFIG);
       % p_reward_moved_permute_nojitter = zeros(nPermute, 1);
       % p_reward_moved_permute_jitter = zeros(nPermute, 1);
       % for t = 1:nPermute
       % 
       %     do_permute_sign = 0;
       %     do_moved        = 1;
       % 
       %     idx_run = find(idx_nojitter);
       %     [~, simu_stats]       = util_pps.simulate_trajectories_permute(behav_data,idx_run, EXP_CONFIG, do_permute_sign, do_moved);
       %     p_reward_moved_permute_nojitter(t)    = simu_stats.p_rewarded;
       % 
       % 
       %     idx_run = find(idx_jitter);
       %     [~, simu_stats]       = util_pps.simulate_trajectories_permute(behav_data,idx_run, EXP_CONFIG, do_permute_sign, do_moved);
       %     p_reward_moved_permute_jitter(t)    = simu_stats.p_rewarded;
       % 
       % end
       % z_score(i,1) = (p_rewarded_moved(i,1) - mean(p_reward_moved_permute_nojitter)) / std(p_reward_moved_permute_nojitter);
       % z_score(i,2) = (p_rewarded_moved(i,2) - mean(p_reward_moved_permute_jitter)) / std(p_reward_moved_permute_nojitter);
       
    
    
    end
    %  subplot(nRow,nCol,n)
    % errorbar(wheel_gain_list, p_rewarded_moved(:,1), p_rewarded_moved_sem(:,1), '-o','color',colors_list(1,:),'LineWidth',2); hold on
    % errorbar(wheel_gain_list, p_rewarded_moved(:,2), p_rewarded_moved_sem(:,2), '-o','color',colors_list(2,:),'LineWidth',2); 
    % legend('No jitter','Jitter')
    % 
    subplot(nRow,nCol,n)
    plot(wheel_gain_list, z_score(:,1), '-o','color',colors_list(1,:),'LineWidth',2); hold on
    plot(wheel_gain_list, z_score(:,2), '-o','color',colors_list(2,:),'LineWidth',2);
    set(gca,'xtick',wheel_gain_list);
    set(gca,'fontsize',18);
    xlabel('Wheel gain');
    ylabel('Z-score')
    line([wheel_gain_list(1) - 0.05, wheel_gain_list(end)+0.05], [1.645, 1.645], 'linestyle','--','color','black')
    legend('No jitter','Jitter','Chance')
    title(exp_date)
end

%%
%%%%% too much jitter?

%exp_date_list = {'20260424';'20260428';'20260429';'20260430';'20260501'};
%exp_date_list = {'20260417';'20260420';'20260422';'20260423';'20260424';'20260428';'20260429';'20260430';'20260501'};
exp_date_list = {'20260507'};
nSession = numel(exp_date_list);
nRow            = floor(sqrt(nSession));
nCol            = ceil(nSession / nRow); 
figure
for n = 1:numel(exp_date_list)
    
    exp_date = exp_date_list{n};
    load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s', subjectCode, exp_date)));
    wheel_jitter_all = [behav_data(:).wheel_jitter];
    wheel_jitter_list = unique(wheel_jitter_all);
    for i = 1:numel(wheel_jitter_list)
        idx = find(wheel_jitter_all == wheel_jitter_list(i) & [behav_data(:).is_moved]);
    
        jitter_percent = zeros(numel(idx), 1);
        for t = 1:numel(idx)
            idx_move = behav_data(idx(t)).delta_cm_jitter ~= 0;
            jitter_percent(t) = mean(100 * abs(behav_data(idx(t)).jitter_only(idx_move)) ./ abs(behav_data(idx(t)).delta_cm_no_jitter(idx_move)));
        end
        subplot(nRow,nCol,n)
        errorbar(wheel_jitter_list(i), mean(jitter_percent), std(jitter_percent),'-o','linewidth',2); hold on
    end
    set(gca,'xtick',wheel_jitter_list);
    xlabel('Wheel jitter');
    ylabel('Percent')
    set(gca,'fontsize',18);
    title(exp_date)

end