function corr_initial_delta = get_corr_initial_position_delta_x(behav_data, doPlot, EXP_CONFIG)

    idx_not_reach_bottom = [behav_data(:).reached_bottom] == 0;
    %%% idx of moving the wheel too much? Two screens?
    too_much_wheel_thres    = 2 * EXP_CONFIG(1).SCREEN_WIDTH_CM;
    idx_too_much_wheel      = [behav_data(:).sum_abs_delta_hori_cm] > too_much_wheel_thres;
    %%%%% idx of good trials to be kept
    idx_good = ~idx_not_reach_bottom & ~idx_too_much_wheel;
    %%%% idx of rewarded trials
    idx_rewarded = [behav_data(:).rewarded] == 1;



    initial_x_rel_cm_good        = [behav_data(idx_good).initial_x_rel_cm];
    sum_delta_x_cm_good          = [behav_data(idx_good).sum_delta_hori_cm];
    sum_abs_delta_x_cm_good      = [behav_data(idx_good).sum_abs_delta_hori_cm];
    %sum_delta_goal_directed_cm = [behav_data(idx_good).sum_delta_goal_directed_cm];
    [corr_initial_delta.sum_delta_good_r, corr_initial_delta.sum_delta_good_p] =...
        corr(initial_x_rel_cm_good', sum_delta_x_cm_good');
    [corr_initial_delta.sum_abs_delta_good_r, corr_initial_delta.sum_abs_delta_good_p] =...
        corr(abs(initial_x_rel_cm_good'), sum_abs_delta_x_cm_good');


    initial_x_rel_cm_rewarded        = [behav_data(idx_rewarded).initial_x_rel_cm];
    sum_delta_x_cm_rewarded          = [behav_data(idx_rewarded).sum_delta_hori_cm];
    sum_abs_delta_x_cm_rewarded      = [behav_data(idx_rewarded).sum_abs_delta_hori_cm];
    %sum_delta_goal_directed_cm = [behav_data(idx_rewarded).sum_delta_goal_directed_cm];
    
    [corr_initial_delta.sum_delta_rewarded_r, corr_initial_delta.sum_delta_rewarded_p]...
        = corr(initial_x_rel_cm_rewarded', sum_delta_x_cm_rewarded');
    [corr_initial_delta.sum_abs_delta_rewarded_r, corr_initial_delta.sum_abs_delta_rewarded_p] ...
        = corr(abs(initial_x_rel_cm_rewarded'), sum_abs_delta_x_cm_rewarded');


   

    if doPlot
        fig_folder  = fullfile('../../figures/behav/individual_sessions',EXP_CONFIG(1).MOUSE_NAME, EXP_CONFIG(1).EXP_DATE);
        if ~isfolder(fig_folder)
            mkdir(fig_folder);
        end
        save_name = fullfile(fig_folder,['fig_corr_position_',EXP_CONFIG(1).MOUSE_NAME,'_',EXP_CONFIG(1).EXP_DATE,'.png']);
        gcf = figure;
        set(gcf,'unit','inches','position',[0,0,10,6]);


        subplot(1,2,1); hold on
        h(1) = scatter(initial_x_rel_cm_good,       sum_delta_x_cm_good);
        h(2) = scatter(initial_x_rel_cm_rewarded,   sum_delta_x_cm_rewarded);
        set(gca,'fontsize' ,18);
        xlabel('Initial difference'); 
        ylabel('Sum. (delta-x)');
        title({sprintf('good: r = %.2f^{%s}', corr_initial_delta.sum_delta_good_r, util_pps.p2star(corr_initial_delta.sum_delta_good_p));...
            sprintf('rewarded: r = %.2f^{%s}', corr_initial_delta.sum_delta_rewarded_r, util_pps.p2star(corr_initial_delta.sum_delta_rewarded_p))});
        legend(h,'Good','Rewarded');
    
        subplot(1,2,2); hold on
        h(1) = scatter(abs(initial_x_rel_cm_good), sum_abs_delta_x_cm_good);
        h(2) = scatter(abs(initial_x_rel_cm_rewarded), sum_abs_delta_x_cm_rewarded);
        set(gca,'fontsize' ,18);
        xlabel('Initial distance'); 
        ylabel('Sum. abs(delta-x)');
        title({sprintf('good: r = %.2f^{%s}', corr_initial_delta.sum_abs_delta_good_r, util_pps.p2star(corr_initial_delta.sum_abs_delta_good_p));...
            sprintf('rewarded: r = %.2f^{%s}', corr_initial_delta.sum_abs_delta_rewarded_r, util_pps.p2star(corr_initial_delta.sum_abs_delta_rewarded_p))});
        legend(h,'Good','Rewarded');
        
        sgtitle([EXP_CONFIG(1).MOUSE_NAME,'-',EXP_CONFIG(1).EXP_DATE],'fontsize',18,'fontweight','bold','interpreter','none');
        
        saveas(gcf, save_name)
        close

    end
end