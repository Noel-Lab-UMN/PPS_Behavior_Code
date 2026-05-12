function NI_timing = read_binary_sync(file_meta, file_bin)
meta = ReadMeta(file_meta);  % You need to download this helper
n_channels = str2double(meta.nSavedChans);     % e.g., 385
fs = str2double(meta.niSampRate);              % Sample rate (e.g., approx 30000 Hz)

fid = fopen(file_bin, 'r');
data_type = 'int16';
raw = fread(fid, [n_channels, Inf], data_type);  % Read all data
fclose(fid);

digital_data                    = raw(end, :);                  % Last channel = digital lines
clear raw
digital_ch1                     = bitget(digital_data, 1);      % seems very continous...up down up down... from the very beginning
digital_ch2                     = bitget(digital_data, 2);      % looks like PRBS but starts HIGH
digital_ch3                     = bitget(digital_data, 3);    
digital_ch4                     = bitget(digital_data, 4); 
clear digital data

%%%
%%%% ch2: prbs
%%%% ch3: trial onset
%%%% ch4: exp start onset?
[NI_timing.ch1_sec, ~]            = find_trigger_times(digital_ch1, fs);
[NI_timing.ch2_sec, ~]            = find_trigger_times(digital_ch2, fs);
[NI_timing.ch3_sec, ~]            = find_trigger_times(digital_ch3, fs);
[NI_timing.ch4_sec, ~]            = find_trigger_times(digital_ch4, fs);

NI_timing.prbs_rising             = NI_timing.ch2_sec;
NI_timing.trial_onset             = NI_timing.ch3_sec;

end