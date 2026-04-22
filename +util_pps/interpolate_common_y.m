function [Xy, yCommon] = interpolate_common_y(x_rel_cm_all, y_cm_all)
nTrials = numel(x_rel_cm_all);
nPts    = 100;

% Find overlapping y range across trials
yMinAll = nan(nTrials,1);
yMaxAll = nan(nTrials,1);

for i = 1:nTrials
    y = y_cm_all{i}(:);
    valid = ~isnan(y);
    y = y(valid);
    
    if numel(y) < 2
        continue
    end
    
    yMinAll(i) = min(y);
    yMaxAll(i) = max(y);
end

yCommonMin = min(yMinAll, [], 'omitnan');
yCommonMax = max(yMaxAll, [], 'omitnan');
yCommon = linspace(yCommonMin, yCommonMax, nPts);

Xy = nan(nTrials, nPts);

for i = 1:nTrials
    x = x_rel_cm_all{i}(:);
    y = y_cm_all{i}(:);
    
    valid = ~isnan(x) & ~isnan(y);
    x = x(valid);
    y = y(valid);
    
    if numel(x) < 2
        continue
    end
    
    % If y is not strictly monotonic, sort by y
    [ySorted, idx] = sort(y);
    xSorted = x(idx);
    
    % Remove duplicate y values if needed
    [yUnique, ia] = unique(ySorted);
    xUnique = xSorted(ia);
    
    if numel(yUnique) < 2
        continue
    end
    
    Xy(i,:) = interp1(yUnique, xUnique, yCommon, 'linear', nan);
end

end