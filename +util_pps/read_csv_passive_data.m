function [behav_data, prbs_rising_t] = read_csv_passive_data(meta_folder, mouse_name, exp_date)

csv_filename_list = dir(fullfile(meta_folder,sprintf('sync_log_pps_passive_%s_%s_*.csv', mouse_name, exp_date)));
if isempty(csv_filename_list)
    csv_filename_list = dir(fullfile(meta_folder,sprintf('sync_log_%s_%s_*.csv', mouse_name, exp_date)));
end

behav_data = struct();
N_exist = 0;
prbs_rising_t = cell(numel(csv_filename_list),1);
for k = 1:numel(csv_filename_list)
    %csv_filename = sprintf('sync_log_%s_%s_%s.csv',EXP_CONFIG(k).MOUSE_NAME, EXP_CONFIG(k).EXP_DATE, EXP_CONFIG(k).START_TIME_MIN);
    % if ~isfile(fullfile(meta_folder,csv_filename))
    %     csv_filename = sprintf('sync_log_pps_passive_%s_%s_%s.csv',EXP_CONFIG(k).MOUSE_NAME, EXP_CONFIG(k).EXP_DATE, EXP_CONFIG(k).START_TIME_MIN);
    % end
    csv_filename = fullfile(meta_folder, csv_filename_list(k).name);

    opts = detectImportOptions(csv_filename);
    opts = setvartype(opts, "slot1", "string");  % or "char"

    opts = setvartype(opts, "t_global_s", "double");
    opts = setvaropts(opts, "t_global_s", "TreatAsMissing", {'NA','NaN','nan','missing'});

    raw_data = readtable(csv_filename, opts);

    %%%%% read prbs if exist
    if ismember('prbs_val', raw_data.Properties.VariableNames)

        rising_edges = find(diff(raw_data.prbs_val) == 1) + 1;
        prbs_rising_t{k} = raw_data.t_global_s(rising_edges);
    end

    raw_data = read_slot_passive(raw_data);

    %%% split based on ball ID
    ball_list = unique(raw_data.slot1_spawn_id(~isnan(raw_data.slot1_spawn_id)));
    nBall = numel(ball_list);
    for i = 1:nBall
        idx = raw_data.slot1_spawn_id == ball_list(i);

        n   =  i   + N_exist ;

        %%%% basic info, subject code, exp_date
        behav_data(n).mouse_name    =  mouse_name;
        behav_data(n).exp_date      =  exp_date;
        %%%%% timing info %%%%%%
        behav_data(n).id_part       = k; %% k th file of the day
        behav_data(n).ball_id       = raw_data.slot1_spawn_id(find(idx,1));
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

        behav_data(n).frame_idx     = raw_data.frame_idx(idx);
        behav_data(n).t_global_s    = raw_data.t_global_s(idx);
        behav_data(n).t_global_s_onset = behav_data(n).t_global_s(1);

        behav_data(n).x_rel_cm = raw_data.slot1_x_cm_rel(idx);

        behav_data(n).y_cm              = raw_data.slot1_y_cm(idx);
    end
end
prbs_rising_t = cat(1,prbs_rising_t{:});
end

function data = read_slot_passive(data)
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
slot1_x_cm_rel     = nan(N,1);
slot1_y_cm         = nan(N,1);
slot1_is_visible   = nan(N,1);
slot1_ball_radius  = nan(N,1);   % NEW

% --- assign safely ---
switch n_fields

    case 5 % second version where I added radius
        % slot_id|x_deg|y_cm|is_visible|ball_radius
        slot1_spawn_id(valid) = str2double(parts(valid,1));
        slot1_x_cm_rel(valid) = str2double(parts(valid,2));
        slot1_y_cm(valid) = str2double(parts(valid,3));
        slot1_is_visible(valid) = str2double(parts(valid,4));
        slot1_ball_radius(valid) = str2double(parts(valid,5));

        data.slot1_spawn_id   = slot1_spawn_id;
        data.slot1_x_cm_rel  = slot1_x_cm_rel;
        data.slot1_y_cm       = slot1_y_cm;
        data.slot1_is_visible = slot1_is_visible;
        data.slot1_ball_radius = slot1_ball_radius;


end

end