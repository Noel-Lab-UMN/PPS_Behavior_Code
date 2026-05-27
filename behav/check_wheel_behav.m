clear all
clc
close all


subjectCode  = 'LSZ_practice_5_violet';
data_folder = fullfile('../../results/behav/pps_processed/',subjectCode);
global PPS_global
generate_PPS_global();
eval(sprintf('session_list_all = PPS_global.%s.session_list.new_params;',subjectCode));

colors_list = get(groot, 'defaultAxesColorOrder');
%%
plotIndividual = false;
plotOption = 'zscore'; % zscore or p_reward
nPermute = 100;

exp_date_list = {'20260417';'20260420';'20260422';'20260423';'20260424';'20260428';'20260429';'20260430';'20260501'};
%exp_date_list = {'20260507'};
nSession = numel(exp_date_list);
nRow            = floor(sqrt(nSession));
nCol            = ceil(nSession / nRow); 
result_summary = struct();
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
    [p_rewarded_moved, p_rewarded_moved_sem, z_score] = deal(zeros(2, numel(wheel_gain_list)));
   
    %%%% jittering vs. no jittering %%%% different gain
    for i = 1:numel(wheel_gain_list)
        idx_nojitter =  wheel_gain_all == wheel_gain_list(i) & wheel_jitter_all == 0;
        idx_jitter = wheel_gain_all == wheel_gain_list(i) & wheel_jitter_all > 0;
       
    
        p_rewarded_moved(1,i) = sum([behav_data(idx_nojitter).is_moved] & [behav_data(idx_nojitter).rewarded]) / sum([behav_data(idx_nojitter).is_moved]);
        p_rewarded_moved(2,i) = sum([behav_data(idx_jitter).is_moved] & [behav_data(idx_jitter).rewarded]) / sum([behav_data(idx_jitter).is_moved]);
    
            
       p_rewarded_moved_sem(1,i) = sqrt(p_rewarded_moved(1,i) * (1 - p_rewarded_moved(1,i)) / ...
                sum([behav_data(idx_nojitter).is_moved]));
       p_rewarded_moved_sem(2,i) = sqrt(p_rewarded_moved(2,i) * (1 - p_rewarded_moved(2,i)) / ...
                sum([behav_data(idx_jitter).is_moved]));
    
       % z-score per condition
       if strcmp(plotOption, 'zscore')
       z_score(1,i) =  util_pps.compute_z_score_condition(behav_data, p_rewarded_moved(1,i), idx_nojitter, nPermute, EXP_CONFIG);
       z_score(2,i) =  util_pps.compute_z_score_condition(behav_data, p_rewarded_moved(2,i), idx_jitter, nPermute, EXP_CONFIG);
       end
     
    
    end
    %  subplot(nRow,nCol,n)
   
    % legend('No jitter','Jitter')
    if plotIndividual
        subplot(nRow,nCol,n)
        switch plotOption
            case 'zscore'
            plot(wheel_gain_list, z_score(1,:), '-o','color',colors_list(1,:),'LineWidth',2); hold on
            plot(wheel_gain_list, z_score(2,:), '-o','color',colors_list(2,:),'LineWidth',2);
            line([wheel_gain_list(1) - 0.05, wheel_gain_list(end)+0.05], [1.645, 1.645], 'linestyle','--','color','black')
            ylabel('Z-score')
    
            case 'p_reward'
            errorbar(wheel_gain_list, p_rewarded_moved(1,:), p_rewarded_moved_sem(:,1), '-o','color',colors_list(1,:),'LineWidth',2); hold on
            errorbar(wheel_gain_list, p_rewarded_moved(2,:), p_rewarded_moved_sem(:,2), '-o','color',colors_list(2,:),'LineWidth',2); 
        
            ylabel('p(reward|moved)')
    
        end
        set(gca,'xtick',wheel_gain_list);
        set(gca,'fontsize',18);
        xlabel('Wheel gain');
        %   
        legend('No jitter','Jitter','Chance')
        title(exp_date)
    end
    result_summary(i).exp_date = exp_date;
    result_summary(i).wheel_gain_list = wheel_gain_list;
    result_summary(i).z_score = z_score;
    result_summary(i).p_rewarded_moved = p_rewarded_moved;
end
sgtitle(subjectCode,'fontsize',18,'fontweight','bold','interpreter','none')
%%

wheel_gain_all = [result_summary(:).wheel_gain_list];
p_rewarded_moved_all = [result_summary(:).p_rewarded_moved];
z_score_all = [result_summary(:).z_score];
wheel_gain_list = unique(wheel_gain_all);

p_reward_avg(1,:)    = arrayfun(@(x)mean(p_rewarded_moved_all(1, wheel_gain_all == x), 2), wheel_gain_list);
p_reward_avg(2,:)    = arrayfun(@(x)mean(p_rewarded_moved_all(2, wheel_gain_all == x), 2), wheel_gain_list);

p_reward_std(1,:)    = arrayfun(@(x)std(p_rewarded_moved_all(1, wheel_gain_all == x), [], 2), wheel_gain_list);
p_reward_std(2,:)    = arrayfun(@(x)std(p_rewarded_moved_all(2, wheel_gain_all == x), [],2), wheel_gain_list);

zscore_avg(1,:)      = arrayfun(@(x)mean(z_score_all(1, wheel_gain_all == x), 2), wheel_gain_list);
zscore_avg(2,:)      = arrayfun(@(x)mean(z_score_all(2, wheel_gain_all == x), 2), wheel_gain_list);

zscore_std(1,:)      = arrayfun(@(x)std(z_score_all(1, wheel_gain_all == x), [],2), wheel_gain_list);
zscore_std(2,:)      = arrayfun(@(x)std(z_score_all(2, wheel_gain_all == x), [],2), wheel_gain_list);


figure
subplot(2,1,1); hold on
errorbar(wheel_gain_list, p_reward_avg(1,:), p_reward_std(1,:),'LineWidth',2,'LineStyle','-');
errorbar(wheel_gain_list, p_reward_avg(2,:), p_reward_std(2,:),'LineWidth',2,'LineStyle','--');
%plot(y_vel_all, p_rewarded_moved_all,'.','MarkerSize',10,'color',[0.5,0.5,0.5]);
legend('No-jitter','Jitter')
xlabel('Wheel gain'); ylabel('P(reward|moved)');
box off
set(gca,'fontsize',18)


subplot(2,1,2); hold on
errorbar(wheel_gain_list, zscore_avg(1,:), zscore_std(1,:),'LineWidth',2,'color','black','LineStyle','-');
errorbar(wheel_gain_list, zscore_avg(2,:), zscore_std(2,:),'LineWidth',2,'color','black','LineStyle','--');
legend('No-jitter','Jitter')
%plot(y_vel_all, z_score_all,'.','MarkerSize',10,'color',[0.5,0.5,0.5])
line([wheel_gain_list(1), wheel_gain_list(end)], [1.645, 1.645], 'linestyle','--','color','black');
xlabel('Wheel gain'); ylabel('Z-score');
box off
set(gca,'fontsize',18)

sgtitle(subjectCode,'fontweight','bold','fontsize',18,'interpreter','none')
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