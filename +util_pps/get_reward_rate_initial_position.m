function get_reward_rate_initial_position(behav_data, doPlot, EXP_CONFIG)

    idx_not_reach_bottom = [behav_data(:).reached_bottom] == 0;
    %%% idx of moving the wheel too much? Two screens?
    too_much_wheel_thres    = 2 * EXP_CONFIG(1).SCREEN_WIDTH_CM;
    idx_too_much_wheel      = [behav_data(:).sum_abs_delta_hori_cm] > too_much_wheel_thres;
    %%%%% idx of good trials to be kept
    idx_good = ~idx_not_reach_bottom & ~idx_too_much_wheel;


    edge = [-EXP_CONFIG(1).SCREEN_WIDTH_CM/2 : EXP_CONFIG(1).CIRCLE_RADIUS_CM: EXP_CONFIG(1).SCREEN_WIDTH_CM/2];
    initial_x_cm = [behav_data(idx_good).initial_x_rel_cm];
    is_rewarded = [behav_data(idx_good).rewarded] == 1;
    
    
    [~,~,idx_bin] = histcounts(initial_x_cm, edge);
    
    
    idx_bin_list = unique(idx_bin);
    pos_bin_list = edge;
    
    reward_rate_bin = arrayfun(@(n)mean(is_rewarded(idx_bin == n)) * 100, idx_bin_list);
    plot(edge, reward_rate_bin, '-o','LineWidth',2);
    hold on

    line([EXP_CONFIG(1).tolerant_space_cm(1), EXP_CONFIG(1).tolerant_space_cm(1)], [0, 50], ...
    'linestyle','--','color','red','linewidth',1.5);
    line([EXP_CONFIG(1).tolerant_space_cm(2), EXP_CONFIG(1).tolerant_space_cm(2)], [0, 50], ...
    'linestyle','--','color','red','linewidth',1.5);

    set(gca,'fontsize',18);

end