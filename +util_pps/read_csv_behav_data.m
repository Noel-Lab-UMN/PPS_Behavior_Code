function behav_data = read_csv_behav_data(meta_folder, EXP_CONFIG)
MOUSE_NAME = EXP_CONFIG.MOUSE_NAME;
csv_filename_list = dir(fullfile(meta_folder,sprintf('sync_log_pps_behav_%s*.csv', MOUSE_NAME)));
if isempty(csv_filename_list)
    csv_filename_list = dir(fullfile(meta_folder,sprintf('sync_log_%s*.csv', MOUSE_NAME)));
end
if numel(csv_filename_list) ~= numel(EXP_CONFIG)
    error('Your config files and data files do not match. Please check')
end
behav_data = struct(); 
N_exist = 0;
for k = 1:numel(EXP_CONFIG)
    csv_filename = sprintf('sync_log_%s_%s_%s.csv',EXP_CONFIG(k).MOUSE_NAME, EXP_CONFIG(k).EXP_DATE, EXP_CONFIG(k).START_TIME_MIN);
    if ~isfile(fullfile(meta_folder,csv_filename))
        csv_filename = sprintf('sync_log_pps_behav_%s_%s_%s.csv',EXP_CONFIG(k).MOUSE_NAME, EXP_CONFIG(k).EXP_DATE, EXP_CONFIG(k).START_TIME_MIN);
    end
    
 
    opts = detectImportOptions(fullfile(meta_folder, csv_filename));
    opts = setvartype(opts, "slot1", "string");  % or "char"
    
    opts = setvartype(opts, "t_global_s", "double");
    opts = setvaropts(opts, "t_global_s", "TreatAsMissing", {'NA','NaN','nan','missing'});

    raw_data = readtable(fullfile(meta_folder, csv_filename), opts);

    %raw_data = readtable(fullfile(meta_folder, csv_filename));
    raw_data = read_slot(raw_data);

    %%% split based on ball ID
    ball_list = unique(raw_data.slot1_spawn_id(~isnan(raw_data.slot1_spawn_id)));
    nBall = numel(ball_list);
    
    %%%%% 
    % Remove the first ball in each csv file due to some bug in the
    % experimental code. But this code was fixed starting from 20260423
    %%%%% 
    if datetime(EXP_CONFIG(k).EXP_DATE,'inputformat','yyyyMMdd') >= datetime('20260423','inputformat','yyyyMMdd')
        start_id = 1;
    else
        start_id = 2;
    end
    for i = start_id:numel(ball_list)
        idx = raw_data.slot1_spawn_id == ball_list(i);

        n = i  - (start_id - 1) + N_exist ;
        %%%% basic info, subject code, exp_date
        behav_data(n).mouse_name    =  EXP_CONFIG.MOUSE_NAME;
        behav_data(n).exp_date      =  EXP_CONFIG.EXP_DATE;
        %%%%% timing info %%%%%%
        behav_data(n).id_part       = k; %% k th file of the day
        if any(strcmp('slot1_ball_radius',fieldnames(raw_data)))
            behav_data(n).ball_radius = raw_data.slot1_ball_radius(find(idx,1));
        end

        if any(strcmp('slot1_ball_opacity',fieldnames(raw_data)))
            behav_data(n).ball_opacity = raw_data.slot1_ball_opacity(find(idx,1));
        end
        
        if any(strcmp('slot1_ball_speed',fieldnames(raw_data)))
            behav_data(n).ball_y_speed = raw_data.slot1_ball_speed(find(idx,1));
        end

        if any(strcmp('slot1_ball_random_bias',fieldnames(raw_data)))
            behav_data(n).ball_random_bias = raw_data.slot1_ball_random_bias(find(idx,1));
        end

        if any(strcmp('slot1_ball_random_std',fieldnames(raw_data)))
            behav_data(n).ball_random_std = raw_data.slot1_ball_random_std(find(idx,1));
        end

        gain_list_str = raw_data.gain_applied(find(idx,1));
        gain_list_vals = parse_num_list(gain_list_str);
        behav_data(n).region_gain = gain_list_vals(1);
        if numel(gain_list_vals) > 1
            behav_data(n).wheel_gain = gain_list_vals(2);
            behav_data(n).wheel_jitter = gain_list_vals(3);
        
        
            behav_data(n).delta_ticks = raw_data.delta_ticks_corrected(idx);
            %%%%% this is without the jitteing. how much it would move if just
            %%%%% tick * gain
            behav_data(n).delta_cm_no_jitter = behav_data(n).delta_ticks * behav_data(n).wheel_gain;
            %%%%% this is how much it actually moved
            behav_data(n).delta_cm_jitter = raw_data.base_delta_cm(idx);
            behav_data(n).jitter_only = behav_data(n).delta_cm_jitter - behav_data(n).delta_cm_no_jitter;
        end



        behav_data(n).frame_idx     = raw_data.frame_idx(idx);
        behav_data(n).t_global_s    = raw_data.t_global_s(idx);
        % behav_data(n).mouse_center_deg = raw_data.mouse_center_deg(idx);  % mouse's degree with respect to the vitual world. Not very useful
        
        
    
        % ========================================================
        %%%%%% positions, horizontal change and velocity
        %%%%%% and some translate between degree and centermeters
        % ========================================================
        
        x_rel_deg_tmp = raw_data.slot1_x_deg_rel(idx); 
        x_rel_deg_tmp(x_rel_deg_tmp > 180) = x_rel_deg_tmp(x_rel_deg_tmp > 180) - 360; %% translate to [-180 to 180];
    
        %behav_data(n).x_rel_deg         = x_rel_deg_tmp;
        behav_data(n).x_rel_cm          = x_rel_deg_tmp * (EXP_CONFIG(k).SPACE_WIDTH_CM / EXP_CONFIG(k).SPACE_DEGREES);
        behav_data(n).y_cm              = raw_data.slot1_y_cm(idx); 
        behav_data(n).delta_hori_cm     = raw_data.delta_cm(idx); %%%% this is wheel only

        %behav_data(n).delta_hori_deg    = behav_data(n).delta_hori_cm  * (EXP_CONFIG(k).SPACE_DEGREES / EXP_CONFIG(k).SPACE_WIDTH_CM); 
        
        %%%% extract random walk: delta_x - delta_cm_wheel
        behav_data(n).x_random_walk     = behav_data(n).x_rel_cm - behav_data(n).delta_hori_cm;


        if isfield(EXP_CONFIG(k), 'CIRCLE_RADIUS_CM')
            radius = EXP_CONFIG(k).CIRCLE_RADIUS_CM;
        elseif isfield(behav_data(n), 'ball_radius')
            radius = behav_data(n).ball_radius;
        end
        if isfield(EXP_CONFIG(k), 'BALL_FALL_SPEED_CM_S')
            y_speed = EXP_CONFIG(k).BALL_FALL_SPEED_CM_S;
        elseif isfield(behav_data(n), 'ball_y_speed')
            y_speed = behav_data(n).ball_y_speed;
        end

        if behav_data(n).y_cm(end) < (radius  + 2 * y_speed / EXP_CONFIG(k).FRAME_RATE)
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
                    behav_data(n).rewarded  = behav_data(n).x_rel_cm(end) > EXP_CONFIG(k).tolerant_space_cm(1) & ...
                        behav_data(n).x_rel_cm(end) < EXP_CONFIG(k).tolerant_space_cm(2);
                end
            end
                 
        end

        % ========================================================
        %%% add some fields from easy analysis
        % ========================================================
    
        %%%%%%% initial position, whether initial position is in reward zone
        behav_data(n).initial_x_rel_cm      = behav_data(n).x_rel_cm(1);
        behav_data(n).end_x_rel_cm          = behav_data(n).x_rel_cm(end);
        
       % behav_data(n).initial_x_rel_deg      = behav_data(n).x_rel_deg(1);
        %behav_data(n).end_x_rel_deg          = behav_data(n).x_rel_deg(end);
    
        %   
        if behav_data(n).initial_x_rel_cm < EXP_CONFIG(k).tolerant_space_cm(2) & behav_data(n).initial_x_rel_cm > EXP_CONFIG(k).tolerant_space_cm(1)
            behav_data(n).initial_in_reward  = 1;
        else
            behav_data(n).initial_in_reward  = 0;
        end
    
        %%%%%%% minimal effort to get ball into reward zone
       % behav_data(n).minimal_effort = min(abs(behav_data(n).initial_x_rel_cm - EXP_CONFIG(k).tolerant_space_cm));
        
    
        %%%%%% How much the ball moved totally
        behav_data(n).sum_delta_hori_cm         = sum(behav_data(n).delta_hori_cm);
        behav_data(n).sum_abs_delta_hori_cm     = sum(abs(behav_data(n).delta_hori_cm));
        %behav_data(n).sum_delta_hori_deg        = sum(behav_data(n).delta_hori_deg);
        %behav_data(n).sum_abs_delta_hori_deg    = sum(abs(behav_data(n).delta_hori_deg));
        %behav_data(n).is_moved                  =  behav_data(n).sum_abs_delta_hori_cm >= behav_data(n).minimal_effort;

        %%%%% By shizhao liu 04/22, use a threshold to determine if balls are
        %%%%% moved
        behav_data(n).is_moved                  =  behav_data(n).sum_abs_delta_hori_cm >= EXP_CONFIG(k).MOVEMENT_THRESHOLD;
    
        %%%% whether the movement is goal directed: i.e. toward the center
        %%%% if these two variables are opposite signs, it is goal-directed
        %%%% zero means static
        behav_data(n).is_goal_directed_movement = -sign(behav_data(n).x_rel_cm) .* sign(behav_data(n).delta_hori_cm);
        idx_zero_x_rel = behav_data(n).x_rel_cm == 0;
        %%%% if the ball is at center then any movement is anti-goal-directed
        behav_data(n).is_goal_directed_movement(idx_zero_x_rel & abs(behav_data(n).delta_hori_cm) > 0) = -1;
    
    
        behav_data(n).sum_delta_goal_directed_cm    = sum(abs(behav_data(n).delta_hori_cm(behav_data(n).is_goal_directed_movement == 1)));
        %behav_data(n).sum_delta_goal_directed_deg   = sum(abs(behav_data(n).delta_hori_deg(behav_data(n).is_goal_directed_movement == 1)));
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

    % --- split first to detect number of fields ---
    split_cells = split(slot(valid), "|");
    n_fields = size(split_cells, 2);   % 4 or 5 or 8

    % --- preallocate with max possible (8) ---
    parts = strings(height(data), min(n_fields,8));
    parts(valid,1:n_fields) = split_cells;

    % --- initialize outputs ---
    N = height(data);

    slot1_spawn_id     = nan(N,1);
    slot1_x_deg_rel    = nan(N,1);
    slot1_y_cm         = nan(N,1);
    slot1_is_visible   = nan(N,1);
    slot1_ball_radius  = nan(N,1);   % NEW

    slot1_ball_opacity = nan(N,1); 
    slot1_ball_speed = nan(N,1);
    slot1_ball_random_bias = nan(N,1);
    slot1_ball_random_std = nan(N,1); 


    % --- assign safely ---
    switch n_fields
        case 4 % the very first version
            % slot_id|x_deg|y_cm|is_visible
            slot1_spawn_id(valid) = str2double(parts(valid,1));
            slot1_x_deg_rel(valid) = str2double(parts(valid,2));
            slot1_y_cm(valid) = str2double(parts(valid,3));
            slot1_is_visible(valid) = str2double(parts(valid,4));

            data.slot1_spawn_id   = slot1_spawn_id;
            data.slot1_x_deg_rel  = slot1_x_deg_rel;
            data.slot1_y_cm       = slot1_y_cm;
            data.slot1_is_visible = slot1_is_visible;

        case 5 % second version where I added radius
            % slot_id|x_deg|y_cm|is_visible|ball_radius
            slot1_spawn_id(valid) = str2double(parts(valid,1));
            slot1_x_deg_rel(valid) = str2double(parts(valid,2));
            slot1_y_cm(valid) = str2double(parts(valid,3));
            slot1_is_visible(valid) = str2double(parts(valid,4));
            slot1_ball_radius(valid) = str2double(parts(valid,5));

            data.slot1_spawn_id   = slot1_spawn_id;
            data.slot1_x_deg_rel  = slot1_x_deg_rel;
            data.slot1_y_cm       = slot1_y_cm;
            data.slot1_is_visible = slot1_is_visible;
            data.slot1_ball_radius = slot1_ball_radius;
        case 8 % the third version where I removed "is_visible" and added more fields
            % slot_id|x_deg|y_cm|ball_radius|opacity|y_speed|random_walk_bias|random_walk|std
            slot1_spawn_id(valid) = str2double(parts(valid,1));
            slot1_x_deg_rel(valid) = str2double(parts(valid,2));
            slot1_y_cm(valid) = str2double(parts(valid,3));
            slot1_ball_radius(valid) = str2double(parts(valid,4));
            slot1_ball_opacity(valid)   = str2double(parts(valid, 5));
            slot1_ball_speed(valid)     = str2double(parts(valid, 6));
            slot1_ball_random_bias(valid) = str2double(parts(valid, 7));
            slot1_ball_random_std(valid) = str2double(parts(valid, 8));
        
            data.slot1_spawn_id         = slot1_spawn_id;
            data.slot1_x_deg_rel        = slot1_x_deg_rel;
            data.slot1_y_cm             = slot1_y_cm;
            data.slot1_ball_radius      = slot1_ball_radius;
            data.slot1_ball_opacity     = slot1_ball_opacity;
            data.slot1_ball_speed       = slot1_ball_speed;
            data.slot1_ball_random_bias = slot1_ball_random_bias;
            data.slot1_ball_random_std  = slot1_ball_random_std;

    end





end

function x_deg =  cm_to_deg(x_cm, SPACE_DEGREES, SPACE_CM)
x_deg =  mod(x_cm, SPACE_CM) * (SPACE_DEGREES / SPACE_CM);
end

function vals = parse_num_list(str)

    % Ensure string type
    str = string(str);

    % Remove brackets and quotes
    str_clean = erase(str, ["[", "]", "'"]);

    % Split by comma
    parts = split(str_clean, ",");

    % Remove empty entries (important!)
    parts = strtrim(parts);
    parts(parts == "") = [];

    % Convert to numbers
    vals = str2double(parts);

end