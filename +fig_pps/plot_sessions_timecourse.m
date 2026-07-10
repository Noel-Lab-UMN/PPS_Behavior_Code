function [h, corr_stats] = plot_sessions_timecourse(behav_results_summary, plotOptions)% fieldname, session_list, errorbar_option)
fieldname_avg   = plotOptions.fieldname_avg;
session_list    = plotOptions.session_list;
if isfield(plotOptions, 'errorbar_option')
    errorbar_option = plotOptions.errorbar_option;
else
    errorbar_option ='none';
end

if isfield(plotOptions, 'doFitting')
    doFitting = plotOptions.doFitting;
else
    doFitting = true;
end

if isfield(plotOptions,'doXticklabel')
    doXticklabel = plotOptions.doXticklabel;
else
    doXticklabel = true;
end
nSession = numel(session_list);
idx = ismember({behav_results_summary(:).sessionStr},session_list);
eval(sprintf('y_all = {behav_results_summary(idx).%s};',  fieldname_avg));
for k = 1:numel(y_all)
    idx_nan = isnan(y_all{k});
    y_all{k} = y_all{k}(~idx_nan);
end
y_avg       = cellfun(@mean, y_all);
y_std       = cellfun(@std, y_all);
y_CI_95(:,1)  = cellfun(@(x) prctile(x, 2.5), y_all);
y_CI_95(:,2)  = cellfun(@(x) prctile(x, 97.5), y_all);

y_CI_68(:,1)  = cellfun(@(x) prctile(x, 16), y_all);
y_CI_68(:,2)  = cellfun(@(x) prctile(x, 84), y_all);

n_sample    = cellfun(@numel, y_all);
y_sem       = y_std ./ sqrt(n_sample);

hold on
x = find(idx);
switch errorbar_option
    case 'none'
        h = plot(x, y_avg, '-o', 'LineWidth',2);
    case 'sem'
        h = errorbar(x, y_avg, y_sem,'LineWidth',2);
    case 'std'
        h = errorbar(x, y_avg, y_std,'LineWidth',2);
    case 'CI_95'
        h = errorbar(x, y_avg, y_avg' - y_CI_95(:,1), y_CI_95(:,2) - y_avg','LineWidth',2,'color',[0.5, 0.5, 0.5]);
    case 'CI_68'
        h = errorbar(x, y_avg, y_avg' - y_CI_68(:,1), y_CI_68(:,2) - y_avg','LineWidth',2,'color',[0.5, 0.5, 0.5]);
    otherwise
        %%% errorbar has been pre-computed
        eval(sprintf('err_val = [behav_results_summary(:).%s];',  errorbar_option));
        h = errorbar(x, y_avg, err_val,'LineWidth',2);
end
%%% fit a line
if doFitting
    coeffs = polyfit(x, y_avg, 1);  
    plot([min(x),max(x)], polyval(coeffs, [min(x),max(x)]),'k--','linewidth',1);
end


[corr_stats.r, corr_stats.p] = corr(x(:), y_avg(:), 'Type', 'Spearman');
if doXticklabel
    set(gca,'xtick',[1:2:nSession],'xticklabels',session_list(1:2:nSession))
end
set(gca,'fontsize',16);
box off
%xlim([0.5,nSession+0.5])
if contains(fieldname_avg,'zscore')
    % one-tailed z-score for p = 0.05
    line([x(1) - 0.5, x(end)+0.5], [1.645, 1.645],'linestyle','--','color','black')
end
end