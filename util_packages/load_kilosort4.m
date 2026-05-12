function ks_data = load_kilosort4(ks_folder, fs)
    if nargin < 2, fs = 30000; end
    ks_data.amplitudes                  = readNPY(fullfile(ks_folder, 'amplitudes.npy'));
    ks_data.channel_map                 = readNPY(fullfile(ks_folder, 'channel_map.npy'));
    ks_data.channel_positions           = readNPY(fullfile(ks_folder, 'channel_positions.npy'));
    ks_data.channel_shanks              = readNPY(fullfile(ks_folder, 'channel_shanks.npy'));
    ks_data.kept_spikes                 = readNPY(fullfile(ks_folder, 'kept_spikes.npy'));
    ks_data.pc_feature_ind              = readNPY(fullfile(ks_folder, 'pc_feature_ind.npy'));
    ks_data.pc_feature                  = readNPY(fullfile(ks_folder, 'pc_features.npy'));
    ks_data.similar_templates           = readNPY(fullfile(ks_folder, 'similar_templates.npy'));
    ks_data.spike_detection_templates   = readNPY(fullfile(ks_folder, 'spike_detection_templates.npy'));
    ks_data.spike_positions             = readNPY(fullfile(ks_folder, 'spike_positions.npy'));
    ks_data.templates                   = readNPY(fullfile(ks_folder, 'templates.npy'));
    ks_data.spike_templates             = readNPY(fullfile(ks_folder, 'spike_templates.npy'));
    ks_data.templates_ind               = readNPY(fullfile(ks_folder, 'templates_ind.npy'));
    ks_data.spike_clusters              = readNPY(fullfile(ks_folder, 'spike_clusters.npy'));
    ks_data.spike_times                 = double(readNPY(fullfile(ks_folder, 'spike_times.npy')));
    ks_data.spike_times_sec             = ks_data.spike_times / fs;

    if exist(fullfile(ks_folder, 'cluster_info.tsv'), 'file')
        ks_data.cluster_info = readtable(fullfile(ks_folder, 'cluster_info.tsv'), 'FileType', 'text', 'Delimiter', '\t');
    end

    if exist(fullfile(ks_folder, 'cluster_group.tsv'), 'file')
        ks_data.cluster_group = readtable(fullfile(ks_folder, 'cluster_group.tsv'), 'FileType', 'text', 'Delimiter', '\t');
    end

    if exist(fullfile(ks_folder, 'cluster_KSLabel.tsv'), 'file')
        ks_data.cluster_KSLabel = readtable(fullfile(ks_folder, 'cluster_KSLabel.tsv'), 'FileType', 'text', 'Delimiter', '\t');
    end


end