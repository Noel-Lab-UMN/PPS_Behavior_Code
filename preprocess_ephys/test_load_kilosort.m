clear all
clc
close all
%%
data_folder =  'PPS0088_test7_g0/PPS0088_test7_g0_imec0';
ephysRawFile = 'PPS0088_test7_g0/PPS0088_test7_g0_imec0/PPS0088_test7_g0_t0.imec0.ap.cbin';
save_name = 'PPS0088_test7_g0/PPS0088_test7_g0_imec0_sorted.mat';
ks_data = run_load_kilosort_data(data_folder, ephysRawFile, save_name);