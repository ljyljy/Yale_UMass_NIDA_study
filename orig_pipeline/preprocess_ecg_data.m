function[subject_profile] = preprocess_ecg_data(subject_profile)

subject_id =  subject_profile.subject_id;
plot_dir = get_project_settings('plots');
if ~exist(fullfile(plot_dir, subject_id))
	mkdir(fullfile(plot_dir, subject_id));
end
result_dir = get_project_settings('results');
if ~exist(fullfile(result_dir, subject_id))
	mkdir(fullfile(result_dir, subject_id));
end

for v = 1:subject_profile.nEvents
	if ~isfield(subject_profile.events{v}, 'preprocessed_mat_path')
		switch subject_profile.events{v}.label
		case 'cocaine'
			mat_path = preprocess_cocaine_day_data(subject_profile, v);
		otherwise
			mat_path = preprocess_other_events_data(subject_profile, v);
		end
		subject_profile.events{v}.preprocessed_mat_path = mat_path;
	end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function[mat_path] = preprocess_other_events_data(subject_profile, event)

data_dir = get_project_settings('data');
result_dir = get_project_settings('results');
raw_ecg_mat_time_res = get_project_settings('raw_ecg_mat_time_res');

subject_id =  subject_profile.subject_id;
subject_sensor = subject_profile.events{event}.sensor;
subject_timestamp = subject_profile.events{event}.timestamp;
dosage_levels = subject_profile.events{event}.dosage_levels;
raw_ecg_mat_columns = subject_profile.columns.raw_ecg;
event_start_hh = subject_profile.events{1, event}.start_time(1);
event_start_mm = subject_profile.events{1, event}.start_time(2);
event_end_hh = subject_profile.events{1, event}.end_time(1);
event_end_mm = subject_profile.events{1, event}.end_time(2);

ecg_mat = csvread(fullfile(data_dir, subject_id, subject_sensor, subject_timestamp, sprintf('%s_ECG.csv', subject_timestamp)), 1, 0);

if length(subject_profile.events{1, event}.start_time) > 2 & length(subject_profile.events{1, event}.end_time) > 2
	start_temp = find(ecg_mat(:, raw_ecg_mat_columns.actual_hh) == event_start_hh &...
			  ecg_mat(:, raw_ecg_mat_columns.actual_mm) == event_start_mm &...
			  round_to(ecg_mat(:, raw_ecg_mat_columns.actual_ss), 0) == subject_profile.events{1, event}.start_time(3));
	end_temp = find(ecg_mat(:, raw_ecg_mat_columns.actual_hh) == event_end_hh &...
			ecg_mat(:, raw_ecg_mat_columns.actual_mm) == event_end_mm &...
			round_to(ecg_mat(:, raw_ecg_mat_columns.actual_ss), 0) == subject_profile.events{1, event}.end_time(3));
else
	start_temp = find(ecg_mat(:, raw_ecg_mat_columns.actual_hh) == event_start_hh &...
			  ecg_mat(:, raw_ecg_mat_columns.actual_mm) == event_start_mm);
	end_temp = find(ecg_mat(:, raw_ecg_mat_columns.actual_hh) == event_end_hh &...
			ecg_mat(:, raw_ecg_mat_columns.actual_mm) == event_end_mm);
end
% assert(length(start_temp) == 60 * raw_ecg_mat_time_res);
% assert(length(end_temp) == 60 * raw_ecg_mat_time_res);

% This is the case since the self administration day is organized as experiment sessions and dosage levels
preprocessed_data = cell(1, length(subject_profile.events{event}.exp_sessions));
for e = 1:length(subject_profile.events{event}.exp_sessions)
	session_data = struct();
	session_data.x_size = [];
	session_data.x_time = cell(1, length(dosage_levels));
	session_data.interpolated_ecg = [];
	session_data.hold_start_end_indices = [];
	session_data.valid_rr_intervals = [];
	session_data.dosage_labels = [];
	for d = 1:length(dosage_levels)
		[length_x, x_time, dos_interpolated_ecg, hold_start_end_indices, valid_rr_intervals] =...
					break_up_trace(event, ecg_mat, subject_profile, start_temp(1), end_temp(end));

		session_data.x_size(d) = length_x;
		session_data.x_time{1, d} = x_time;
		session_data.interpolated_ecg = [session_data.interpolated_ecg; dos_interpolated_ecg];
		session_data.hold_start_end_indices = [session_data.hold_start_end_indices; hold_start_end_indices];
		session_data.valid_rr_intervals = [session_data.valid_rr_intervals; valid_rr_intervals];
		session_data.dosage_labels = [session_data.dosage_labels; repmat(dosage_levels(d), size(dos_interpolated_ecg, 1), 1)];
	end
	preprocessed_data{1, e} = session_data;
end
mat_path = fullfile(result_dir, subject_id, sprintf('%s_preprocessed_data', subject_profile.events{event}.file_name));
save(mat_path, 'preprocessed_data');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function[mat_path] = preprocess_cocaine_day_data(subject_profile, event)

data_dir = get_project_settings('data');
result_dir = get_project_settings('results');

subject_id =  subject_profile.subject_id;
subject_sensor = subject_profile.events{event}.sensor;
subject_timestamp = subject_profile.events{event}.timestamp;
behav_mat_columns = subject_profile.columns.behav;

% Loading the raw ECG data
% The raw ECG data is sampled every 4 milliseconds so for every 250 (250 x 4 = 1000 = 1 second) samples we will have an entry in the summary table. Now the summary table has entries for sec1.440 i.e. sec1.440 to sec2.436 are summarized into this entry.
ecg_mat = csvread(fullfile(data_dir, subject_id, subject_sensor, subject_timestamp, sprintf('%s_ECG.csv', subject_timestamp)), 1, 0);

% Loading the behavior data
behav_mat = csvread(fullfile(data_dir, subject_id, sprintf('%s_behav.csv', subject_id)), 1, 0);

preprocessed_data = cell(1, length(subject_profile.events{event}.exp_sessions));
for e = 1:length(subject_profile.events{event}.exp_sessions)
	preprocessed_data{1, e} = preprocess_by_session(subject_profile, ecg_mat, behav_mat, event, e);
end
mat_path = fullfile(result_dir, subject_id, sprintf('%s_preprocessed_data', subject_profile.events{event}.file_name));
save(mat_path, 'preprocessed_data');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function[session_data] = preprocess_by_session(subject_profile, ecg_mat, behav_mat, event, exp_sess_no)

image_format = get_project_settings('image_format');
plot_dir = get_project_settings('plots');
raw_ecg_mat_time_res = get_project_settings('raw_ecg_mat_time_res');

subject_id =  subject_profile.subject_id;
experiment_session = subject_profile.events{event}.exp_sessions(exp_sess_no);
dosage_levels = subject_profile.events{event}.dosage_levels;
behav_mat_columns = subject_profile.columns.behav;
raw_ecg_mat_columns = subject_profile.columns.raw_ecg;

session_data = struct();
session_data.interpolated_ecg = [];
session_data.dosage_labels = [];
session_data.hold_start_end_indices = [];
session_data.x_size = [];
session_data.x_time = cell(1, length(dosage_levels));
session_data.valid_rr_intervals = [];

for d = 1:length(dosage_levels)
	% For the d mg infusion ONLY in the first session, fetch the associated indices from the absolute time axis.
	% For instance this fetches 11100:60:12660 = 27 time points
	sess_start_end = find(behav_mat(:, behav_mat_columns.session) == experiment_session);
	dosg_start_end = find(behav_mat(:, behav_mat_columns.dosage) == dosage_levels(d));
	dosg_sess_start_end = intersect(dosg_start_end, sess_start_end);
	if ~isempty(dosg_sess_start_end)
		disp(sprintf('dosage=%d', dosage_levels(d)));
		disp(sprintf('Behav: %d:%d -- %d:%d',...
			behav_mat(dosg_sess_start_end(1), behav_mat_columns.actual_hh),...
			behav_mat(dosg_sess_start_end(1), behav_mat_columns.actual_mm),...
			behav_mat(dosg_sess_start_end(end), behav_mat_columns.actual_hh),...
			behav_mat(dosg_sess_start_end(end), behav_mat_columns.actual_mm)));

		% I index the start and end times in raw ECG data stream using the start and end times from behavior data
		raw_start_time = find(ecg_mat(:, raw_ecg_mat_columns.actual_hh) ==...
				  behav_mat(dosg_sess_start_end(1), behav_mat_columns.actual_hh) &...
				  ecg_mat(:, raw_ecg_mat_columns.actual_mm) ==...
				  behav_mat(dosg_sess_start_end(1), behav_mat_columns.actual_mm));
		raw_end_time = find(ecg_mat(:, raw_ecg_mat_columns.actual_hh) ==...
				behav_mat(dosg_sess_start_end(end), behav_mat_columns.actual_hh) &...
				ecg_mat(:, raw_ecg_mat_columns.actual_mm) ==...
				behav_mat(dosg_sess_start_end(end), behav_mat_columns.actual_mm));

		[length_x, x_time, dos_interpolated_ecg, hold_start_end_indices, valid_rr_intervals] =...
						break_up_trace(event, ecg_mat, subject_profile, raw_start_time(1), raw_end_time(end));

		session_data.x_size(d) = length_x;
		session_data.x_time{1, d} = x_time;
		session_data.interpolated_ecg = [session_data.interpolated_ecg;...
						dos_interpolated_ecg];
		session_data.hold_start_end_indices = [session_data.hold_start_end_indices;...
						hold_start_end_indices];
		session_data.valid_rr_intervals = [session_data.valid_rr_intervals;...
						valid_rr_intervals];
		session_data.dosage_labels = [session_data.dosage_labels;...
						repmat(dosage_levels(d), size(dos_interpolated_ecg, 1), 1)];
	end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function[length_x, x_time, dos_interpolated_ecg, hold_start_end_indices, valid_rr_intervals] =...
						break_up_trace(event, ecg_mat, subject_profile, raw_start_time, raw_end_time)

cut_off_heart_rate = get_project_settings('cut_off_heart_rate');
nInterpolatedFeatures = get_project_settings('nInterpolatedFeatures');
raw_ecg_mat_time_res = get_project_settings('raw_ecg_mat_time_res');
subject_id =  subject_profile.subject_id;
subject_sensor = subject_profile.events{event}.sensor;
subject_timestamp = subject_profile.events{event}.timestamp;
raw_ecg_mat_columns = subject_profile.columns.raw_ecg;
subject_threshold = subject_profile.events{event}.rr_thresholds;
scaling_factor = subject_profile.events{event}.scaling_factor;

dos_interpolated_ecg = [];
hold_start_end_indices = [];
valid_rr_intervals = [];

disp(sprintf('Raw ECG: %d:%d:%0.3f -- %d:%d:%0.3f',...
	ecg_mat(raw_start_time, raw_ecg_mat_columns.actual_hh),...
	ecg_mat(raw_start_time, raw_ecg_mat_columns.actual_mm),...
	ecg_mat(raw_start_time, raw_ecg_mat_columns.actual_ss),...
	ecg_mat(raw_end_time, raw_ecg_mat_columns.actual_hh),...
	ecg_mat(raw_end_time, raw_ecg_mat_columns.actual_mm),...
	ecg_mat(raw_end_time, raw_ecg_mat_columns.actual_ss)));

% converting the bioharness numbers into millivolts
x = ecg_mat(raw_start_time:raw_end_time, raw_ecg_mat_columns.ecg) .* scaling_factor;
length_x = length(x);

% the below code will need to be revamped since there are gaps in cellphone data
x_time = ecg_mat(raw_start_time:raw_end_time, raw_ecg_mat_columns.actual_y:raw_ecg_mat_columns.actual_ss);

rr_pk_window = 15000;
rr_win = [0:rr_pk_window:length(x)];
if length(x) - rr_win(end) > 0
	rr_win = [0:rr_pk_window:length(x), length(x)];
end
rr = [];
for r = 1:length(rr_win)-1
	rr = [rr, rr_win(r)+rrextract(x(rr_win(r)+1:rr_win(r+1)), raw_ecg_mat_time_res, subject_threshold)];
end
assert(length(rr) == length(unique(rr)));

rr_start_end = [rr(1:end-1); rr(2:end)-1]';
for s = 1:size(rr_start_end, 1)
	if length(rr_start_end(s, 1):rr_start_end(s, 2)) >= cut_off_heart_rate(1) &...
	   length(rr_start_end(s, 1):rr_start_end(s, 2)) <= cut_off_heart_rate(2)

		% Interplotaing the RR chunks
		x_length = length(rr_start_end(s, 1):rr_start_end(s, 2));
		xi = linspace(1, x_length, nInterpolatedFeatures);
		interpol_data = interp1(1:x_length, x(rr_start_end(s, 1):rr_start_end(s, 2)), xi, 'pchip');
		if max(interpol_data) <= 5 & min(interpol_data) >= 0
			dos_interpolated_ecg = [dos_interpolated_ecg; interpol_data];
			hold_start_end_indices = [hold_start_end_indices; rr_start_end(s, :)];
			valid_rr_intervals = [valid_rr_intervals; x_length];
		else
			disp(sprintf('Interpolated data is out of bounds!')); keyboard
		end
	end
end

%{
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Plot 1: Raw ECG for baselines, 8mg, etc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure(); set(gcf, 'Position', get_project_settings('figure_size'));
plot(x, 'b-');
xlabel('Time(4ms resolution)'); ylabel('millivolts');
title(sprintf('%s, raw ECG', title_str)); ylim([0, 5]);
file_name = sprintf('%s/subj_%s_dos_%d_raw_chunk', plot_dir, subject_id, d);
savesamesize(gcf, 'file', file_name, 'format', image_format);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Plot 2: Raw ECG broken into RR chunks; variable length
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure(); set(gcf, 'Position', get_project_settings('figure_size'));
plot(x(rr_start_end(s, 1):rr_start_end(s, 2)), 'r-'); hold on;
plot(repmat(cut_off_heart_rate(1), 1, 6), 0:5, 'k*');
plot(repmat(cut_off_heart_rate(2), 1, 6), 0:5, 'k*');
xlabel('Time(milliseconds)'); ylabel('millivolts');
title(sprintf('%s, raw ECG b/w RR', title_str)); ylim([0, 5]);
set(gca, 'XTickLabel', str2num(get(gca, 'XTickLabel')) * 4);
file_name = sprintf('%s/subj_%s_dos_%d_raw_rr', plot_dir, subject_id, d);
savesamesize(gcf, 'file', file_name, 'format', image_format);
%}

%{
figure(); plot(x); hold on; plot(rr, x(rr), 'ro'); 
length(rr)
keyboard
close all;
%}

