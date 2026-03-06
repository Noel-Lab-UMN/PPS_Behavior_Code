function behav_data = read_csv_behav_data(meta_folder, EXP_CONFIG)

csv_filename_list = dir(fullfile(meta_folder,'sync_log_*.csv'));
if numel(csv_filename_list) ~= numel(EXP_CONFIG)
    error('Your config files and data files do not match. Please check')
end
behav_data = struct(); 
N_exist = 0;
for k = 1:numel(EXP_CONFIG)
    csv_filename = sprintf('sync_log_%s_%s_%s.csv',EXP_CONFIG(k).MOUSE_NAME, EXP_CONFIG(k).EXP_DATE, EXP_CONFIG(k).START_TIME_MIN);
    
    raw_data = readtable(fullfile(meta_folder, csv_filename));
    raw_data = read_slot(raw_data);

    %%% split based on ball ID
    ball_list = unique(raw_data.slot1_spawn_id(~isnan(raw_data.slot1_spawn_id)));
    nBall = numel(ball_list);
    


    for i = 1:numel(ball_list)
        idx = raw_data.slot1_spawn_id == ball_list(i);

        n = i + N_exist;
        %%%% basic info, subject code, exp_date
        behav_data(n).mouse_name    =  EXP_CONFIG.MOUSE_NAME;
        behav_data(n).exp_date      =  EXP_CONFIG.EXP_DATE;
        %%%%% timing info %%%%%%
        behav_data(n).id_part       = k; %% k th file of the day
        behav_data(n).frame_idx     = raw_data.frame_idx(idx);
        behav_data(n).t_global_s    = raw_data.t_global_s(idx);
        % behav_data(n).mouse_center_deg = raw_data.mouse_center_deg(idx);  % mouse's degree with respect to the vitual world. Not very useful
        
        
    
        % ========================================================
        %%%%%% positions, horizontal change and velocity
        %%%%%% and some translate between degree and centermeters
        % ========================================================
        
        x_rel_deg_tmp = raw_data.slot1_x_deg_rel(idx); 
        x_rel_deg_tmp(x_rel_deg_tmp > 180) = x_rel_deg_tmp(x_rel_deg_tmp > 180) - 360; %% translate to [-180 to 180];
    
        behav_data(n).x_rel_deg         = x_rel_deg_tmp;
        behav_data(n).x_rel_cm          = x_rel_deg_tmp * (EXP_CONFIG(k).SPACE_WIDTH_CM / EXP_CONFIG(k).SPACE_DEGREES);
        behav_data(n).y_cm              = raw_data.slot1_y_cm(idx); 
        behav_data(n).delta_hori_cm     = raw_data.delta_cm(idx); %%%% 
        behav_data(n).delta_hori_deg    = behav_data(n).delta_hori_cm  * (EXP_CONFIG(k).SPACE_DEGREES / EXP_CONFIG(k).SPACE_WIDTH_CM); 
       
        if behav_data(n).y_cm(end) < (EXP_CONFIG(k).CIRCLE_RADIUS_CM  + 2 * EXP_CONFIG(k).BALL_FALL_SPEED_CM_S / EXP_CONFIG(k).FRAME_RATE)
            %%%%%%% add another two steps of y, only because in early sessions, the
            %%%%%%% last status of balls was not logged
            behav_data(n).reached_bottom = 1;
        else
            behav_data(n).reached_bottom = 0;
        end
        
        %%%%% rewarded or not %%%%%%%%%%%%%
        idx_end = find(idx,1, 'last');
        if i < nBall | idx_end < numel(raw_data.reward_state) 
            %%%% Used to only look at idx(end)+1. But since I changed the code
            %%%% (starting from 02/27) such that the last position of ball
            %%%% is logged, idx(end) also can reflect whether a trial is
            %%%% rewarded
            behav_data(n).rewarded          = raw_data.reward_state(idx_end + 1) | ...
                                              raw_data.reward_state(idx_end);
        else 
            %%%%% All these codes are just for rescuing the reward
            %%%%% information of the very last ball....

            %%% the last ball, idx+1 can be out of range
            last_reward_state = raw_data.reward_state(idx_end);
            if last_reward_state == 1
                %%% clearly recorded this trial was rewarded
                behav_data(n).rewarded = 1;
            else
                if behav_data(n).reached_bottom == 0
                    % if did not reach bottom, then definitely not rewarded
                    behav_data(n).rewarded = 0;
                else
                    % check if within the reward zone
                    behav_data(n).rewarded  = behav_data(n).x_rel_deg(end) > EXP_CONFIG(k).tolerance_space_deg(1) & ...
                        behav_data(n).x_rel_deg(end) < EXP_CONFIG(k).tolerance_space_deg(2);
                end
            end
                 
        end

        % ========================================================
        %%% add some fields from easy analysis
        % ========================================================
    
        %%%%%%% initial position, whether initial position is in reward zone
        behav_data(n).initial_x_rel_cm      = behav_data(n).x_rel_cm(1);
        behav_data(n).end_x_rel_cm          = behav_data(n).x_rel_cm(end);
        
        behav_data(n).initial_x_rel_deg      = behav_data(n).x_rel_deg(1);
        behav_data(n).end_x_rel_deg          = behav_data(n).x_rel_deg(end);
    
        %   
        if behav_data(n).initial_x_rel_deg < EXP_CONFIG(k).tolerant_space_deg(2) & behav_data(n).initial_x_rel_deg > EXP_CONFIG(k).tolerant_space_deg(1)
            behav_data(n).initial_in_reward  = 1;
        else
            behav_data(n).initial_in_reward  = 0;
        end
    
        %%%%%%% reaction time?
        
    
        %%%%%% How much the ball moved totally
        behav_data(n).sum_delta_hori_cm         = sum(behav_data(n).delta_hori_cm);
        behav_data(n).sum_abs_delta_hori_cm     = sum(abs(behav_data(n).delta_hori_cm));
        behav_data(n).sum_delta_hori_deg        = sum(behav_data(n).delta_hori_deg);
        behav_data(n).sum_abs_delta_hori_deg    = sum(abs(behav_data(n).delta_hori_deg));
    
        %%%% whether the movement is goal directed: i.e. toward the center
        %%%% if these two variables are opposite signs, it is goal-directed
        %%%% zero means static
        behav_data(n).is_goal_directed_movement = -sign(behav_data(n).x_rel_cm) .* sign(behav_data(n).delta_hori_cm);
        idx_zero_x_rel = behav_data(n).x_rel_cm == 0;
        %%%% if the ball is at center then any movement is anti-goal-directed
        behav_data(n).is_goal_directed_movement(idx_zero_x_rel & abs(behav_data(n).delta_hori_cm) > 0) = -1;
    
    
        behav_data(n).sum_delta_goal_directed_cm    = sum(abs(behav_data(n).delta_hori_cm(behav_data(n).is_goal_directed_movement == 1)));
        behav_data(n).sum_delta_goal_directed_deg   = sum(abs(behav_data(n).delta_hori_deg(behav_data(n).is_goal_directed_movement == 1)));
        behav_data(n).percent_goal_directed         = sum(behav_data(n).is_goal_directed_movement == 1) / numel(behav_data(n).is_goal_directed_movement);
        behav_data(n).percent_anti_goal_directed    = sum(behav_data(n).is_goal_directed_movement == -1) / numel(behav_data(n).is_goal_directed_movement);
        behav_data(n).percent_static                = sum(behav_data(n).is_goal_directed_movement == 0) / numel(behav_data(n).is_goal_directed_movement);
    
        
    
    end
    N_exist =  numel(behav_data); % how many balls already existed in the struct
end
end



%% helper functions

function data = read_slot(data)
    %%%%%% Convert the slot column into numerical variables
    slot = data.("slot1");        % string array or cellstr
    slot = string(slot);           % ensure it's string type
    slot = erase(slot, "'");       % remove quotes if present

    valid = strlength(strtrim(slot)) > 0;

    parts = strings(height(data), 4);   % preallocate with missing

    parts(valid,:) = split(slot(valid), "|");

    slot1_spawn_id       = nan(height(data),1);
    slot1_x_deg_rel          = nan(height(data),1);
    slot1_y_cm           = nan(height(data),1);
    slot1_is_visible     = nan(height(data),1);
    
    slot1_spawn_id(valid)   = str2double(parts(valid,1));
    slot1_x_deg_rel(valid)        = str2double(parts(valid,2));
    slot1_y_cm(valid)         = str2double(parts(valid,3));
    slot1_is_visible(valid)   = str2double(parts(valid,4));

    data.slot1_spawn_id     = slot1_spawn_id;
    data.slot1_x_deg_rel        = slot1_x_deg_rel;
    data.slot1_y_cm         = slot1_y_cm;
    data.slot1_is_visible   = slot1_is_visible;

end

function x_deg =  cm_to_deg(x_cm, SPACE_DEGREES, SPACE_CM)
x_deg =  mod(x_cm, SPACE_CM) * (SPACE_DEGREES / SPACE_CM);
end