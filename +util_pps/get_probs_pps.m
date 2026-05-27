function [percent_pps, percent_pps_timebin] = get_probs_pps(behav_data, doTimebin, doPlot, EXP_CONFIG)

%%%% all trials
idx_all = ones(size(behav_data));
percent_pps = calcu_probs(behav_data, idx_all, EXP_CONFIG);

if doTimebin
    %%% trials of individual time bin
    timebin_size = 5; % in minute
    start_time = arrayfun(@(x) x.t_global_s(1), behav_data);
    time_bin = ceil(start_time / 60 / timebin_size);
    time_bin_list = unique(time_bin);
    time_elapsed_list = time_bin_list * timebin_size;

    for k = 1:max(time_bin)
        idx = time_bin == k;
        percent_pps_timebin(k) =  calcu_probs(behav_data, idx, EXP_CONFIG);
    end
 
else
    percent_pps_timebin = struct();
end



if doPlot
    
    fig_folder  = fullfile('../../figures/behav/individual_sessions',EXP_CONFIG(1).MOUSE_NAME, EXP_CONFIG(1).EXP_DATE);
    if ~isfolder(fig_folder)
        mkdir(fig_folder);
    end
    save_name = fullfile(fig_folder,['fig_percentages_',EXP_CONFIG(1).MOUSE_NAME,'_',EXP_CONFIG(1).EXP_DATE,'.png']);
    gcf = figure;
    set(gcf,'unit','inches','position',[0,0,10,10]); 

    subplot(2,1,1); hold on
    bar(1, percent_pps.p_good);
    bar(2, percent_pps.p_reward);
    bar(3, percent_pps.p_reward_initialIN);
    bar(4, percent_pps.p_reward_initialOUT);


    bar(5,  percent_pps.p_initialIN_reward);
    bar(6,  percent_pps.p_initialOUT_reward);

    line([0.5, 3.5], 100 * [EXP_CONFIG(1).chance_level_null, EXP_CONFIG(1).chance_level_null],'color','black','linestyle','--');
    line([0.5, 3.5], 100 * [EXP_CONFIG(1).chance_level_random, EXP_CONFIG(1).chance_level_random],'color','black','linestyle','-.');
    text(3.5, 100 * EXP_CONFIG(1).chance_level_null, 'Null','fontsize',16);
    text(3.5, 100 * EXP_CONFIG(1).chance_level_random,'Random','fontsize',16);
    grid on ;grid minor
    set(gca,'fontsize',16);ylim([0, 100]); ylabel('Percent ball');
    set(gca,'xtick',[1,2,3, 4, 5,6],'xticklabels',{'Good';'Rewarded';'Rewarded/Initial-In';'Rewarded/Initial-Out';'Initial-In/Rewarded';'Initial-Out/Rewarded'});
    

    subplot(2,1,2); hold on
    plot([percent_pps_timebin(:).time_bin], [percent_pps_timebin(:).p_good],'-o', 'LineWidth',2);
    plot([percent_pps_timebin(:).time_bin], [percent_pps_timebin(:).p_reward],'-o', 'LineWidth',2);
    plot([percent_pps_timebin(:).time_bin], [percent_pps_timebin(:).p_reward_initialIN],'-o', 'LineWidth',2);
    plot([percent_pps_timebin(:).time_bin], [percent_pps_timebin(:).p_reward_initialOUT],'-o', 'LineWidth',2);
    % plot([percent_pps_timebin(:).time_bin], [percent_pps_timebin(:).p_initialIN_reward],'-o', 'LineWidth',2);
    % plot([percent_pps_timebin(:).time_bin], [percent_pps_timebin(:).p_initialOUT_reward],'-o', 'LineWidth',2);
    
    line([0.5, max([percent_pps_timebin(:).time_bin]) + 0.5], 100 * [EXP_CONFIG(1).chance_level_null, EXP_CONFIG(1).chance_level_null],'color','black','linestyle','--');
    line([0.5, max([percent_pps_timebin(:).time_bin]) + 0.5], 100 * [EXP_CONFIG(1).chance_level_random, EXP_CONFIG(1).chance_level_random],'color','black','linestyle','-.');

    grid on ;grid minor
    set(gca,'fontsize',16);ylim([0, 100]); ylabel('Percent ball');
    xlabel('Time elapsed (minutes)')
    legend('Good','Rewarded','Rewarded-InitialIn','Rewarded-InitialOut','location','northoutside','orientation','horizontal')

    sgtitle([EXP_CONFIG(1).MOUSE_NAME,'-',EXP_CONFIG(1).EXP_DATE],'fontsize',18,'fontweight','bold','interpreter','none');

    saveas(gcf, save_name)
    close

end



end

function percent_pps = calcu_probs(behav_data, idx, EXP_CONFIG)
    if all(ismember(idx(:),[0,1]))
        nTotal = sum(idx);
        idx = boolean(idx);
    else
        nTotal = numel(idx);
    end
    % %%% idx of balls not reach bottom
    % idx_not_reach_bottom = [behav_data(idx).reached_bottom] == 0;
    % %%% idx of moving the wheel too much? Two screens?
    % % too_much_wheel_thres    = 2 * EXP_CONFIG(1).SCREEN_WIDTH_CM;
    % % idx_too_much_wheel      = [behav_data(idx).sum_abs_delta_hori_cm] > too_much_wheel_thres;
    % %%%%% idx of good trials to be kept
    % idx_good = ~idx_not_reach_bottom & ~idx_too_much_wheel;
    % p_good   = sum(idx_good) / nTotal;
    
    %%%%% idx of moved trials
    %%%% d
    is_moved = [behav_data(idx).is_moved];
   
    is_rewarded = [behav_data(idx).rewarded] == 1;
    
    % is_initial_in_reward     = [behav_data(idx).initial_in_reward] == 1;
    % initial_x_rel_cm         = [behav_data(idx).initial_x_rel_cm];
    % 
    p_moved = sum(is_moved) / nTotal;
    p_reward = sum(is_rewarded) / nTotal;
    p_reward_moved = sum(is_rewarded & is_moved) /sum(is_moved);

    p_moved_sem     = sqrt(p_moved * (1 - p_moved) / nTotal);
    p_reward_sem    = sqrt(p_reward * (1 - p_reward) / nTotal);
    p_reward_moved_sem = sqrt(p_reward_moved * (1 - p_reward_moved)/sum(is_moved));


    percent_pps.p_moved                 = p_moved;
    percent_pps.p_reward                = p_reward;
    percent_pps.p_reward_moved          = p_reward_moved;
    percent_pps.p_moved_sem             = p_moved_sem;
    percent_pps.p_reward_sem            = p_reward_sem;
    percent_pps.p_reward_moved_sem      = p_reward_moved_sem;
    % p_intialIN = sum(is_initial_in_reward) / nTotal;
    % 
    % %%% P(reward|intial_in_reward)
    % p_reward_initialIN = sum(is_rewarded & is_initial_in_reward) / sum(is_initial_in_reward);
    % %%% P(reward|initial_out_reward)
    % p_reward_initalOUT = sum(is_rewarded & ~is_initial_in_reward) / sum(~is_initial_in_reward);
    % 
    % %%% P(reward|initial_out_reward, left side of the screen)
    % is_initial_left = ~is_initial_in_reward & initial_x_rel_cm < 0;
    % p_reward_initialOUT_left = sum(is_rewarded & is_initial_left) / sum(is_initial_left);
    % 
    % %%% P(reward|initial_out_reward, right side of the screen)
    % is_initial_right = ~is_initial_in_reward & initial_x_rel_cm > 0;
    % p_reward_initialOUT_right = sum(is_rewarded & is_initial_right) / sum(is_initial_right);
    % 
    % 
    % %%%  P(initial_in|rewarded)
    % p_initialIN_reward = sum(is_rewarded & is_initial_in_reward) / sum(is_rewarded);
    % %%%% P(initial_out|rewarded)
    % p_initialOUT_reward = sum(is_rewarded & ~is_initial_in_reward) / sum(is_rewarded);
    
   % percent_pps.p_good                  = p_good;

    % percent_pps.p_intialIN              = p_intialIN;
    % percent_pps.p_reward_initialIN      = p_reward_initialIN;
    % percent_pps.p_reward_initialOUT     = p_reward_initalOUT;
    % percent_pps.p_initialIN_reward      = p_initialIN_reward;
    % percent_pps.p_initialOUT_reward     = p_initialOUT_reward;
    % 
    % percent_pps.p_reward_initialOUT_left    = p_reward_initialOUT_left;
    % percent_pps.p_reward_initialOUT_right   = p_reward_initialOUT_right;
    %%%% calculate reward rate: ul per second

    %start_time = arrayfun(@(x)x.t_global_s(1), behav_data(idx));
  %  T = max(start_time) - min(start_time);
   % percent_pps.reward_rate             = sum(is_rewarded) * EXP_CONFIG(1).REWARD_TARGET / T; 

end