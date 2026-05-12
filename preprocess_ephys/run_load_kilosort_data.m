function ks_data = run_load_kilosort_data(data_folder, ephysRawFile, save_name)
    %%
   %  data_folder = 'PPS0088_test7_g0/PPS0088_test7_g0_imec0';
    ephysKilosortPath = fullfile(data_folder, 'kilosort4');
    
    %ephysRawFile = 'PPS0088_test7_g0/PPS0088_test7_g0_imec0/PPS0088_test7_g0_t0.imec0.ap.cbin';
    ephysMetaDir = dir(fullfile(data_folder,'*.ap.meta'));

    %% Parameters
    prs.fs = 30000;
    prs.min_fr = 0.5;
    prs.min_presence = 0.7;
    prs.new_sr = 100;                                  % new sampling rate...
    prs.smooth = 80;                                   % points for smoothing
    
    % neuropixel stuff
    prs.lfpFs = 2500;                                  % neuropixels phase3b
    prs.lfpFs_new = 1000;                              % downsample for space etc..
    prs.nChansInFile = 385;                            % neuropixels phase3a, from spikeGLX
    prs.syncChanIndex = 385;
    prs.dtype = 'int16';                               % Always int16 for SpikeGLX
    prs.bytes_per_sample = 2;                          % int16 = 2 bytes
    %% Importing neurons
    disp("LOADING SPIKES DATA NOW.....")
    sp  = loadKSdir(ephysKilosortPath);
    %% Run BOMBCELL
    % quality control... BOMBCELL
    savePath = [data_folder filesep 'bombcell']; % where you want to save the quality metrics
    disp("RUNNING BOMBCELL NOW.....")
    [qMetric, unitType] = run_bombcell(ephysKilosortPath, ephysRawFile, ephysMetaDir, savePath);
    
    %  % unitType:
    % noiseUnits                  = unitType == 0;
    % goodUnits                   = unitType == 1;
    % muaUnits                    = unitType == 2;
    % nonSomaticUnits             = unitType == 3;
    
   
    %% Importing KS data
    disp("IMPORTING KS data.....")
    ks_data = load_kilosort4(ephysKilosortPath, prs.fs);
    % check the metrics and try to classify as putative inh and exc.
    ks_data.waveform_duration = qMetric.waveformDuration_peakTrough;
    ks_data.unitType          = unitType;
    ks_data.sp                = sp;
    ks_data.qMetric           = qMetric;
    
    [~, ~, spikeDepths, spikeSites] = ksDriftmap(ephysKilosortPath);
    ks_data.spikeDepths                              = spikeDepths;
    ks_data.spikeSites                               = spikeSites;
    
    ks_data.prs     = prs;
        
    save(save_name, 'ks_data');

end