function EXP_CONFIG = read_json_config(meta_folder, subject_code, exp_date)
%EXP_CONFIG = struct();
config_filename_list = dir(fullfile(meta_folder,'exp_config_*.json'));
for k = 1:numel(config_filename_list)
    jsonStr = fileread(fullfile(meta_folder, config_filename_list(k).name));
    EXP_CONFIG(k) = jsondecode(jsonStr);

    if strcmp(EXP_CONFIG(k).MOUSE_NAME ,'LSZ_practice_4_violet')
        EXP_CONFIG(k).MOUSE_NAME = 'LSZ_practice_5_violet'; % fix typo in exp
    end
end

for k = 1:numel(config_filename_list)
    EXP_CONFIG(k).START_TIME_MIN =  config_filename_list(k).name(end-8:end-5);
    
  
    %%%%% Make the exp code save these instead of manually copy!!
    if ~isfield(EXP_CONFIG(k), 'EXP_DATE') | isempty(EXP_CONFIG(k).EXP_DATE)
        EXP_CONFIG(k).EXP_DATE = exp_date;
    end
    if ~isfield(EXP_CONFIG(k), 'SPACE_DEGREES') | isempty(EXP_CONFIG(k).SPACE_DEGREES)
        EXP_CONFIG(k).SPACE_DEGREES = 360;
    end
    if ~isfield(EXP_CONFIG(k), 'SPAWN_DISTRIBUTION') | isempty(EXP_CONFIG(k).SPAWN_DISTRIBUTION)
        EXP_CONFIG(k).SPAWN_DISTRIBUTION = 'uniform';
    end
    
    if ~isfield(EXP_CONFIG(k), 'FRAME_RATE') | isempty(EXP_CONFIG(k).FRAME_RATE)
        EXP_CONFIG(k).FRAME_RATE = 60;
    end
    
    %%%%%% calculate the reward zone in degrees (relative to the animal)
    %%%% in centermeters relative to the animal
    tolerant_space_cm   = [-EXP_CONFIG(k).SUCCESS_EDGE_TOLERANCE_MULT * EXP_CONFIG(k).CIRCLE_RADIUS_CM, ...
                        EXP_CONFIG(k).SUCCESS_EDGE_TOLERANCE_MULT * EXP_CONFIG(k).CIRCLE_RADIUS_CM];
    
    tolerant_space_deg  = tolerant_space_cm * (EXP_CONFIG(k).SPACE_DEGREES / EXP_CONFIG(k).SPACE_WIDTH_CM);
    
    switch EXP_CONFIG(k).SPAWN_DISTRIBUTION
        case 'uniform'
            chance_level_null   = (tolerant_space_cm(2) - tolerant_space_cm(1)) / (EXP_CONFIG(k).SCREEN_WIDTH_CM);
        case 'gaussian'
            %%% 
            n_center    = numel(EXP_CONFIG(k).SPAWN_GAUSS_CENTER_LIST);
            p_in_null   = zeros(n_center,1);
            for i = 1:n_center
                p_in_null(i) = normcdf(tolerant_space_cm(2), EXP_CONFIG(k).SPAWN_GAUSS_CENTER_LIST(i), EXP_CONFIG(k).SPAWN_GAUSS_SIGMA_CM) - ...
                        normcdf(tolerant_space_cm(1), EXP_CONFIG(k).SPAWN_GAUSS_CENTER_LIST(i), EXP_CONFIG(k).SPAWN_GAUSS_SIGMA_CM);
            end
            chance_level_null = mean(p_in_null);
    
    end
    chance_level_random   = (tolerant_space_cm(2) - tolerant_space_cm(1)) / (EXP_CONFIG(k).SPACE_WIDTH_CM);

    EXP_CONFIG(k).tolerant_space_cm         = tolerant_space_cm;
    EXP_CONFIG(k).tolerant_space_deg        = tolerant_space_deg;
    EXP_CONFIG(k).chance_level_null         = chance_level_null;
    EXP_CONFIG(k).chance_level_random       = chance_level_random;
end

end