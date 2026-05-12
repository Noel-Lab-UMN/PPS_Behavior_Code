function [qMetric, unitType] = run_bombcell(ephysKilosortPath, ephysRawFile, ephysMetaDir, savePath)
save_name = fullfile(savePath, 'unitType.mat');
if ~isfile(save_name) 

    mkdir(savePath)
    kilosortVersion = 4;
    gain_to_uV = NaN;
    [spikeTimes_samples, spikeClusters, templateWaveforms, templateAmplitudes, pcFeatures, pcFeatureIdx, channelPositions] = bc.load.loadEphysData(ephysKilosortPath, savePath);
    param = bc.qm.qualityParamValues(ephysMetaDir, ephysRawFile, ephysKilosortPath, gain_to_uV, kilosortVersion);

    %param.computeDistanceMetrics=1;
    param.computeDrift=1;
    param.computeTimeChunks=0;
    %param.removeDuplicateSpikes=1;
    param.tauR_valuesMin = 0.5/1000;
    param.tauR_valuesMax = 0.01;
    param.tauR_valuesStep = 0.5/1000;
    param.computeDistanceMetrics = 0;
    param.removeDuplicateSpikes = 0;
    param.hillOrLlobetMethod = 1;
    param.computeTimeChunks = 0;
    param.extractRaw = 0;
    param.reextractRaw = 0;
    param.verbose = 1;
    param.plotGlobal = 0;
    [qMetric, unitType] = bc.qm.runAllQualityMetrics(param, spikeTimes_samples, spikeClusters, templateWaveforms, templateAmplitudes, pcFeatures, pcFeatureIdx, channelPositions, savePath);
    save([savePath, '/unitType.mat'], 'unitType');

else
    qMetric = parquetread(fullfile(savePath, 'templates._bc_qMetrics.parquet'));
    load(save_name);
end

end