function correlation_stats = get_trajectory_correlation_stats(behav_data)
    doPlot = false;
    
    
    idx_moved       =  find(([behav_data(:).is_moved] == 1) & ([behav_data(:).reached_bottom] == 1));
    
    idx_rewarded    = find([behav_data(:).rewarded] == 1);
    
    
    [r_all_moved, r_single_moved] = util_pps.compute_trajectory_correlation(behav_data, idx_moved, doPlot);
    [r_all_rewarded, r_single_rewarded] = util_pps.compute_trajectory_correlation(behav_data, idx_rewarded, doPlot);
    
    
    correlation_stats.r_all_moved           = r_all_moved;
    correlation_stats.r_single_moved        = r_single_moved;
    correlation_stats.r_all_rewarded        = r_all_rewarded;
    correlation_stats.r_single_rewarded     = r_single_rewarded;


    correlation_stats.r_avg_moved           = mean(r_all_moved);
    correlation_stats.r_sem_moved           = std(r_all_moved) / sqrt(numel(r_all_moved));
    correlation_stats.r_avg_rewarded        = mean(r_all_rewarded);
    correlation_stats.r_sem_rewarded        = std(r_all_rewarded) / sqrt(numel(r_all_rewarded));
end