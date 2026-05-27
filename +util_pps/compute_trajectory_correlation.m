function [r_all, r_single] = compute_trajectory_correlation(behav_data, idx, doPlot)

nTrial = numel(idx);
[x_trajectory_ideal,x_trajectory_real] = deal(cell(nTrial,1));
idx_all = cell(nTrial,1);
idx_offset = 0;
for n = 1:nTrial
    k = idx(n);

    if n == 1
        x_init_pos = 0;

    else
        x_init_pos = x_trajectory_real{n-1}(end);
    end

    x_trajectory_real{n} = x_init_pos - cumsum(behav_data(k).delta_hori_cm);


    nFrame = numel(behav_data(k).frame_idx);
    if n == 1
        x_init_pos = 0;

    else
        x_init_pos = x_trajectory_ideal{n-1}(end);
    end
    x_rel_init = behav_data(k).initial_x_rel_cm + x_init_pos;
    x_trajectory_ideal{n} = linspace(x_init_pos, x_rel_init, nFrame)';

    idx_all{n} = idx_offset + [1:numel(x_trajectory_ideal{n})]';

    idx_offset = idx_all{n}(end);
end


r_all = arrayfun(@(x)corr(x_trajectory_ideal{x}, x_trajectory_real{x}),[1:nTrial]);
x_end_ideal = arrayfun(@(x)x_trajectory_ideal{x}(end), [1:nTrial]);
x_end_real  =  arrayfun(@(x)x_trajectory_real{x}(end), [1:nTrial]);
idx_end_ideal   = cumsum(cellfun(@numel, x_trajectory_ideal));
idx_end_real    = cumsum(cellfun(@numel, x_trajectory_real));


r_single        = corr(cat(1, x_trajectory_ideal{:}), cat(1, x_trajectory_real{:}));



if doPlot
    figure
    subplot(2,1,1)
    hold on
    colors_list = get(groot, 'defaultAxesColorOrder');
   % T = numel(x_trajectory_ideal);
    h(1) = plot(cat(1, idx_all{:}), cat(1, x_trajectory_ideal{:}), 'color', colors_list(1,:));
    h(2) = plot(cat(1, idx_all{:}), cat(1, x_trajectory_real{:}), 'color', [0.5,0.5,0.5]);
    for t = 1:numel(idx_rewarded)
        h(3) = plot( idx_all{idx_rewarded(t)},  x_trajectory_real{idx_rewarded(t)}, 'color', 'red');
    end
    plot(idx_end_ideal, x_end_ideal, 'o', 'color', colors_list(1,:))
    plot(idx_end_real, x_end_real, 'o', 'color', [0.5,0.5,0.5])
    
    set(gca,'fontsize',18);
    legend(h, 'Ideal','Real','Rewarded')
    title(sprintf('r-concatenate = %.2f', r_single));
   

    subplot(2,1,2)
    histogram(r_all);
    set(gca,'fontsize',18);
    title(sprintf('Avg.(r) = %.2f', mean(r_all)))
    xlabel('r (per trial)')
    
end

end