% =========================================================================
% Logistic Map Sensitivity – SCI publication-quality version
% =========================================================================
clear; clc; close all;

%% ===================== Global style settings ============================
fontName = 'Times New Roman';

set(groot, ...
    'DefaultFigureColor', 'w', ...
    'DefaultAxesFontName', fontName, ...
    'DefaultTextFontName', fontName, ...
    'DefaultAxesFontSize', 9, ...
    'DefaultTextFontSize', 9, ...
    'DefaultAxesLineWidth', 0.75, ...
    'DefaultLineLineWidth', 1.1, ...
    'DefaultAxesTickDir', 'out', ...
    'DefaultAxesBox', 'on', ...
    'DefaultAxesXGrid', 'on', ...
    'DefaultAxesYGrid', 'on', ...
    'DefaultAxesGridAlpha', 0.18, ...
    'DefaultAxesMinorGridAlpha', 0.08, ...
    'DefaultAxesTickLabelInterpreter', 'tex', ...
    'DefaultTextInterpreter', 'tex', ...
    'DefaultLegendInterpreter', 'tex');

dpi = 600;
outDir = 'SCI_Figures';
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% ===================== Load data ========================================
load('logistic_sensitivity.mat');

R_rand = double(R_rand(:));
R_x0   = double(R_x0(:));
R_r    = double(R_r(:));

data = {R_rand, R_x0, R_r};
N = numel(R_rand);

% Check data length
if any([numel(R_x0), numel(R_r)] ~= N)
    warning('The lengths of R_rand, R_x0 and R_r are not identical.');
end

%% ===================== Colors ===========================================
% Colorblind-friendly palette
c_rand  = [0.0000 0.4470 0.7410];   % blue
c_x0    = [0.8500 0.3250 0.0980];   % orange-red
c_r     = [0.4660 0.6740 0.1880];   % green
c_ideal = [0.6350 0.0780 0.1840];   % dark red
c_mean  = [0.1000 0.1000 0.1000];   % black-gray

colors = {c_rand, c_x0, c_r};

titles_en = {'(a) Random bit flip', ...
             '(b) Perturb x_0', ...
             '(c) Perturb r'};

scene_names = {'Random flip', 'x_0 perturbation', 'r perturbation'};

%% ========================================================================
% FIGURE 1: Histograms
% ========================================================================
fig1 = figure('Name', 'Histograms', ...
              'Units', 'centimeters', ...
              'Position', [2 12 17.5 6.2], ...
              'Color', 'w');

t1 = tiledlayout(fig1, 1, 3, ...
                 'TileSpacing', 'compact', ...
                 'Padding', 'compact');

edges = 0.35:0.01:0.65;

% Pre-calculate unified y limit
histMax = 0;
for idx = 1:3
    counts = histcounts(data{idx}, edges, 'Normalization', 'probability');
    histMax = max(histMax, max(counts));
end
histYLim = [0, histMax * 1.18];

for idx = 1:3
    ax = nexttile(t1);
    R = data{idx};
    col = colors{idx};

    histogram(R, edges, ...
        'Normalization', 'probability', ...
        'FaceColor', col, ...
        'FaceAlpha', 0.85, ...
        'EdgeColor', 'w', ...
        'LineWidth', 0.45);
    hold on;

    xline(0.5, '--', ...
        'Color', c_ideal, ...
        'LineWidth', 1.2);

    xline(mean(R), '-', ...
        'Color', c_mean, ...
        'LineWidth', 1.2);

    xlabel('Bit change rate, R');
    if idx == 1
        ylabel('Probability');
    end

    title(titles_en{idx}, ...
        'FontWeight', 'normal', ...
        'FontSize', 10);

    xlim([0.35 0.65]);
    ylim(histYLim);

    set(ax, ...
        'FontName', fontName, ...
        'FontSize', 9, ...
        'LineWidth', 0.75, ...
        'TickDir', 'out', ...
        'Layer', 'top');

    ax.XMinorTick = 'on';
    ax.YMinorTick = 'on';
end

exportFig(fig1, fullfile(outDir, 'Fig1_Histograms'), dpi);

%% ========================================================================
% FIGURE 2: Sequential responses
% ========================================================================
fig2 = figure('Name', 'Sequential', ...
              'Units', 'centimeters', ...
              'Position', [2 4 17.5 6.2], ...
              'Color', 'w');

t2 = tiledlayout(fig2, 1, 3, ...
                 'TileSpacing', 'compact', ...
                 'Padding', 'compact');

legendHandles = gobjects(1, 4);

for idx = 1:3
    ax = nexttile(t2);
    R = data{idx};
    col = colors{idx};
    nLocal = numel(R);

    % Lighter raw curve
    rawCol = 0.65 * [1 1 1] + 0.35 * col;

    p1 = plot(1:nLocal, R, '-', ...
        'Color', rawCol, ...
        'LineWidth', 0.45);
    hold on;

    win = min(20, nLocal);
    R_sm = movmean(R, win);

    p2 = plot(1:nLocal, R_sm, '-', ...
        'Color', col, ...
        'LineWidth', 1.25);

    p3 = yline(0.5, '--', ...
        'Color', c_ideal, ...
        'LineWidth', 1.15);

    p4 = yline(mean(R), '-', ...
        'Color', c_mean, ...
        'LineWidth', 1.05);

    if idx == 1
        legendHandles = [p1 p2 p3 p4];
    end

    xlabel('Test index');
    if idx == 1
        ylabel('Bit change rate, R');
    end

    title(titles_en{idx}, ...
        'FontWeight', 'normal', ...
        'FontSize', 10);

    xlim([1 nLocal]);
    ylim([0.35 0.65]);

    set(ax, ...
        'FontName', fontName, ...
        'FontSize', 9, ...
        'LineWidth', 0.75, ...
        'TickDir', 'out', ...
        'Layer', 'top');

    ax.XMinorTick = 'on';
    ax.YMinorTick = 'on';
end

lgd = legend(legendHandles, ...
    {'Raw data', 'Moving average', 'Ideal value 0.5', 'Mean value'}, ...
    'Orientation', 'horizontal', ...
    'FontSize', 8, ...
    'Box', 'off');

lgd.Layout.Tile = 'south';

exportFig(fig2, fullfile(outDir, 'Fig2_Sequential'), dpi);

%% ========================================================================
% FIGURE 3: Statistical metrics
% ========================================================================
metrics = zeros(3, 4);
for idx = 1:3
    d = data{idx};
    metrics(idx, :) = [mean(d), std(d), min(d), max(d)];
end

metric_names = {'(a) Mean', '(b) Standard deviation', ...
                '(c) Minimum', '(d) Maximum'};

bar_colors = [c_rand; c_x0; c_r];

fig3 = figure('Name', 'Metrics', ...
              'Units', 'centimeters', ...
              'Position', [10 2 17.5 13.5], ...
              'Color', 'w');

t3 = tiledlayout(fig3, 2, 2, ...
                 'TileSpacing', 'compact', ...
                 'Padding', 'compact');

for m = 1:4
    ax = nexttile(t3);

    b = bar(1:3, metrics(:, m), 0.55);
    b.FaceColor = 'flat';
    b.EdgeColor = [0.15 0.15 0.15];
    b.LineWidth = 0.55;

    for k = 1:3
        b.CData(k, :) = bar_colors(k, :);
    end
    hold on;

    if m == 1
        yline(0.5, '--', ...
            'Color', c_ideal, ...
            'LineWidth', 1.2);
    end

    maxVal = max(metrics(:, m));
    minVal = min(metrics(:, m));

    if m == 1
        ylim([0.45 0.55]);
        textOffset = 0.004;
    elseif m == 2
        ylim([0, maxVal * 1.35]);
        textOffset = maxVal * 0.05;
    else
        yLower = max(0, minVal - 0.08);
        yUpper = min(1, maxVal + 0.08);
        ylim([yLower yUpper]);
        textOffset = (yUpper - yLower) * 0.035;
    end

    for k = 1:3
        text(k, metrics(k, m) + textOffset, ...
            sprintf('%.4f', metrics(k, m)), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', ...
            'FontSize', 8.5);
    end

    set(ax, ...
        'XTick', 1:3, ...
        'XTickLabel', scene_names, ...
        'FontName', fontName, ...
        'FontSize', 9, ...
        'LineWidth', 0.75, ...
        'TickDir', 'out', ...
        'Layer', 'top');

    xtickangle(18);

    title(metric_names{m}, ...
        'FontWeight', 'normal', ...
        'FontSize', 10);

    if m == 1 || m == 3
        ylabel('Bit change rate, R');
    end

    ax.XMinorTick = 'off';
    ax.YMinorTick = 'on';
end

exportFig(fig3, fullfile(outDir, 'Fig3_Metrics'), dpi);

%% ===================== Print numerical results ===========================
fprintf('\nStatistical metrics:\n');
fprintf('-------------------------------------------------------------\n');
fprintf('%-20s %10s %10s %10s %10s\n', ...
    'Case', 'Mean', 'Std.', 'Min.', 'Max.');
fprintf('-------------------------------------------------------------\n');

for idx = 1:3
    fprintf('%-20s %10.4f %10.4f %10.4f %10.4f\n', ...
        scene_names{idx}, ...
        metrics(idx, 1), metrics(idx, 2), ...
        metrics(idx, 3), metrics(idx, 4));
end

fprintf('-------------------------------------------------------------\n');
fprintf('\nAll figures saved in folder: %s\n', outDir);
fprintf('Formats: 600 dpi TIFF and vector PDF.\n');

%% ========================================================================
% Local function: export figures
% ========================================================================
function exportFig(figHandle, fileBase, dpi)
    % Save high-resolution TIFF and vector PDF.
    % TIFF is suitable for journal submission.
    % PDF is suitable for later editing or typesetting.

    set(figHandle, 'PaperPositionMode', 'auto');

    try
        exportgraphics(figHandle, [fileBase '.tif'], ...
            'Resolution', dpi, ...
            'BackgroundColor', 'white');

        exportgraphics(figHandle, [fileBase '.pdf'], ...
            'ContentType', 'vector', ...
            'BackgroundColor', 'white');
    catch
        print(figHandle, [fileBase '.tif'], '-dtiff', ['-r' num2str(dpi)]);
        print(figHandle, [fileBase '.pdf'], '-dpdf', '-painters');
    end
end