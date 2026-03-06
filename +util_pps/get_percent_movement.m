function percent_move = get_percent_movement(behav_data, doPlot, EXP_CONFIG)
    idx_not_reach_bottom = [behav_data(:).reached_bottom] == 0;
    %%% idx of moving the wheel too much? Two screens?
    too_much_wheel_thres    = 2 * EXP_CONFIG(1).SCREEN_WIDTH_CM;
    idx_too_much_wheel      = [behav_data(:).sum_abs_delta_hori_cm] > too_much_wheel_thres;
    %%%%% idx of good trials to be kept
    idx_good = ~idx_not_reach_bottom & ~idx_too_much_wheel;

    % All balls
    percent_goal_directed_all               = 100 * [behav_data(idx_good).percent_goal_directed];
    percent_static_all                      = 100 * [behav_data(idx_good).percent_static];
    
    % Condition on inital In/ Initial out
    idx_initialIN                           = [behav_data(:).initial_in_reward] == 1 & idx_good;
    percent_goal_directed_initialIN         = 100 * [behav_data(idx_initialIN).percent_goal_directed];
    
    percent_static_initialIN                = 100 * [behav_data(idx_initialIN).percent_static];
    
    idx_initialOUT                          = [behav_data(:).initial_in_reward] == 0 & idx_good;
    percent_goal_directed_initialOUT        = 100 * [behav_data(idx_initialOUT).percent_goal_directed];
    
    percent_static_initialOUT               = 100 *  [behav_data(idx_initialOUT).percent_static];
    
    percent_move.percent_goal_directed_all          = percent_goal_directed_all;
    percent_move.percent_static_all                 = percent_static_all;
    percent_move.percent_goal_directed_initialIN    = percent_goal_directed_initialIN;
    percent_move.percent_static_initialIN           = percent_static_initialIN;
    percent_move.percent_goal_directed_initialOUT   = percent_goal_directed_initialOUT;
    percent_move.percent_static_initialOUT          = percent_static_initialOUT;

    if doPlot
        fig_folder  = fullfile('../../figures/behav/individual_sessions',EXP_CONFIG(1).MOUSE_NAME, EXP_CONFIG(1).EXP_DATE);
        if ~isfolder(fig_folder)
            mkdir(fig_folder);
        end
        save_name = fullfile(fig_folder,['fig_movement_percent_',EXP_CONFIG(1).MOUSE_NAME,'_',EXP_CONFIG(1).EXP_DATE,'.png']);
        gcf = figure;
        set(gcf,'unit','inches','position',[0,0,10,6]);

        subplot(1,2,1); hold on; RGB = orderedcolors("gem"); 
        yyaxis left
        h(1) = errorbar(1,  mean(percent_move.percent_goal_directed_all),std(percent_move.percent_goal_directed_all) / sqrt(sum(idx_good)),...
                        'LineWidth', 2, 'Color',RGB(1,:), 'LineStyle','none');
        
        h(2) = errorbar(1, mean(percent_move.percent_goal_directed_initialIN), std(percent_move.percent_goal_directed_initialIN) / sqrt(sum(idx_initialIN)), ...
                         'LineWidth',  2, 'Color',RGB(2,:), 'LineStyle','none');
        
        h(3) = errorbar(1, mean(percent_move.percent_goal_directed_initialOUT), std(percent_move.percent_goal_directed_initialOUT) / sqrt(numel(idx_initialOUT)), ...
                        'LineWidth',  2, 'Color',RGB(3,:), 'LineStyle','none');
        ylabel('Percent time')
        
        yyaxis right
        errorbar(2, mean(percent_move.percent_static_all), std(percent_move.percent_static_all) /sqrt(sum(idx_good)), ...
                    'LineWidth', 2, 'Color',RGB(1,:), 'LineStyle', 'none');
        errorbar(2, mean(percent_move.percent_static_initialIN), std(percent_move.percent_static_initialIN) /sqrt(sum(idx_initialIN)), ...
                    'LineWidth', 2, 'Color',RGB(2,:), 'LineStyle', 'none');
        errorbar(2, mean(percent_move.percent_static_initialOUT), std(percent_move.percent_static_initialOUT) /sqrt(sum(idx_initialOUT)), ...
                    'LineWidth', 2, 'Color',RGB(3,:), 'LineStyle', 'none');
        
        box off
        set(gca,'fontsize',18, 'xtick',[1,2],'xticklabels',{'Goal-directed';'Static'})
        ylabel('Percent time')
        xlim([0.5, 2.5]); %ylim([0, 100])
        legend(h, 'All balls','Initial In','Initial Out','location','northoutside','Orientation','horizontal')
    
        %%% Percent of goal-directed as a function of distance to centert
        tmp = {behav_data(idx_good).x_rel_cm};
        x_abs_rel_cm_good       = abs(cat(1,tmp{:}));
        tmp = {behav_data(idx_good).is_goal_directed_movement};
        is_goal_directed        = cat(1,tmp{:});
        
        
        edges = [0 : EXP_CONFIG(1).CIRCLE_RADIUS_CM: EXP_CONFIG(1).SCREEN_WIDTH_CM/2];
        [~,~,idx_bin] = histcounts(x_abs_rel_cm_good, edges);
        idx_bin_list = unique(idx_bin);
        y_mean = 100 * arrayfun(@(n)mean(is_goal_directed(idx_bin == n) == 1), idx_bin_list);
        
        subplot(1,2,2)
        plot(edges, y_mean,'-o','LineWidth',2,'Color','black');
        set(gca,'fontsize',18);
        xlabel('Initial distance');
        ylabel('Percent goal-directed')


        sgtitle([EXP_CONFIG(1).MOUSE_NAME,'-',EXP_CONFIG(1).EXP_DATE],'fontsize',18,'fontweight','bold','interpreter','none');
        saveas(gcf, save_name)
        close

    end
end