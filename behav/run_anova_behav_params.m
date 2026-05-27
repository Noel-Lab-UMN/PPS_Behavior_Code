clear all
clc
close all
global PPS_global
generate_PPS_global();


%%
subjectCode = 'LSZ_practice_5_violet';
data_folder = fullfile('../../results/behav/pps_processed', subjectCode);
eval(sprintf('session_list = PPS_global.%s.session_list.new_params;',subjectCode));
[session_id_all, ball_opacity_all, y_vel_all, has_random_walk_all, wheel_gain_all, has_wheel_jitter_all] = ...
    deal([]);
[is_rewarded_all, r_trajectory_all, target_distance_all] = deal([]);

for n = 1:numel(session_list)
    exp_date = session_list{n};
    load(fullfile(data_folder, sprintf('behav_data_PPS_%s_%s', subjectCode, exp_date)));
    
    idx        = [behav_data(:).is_moved] == 1 & [behav_data(:).reached_bottom] == 1;
   
    %idx_rewarded = [behav_data(:).is_rewarded] == 1;
    
    ball_opacity    = [behav_data(idx).ball_opacity];
    y_vel           = [behav_data(idx).ball_y_speed];

    random_std  = [behav_data(idx).ball_random_std];
    has_random_walk = abs(random_std) > 0;
    
    wheel_gain      = [behav_data(idx).wheel_gain];
    wheel_jittering = [behav_data(idx).wheel_jitter];
    has_wheel_jitter = abs(wheel_jittering) > 0;

    is_rewarded     = [behav_data(idx).rewarded]; 

    session_id   = ones(size(is_rewarded)) * n;

    target_distance =  util_pps.compute_target_distance(behav_data(idx));
    correlation_stats = util_pps.get_trajectory_correlation_stats(behav_data(idx));


    session_id_all = [session_id_all, session_id];
    is_rewarded_all = [is_rewarded_all, is_rewarded];
    r_trajectory_all = [r_trajectory_all, correlation_stats.r_all_moved];
    target_distance_all = [target_distance_all, target_distance.distance_moved];
    ball_opacity_all = [ball_opacity_all, ball_opacity];
    y_vel_all = [y_vel_all, y_vel];
    has_random_walk_all = [has_random_walk_all, has_random_walk];
    wheel_gain_all = [wheel_gain_all, wheel_gain];
    has_wheel_jitter_all = [has_wheel_jitter_all, has_wheel_jitter];




end
%%


tbl = table();

tbl.is_rewarded         = is_rewarded_all(:);
tbl.r_trajectory        = r_trajectory_all(:);
tbl.target_distance     = target_distance_all(:); 

tbl.opacity        = ball_opacity_all(:);
tbl.y_vel          = y_vel_all(:);

tbl.has_random_walk    = categorical(has_random_walk_all(:));
tbl.has_wheel_jitter   = categorical(has_wheel_jitter_all(:));

tbl.wheel_gain     = wheel_gain_all(:);

tbl.session        = categorical(session_id_all(:));

%%
tbl_reward = table();
tbl_reward.r_trajectory = tbl.r_trajectory(tbl.is_rewarded == 1);
tbl_reward.target_distance = tbl.target_distance(tbl.is_rewarded == 1);
tbl_reward.opacity = tbl.opacity(tbl.is_rewarded == 1);
tbl_reward.y_vel = tbl.y_vel(tbl.is_rewarded == 1);
tbl_reward.has_random_walk = tbl.has_random_walk(tbl.is_rewarded == 1);
tbl_reward.has_wheel_jitter = tbl.has_wheel_jitter(tbl.is_rewarded == 1);
tbl_reward.wheel_gain = tbl.wheel_gain(tbl.is_rewarded == 1);
tbl_reward.session = tbl.session(tbl.is_rewarded == 1);


%%
display('Effect on p-rewarded:');
glme = fitglme(tbl, ...
    ['is_rewarded ~ opacity + y_vel + has_random_walk + ' ...
     'wheel_gain * has_wheel_jitter + ' ...
     '(1|session)'], ...
    'Distribution','Binomial');

%anova(glme)

disp(glme.Coefficients)
%%
% display('Effect on corr-trajecory (moved):');
% glme = fitglme(tbl, ...
%     ['r_trajectory ~ opacity + y_vel + has_random_walk + ' ...
%      'wheel_gain * has_wheel_jitter + ' ...
%      '(1|session)']);
% 
% %anova(glme)
% 
% disp(glme.Coefficients)
%%
display('Effect on target-distance (rewarded):');
glme = fitglme(tbl_reward, ...
    ['target_distance ~ opacity + y_vel + has_random_walk + ' ...
     'wheel_gain * has_wheel_jitter + ' ...
     '(1|session)']);

%anova(glme)

disp(glme.Coefficients)
%% 
display('Effect on corr-trajecory (rewarded):');
glme = fitglme(tbl_reward, ...
    ['r_trajectory ~ opacity + y_vel + has_random_walk + ' ...
     'wheel_gain * has_wheel_jitter + ' ...
     '(1|session)']);

%anova(glme)

disp(glme.Coefficients)