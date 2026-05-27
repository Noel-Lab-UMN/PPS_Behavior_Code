clear all
clc
close all
%%
meta_folder = '/Users/liushizhao/projects_local/PPS/data_ephys/LSZ_practice_5_violet_05_01_26_g0';
probe_folder = fullfile(meta_folder, 'LSZ_practice_5_violet_05_01_26_g0_imec0');
cluster_folder = fullfile(probe_folder, 'LSZ_practice_5_violet_05_01_26_g0_imec0_ksdata_individual_cluster');
behav_folder = fullfile(meta_folder, 'LSZ_practice_5_violet_20260501_behav');

load(fullfile(behav_folder,'behav_data_PPS_LSZ_practice_5_violet_20260501.mat'));

cluster_list = dir(fullfile(cluster_folder,'*.mat'));

%%
spike_data_name = fullfile(meta_folder,'spikes_extracted_behav.mat');
if ~isfile(spike_data_name)
    nCluster = numel(cluster_list);
    nTrial = numel(behav_data);
    spike_times = cell(nTrial, nCluster);
    firing_rate = zeros(nTrial, nCluster);
    time_lim = [-200, 200]; % before trial onset and after trial off set, in ms

    for n = 1:nCluster

        load(fullfile(cluster_folder, cluster_list(n).name));
        spike_time_behav = neuron.n.spike_times_behav;

        for t = 1:nTrial
            trial_on = behav_data(t).t_global_s(1);
            %%% align everything to trial onset
            trial_off = 1000 * (behav_data(t).t_global_s(end) - trial_on);

            spike_time_trial = 1000 * (spike_time_behav - trial_on); % sec to ms

            idx_keep = spike_time_trial >= time_lim(1) & spike_time_trial <= (trial_off + time_lim(2));

            spike_times{t,n} = spike_time_trial(idx_keep);

            firing_rate(t,n) = 1000 * sum(spike_times{t,n} >= 0 & spike_times{t,n} <= trial_off) / trial_off;
        end
    end
    save(spike_data_name,'firing_rate','spike_times')
else
    load(spike_data_name);
end
%%

ball_opacity    = [behav_data(:).ball_opacity];
y_vel           = [behav_data(:).ball_y_speed];
init_x          = [behav_data(:).initial_x_rel_cm]; 
random_std  = [behav_data(:).ball_random_std];
has_random_walk = abs(random_std) > 0;

wheel_gain      = [behav_data(:).wheel_gain];
wheel_jittering = [behav_data(:).wheel_jitter];
has_wheel_jitter = abs(wheel_jittering) > 0;

is_rewarded     = [behav_data(:).rewarded]; 

sum_wheel_movement = [behav_data(:).sum_wheel_movement_cm];
sum_wheel_movement_abs = [behav_data(:).sum_abs_wheel_movement_cm];
sum_wheel_movement_GD = [behav_data(:).sum_abs_wheel_movement_directed_cm];


tbl = table();

tbl.opacity         = ball_opacity(:);
tbl.y_vel           = y_vel(:);
tbl.init_x          = init_x(:); 
tbl.has_random_walk    = categorical(has_random_walk(:));
tbl.has_wheel_jitter   = categorical(has_wheel_jitter(:));
tbl.wheel_gain     = wheel_gain(:);

tbl.movement        = sum_wheel_movement(:);
tbl.movement_abs    = sum_wheel_movement_abs(:);
tbl.movement_GD     = sum_wheel_movement_GD(:);

tbl.rewarded        = is_rewarded(:);

%%
nNeuron = size(firing_rate, 2);


predictor_names = {
    'opacity'
    'y_vel'
    'init_x'
    'has_random_walk_true'
    'has_wheel_jitter_true'
    'wheel_gain'
    'movement'
    'movement_abs'
    'movement_GD'
    'rewarded'
};

neuron_stats = struct();

for iNeuron = 1:nNeuron
    fprintf('Fitting for neuron %d/%d \n', iNeuron, nNeuron)
    tbl.firing_rate = firing_rate(:,iNeuron);
    
    glme = fitglme(tbl, ...
        ['firing_rate ~ opacity + y_vel + init_x + has_random_walk + ' ...
         'wheel_gain + has_wheel_jitter + ' ...
         'movement + movement_abs + movement_GD + rewarded']);

    coef_tbl = glme.Coefficients;

    neuron_stats(iNeuron).neuron_id = iNeuron;
    neuron_stats(iNeuron).coef_tbl  = coef_tbl;

    for k = 1:numel(predictor_names)

        this_name = predictor_names{k};
        idx = strcmp(coef_tbl.Name, this_name);

         if any(idx)

            neuron_stats(iNeuron).([this_name '_beta'])  = coef_tbl.Estimate(idx);
            neuron_stats(iNeuron).([this_name '_p'])     = coef_tbl.pValue(idx);
            % neuron_stats(iNeuron).([this_name '_SE'])    = coef_tbl.SE(idx);
            % neuron_stats(iNeuron).([this_name '_tStat']) = coef_tbl.tStat(idx);
            % 
            % neuron_stats(iNeuron).([this_name '_CI_lower']) = coef_tbl.Lower(idx);
            % neuron_stats(iNeuron).([this_name '_CI_upper']) = coef_tbl.Upper(idx);

        else

            neuron_stats(iNeuron).([this_name '_beta'])  = NaN;
            neuron_stats(iNeuron).([this_name '_p'])     = NaN;
            % neuron_stats(iNeuron).([this_name '_SE'])    = NaN;
            % neuron_stats(iNeuron).([this_name '_tStat']) = NaN;
            % 
            % neuron_stats(iNeuron).([this_name '_CI_lower']) = NaN;
            % neuron_stats(iNeuron).([this_name '_CI_upper']) = NaN;

        end
    end
end
%% example psth
colors_list = get(groot, 'defaultAxesColorOrder');
binSize = 20;              % 20 ms bins
tWindow = 1000*[-0.2 1.2];        % plot window around trial onset
edges = tWindow(1):binSize:tWindow(2);
tBin = edges(1:end-1) + binSize/2;


opacity_all = [behav_data(:).ball_opacity];
opacityLevels = unique(opacity_all);
%opacityLevels = sort(opacityLevels,'descend');
figure; hold on
n =7;
for c = 1:numel(opacityLevels)

    thisOpacity = opacityLevels(c);
    trialIdx = opacity_all == thisOpacity;

    psthCounts = zeros(sum(trialIdx), numel(edges)-1);

    trials = find(trialIdx);

    for k = 1:numel(trials)
        spk = spike_times{trials(k),n};
        psthCounts(k, :) = histcounts(spk, edges);
    end

    % Convert spike count/bin to firing rate Hz
    psthHz = 1000 * psthCounts / binSize;

    meanPSTH = mean(psthHz, 1, 'omitnan');
    semPSTH = std(psthHz, [], 1, 'omitnan') / sqrt(size(psthHz, 1));

    plot(tBin, meanPSTH, 'LineWidth', 2, ...
        'DisplayName', sprintf('Opacity = %.2f', thisOpacity),'Color',colors_list(c,:));

    % Optional SEM shading
    fill([tBin fliplr(tBin)], ...
         [meanPSTH - semPSTH fliplr(meanPSTH + semPSTH)], 1,...
         'facecolor',colors_list(c,:), 'FaceAlpha', 0.12, 'EdgeColor', 'none', ...
         'HandleVisibility', 'off');
end

xl = xline(0, '--k', 'Trial onset','HandleVisibility','off');
xl.FontSize = 16;
xlabel('Time from trial onset (s)');
ylabel('Firing rate (Hz)');
legend('Location', 'best');
box off
set(gca,'fontsize',18)

% %%
% % correlation FR with movement, GD movement, 
% 
% sum_wheel_movement = [behav_data(:).sum_wheel_movement_cm];
% sum_wheel_movement_abs = [behav_data(:).sum_abs_wheel_movement_cm];
% sum_wheel_movement_GD = [behav_data(:).sum_abs_wheel_movement_directed_cm];
% gd_ratio = sum_wheel_movement_GD ./ sum_wheel_movement;
% 
% corr_fr_movement = corr(firing_rate,sum_wheel_movement');
% corr_fr_abs_movement = corr(firing_rate,sum_wheel_movement_abs');
% corr_fr_movement_gd = corr(firing_rate,sum_wheel_movement_GD');
% 
% is_nan = isnan(gd_ratio);
% 
% corr_fr_gd_ratio = corr(firing_rate(~is_nan,:),gd_ratio(~is_nan)');
% 
% figure;
% % histogram(corr_fr_movement_gd);
% % hold on
% histogram(corr_fr_movement);hold on
% histogram(corr_fr_abs_movement)
%%
