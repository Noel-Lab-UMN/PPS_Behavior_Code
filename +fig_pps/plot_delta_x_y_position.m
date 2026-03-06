function plot_delta_x_y_position(behav_data, EXP_CONFIG)
%%%% 
idx_not_reach_bottom = [behav_data(:).reached_bottom] == 0;
%%% idx of moving the wheel too much? Two screens?
too_much_wheel_thres    = 2 * EXP_CONFIG(1).SCREEN_WIDTH_CM;
idx_too_much_wheel      = [behav_data(:).sum_abs_delta_hori_cm] > too_much_wheel_thres;
%%%%% idx of good trials to be kept
idx_good = ~idx_not_reach_bottom & ~idx_too_much_wheel;
%%%% idx of rewarded trials
idx_rewarded = [behav_data(:).rewarded] == 1;


%idx_all = ones(size(behav_data));



figure;
set(gcf,'Units','inches','Position',[0,0,10,4]);
% subplot(1,3,1)
% plot_with_y(behav_data, idx_all); title('All trials')
subplot(1,2,1)
plot_with_y(behav_data, idx_good); title('Good trials');
subplot(1,2,2);
plot_with_y(behav_data, idx_rewarded); title('Rewarded trials');

% subplot(2,3,4)
% plot_with_t(behav_data, idx_all); title('All trials')
% subplot(2,3,5)
% plot_with_t(behav_data, idx_good); title('Good trials');
% subplot(2,3,6);
% plot_with_t(behav_data, idx_rewarded); title('Rewarded trials');



fig_folder  = fullfile('../../figures/behav/individual_sessions',EXP_CONFIG.MOUSE_NAME, EXP_CONFIG.EXP_DATE);
if ~isfolder(fig_folder)
    mkdir(fig_folder);
end

fig_save_name = fullfile(fig_folder,['fig_delta_x_y_',EXP_CONFIG.MOUSE_NAME,'_',EXP_CONFIG.EXP_DATE,'.png']);

sgtitle([EXP_CONFIG.MOUSE_NAME,'-',EXP_CONFIG.EXP_DATE],'fontsize',18,'fontweight','bold','interpreter','none');
saveas(gcf, fig_save_name)
close

end

function plot_with_y(behav_data, idx)

tmp = {behav_data(idx).y_cm};
y_cm_all = cat(1, tmp{:});

tmp = {behav_data(idx).delta_hori_cm};
delta_hori_abs_cm_all = abs(cat(1, tmp{:}));

bin_width = 3;

idx_bin = ceil(y_cm_all / bin_width);
idx_bin_list = unique(idx_bin);
delta_abs_x_mean = arrayfun(@(n)mean(delta_hori_abs_cm_all(idx_bin == n),'omitnan'), idx_bin_list);
delta_abs_x_sem =  arrayfun(@(n)std(delta_hori_abs_cm_all(idx_bin == n), 'omitnan') / sqrt(sum(idx_bin == n)),...
            idx_bin_list);

errorbar(delta_abs_x_mean, idx_bin_list * bin_width, delta_abs_x_sem,'horizontal','linewidth', 2);
xlabel('Abs. (delta-x)');
ylabel('y position')
set(gca,'fontsize',18);
end

function plot_with_t(behav_data, idx)

tmp = {behav_data(idx).t_global_s};
for n = 1:numel(tmp)
    tmp{n} = tmp{n} - tmp{n}(1);
end
t_all = cat(1,tmp{:});


tmp = {behav_data(idx).delta_hori_cm};
delta_hori_abs_cm_all = abs(cat(1, tmp{:}));


edge = [0:0.2:max(t_all)];
[~,~,idx_bin] = histcounts(t_all, edge);
idx_bin_list = unique(idx_bin);
delta_abs_x_mean = arrayfun(@(n)mean(delta_hori_abs_cm_all(idx_bin == n)), idx_bin_list);
delta_abs_x_sem =  arrayfun(@(n)std(delta_hori_abs_cm_all(idx_bin == n)) / sqrt(sum(idx_bin == n)),...
            idx_bin_list);


errorbar(delta_abs_x_mean,edge, delta_abs_x_sem,'horizontal','linewidth', 2);

%set(gca, 'YDir', 'reverse')
xlabel('Abs. (delta-x)');
ylabel('Time elapsed')
set(gca,'fontsize',18);
end