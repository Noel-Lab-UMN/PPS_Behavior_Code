function EXP_CONFIG = read_json_config(meta_folder, subject_code, exp_date)
%EXP_CONFIG = struct();
config_filename_list = dir(fullfile(meta_folder,sprintf('exp_config_pps_behav_%s_%s_*.json', subject_code, exp_date)));
if isempty(config_filename_list)
    % older version of file name 
    config_filename_list = dir(fullfile(meta_folder,sprintf('exp_config_pps_%s_%s_*.json', subject_code, exp_date)));
end
for k = 1:numel(config_filename_list)
    json_name = fullfile(meta_folder, config_filename_list(k).name);
    if  datetime(exp_date,'InputFormat','yyyyMMdd') >= datetime('20260407','InputFormat','yyyyMMdd')
        %%%% new version 
         EXP_CONFIG(k) = process_json_new_version(json_name, subject_code);
    else
        %%%%% older version
        EXP_CONFIG(k) = process_json_old_version(json_name);
    end


end

end

function EXP_CONFIG = process_json_new_version(json_name, subject_code)
jsonStr = fileread(json_name);
EXP_CONFIG = jsondecode(jsonStr);
if isfield(EXP_CONFIG.metadata, 'mouse_name')
    EXP_CONFIG.MOUSE_NAME = EXP_CONFIG.metadata.mouse_name;
else
    EXP_CONFIG.MOUSE_NAME = subject_code;
end
EXP_CONFIG.EXP_DATE = EXP_CONFIG.metadata.timestamp(1:8);
EXP_CONFIG.START_TIME_MIN = EXP_CONFIG.metadata.timestamp(10:end);
EXP_CONFIG.SPACE_DEGREES = EXP_CONFIG.config.experiment.SPACE_DEGREES;
EXP_CONFIG.SCREEN_WIDTH_CM = EXP_CONFIG.config.hardware.SCREEN_WIDTH_CM;
EXP_CONFIG.SPACE_WIDTH_CM = EXP_CONFIG.config.hardware.SCREEN_WIDTH_CM * 2.0;
try
    EXP_CONFIG.BALL_FALL_SPEED_CM_S = EXP_CONFIG.config.experiment.BALL_FALL_SPEED_CM_S;
end

EXP_CONFIG.FRAME_RATE  = EXP_CONFIG.config.hardware.FRAME_RATE;
EXP_CONFIG.tolerant_space_cm = EXP_CONFIG.config.experiment.SUCCESS_EDGE_TOLERANCE_RANGE;
%EXP_CONFIG.REWARD_TARGET  = EXP_CONFIG.config.reward.
end

function EXP_CONFIG = process_json_old_version(json_name)
    jsonStr = fileread(json_name);
    
    EXP_CONFIG = jsondecode(jsonStr);

    EXP_CONFIG.START_TIME_MIN =  json_name(end-8:end-5);
    
  
    %%%%% Make the exp code save these instead of manually copy!!
    if ~isfield(EXP_CONFIG, 'EXP_DATE') | isempty(EXP_CONFIG.EXP_DATE)
        EXP_CONFIG.EXP_DATE = exp_date;
    end
    if ~isfield(EXP_CONFIG, 'SPACE_DEGREES') | isempty(EXP_CONFIG.SPACE_DEGREES)
        EXP_CONFIG.SPACE_DEGREES = 360;
    end
    if ~isfield(EXP_CONFIG, 'SPAWN_DISTRIBUTION') | isempty(EXP_CONFIG.SPAWN_DISTRIBUTION)
        EXP_CONFIG.SPAWN_DISTRIBUTION = 'uniform';
    end
    
    if ~isfield(EXP_CONFIG, 'FRAME_RATE') | isempty(EXP_CONFIG.FRAME_RATE)
        EXP_CONFIG.FRAME_RATE = 60;
    end
    
    %%%%%% calculate the reward zone in degrees (relative to the animal)
    %%%% in centermeters relative to the animal
    if isfield(EXP_CONFIG, 'SUCCESS_EDGE_TOLERANCE_MULT')
        tolerant_space_cm   = [-EXP_CONFIG.SUCCESS_EDGE_TOLERANCE_MULT * EXP_CONFIG.CIRCLE_RADIUS_CM, ...
                            EXP_CONFIG.SUCCESS_EDGE_TOLERANCE_MULT * EXP_CONFIG.CIRCLE_RADIUS_CM];
    elseif isfield(EXP_CONFIG,'SUCCESS_EDGE_TOLERANCE_RANGE')
        tolerant_space_cm = EXP_CONFIG.SUCCESS_EDGE_TOLERANCE_RANGE;
    end
    
    %tolerant_space_deg  = tolerant_space_cm * (EXP_CONFIG.SPACE_DEGREES / EXP_CONFIG.SPACE_WIDTH_CM);
    
    switch EXP_CONFIG.SPAWN_DISTRIBUTION
        case 'uniform'
            chance_level_null   = (tolerant_space_cm(2) - tolerant_space_cm(1)) / (EXP_CONFIG.SCREEN_WIDTH_CM);
        case 'gaussian'
            %%% 
            n_center    = numel(EXP_CONFIG.SPAWN_GAUSS_CENTER_LIST);
            p_in_null   = zeros(n_center,1);
            for i = 1:n_center
                p_in_null(i) = normcdf(tolerant_space_cm(2), EXP_CONFIG.SPAWN_GAUSS_CENTER_LIST(i), EXP_CONFIG.SPAWN_GAUSS_SIGMA_CM) - ...
                        normcdf(tolerant_space_cm(1), EXP_CONFIG.SPAWN_GAUSS_CENTER_LIST(i), EXP_CONFIG.SPAWN_GAUSS_SIGMA_CM);
            end
            chance_level_null = mean(p_in_null);
    
    end
    chance_level_random   = (tolerant_space_cm(2) - tolerant_space_cm(1)) / (EXP_CONFIG.SPACE_WIDTH_CM);

    EXP_CONFIG.tolerant_space_cm         = tolerant_space_cm;
    %EXP_CONFIG.tolerant_space_deg        = tolerant_space_deg;
    EXP_CONFIG.chance_level_null         = chance_level_null;
    EXP_CONFIG.chance_level_random       = chance_level_random;

end