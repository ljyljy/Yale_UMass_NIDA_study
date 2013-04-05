function[] = classify_ecg_driver(tr_percent)

nSubjects = 7;
set_of_features_to_try = [1:9];
nRuns = 1;
% classifierList = {@two_class_linear_kernel_logreg, @two_class_logreg, @two_class_svm_linear};
classifierList = {@two_class_logreg};

subject_ids = get_subject_ids(nSubjects);
result_dir = get_project_settings('results');

% Looping over each subject and performing classification
for s = 1:nSubjects
	switch subject_ids{s}
	case 'P20_060', classes_to_classify = [1, 2; 1, 3; 1, 4; 1, 5; 5, 9; 5, 10];
	case 'P20_061', classes_to_classify = [1, 4; 1, 5; 5, 12];
	otherwise, classes_to_classify = [1, 2; 1, 3; 1, 4; 1, 5];
	end
	nAnalysis = size(classes_to_classify, 1);
	mean_over_runs = cell(1, nAnalysis);
	errorbars_over_runs = cell(1, nAnalysis);
	tpr_over_runs = cell(1, nAnalysis);
	fpr_over_runs = cell(1, nAnalysis);
	auc_over_runs = cell(1, nAnalysis);
	chance_baseline = cell(1, nAnalysis);
	feature_str = cell(1, nAnalysis);
	class_label = cell(1, nAnalysis);
	% Looping over each pair of classification tasks i.e. 1 vs 2, 1 vs 3, etc
	for c = 1:nAnalysis
		[mean_over_runs{1, c}, errorbars_over_runs{1, c}, feature_str{1, c}, class_label{1, c},...
		chance_baseline{1, c}, tpr_over_runs{1, c}, fpr_over_runs{1, c}, auc_over_runs{1, c}] =...
				classify_ecg_data(subject_ids{s}, classes_to_classify(c, :),...
				set_of_features_to_try, nRuns, tr_percent, classifierList);
	end
	% Collecting the results to plotted later
	classifier_results = struct();
	classifier_results.mean_over_runs = mean_over_runs;
	classifier_results.errorbars_over_runs = errorbars_over_runs;
	classifier_results.tpr_over_runs = tpr_over_runs;
	classifier_results.fpr_over_runs = fpr_over_runs;
	classifier_results.auc_over_runs = auc_over_runs;
	classifier_results.feature_str = feature_str;
	classifier_results.class_label = class_label;
	classifier_results.chance_baseline = chance_baseline;
	% save(fullfile(result_dir, subject_ids{s}, sprintf('%s_classifier_results_tr%d', subject_ids{s}, tr_percent)),...
	%						'-struct', 'classifier_results');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function[mean_over_runs, errorbars_over_runs, feature_str, class_label, chance_baseline, tpr_over_runs, fpr_over_runs, auc_over_runs] =...
			classify_ecg_data(subject_id, classes_to_classify, set_of_features_to_try, nRuns, tr_percent, classifierList)

nFeatures = length(set_of_features_to_try);
nClassifiers = numel(classifierList);
nClasses = length(classes_to_classify);
if nargin < 6, error('Missing input arguments!'); end
assert(nClasses == 2);

loaded_data = [];
class_label = cell(1, nClasses);
feature_str = cell(1, nFeatures);
chance_baseline = NaN(nFeatures, nRuns);
mean_over_runs = NaN(nFeatures, nClassifiers);
errorbars_over_runs = NaN(nFeatures, nClassifiers);
tpr_over_runs = NaN(nFeatures, nClassifiers);
fpr_over_runs = NaN(nFeatures, nClassifiers);
auc_over_runs = NaN(nFeatures, nClassifiers);

% Loop over each class in a two class problem and fetch the data instances x all features for each class (while respecting the session and dosage levels). Look at this as trimming the data matrix by only removing unnecessary rows
for c = 1:nClasses
	loaded_data = [loaded_data; massage_data(subject_id, classes_to_classify(c))];
	class_information = classifier_profile(classes_to_classify(c));
	class_label{1, c} = class_information{1, 1}.label;
end

switch classes_to_classify(2)
case 2
	fprintf('%s, class %d = %d; class %d = %d\n', subject_id, classes_to_classify(1), sum(loaded_data(:, end) == 1),...
						  classes_to_classify(2), sum(loaded_data(:, end) == 2));
case 3
	fprintf('%s, class %d = %d; class %d = %d\n', subject_id, classes_to_classify(1), sum(loaded_data(:, end) == 1),...
						  classes_to_classify(2), sum(loaded_data(:, end) == 3));
case 4
	fprintf('%s, class %d = %d; class %d = %d\n', subject_id, classes_to_classify(1), sum(loaded_data(:, end) == 1),...
						  classes_to_classify(2), sum(loaded_data(:, end) == 4));
case 5
	fprintf('%s, class %d = %d; class %d = %d\n', subject_id, classes_to_classify(1), sum(loaded_data(:, end) == 1),...
						  classes_to_classify(2), sum(loaded_data(:, end) == 5));
end

%{
% For each feature to try we trim the data matrix by removing irrelevant columns
for f = 1:length(set_of_features_to_try)
	accuracies = NaN(nRuns, nClassifiers);
	true_pos_rate = NaN(nRuns, nClassifiers);
	false_pos_rate = NaN(nRuns, nClassifiers);
	auc = NaN(nRuns, nClassifiers);
	[feature_extracted_data, feature_str{1, f}] = setup_features(loaded_data, set_of_features_to_try(f));
	% Repeat this process over runs. Now for the training partition we are performing (retain first half to train and
	% second half to test) there is no randomness so only one run will suffice. This code exists to make life easier :)
	for r = 1:nRuns
		[complete_train_set, complete_test_set, chance_baseline(f, r)] =...
					partition_and_relabel(feature_extracted_data, tr_percent);
		disp(sprintf('%s \t%s \t%s \t%s \t%d \t%d', subject_id, class_label{1, 1}, class_label{1, 2},...
			feature_str{1, f}, size(complete_train_set, 1), size(complete_test_set, 1)));
		% Finally run this dataset through each classifier and gather results
		for k = 1:nClassifiers
			save_betas = sprintf('class_%s_feat%d_%d_vs_%d', subject_id,...
				set_of_features_to_try(f), classes_to_classify(1), classes_to_classify(2));

			[accuracies(r, k), true_pos_rate(r, k), false_pos_rate(r, k), auc(r, k)] =...
			classifierList{k}(complete_train_set, complete_test_set, save_betas);
		end
	end
	mean_over_runs(f, :) = mean(accuracies, 1);
	errorbars_over_runs(f, :) = std(accuracies, [], 1) ./ nRuns;
	tpr_over_runs(f, :) = mean(true_pos_rate, 1);
	fpr_over_runs(f, :) = mean(false_pos_rate, 1);
	auc_over_runs(f, :) = mean(auc, 1);
end
%}

