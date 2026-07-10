clear all
clc
close all
%%
meta_folder = '/Users/liushizhao/projects_local/PPS/data_ephys/LSZ_practice_5_violet_05_01_26_g0';
probe_folder = fullfile(meta_folder, 'LSZ_practice_5_violet_05_01_26_g0_imec0');
cluster_folder = fullfile(probe_folder, 'LSZ_practice_5_violet_05_01_26_g0_imec0_ksdata_individual_cluster');
behav_folder = fullfile(meta_folder, 'LSZ_practice_5_violet_20260501_behav');


cluster_list = dir(fullfile(cluster_folder,'*.mat'));

%% extract spike data during task-performing
spike_data_name = fullfile(meta_folder,'spikes_extracted_behav.mat');
load(fullfile(behav_folder,'behav_data_PPS_LSZ_practice_5_violet_20260501.mat'));
behav_data_spike = behav_data;
if ~isfile(spike_data_name)
    behav_data_spike = add_extracted_spikedata_behav(behav_data, cluster_list);
    save(spike_data_name,'behav_data','behav_data_spike')
else
    load(spike_data_name);
end
%% extract spike data during passive viewing
spike_data_name = fullfile(meta_folder,'spikes_extracted_passive.mat');
load(fullfile(behav_folder,'passive_data_PPS_LSZ_practice_5_violet_20260501.mat'));

if ~isfile(spike_data_name)
    passive_data_spike = add_extracted_spikedata_behav(passive_data, cluster_list);
    save(spike_data_name,'passive_data','passive_data_spike')
  
else
    load(spike_data_name);
end

%%
function behav_data_spike = add_extracted_spikedata_behav(behav_data, cluster_list)
    behav_data_spike = behav_data;
    
    firing_timeWin = [-200, 200]; % before trial onset and after trial off set, in ms
    nCluster = numel(cluster_list);
    nTrial = numel(behav_data);
    %%%% place holder for spike data
    for t = 1:nTrial
        behav_data_spike(t).spike_times = cell(nCluster, 1);
        behav_data_spike(t).avg_firing_rate = zeros(nCluster, 1);
       
    end
    
   

    for n = 1:nCluster

        load(fullfile(cluster_list(n).folder, cluster_list(n).name));
        spike_time_behav = neuron.n.spike_times_behav;


        for t = 1:nTrial
            trial_on = behav_data_spike(t).t_global_s(1);
            %%% align everything to trial onset
            trial_off = 1000 * (behav_data_spike(t).t_global_s(end) - trial_on);

            spike_time_trial = 1000 * (spike_time_behav - trial_on); % sec to ms

            idx_keep = spike_time_trial >= firing_timeWin(1) & spike_time_trial <= (trial_off + firing_timeWin(2));
            

            spike_times_keep =  spike_time_trial(idx_keep);

            behav_data_spike(t).spike_times{n} = spike_times_keep;

            behav_data_spike(t).firingrate_stimOn(n) = 1000 * sum(spike_times_keep >= 0 & spike_times_keep <= trial_off) / trial_off;
        end
    end

end