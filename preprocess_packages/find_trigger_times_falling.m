function [trigger_times_sec, falling_edges] = find_trigger_times_falling(digital_tactile, fs)
% FIND_TRIGGER_TIMES_FALLING Finds falling edges in a binary signal
%   INPUTS:
%     digital_tactile - vector with mostly 0s, goes to 1 for ~20 samples
%     fs - sampling frequency in Hz
%   OUTPUT:
%     trigger_times_sec - times in seconds where signal falls from 1 to 0

    % Ensure the input is a column vector
    digital_tactile = digital_tactile(:);
    
    % Find where the signal falls from 1 to 0
    falling_edges = find(diff(digital_tactile) == -1) + 1;
    
    % Convert sample indices to time (seconds)
    trigger_times_sec = falling_edges / fs;
end