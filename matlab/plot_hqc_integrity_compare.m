%% ==============================================================
%  Original HQC vs Chaos-enhanced HQC
%  Ciphertext Integrity / Tamper Resistance Comparison
%  SCI-style figures: colored lines, Times New Roman, 600 dpi
% ==============================================================

clear;
clc;
close all;

%% ---------- File names ----------
file_original = 'y_ciphertext_integrity_original.mat';
file_chaos    = 'ciphertext_integrity_uv.mat';

out_dir = 'fig_integrity_compare';

if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

%% ---------- Load data ----------
T_ori   = load_integrity_result(file_original, 'Original HQC');
T_chaos = load_integrity_result(file_chaos,    'Chaos-HQC');

%% ---------- Figure style ----------
set(0, 'DefaultFigureColor', 'w');
set(0, 'DefaultAxesFontName', 'Times New Roman');
set(0, 'DefaultTextFontName', 'Times New Roman');
set(0, 'DefaultAxesFontSize', 9);
set(0, 'DefaultTextFontSize', 9);
set(0, 'DefaultAxesLineWidth', 0.8);
set(0, 'DefaultLineLineWidth', 1.4);

components = {'u', 'v', 'full_ct'};
component_titles = {'(a) u component', '(b) v component', '(c) full ciphertext'};

%% ---------- Figure 1: SS Difference Rate ----------
plot_metric_compare( ...
    T_ori, T_chaos, ...
    components, component_titles, ...
    'SSDiffRate', ...
    'Shared-secret difference rate (%)', ...
    [0 105], ...
    fullfile(out_dir, 'Fig_SSDiffRate') ...
);

%% ---------- Figure 2: BCR Mean ----------
plot_metric_compare( ...
    T_ori, T_chaos, ...
    components, component_titles, ...
    'BCRMean', ...
    'Mean BCR of shared secret (%)', ...
    [0 100], ...
    fullfile(out_dir, 'Fig_BCRMean') ...
);

%% ---------- Figure 3: Reject Rate ----------
all_reject = [T_ori.RejectRate; T_chaos.RejectRate];

if any(isfinite(all_reject))
    plot_metric_compare( ...
        T_ori, T_chaos, ...
        components, component_titles, ...
        'RejectRate', ...
        'Decapsulation rejection rate (%)', ...
        [0 105], ...
        fullfile(out_dir, 'Fig_RejectRate') ...
    );
else
    fprintf('RejectRate 全部为 NaN，说明接口可能采用隐式拒绝且未返回 status，已跳过 RejectRate 图。\n');
end

fprintf('\n所有图像已保存到文件夹: %s\n', out_dir);


%% ==============================================================
%                      Local functions
% ==============================================================

function T = load_integrity_result(filename, scheme_name)

    S = load(filename);

    % ---------- component name ----------
    if isfield(S, 'component_name')
        comp = normalize_component_name(S.component_name);
    elseif isfield(S, 'component')
        comp = normalize_component_name(S.component);
    elseif isfield(S, 'component_code')
        comp = component_code_to_name(S.component_code);
    else
        error('文件 %s 中找不到 component_name / component / component_code', filename);
    end

    % ---------- required fields ----------
    flip_bits = get_field_vector(S, 'flip_bits');

    ss_diff_rate = get_field_vector(S, 'ss_diff_rate');
    bcr_mean     = get_field_vector(S, 'bcr_mean');

    if isfield(S, 'status_reject_rate')
        reject_rate = get_field_vector(S, 'status_reject_rate');
    else
        reject_rate = nan(size(flip_bits));
    end

    n = length(flip_bits);

    if length(comp) ~= n
        error('文件 %s 中 component 数量与 flip_bits 数量不一致', filename);
    end

    scheme = repmat({scheme_name}, n, 1);

    T = table( ...
        scheme, ...
        comp(:), ...
        flip_bits(:), ...
        ss_diff_rate(:), ...
        bcr_mean(:), ...
        reject_rate(:), ...
        'VariableNames', { ...
            'Scheme', ...
            'Component', ...
            'FlipBits', ...
            'SSDiffRate', ...
            'BCRMean', ...
            'RejectRate' ...
        } ...
    );
end


function comp = normalize_component_name(x)

    if iscell(x)
        comp = x(:);
    elseif isstring(x)
        comp = cellstr(x(:));
    elseif ischar(x)
        comp = cellstr(x);
    elseif isnumeric(x)
        comp = component_code_to_name(x);
    else
        error('无法识别 component_name 的数据类型');
    end

    for i = 1:length(comp)
        comp{i} = strtrim(comp{i});
    end
end


function comp = component_code_to_name(code)

    code = code(:);
    comp = cell(length(code), 1);

    for i = 1:length(code)
        if code(i) == 1
            comp{i} = 'u';
        elseif code(i) == 2
            comp{i} = 'v';
        elseif code(i) == 3
            comp{i} = 'full_ct';
        else
            comp{i} = 'unknown';
        end
    end
end


function v = get_field_vector(S, field_name)

    if ~isfield(S, field_name)
        error('mat 文件中缺少字段: %s', field_name);
    end

    v = double(S.(field_name));
    v = v(:);
end


function plot_metric_compare(T_ori, T_chaos, components, component_titles, metric_name, y_label, y_lim, save_base)

    fig = figure;
    set(fig, 'Units', 'centimeters', 'Position', [2, 2, 18, 6.5]);

    for k = 1:length(components)

        subplot(1, 3, k);
        hold on;
        box on;

        comp = components{k};

        idx_ori = strcmp(T_ori.Component, comp);
        idx_cha = strcmp(T_chaos.Component, comp);

        x_ori = T_ori.FlipBits(idx_ori);
        y_ori = T_ori.(metric_name)(idx_ori);

        x_cha = T_chaos.FlipBits(idx_cha);
        y_cha = T_chaos.(metric_name)(idx_cha);

        [x_ori, order_ori] = sort(x_ori);
        y_ori = y_ori(order_ori);

        [x_cha, order_cha] = sort(x_cha);
        y_cha = y_cha(order_cha);

        % ========== 修改为彩色 ==========
        % Original HQC: 蓝色
        plot( ...
            x_ori, y_ori, ...
            '-o', ...
            'Color', [0, 0.4470, 0.7410], ...      % MATLAB 默认蓝
            'MarkerFaceColor', [0, 0.4470, 0.7410], ...
            'MarkerEdgeColor', [0, 0.4470, 0.7410], ...
            'MarkerSize', 4.5 ...
        );

        % Chaos-HQC: 红色
        plot( ...
            x_cha, y_cha, ...
            '--s', ...
            'Color', [0.85, 0.325, 0.098], ...      % MATLAB 默认橙红
            'MarkerFaceColor', [0.85, 0.325, 0.098], ...
            'MarkerEdgeColor', [0.85, 0.325, 0.098], ...
            'MarkerSize', 4.5 ...
        );
        % =================================

        title(component_titles{k}, 'FontWeight', 'normal');
        xlabel('Number of flipped bits');
        ylabel(y_label);

        ylim(y_lim);

        x_all = unique([x_ori; x_cha]);
        set(gca, 'XTick', x_all);

        grid on;
        set(gca, ...
            'GridLineStyle', ':', ...
            'GridAlpha', 0.25, ...
            'TickDir', 'in', ...
            'Layer', 'top' ...
        );

        if k == 1
            legend( ...
                {'Original HQC', 'Chaos-HQC'}, ...
                'Location', 'best', ...
                'Box', 'off' ...
            );
        end
    end

    % ---------- Save figures ----------
    print(fig, [save_base '.tif'], '-dtiff', '-r600');
    print(fig, [save_base '.eps'], '-depsc', '-painters');

end