function target_distance = compute_target_distance(behav_data)
idx_reach_bottom    = [behav_data(:).reached_bottom] == 1;
idx_rewarded        = [behav_data(:).rewarded] == 1;
idx_moved           = [behav_data(:).is_moved] == 1; 

%%% how centralized the ending position is
%%%%% 05/18/2026: Replace mean with median
%%% rewarded
distance_rewarded  = abs([behav_data(idx_rewarded).end_x_rel_cm]);
%MAD_rewarded    = mean(abs(x_end_rewarded));
distance_median_rewarded        = median(distance_rewarded); 
distance_MAD_rewarded           = median(abs(distance_rewarded - distance_median_rewarded));


%%% moved reached bottom
distance_moved  = abs([behav_data(idx_reach_bottom & idx_moved).end_x_rel_cm]);
%MAD_moved_reachbottom    = mean(abs(x_end_moved_reachbottom));
distance_median_moved       = median(distance_moved);
distance_MAD_moved          = median(abs(distance_moved - distance_median_moved));

% %%% non-rewarded but non-collided
% distance_reachbottom  = abs([behav_data(idx_reach_bottom).end_x_rel_cm]);
% %MAD_reachbottom    = mean(abs(x_end_reachbottom));
% distance_median_reachbottom         = median(distance_reachbottom);
% distance_MAD_reachbottom            = median(abs(distance_reachbottom - distance_median_reachbottom));



target_distance.distance_rewarded           = distance_rewarded;
target_distance.distance_moved              = distance_moved;

target_distance.distance_median_rewarded    = distance_median_rewarded;
target_distance.distance_MAD_rewarded       = distance_MAD_rewarded;

target_distance.distance_median_moved       = distance_median_moved; 
target_distance.distance_MAD_moved          = distance_MAD_moved; 

% target_distance.distance_median_reachbottom = distance_median_reachbottom;
% target_distance.distance_MAD_reachbottom    = distance_MAD_reachbottom; 

end