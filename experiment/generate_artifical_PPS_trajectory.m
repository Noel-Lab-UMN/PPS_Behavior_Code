clear all
clc
close all
%%
frame_freq  = 60; % in Hz
y_0         = 30; % in cm  
y_vel       = 25; % in cm/s
isi_sec     = 3; % in seconds
csv_save_name = 'synthetic_PPS_trajectory_habituation_longisi.csv'; 
x_0_list = [-15, -12, -9, -6, 6, 9, 12, 15]; % in cm
reward_amount_list = [1.5, 1.5, 1.0, 1.0, 1.0, 1.0, 1.5, 1.5];
reward_level_list = zeros(size(x_0_list));
for n = 1:numel(reward_level_list)
    reward_level_list(n) = find(unique(abs(x_0_list)) == abs(x_0_list(n)));
end
frac_move_list = [0,0,0, 10, 25, 50, 100]; % % in percent, if 0, no rewarsa
ball_radius_list = [1.5, 3];

nRep = 1;
k = 1;
for i  = 1:numel(x_0_list)
    for j = 1:numel(frac_move_list)
        for m = 1:numel(ball_radius_list)
            x_0         = x_0_list(i); 
            reward_level = reward_level_list(i);
            reward_amount = reward_amount_list(i);
            frac_move   = frac_move_list(j);
            ball_radius = ball_radius_list(m);
            for n = 1:nRep
                [x,y] = generate_single_trajectory(x_0, frac_move, y_0, y_vel, frame_freq);
                synth_trajectory(k).x = x;
                synth_trajectory(k).y = y;
                synth_trajectory(k).ball_radius = ball_radius;

                if frac_move == 0
                    is_reward = 0;
                    
                else
                    is_reward = 1;
                end
                reward_level =  is_reward * reward_level;

                synth_trajectory(k).is_reward = is_reward;
                synth_trajectory(k).reward_level = reward_level;
                synth_trajectory(k).reward_amount = reward_amount;
                k = k+1;
            end
        end
        
    end
end

%% permute the trial order
idx_perm = randperm(numel(synth_trajectory));
synth_trajectory = synth_trajectory(idx_perm);

%%% get a sense of how much reward will be given
reward_total = sum([synth_trajectory(:).reward_amount]);
%%% get a sense of how long the sessions will be, in minutes
T = ((y_0 / y_vel) * numel(synth_trajectory) + isi_sec * (numel(synth_trajectory) - 1)) / 60;
%% Write CSV
table_out  = struct2table(synth_trajectory, frame_freq, y_vel, isi_sec);

writetable(table_out, csv_save_name);
%%
function [x,y] = generate_single_trajectory(x_0, frac_move, y_0, y_vel, frame_freq)

    T                   = frame_freq * ceil(y_0 / y_vel);        
    delta_y_single      = y_0 / T;
    delta_y             = ones(T,1) * delta_y_single;
    y                   = y_0 - cumsum(delta_y);
    
    if frac_move > 0
        n_move              = T * frac_move / 100;
        delta_x_single      = (0 - x_0) / n_move;
    else
        n_move = 0;
        delta_x_single = 0;
    end
    
    idx_move            = zeros(T, 1);
    idx_move(randsample([1:T],n_move)) = 1;
    
    delta_x             = idx_move * delta_x_single;
    
    x = x_0 + cumsum(delta_x);


end

function table_out  = struct2table(synth_trajectory, frame_freq, y_vel, isi_sec)

%%% Convert struct to frame-by-frame CSV table
frame_idx_all       = [];
t_global_s_all      = [];
linear_velocity_all = [];
reward_state_all    = [];
reward_amount_all   = [];
reward_level_all    = [];
slot1_all           = {};

frame_counter = 0;   % global frame counter across all trajectories
is_visible = 1;      % all frames visible

isi_frames = round(isi_sec * frame_freq);

for k = 1:numel(synth_trajectory)
    x = synth_trajectory(k).x;
    y = synth_trajectory(k).y;
    is_reward = synth_trajectory(k).is_reward;
 

    T = numel(x);

    % ===== stimulus frames =====
    % global frame indices for this trajectory
    frame_idx = (frame_counter + 1 : frame_counter + T)';
    t_global_s = frame_idx / frame_freq;
    linear_velocity = ones(T,1) * y_vel;
    reward_state = zeros(T,1);
    if is_reward == 1
        reward_state(end) = 1;
    end

    reward_level = zeros(T,1);
    reward_level(end) = synth_trajectory(k).reward_level;

    reward_amount = zeros(T,1);
    reward_amount(end) = synth_trajectory(k).reward_amount;



    % build slot_1 strings: "id|x_cm|y_cm|is_visible"
    slot1 = cell(T,1);
    ball_radius = synth_trajectory(k).ball_radius;
    for t = 1:T
        slot1{t} = sprintf('%d|%.3f|%.3f|%d|%.3f', k, x(t), y(t), is_visible, ball_radius);
    end

    % append
    frame_idx_all       = [frame_idx_all; frame_idx];
    t_global_s_all      = [t_global_s_all; t_global_s];
    linear_velocity_all = [linear_velocity_all; linear_velocity];
    reward_state_all    = [reward_state_all; reward_state];
    reward_amount_all   = [reward_amount_all; reward_amount]; 
    reward_level_all    = [reward_level_all; reward_level]; 
    slot1_all           = [slot1_all; slot1];

    % update global counter
    frame_counter = frame_counter + T;

    % ===== ISI frames =====
    frame_idx_isi = (frame_counter + 1 : frame_counter + isi_frames)';
    t_global_s_isi = frame_idx_isi / frame_freq;
    linear_velocity_isi = zeros(isi_frames,1);   % blank period
    reward_state_isi = zeros(isi_frames,1);
    reward_amount_isi  = zeros(isi_frames,1);
    reward_level_isi    = zeros(isi_frames, 1); 
    slot1_isi = repmat({''}, isi_frames, 1);

    frame_idx_all       = [frame_idx_all; frame_idx_isi];
    t_global_s_all      = [t_global_s_all; t_global_s_isi];
    linear_velocity_all = [linear_velocity_all; linear_velocity_isi];
    reward_state_all    = [reward_state_all; reward_state_isi];
    reward_amount_all   = [reward_amount_all; reward_amount_isi]; 
    reward_level_all    = [reward_level_all;reward_level_isi]; 
    slot1_all           = [slot1_all; slot1_isi];

    frame_counter = frame_counter + isi_frames;

end

%%% Make table
table_out = table( ...
    frame_idx_all, ...
    t_global_s_all, ...
    linear_velocity_all, ...
    reward_state_all, ...
    reward_amount_all,...
    reward_level_all,...
    slot1_all, ...
    'VariableNames', {'frame_idx','t_global_s','linear_velocity','reward_state','reward_amount','reward_level','slot1'});

end