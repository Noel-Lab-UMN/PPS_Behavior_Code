function [change_times, change_idx] = find_trial_change_times(log_tool, trial_col, time_col)
% FIND_TRIAL_CHANGE_TIMES
% Returns timestamps when trial number increases (ignoring NaNs)
%
% INPUTS:
%   log_tool  - table
%   trial_col - string or char (column name for trial index)
%   time_col  - string or char (column name for timestamp)
%
% OUTPUTS:
%   change_times - timestamps where trial increments
%   change_idx   - row indices of those changes

    % Extract columns
    trial = log_tool.(trial_col);
    time  = log_tool.(time_col);

    % Ensure column vectors
    trial = trial(:);
    time  = time(:);

    % Keep only valid (non-NaN) trials
    valid_mask = ~isnan(trial);
    trial_valid = trial(valid_mask);
    idx_valid   = find(valid_mask);

    % Find where trial increases
    trial_diff = diff(trial_valid);
    change_mask = trial_diff > 0;

    % Indices of change (in original table)
    change_idx = idx_valid(find(change_mask) + 1);

    % Corresponding timestamps
    change_times = time(change_idx);
end