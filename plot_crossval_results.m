function[] = plot_crossval_results()

close all;

nSubjects = 6;
subject_ids = get_subject_ids(nSubjects);
result_dir = get_project_settings('results');
plot_dir = get_project_settings('plots');
image_format = get_project_settings('image_format');

auroc_over_subjects = NaN(4, 4, nSubjects);
for s = 1:nSubjects
	classifier_results = load(fullfile(result_dir, subject_ids{s}, sprintf('cross_val_results.mat')));
	nAnalysis = length(classifier_results.mean_over_runs);
	legend_str = {};
	for a = 1:nAnalysis
		nFeatures = length(classifier_results.mean_over_runs{1, a});
		feature_str = classifier_results.feature_str{1, a};
		class_label = classifier_results.class_label{1, a};
		legend_str{a} = sprintf('%s vs %s', class_label{1}, class_label{2});
	end

	figure('visible', 'off'); set(gcf, 'Position', get_project_settings('figure_size'));
	% figure(); set(gcf, 'Position', get_project_settings('figure_size'));
	bar([classifier_results.auc_over_runs{:}]);
	legend(legend_str, 'Location', 'South', 'Orientation', 'Horizontal');
	xlabel('Features'); ylabel('AUROC');
	set(gca, 'XTick', 1:nFeatures);
	set(gca, 'XTickLabel', feature_str);
	xlim([0.5, nFeatures+0.5]); grid on; ylim([0, 1]);
	title(sprintf('%s, cross validation, Logistic reg, Area under ROC', get_project_settings('strrep_subj_id', subject_ids{s})));
	file_name = sprintf('%s/%s/crossval_subj%d_auroc', plot_dir, subject_ids{s}, s);
	savesamesize(gcf, 'file', file_name, 'format', image_format);

	auroc_over_subjects(:, :, s) = [classifier_results.auc_over_runs{:}];

end

figure(); set(gcf, 'Position', get_project_settings('figure_size'));
model_series = mean(auroc_over_subjects, 3);
model_error = (std(auroc_over_subjects, [], 3) ./ nSubjects);

h = bar(model_series);
set(h, 'BarWidth', 1); % The bars will now touch each other
hold on; grid on;

numgroups = size(model_series, 1); 
numbars = size(model_series, 2); 
groupwidth = min(0.8, numbars/(numbars+1.5));
for i = 1:numbars
	% Based on barweb.m by Bolu Ajiboye from MATLAB File Exchange
	x = (1:numgroups) - groupwidth/2 + (2*i-1) * groupwidth / (2*numbars); % Aligning error bar with individual bar
	errorbar(x, model_series(:,i), model_error(:,i), 'k', 'linestyle', 'none', 'LineWidth', 2);
end

legend(legend_str, 'Location', 'South', 'Orientation', 'Horizontal');
xlabel('Features'); ylabel('AUROC');
set(gca, 'XTick', 1:nFeatures);
set(gca, 'XTickLabel', feature_str);
xlim([0.5, nFeatures+0.5]); grid on; ylim([0, 1]);
title(sprintf('Mean cross validation, Logistic reg, Area under ROC'));

file_name = sprintf('%s/mean_crossval_auroc', plot_dir);
savesamesize(gcf, 'file', file_name, 'format', image_format);

