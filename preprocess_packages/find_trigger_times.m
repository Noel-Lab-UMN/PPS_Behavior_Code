function [trigger_times_sec, rising_edges] = find_trigger_times(digital_tactile, fs)
% FIND_TRIGGER_TIMES Finds rising edges in a binary signal
%   INPUTS:
%     digital_tactile - vector with mostly 0s, goes to 1 for ~20 samples
%     fs - sampling frequency in Hz
%   OUTPUT:
%     trigger_times_sec - times in seconds where signal rises from 0 to 1

    % Ensure the input is a column vector
    digital_tactile = digital_tactile(:);
    
    % Find where the signal rises from 0 to 1
    rising_edges = find(diff(digital_tactile) == 1) + 1;
    
    % Convert sample indices to time (seconds)
    trigger_times_sec = rising_edges / fs;
end