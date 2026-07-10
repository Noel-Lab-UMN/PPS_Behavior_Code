function h = plot_ball_trajectories(behav_data, idx_plot, EXP_CONFIG, plotOptions)

%%%%% default settings
if ~isfield(plotOptions, 'style')
    plotOptions.style = 'avg';
end
if ~isfield(plotOptions, 'doExample')
    plotOptions.doExample = false;
end
if ~isfield(plotOptions, 'doSEM')
    plotOptions.doSEM = true;
end

if ~isfield(plotOptions, 'color')
    plotOptions.color = 'black';
end
hold on
switch plotOptions.style
    case 'individual'
        for i = 1:numel(idx_plot)
            plot(behav_data(idx_plot(i)).x_rel_cm, behav_data(idx_plot(i)).y_cm)
        end
    case 'avg'
        x_rel_cm_all    = {behav_data(:).x_rel_cm};
        y_cm_all        = {behav_data(:).y_cm};

        [Xy, yCommon] = util_pps.interpolate_common_y(x_rel_cm_all, y_cm_all);
        nTrial = numel(idx_plot);


        x_cm_mean   = mean(Xy(idx_plot,:),1);
     

        x_cm_sem    = std(Xy(idx_plot,:), [], 1) / sqrt(nTrial);
        
        
        valid = ~isnan(x_cm_mean) & ~isnan(x_cm_sem) & ~isnan(yCommon);


        Xy = Xy(:,valid);
        x_cm_mean = x_cm_mean(valid);
        x_cm_sem  = x_cm_sem(valid);
        yCommon   = yCommon(valid);

        x_left  = x_cm_mean - x_cm_sem;
        x_right = x_cm_mean + x_cm_sem;
        
        
        h = plot(x_cm_mean, yCommon, 'LineWidth', 2, 'color', plotOptions.color); hold on
        
        if plotOptions.doSEM
            fill([x_left, fliplr(x_right)], ...
                 [yCommon,      fliplr(yCommon)], ...
                 plotOptions.color, ...
                 'FaceAlpha', 0.3, ...
                 'EdgeColor', 'none');
        end


        if plotOptions.doExample
            %delta = 10;
            x_sample = Xy(idx_plot,:);
   
            %x_range = [x_cm_mean - delta * x_cm_sem; x_cm_mean + delta * x_cm_sem];

            dist_from_mean = arrayfun(@(t)mean((x_sample(t,:) - x_cm_mean) .^ 2,'omitnan'), [1:size(x_sample,1)]);

            %x_in = x_sample(~is_out,:);

            [~, i_min] = mink(dist_from_mean,5);

            for n = 1:numel(i_min)
                h_e = plot(x_sample(i_min(n),:), yCommon, 'LineWidth', 1, 'color', plotOptions.color);
                h_e.Color(4) = 0.3;
            end


        end
end



xlim([-EXP_CONFIG(1).SCREEN_WIDTH_CM / 2, EXP_CONFIG(1).SCREEN_WIDTH_CM / 2])
set(gca,'fontsize',16);
xlabel('x-pos-cm'); ylabel('y-pos-cm');
%title(sprintf('%s: %d/%d', plotOptions.titleStr, numel(idx_plot), numel(behav_data)));


ball_r = 3;
line([EXP_CONFIG(1).tolerant_space_cm(1), EXP_CONFIG(1).tolerant_space_cm(1)], [0, ball_r], ...
    'linestyle','--','color','red','linewidth',1.5);
line([EXP_CONFIG(1).tolerant_space_cm(2), EXP_CONFIG(1).tolerant_space_cm(2)], [0, ball_r], ...
    'linestyle','--','color','red','linewidth',1.5);
line([EXP_CONFIG(1).tolerant_space_cm(1), EXP_CONFIG(1).tolerant_space_cm(2)], [ball_r,ball_r], ...
    'linestyle','--','color','red','linewidth',1.5);

plot(0,0,'Marker','^','Color','blue','MarkerSize',10);


end