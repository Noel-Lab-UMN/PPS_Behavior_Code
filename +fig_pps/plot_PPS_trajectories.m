function plot_PPS_trajectories(behav_data, EXP_CONFIG)

fig_folder  = fullfile('../../figures/behav/individual_sessions',EXP_CONFIG(1).MOUSE_NAME, EXP_CONFIG(1).EXP_DATE);
if ~isfolder(fig_folder)
    mkdir(fig_folder);
end

fig_save_name = fullfile(fig_folder,['fig_trajectories_',EXP_CONFIG(1).MOUSE_NAME,'_',EXP_CONFIG(1).EXP_DATE,'.png']);

%%% idx of balls not reach bottom
idx_not_reach_bottom = [behav_data(:).reached_bottom] == 0;
%%% idx of moving the wheel too much? Two screens?
too_much_wheel_thres    = 2 * EXP_CONFIG(1).SCREEN_WIDTH_CM;
idx_too_much_wheel      = [behav_data(:).sum_abs_delta_hori_cm] > too_much_wheel_thres;
%%%%% idx of good trials to be kept
idx_good = ~idx_not_reach_bottom & ~idx_too_much_wheel;
    % p_good   = sum(idx_good) / nBall_total;
    % 
    % idx_rewarded = [behav_data(:).rewarded] == 1;

edge = [-EXP_CONFIG(1).SCREEN_WIDTH_CM/2 : 1.5: EXP_CONFIG(1).SCREEN_WIDTH_CM/2];

gcf = figure;
set(gcf,'unit','normalized','position',[0,0,1,1])

%figure;
subplot(2,4,[1:4]); hold on
%
histogram([behav_data(idx_good).initial_x_rel_cm],edge);
histogram([behav_data(idx_good).end_x_rel_cm],edge);
idx_rewarded = [behav_data(:).rewarded] == 1;
histogram([behav_data(idx_rewarded).end_x_rel_cm],edge);
line([EXP_CONFIG(1).tolerant_space_cm(1), EXP_CONFIG(1).tolerant_space_cm(1)], [0, numel(behav_data)/numel(edge)], ...
    'linestyle','--','color','red','linewidth',1.5);
line([EXP_CONFIG(1).tolerant_space_cm(2), EXP_CONFIG(1).tolerant_space_cm(2)], [0, numel(behav_data)/numel(edge)], ...
    'linestyle','--','color','red','linewidth',1.5);
set(gca,'fontsize',18);
xlabel('x-rel-cm'); ylabel('nBalls');
legend('Initial','End','End-rewarded')

%%% visulization of trajectories
idx_rewarded    =  [behav_data(:).rewarded] == 1;
idx_initialIN   =  [behav_data(:).initial_in_reward] == 1;

%%%% initial in, rewarded
idx_rewarded_initial_in         = find(idx_good & idx_rewarded & idx_initialIN);
%%%% initial in, non-rewarded
idx_nonrewarded_initial_in      = find(idx_good & ~idx_rewarded & idx_initialIN);
%%%% initial out, rewarded
idx_rewarded_initial_out        = find(idx_good & idx_rewarded & ~idx_initialIN);
%%%% initial in, non rewarded
idx_nonrewarded_initial_out     = find(idx_good & ~idx_rewarded & ~idx_initialIN);

subplot(2,4,5);
fig_pps.plot_ball_trajectories(behav_data, idx_rewarded_initial_in, EXP_CONFIG, 'Initial in, rewarded')
subplot(2,4,6);
fig_pps.plot_ball_trajectories(behav_data, idx_nonrewarded_initial_in, EXP_CONFIG, 'Initial in, non-rewarded')
subplot(2,4,7);
fig_pps.plot_ball_trajectories(behav_data, idx_rewarded_initial_out, EXP_CONFIG, 'Initial out, rewarded')
subplot(2,4,8);
fig_pps.plot_ball_trajectories(behav_data, idx_nonrewarded_initial_out, EXP_CONFIG, 'Initial out, non-rewarded')
sgtitle([EXP_CONFIG(1).MOUSE_NAME,'-',EXP_CONFIG(1).EXP_DATE],'fontsize',18,'fontweight','bold','interpreter','none');
saveas(gcf, fig_save_name)
close

end

