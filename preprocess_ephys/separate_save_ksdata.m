clear all
clc
close all
%%
ks_data_path        = '/Users/liushizhao/projects_local/PPS/test_ephys_workflow/LSZ_Practice_5_Violet';
ks_data_file_name   = 'LSZ_Practice_5_Violet_04_30_2026_g0_imec0_sorted.mat';
individual_ks_data_folder  = fullfile(ks_data_path, 'ksdata_individual_cluster');
mkdir(individual_ks_data_folder);
load(fullfile(ks_data_path, ks_data_file_name));

unique_clusters = unique(ks_data.spike_clusters);

nCluster = numel(unique_clusters);

brain_area          = 'TBD';

for i_cluster = 1:nCluster
    disp([num2str(i_cluster) , ' / ', num2str(size(unique_clusters, 1))]);
    clear idx
    clear neuron

    idx = unique_clusters(i_cluster);
    n_spikes = size(double(ks_data.spike_times_sec(ks_data.spike_clusters == idx)), 1);

    neuron.n.st                                     = double(ks_data.spike_times(ks_data.spike_clusters == idx)); %in samples...
    neuron.n.st_sec                                 = double(ks_data.spike_times_sec(ks_data.spike_clusters == idx)); % in seconds...
    neuron.n.amp                                    = double(ks_data.amplitudes(ks_data.spike_clusters == idx));
    neuron.n.spike_position_lat                     = double(ks_data.spike_positions(ks_data.spike_clusters == idx, 1)); % is this what I am looking for in terms of depth?...
    neuron.n.spike_position_dep                     = double(ks_data.spike_positions(ks_data.spike_clusters == idx, 2)); % is this what I am looking for in terms of depth?...
    neuron.n.spike_templates                        = double(ks_data.spike_templates(ks_data.spike_clusters == idx));
    neuron.n.template                               = mean(squeeze(ks_data.templates(i_cluster, :, :))','omitnan');
    neuron.n.waveform_duration                      = ks_data.waveform_duration(i_cluster);
    neuron.n.KSlabel                                = ks_data.cluster_KSLabel.KSLabel{i_cluster};
    neuron.n.cluster_group                          = ks_data.cluster_group.KSLabel{i_cluster};                         % according to phy
    neuron.n.unitType                               = ks_data.unitType(i_cluster);                                      % according to bombcell
    %neuron.n.spike_depths                          = double(ks_data.spikeDepths(ks_data.spike_clusters == idx));     % Not sure what the difference between depth and position is...
    neuron.n.spike_sites                            = double(ks_data.spikeSites(ks_data.spike_clusters == idx));
    neuron.n.x                                      = median(neuron.n.spike_position_lat, 'omitnan');
    neuron.n.y                                      = median(neuron.n.spike_position_dep, 'omitnan');
    neuron.n.brain_area                             = brain_area;

    neuron.qc.phy_clusterID                         = ks_data.qMetric.phy_clusterID(i_cluster);
    neuron.qc.clusterID                             = ks_data.qMetric.clusterID(i_cluster);
    neuron.qc.percentageSpikesMissing_gaussian      = ks_data.qMetric.percentageSpikesMissing_gaussian(i_cluster);
    neuron.qc.percentageSpikesMissing_symmetric     = ks_data.qMetric.percentageSpikesMissing_symmetric(i_cluster);
    neuron.qc.presenceRatio                         = ks_data.qMetric.presenceRatio(i_cluster);
    neuron.qc.maxDriftEstimate                      = ks_data.qMetric.maxDriftEstimate(i_cluster);
    neuron.qc.cumDriftEstimate                      = ks_data.qMetric.cumDriftEstimate(i_cluster);
    neuron.qc.mainPeakToTroughRatio                 = ks_data.qMetric.mainPeakToTroughRatio(i_cluster);
    neuron.qc.mainTrough_width                      = ks_data.qMetric.mainTrough_width(i_cluster);


    % save neuron
    % NEED TO ADD BRAIN AREA TO THIS...
    save_name = fullfile(individual_ks_data_folder, sprintf('LSZ_Practice_5_Violet_04_30_2026_g0_imec0_cluster_%d', i_cluster));
    save(save_name, 'neuron', '-v7.3');
end

