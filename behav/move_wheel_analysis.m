clear all
clc
close all

%%
subjectCode = 'GD_3_pink';
%exp_date     = '20260406';
exp_date_list = {'20260331';'20260401';'20260402';'20260403';'20260406';'20260407';'20260408'};
nSession = numel(exp_date_list);
running_avg_prctiles    = zeros(nSession, 2);
running_avg_min         = zeros(nSession, 1);
for k = 1:numel(exp_date_list)
    exp_date = exp_date_list{k};
    meta_folder = fullfile('../../meta_data_local/', [subjectCode,'_',exp_date]);
    
    csv_file_list = dir(fullfile(meta_folder,sprintf('sync_log_wheelmove_%s_%s_*',subjectCode,exp_date)));
    
    raw_data_all  = [];
    for n = 1:numel(csv_file_list)
        raw_data = readtable(fullfile(meta_folder, csv_file_list(n).name));
        raw_data_all = [raw_data_all; raw_data];
    end
    %%%%
    idx_reward = find(raw_data_all.reward_amount > 0);
    reward_vel = raw_data_all.running_velocity(idx_reward-1);
    running_avg_min(k) = min(reward_vel);
    running_avg_prctiles(k,1) = prctile(reward_vel, 50);
    running_avg_prctiles(k,2) = prctile(reward_vel, 70);
    % %%%%
    % abs_delta_cm = abs(raw_data_all.delta_cm(2:end));
    % t_global_s = raw_data_all.t_global_s;
    % delta_t = raw_data_all.t_global_s(2:end) - raw_data_all.t_global_s(1:end-1);
    % abs_velo_cm = abs_delta_cm./delta_t;
    % % use movmean with time window
    % running_avg = movmean(abs_velo_cm, [1 0], 'SamplePoints', t_global_s(2:end));
    % running_avg = running_avg(running_avg ~= 0);
    % median_running_avg(k) = prctile(running_avg, 50);
    idx_left = raw_data_all.delta_cm < 0;
    idx_right = raw_data_all.delta_cm > 0;
    delta_x_left(k) = sum(abs(raw_data_all.delta_cm(idx_left)));
    delta_x_right(k) = sum(abs(raw_data_all.delta_cm(idx_right)));
end
figure;  hold on
plot(running_avg_prctiles(:,1),'-o');
plot(running_avg_prctiles(:,2),'-o');
plot(running_avg_min, '-o')

figure; hold on
plot(delta_x_left, '-o');
plot(delta_x_right,'--o');