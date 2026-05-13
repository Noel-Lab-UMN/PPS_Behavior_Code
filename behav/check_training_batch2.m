clear all
clc
%close all

global PPS_global
generate_PPS_global();

%%%% conditioned on ball radius?  conditioned on distance? any bias?
%% load data
results_summary = struct();
n = 1;
subjectCode_list = {'GD_1_red';'GD_2_blue';'GD_3_pink';'GD_4_mint';'GD_5_grey'};
for i = 1:numel(subjectCode_list)

    subjectCode = subjectCode_list{i};
    eval(sprintf('session_list = PPS_global.%s.session_list.initial;',subjectCode));
    for j =  1 : numel(session_list)
        data_folder =  fullfile('../../results/behav/pps_processed',subjectCode);

        exp_date = session_list{j};
        data_name          = fullfile(data_folder,['behav_data_PPS_',subjectCode,'_',exp_date,'.mat']);

        load(data_name);

        ball_radius = [behav_data(:).ball_radius];
        ball_init_x = round([behav_data(:).initial_x_rel_cm]);
        ball_init_sign = sign(ball_init_x);
        ball_init_distance = abs(ball_init_x);


        idx = boolean(ones(size(behav_data)));
        [p_move, p_reward_move] = calcu_percent(behav_data, idx);

        idx = ball_radius == 1.5;
        [p_move_small, p_reward_move_small] = calcu_percent(behav_data, idx);

        idx = ball_radius == 3.0;
        [p_move_big, p_reward_move_big]  = calcu_percent(behav_data, idx);

        idx = ball_init_distance == 15;
        [p_move_far, p_reward_move_far] = calcu_percent(behav_data, idx);

        idx = ball_init_distance == 10;
        [p_move_near, p_reward_move_near] = calcu_percent(behav_data, idx);

        idx = ball_init_sign == -1;
        [p_move_left, p_reward_move_left] = calcu_percent(behav_data, idx);

        idx = ball_init_sign == 1;
        [p_move_right, p_reward_move_right] = calcu_percent(behav_data, idx);

        results_summary(n).subjectCode          = subjectCode;
        results_summary(n).exp_date             = exp_date;
        results_summary(n).p_move               = p_move;
        results_summary(n).p_reward_move        = p_reward_move;
        results_summary(n).p_move_small         = p_move_small;
        results_summary(n).p_reward_move_small  = p_reward_move_small;
        results_summary(n).p_move_big           = p_move_big;
        results_summary(n).p_reward_move_big    = p_reward_move_big;
        results_summary(n).p_move_far           = p_move_far;
        results_summary(n).p_reward_move_far    = p_reward_move_far;
        results_summary(n).p_move_near          = p_move_near;
        results_summary(n).p_reward_move_near   = p_reward_move_near;
        results_summary(n).p_move_left          = p_move_left;
        results_summary(n).p_reward_move_left   = p_reward_move_left;
        results_summary(n).p_move_right         = p_move_right;
        results_summary(n).p_reward_move_right  = p_reward_move_right;


        %%% end_x_cm conditioned on size?
        idx_rewarded = [behav_data(:).rewarded] == 1;
        idx = ball_radius == 1.5 & idx_rewarded;
        results_summary(n).end_abs_x_small = mean(abs([behav_data(idx).end_x_rel_cm]));

        idx = ball_radius == 3.0 & idx_rewarded;
        results_summary(n).end_abs_x_big = mean(abs([behav_data(idx).end_x_rel_cm]));




        n = n+1;

    end
end
%% make figures
color_list = {'red';'blue';'magenta';'cyan';'black'};
figure;
subplot(2,1,1); hold on
for i = 1:numel(subjectCode_list)
    idx = strcmp({results_summary(:).subjectCode}, subjectCode_list{i});
    plot_data = [results_summary(idx).p_move];
    plot([1:numel(plot_data)], plot_data,'-o','Color',color_list{i}, 'LineWidth', 2, 'MarkerSize',8);

end
set(gca, 'fontsize', 18);
ylabel('P(move)'); xlabel('Session index')
subplot(2,1,2); hold on
for i = 1:numel(subjectCode_list)
    idx = strcmp({results_summary(:).subjectCode}, subjectCode_list{i});
    plot_data = [results_summary(idx).p_reward_move];

    plot([1:numel(plot_data)], plot_data,'-o','Color',color_list{i}, 'LineWidth', 2,'MarkerSize',8);
end
set(gca, 'fontsize', 18);
ylabel('P(reward|move)'); xlabel('Session index')
%%
color_list = {'red';'blue';'magenta';'cyan';'black'};
figure;
pair_str = {'left';'right'};
for i = 1:numel(subjectCode_list)
    subplot(5,2,(i-1)*2+1); hold on
    idx = strcmp({results_summary(:).subjectCode}, subjectCode_list{i});

    eval(sprintf('plot_data = [results_summary(idx).p_move_%s];', pair_str{1}));
    plot([1:numel(plot_data)], plot_data,'-o','Color',color_list{i});

    eval(sprintf('plot_data = [results_summary(idx).p_move_%s];', pair_str{2}));
    plot([1:numel(plot_data)], plot_data,'--o','Color',color_list{i});
    
    set(gca, 'fontsize', 16);
    if i == 1
    legend(pair_str,'Orientation','horizontal','Location','northoutside')
    end
    ylabel('P(move)'); xlabel('Session index')
end


for i = 1:numel(subjectCode_list)
    subplot(5,2,i*2); hold on
    idx = strcmp({results_summary(:).subjectCode}, subjectCode_list{i});

    eval(sprintf('plot_data = [results_summary(idx).p_reward_move_%s];', pair_str{1}));
    plot([1:numel(plot_data)], plot_data,'-o','Color',color_list{i});

    eval(sprintf('plot_data = [results_summary(idx).p_reward_move_%s];', pair_str{2}));
    plot([1:numel(plot_data)], plot_data,'--o','Color',color_list{i});
    

    set(gca, 'fontsize', 16);
    ylabel('P(reward|move)'); xlabel('Session index')

end
%%
color_list = {'red';'blue';'magenta';'cyan';'black'};
figure; hold on
for i = 1:numel(subjectCode_list)
    idx = strcmp({results_summary(:).subjectCode}, subjectCode_list{i});
    plot_data = [results_summary(idx).end_abs_x_small];
    plot([1:numel(plot_data)], plot_data,'-o','Color',color_list{i}, 'LineWidth', 2, 'MarkerSize',8);

    plot_data = [results_summary(idx).end_abs_x_big];
    plot([1:numel(plot_data)], plot_data,'--o','Color',color_list{i}, 'LineWidth', 2, 'MarkerSize',8);

end
set(gca, 'fontsize', 18);
ylabel('End distance'); xlabel('Session index')

%% animals with wheel training more active?
%% plot trajectory for each animal
%% z-score for each condition?


%% small help functions
function [p_move, p_reward_move] = calcu_percent(behav_data, idx)
p_move = sum([behav_data(idx).is_moved]) / sum(idx);
p_reward_move = sum([behav_data(idx).is_moved] & [behav_data(idx).rewarded]) / sum([behav_data(idx).is_moved]);
end