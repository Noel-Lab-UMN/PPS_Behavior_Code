function h = plot_sessions_timecourse(behav_results_summary, fieldname, session_list, errorbar_option)
nSession = numel(session_list);
eval(sprintf('y_all = {behav_results_summary(:).%s};',  fieldname));
y_avg       = cellfun(@mean, y_all);
y_std       = cellfun(@std, y_all);
y_CI_95(:,1)  = cellfun(@(x) prctile(x, 2.5), y_all);
y_CI_95(:,2)  = cellfun(@(x) prctile(x, 97.5), y_all);

y_CI_68(:,1)  = cellfun(@(x) prctile(x, 16), y_all);
y_CI_68(:,2)  = cellfun(@(x) prctile(x, 84), y_all);

n_sample    = cellfun(@numel, y_all);
y_sem       = y_std ./ sqrt(n_sample);

switch errorbar_option
    case 'none'
        h = plot([1:nSession], y_avg, '-o', 'LineWidth',2);
    case 'sem'
        h = errorbar([1:nSession], y_avg, y_sem,'LineWidth',2);
    case 'std'
        h = errorbar([1:nSession], y_avg, y_std,'LineWidth',2);
    case 'CI_95'
        h = errorbar([1:nSession], y_avg, y_avg' - y_CI_95(:,1), y_CI_95(:,2) - y_avg','LineWidth',2,'color',[0.5, 0.5, 0.5]);
    case 'CI_68'
        h = errorbar([1:nSession], y_avg, y_avg' - y_CI_68(:,1), y_CI_68(:,2) - y_avg','LineWidth',2,'color',[0.5, 0.5, 0.5]);
end


set(gca,'xtick',[1:nSession],'xticklabels',session_list)
set(gca,'fontsize',16);
box off
xlim([0.5,nSession+0.5])
end