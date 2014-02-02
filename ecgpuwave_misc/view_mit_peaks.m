function[] = view_mit_peaks(rec_no, analysis_id)

close all;
plot_dir = get_project_settings('plots');

global record_no
record_no = rec_no;
global target_rec
target_rec = 'P20_040';
global prblm_start_time
prblm_start_time = 0;
global start_time
start_time = 1; 
global window_length;
window_length = 1000;
global label_str
label_str = {'P', 'Q', 'R', 'S', 'T', 'U'};

nAnnotations = numel(label_str)-1;
load(fullfile(pwd, 'ecgpuwave', 'annotations', sprintf('%s.mat', record_no)));

global ecg_mat_puwave
ecg_mat_puwave = ecg_mat;
clear ecg_mat;
global peak_labels_puwave
peak_labels_puwave = ones(size(ecg_mat_puwave)) .* 6;
% if all(peak_labels_puwave(1, annt.P(~isnan(annt.P))) > 5)
	peak_labels_puwave(1, annt.P(~isnan(annt.P))) = 1;
% end
% if all(peak_labels_puwave(1, annt.Q(~isnan(annt.Q))) > 5)
	peak_labels_puwave(1, annt.Q(~isnan(annt.Q))) = 2;
% end
% if all(peak_labels_puwave(1, annt.R(~isnan(annt.R))) > 5)
	peak_labels_puwave(1, annt.R(~isnan(annt.R))) = 3;
% end
% if all(peak_labels_puwave(1, annt.S(~isnan(annt.S))) > 5)
	% nine labels 7 - Q's and 2 - P's
	peak_labels_puwave(1, annt.S(~isnan(annt.S))) = 4;
% end
% if all(peak_labels_puwave(1, annt.T(~isnan(annt.T))) > 5)
	peak_labels_puwave(1, annt.T(~isnan(annt.T))) = 5;
% end
assert(sum(isnan(peak_labels_puwave)) == 0);
assert(length(unique(peak_labels_puwave)) == 6);

global crf_pred_lbl
global misc_mat
global magic_idx
if strcmp(record_no(1:length(target_rec)), target_rec) | strcmp(record_no(1:length(target_rec)), target_rec)
	misc_mat = load(sprintf('misc_mats/%s_info.mat', analysis_id));
	magic_idx = [1.29e+5:7.138e+5, 7.806e+5:3.4e+6, 3.515e+6:length(misc_mat.peak_labels)];
	crf_pred_lbl = misc_mat.peak_labels(1, magic_idx);
	assert(isequal(size(crf_pred_lbl), size(ecg_mat_puwave)));
	assert(sum(isnan(crf_pred_lbl)) == 0);
end

S.fh = figure('units','pixels',...
		'position', [70, 10, 1300, 700],...
		'menubar', 'none',...
		'name', 'PQRST Interface',...
		'numbertitle', 'off',...
		'resize', 'off');

plot_data();

S.win_text = uicontrol('Style', 'text',...
		  'String', 'WIN Length',...
		  'units', 'pixels',...
		  'FontWeight', 'bold',...
		  'fontsize', 10,...
		  'Position', [20 600 100 20]);

S.disp_poph = uicontrol('Style', 'popup',...
		  'String', '50|100|250|500|1000',...
		  'Position', [20 550 100 50],...
		  'Callback', @update_window_length);

S.win_text = uicontrol('Style', 'text',...
		  'String', 'Shift WIN by',...
		  'units', 'pixels',...
		  'FontWeight', 'bold',...
		  'fontsize', 10,...
		  'Position', [20 540 100 20]);

S.shift_poph = uicontrol('Style', 'popup',...
		  'String', '0|500|1000|10000|100000',...
		  'Position', [20 490 100 50]);

y_location = 470;

S.disp_r_pushh = uicontrol('Style', 'pushbutton', 'String', 'NEXT WIN',...
		  'Position', [20 y_location 100 20],...
		  'Callback', {@right_shift_start_time, S});

S.disp_l_pushh = uicontrol('Style', 'pushbutton', 'String', 'PREV WIN',...
		  'Position', [20 y_location-30 100 20],...
		  'Callback', {@left_shift_start_time, S});

S.rnd_pushh = uicontrol('Style', 'pushbutton', 'String', 'RAND SAMPLE',...
		  'Position', [20 y_location-60 100 20],...
		  'Callback', {@generate_rand_sample, S});

S.ex_pushh = uicontrol('Style', 'pushbutton', 'String', 'QUIT',...
		  'Position', [20 y_location-180 100 20],...
		  'Callback', @exit_interface);

S.ex_pushh = uicontrol('Style', 'pushbutton', 'String', 'PRBL SEG',...
		  'Position', [20 y_location-210 100 20],...
		  'Callback', @problematic_segments);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function[] = problematic_segments(varargin)

global prblm_start_time;
global peak_labels_puwave;
global crf_pred_lbl;
global window_length;
global start_time;

b = find(crf_pred_lbl > 0 & crf_pred_lbl < 6 & crf_pred_lbl ~= peak_labels_puwave);
start_time = b(find(b > prblm_start_time));
start_time = start_time(1);
prblm_start_time = start_time + window_length;

plot_data();

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function[] = update_window_length(hObj, event)

global window_length
window_length = get(hObj, 'String');
window_length = str2num(window_length(get(hObj, 'Value'), :));

plot_data();

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function[] = right_shift_start_time(varargin)

global start_time;
global ecg_mat_puwave;
global window_length;

S = varargin{3};  % Get the structure.
user_choices = get(S.shift_poph, {'string', 'value'});  % Get the users choice.
shift_by = str2num(user_choices{1}(user_choices{2}, :));
start_time = start_time + window_length + shift_by;
if start_time+window_length > length(ecg_mat_puwave)
	start_time = length(ecg_mat_puwave) - window_length;
end

plot_data();

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function[] = left_shift_start_time(varargin)

global start_time;
global ecg_mat_puwave;
global window_length;

S = varargin{3};  % Get the structure.
user_choices = get(S.shift_poph, {'string', 'value'});  % Get the users choice.
shift_by = str2num(user_choices{1}(user_choices{2}, :));
start_time = start_time - window_length - shift_by;
if start_time < 1
	start_time = 1;
end

plot_data();

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function[] = generate_rand_sample(varargin)

global ecg_mat_puwave;
global start_time;

time = clock();
rand('twister', sum(100 * clock));
start_time = randi(length(ecg_mat_puwave), 1);

plot_data();

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function[] = plot_data()

global ecg_mat_puwave;
global peak_labels_puwave;
global crf_pred_lbl;
global start_time;
global window_length;
global record_no;
global target_rec;
global label_str;

font_size = get_project_settings('font_size');
le_fs = font_size(1); xl_fs = font_size(2); yl_fs = font_size(3);
xt_fs = font_size(4); yt_fs = font_size(5); tl_fs = font_size(6);

nIndicators = 6;

label_str2 = {'o', '+', 's', '*', 'd', '+'};
label_clr = {'R', 'B', 'G', 'M', 'C', 'K'};

data_idx = start_time:start_time+window_length;
if min(ecg_mat_puwave(data_idx)) == max(ecg_mat_puwave(data_idx))
	y_entries = linspace(1, 5, nIndicators);
	y_lim = [1, 5];
else
	y_entries = linspace(min(ecg_mat_puwave(data_idx)), max(ecg_mat_puwave(data_idx)), nIndicators);
	y_lim = [min(ecg_mat_puwave(data_idx)), max(ecg_mat_puwave(data_idx))];
end

plot(1:length(data_idx), ecg_mat_puwave(1, data_idx), 'b-', 'LineWidth', 2); hold on;
xlim([0, length(data_idx)]);
ylabel('Normalized Millivolts', 'FontSize', xl_fs, 'FontWeight', 'b', 'FontName', 'Times');
ylim(y_lim);
% set(gca, 'XTickLabel', time_matrix(1, [data_idx(1:window_length/10:window_length), data_idx(end)]),...
%					'FontSize', xt_fs, 'FontWeight', 'b', 'FontName', 'Times');

[rr, rs] = rrextract(ecg_mat_puwave(data_idx)', 250, 0.05);
rr_start_end = [rr(1:end-1); rr(2:end)-1]';
heart_rate = (1000 * 60) ./ (4 .* mean(rr_start_end(:, 2) - rr_start_end(:, 1)));
text(900, max(ecg_mat_puwave(data_idx)) + 10, sprintf('HR=%0.2f', heart_rate));

grid on;
win_peak_labels_puwave = peak_labels_puwave(1, data_idx);

if strcmp(record_no(1:length(target_rec)), target_rec) | strcmp(record_no(1:length(target_rec)), target_rec)
	win_peak_labels_crf = crf_pred_lbl(1, data_idx);
end

for lbl = 1:length(label_str)-1
	clear idx3;
	idx3 = win_peak_labels_puwave == lbl;
	text(find(idx3), ecg_mat_puwave(1, data_idx(find(idx3))), label_str{lbl}, 'FontSize', 16, 'FontWeight', 'Bold',...
									'color', label_clr{lbl});
	if strcmp(record_no(1:length(target_rec)), target_rec) | strcmp(record_no(1:length(target_rec)), target_rec)
		clear idx4;
		idx4 = win_peak_labels_crf == lbl;

		switch lbl
		case {1, 3, 5}
			%text(find(idx4), ecg_mat_puwave(1, data_idx(find(idx4))) - 7, label_str2{lbl}, 'FontSize', 20,...
			% 'FontWeight', 'Bold', 'color', label_clr{lbl});
			plot(find(idx4), ecg_mat_puwave(1, data_idx(find(idx4))) - 7, sprintf('%s%s', label_str2{lbl}, label_clr{lbl}),...
			'MarkerSize', 10, 'MarkerFaceColor', label_clr{lbl});

		case {2, 4}
			%text(find(idx4), ecg_mat_puwave(1, data_idx(find(idx4))) + 7, label_str2{lbl}, 'FontSize', 20,...
			% 'FontWeight', 'Bold', 'color', label_clr{lbl});
			plot(find(idx4), ecg_mat_puwave(1, data_idx(find(idx4))) + 7, sprintf('%s%s', label_str2{lbl}, label_clr{lbl}),...
			'MarkerSize', 15);
		end
	end
end	
hold off;

