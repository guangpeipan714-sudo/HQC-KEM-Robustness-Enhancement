% =========================================================================
% Plaintext Avalanche Effect Analysis
% Original HQC vs Chaos-enhanced HQC
% SCI-style figures, English labels, 600 dpi TIF output
% =========================================================================
clear; clc; close all;

%% ===================== 1. Global style settings ==========================
fontName = 'Times New Roman';

set(groot, ...
    'DefaultFigureColor', 'w', ...
    'DefaultAxesFontName', fontName, ...
    'DefaultTextFontName', fontName, ...
    'DefaultAxesFontSize', 9, ...
    'DefaultTextFontSize', 9, ...
    'DefaultAxesLineWidth', 0.8, ...
    'DefaultLineLineWidth', 1.1, ...
    'DefaultAxesTickDir', 'out', ...
    'DefaultAxesBox', 'on', ...
    'DefaultAxesXGrid', 'on', ...
    'DefaultAxesYGrid', 'on', ...
    'DefaultAxesGridAlpha', 0.22, ...
    'DefaultAxesTickLabelInterpreter', 'tex', ...
    'DefaultTextInterpreter', 'tex', ...
    'DefaultLegendInterpreter', 'tex');

dpi = 600;

outDir = 'SCI_PlaintextAvalanche_Figures';
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% ===================== 2. Load data =====================================
file_original = 'y_plaintext_avalanche_original.mat';
file_chaos    = 'plaintext_avalanche.mat';

D_original = loadPlainAvalancheFile(file_original);
D_chaos    = loadPlainAvalancheFile(file_chaos);

algNames = {'Original HQC', 'Chaos-enhanced HQC'};
caseNames = {'M-C', 'M-K'};
caseNamesLong = {'Plaintext to ciphertext', ...
                 'Plaintext to shared key'};

% data{algorithm, case}
% case 1: plaintext -> ciphertext
% case 2: plaintext -> shared key
data = cell(2, 2);
data{1,1} = D_original.R_ct;
data{1,2} = D_original.R_ss;
data{2,1} = D_chaos.R_ct;
data{2,2} = D_chaos.R_ss;

%% ===================== 3. Statistical metrics ============================
metrics = zeros(2, 2, 4);
% metrics(:, :, 1): mean
% metrics(:, :, 2): std
% metrics(:, :, 3): min
% metrics(:, :, 4): max

for a = 1:2
    for c = 1:2
        d = data{a,c};
        metrics(a,c,1) = mean(d);
        metrics(a,c,2) = std(d);
        metrics(a,c,3) = min(d);
        metrics(a,c,4) = max(d);
    end
end

fprintf('\nPlaintext avalanche statistics:\n');
fprintf('===============================================================\n');
fprintf('%-22s %-8s %10s %10s %10s %10s\n', ...
    'Algorithm', 'Case', 'Mean', 'Std.', 'Min.', 'Max.');
fprintf('---------------------------------------------------------------\n');

for a = 1:2
    for c = 1:2
        fprintf('%-22s %-8s %10.4f %10.4f %10.4f %10.4f\n', ...
            algNames{a}, caseNames{c}, ...
            metrics(a,c,1), metrics(a,c,2), ...
            metrics(a,c,3), metrics(a,c,4));
    end
end
fprintf('===============================================================\n');

%% ========================================================================
% Fig. 1: Distribution comparison
% ========================================================================
fig1 = figure('Name', 'Plaintext Avalanche Distribution', ...
              'Units', 'centimeters', ...
              'Position', [2 2 17.5 11.5], ...
              'Color', 'w');

t1 = tiledlayout(fig1, 2, 2, ...
                 'TileSpacing', 'compact', ...
                 'Padding', 'compact');

algColors = [0.35 0.35 0.35;          % Original HQC
             0.0000 0.4470 0.7410];   % Chaos-enhanced HQC

fitColor   = [0.75 0.10 0.10];
idealColor = [0.15 0.15 0.15];

% Common x-axis range
allValues = [];
for a = 1:2
    for c = 1:2
        allValues = [allValues; data{a,c}(:)];
    end
end

xMin = max(0, floor((min(allValues) - 2) / 5) * 5);
xMax = min(100, ceil((max(allValues) + 2) / 5) * 5);

% For avalanche effect, 35%-65% is usually more readable
if xMax - xMin < 30
    xMin = 35;
    xMax = 65;
end

xMin = min(xMin, 50);
xMax = max(xMax, 50);

legendHandles = [];

for a = 1:2
    for c = 1:2
        ax = nexttile(t1);
        d = data{a,c};
        col = algColors(a,:);

        edges = linspace(xMin, xMax, 31);
        binWidth = edges(2) - edges(1);

        hHist = histogram(d, edges, ...
            'Normalization', 'probability', ...
            'FaceColor', col, ...
            'FaceAlpha', 0.78, ...
            'EdgeColor', 'w', ...
            'LineWidth', 0.45);
        hold on;

        mu = mean(d);
        sigma = std(d);
        xFit = linspace(xMin, xMax, 300);

        if sigma > 0
            yFit = binWidth .* (1 ./ (sigma .* sqrt(2*pi))) .* ...
                   exp(-0.5 .* ((xFit - mu) ./ sigma).^2);

            hFit = plot(xFit, yFit, '-', ...
                'Color', fitColor, ...
                'LineWidth', 1.25);
        else
            hFit = plot(nan, nan, '-', ...
                'Color', fitColor, ...
                'LineWidth', 1.25);
        end

        hIdeal = xline(50, '--', ...
            'Color', idealColor, ...
            'LineWidth', 1.1);

        title(sprintf('(%c) %s: %s', ...
            char('a' + (a-1)*2 + c - 1), algNames{a}, caseNames{c}), ...
            'FontWeight', 'normal', ...
            'FontSize', 9.2);

        xlabel('BCR (%)');
        if c == 1
            ylabel('Probability');
        end

        xlim([xMin xMax]);

        yl = ylim;
        ylim([0 yl(2) * 1.22]);

        text(0.04, 0.94, ...
            sprintf('n = %d\nMean = %.2f%%\nStd. = %.2f', ...
            numel(d), mu, sigma), ...
            'Units', 'normalized', ...
            'VerticalAlignment', 'top', ...
            'FontName', fontName, ...
            'FontSize', 7.8, ...
            'BackgroundColor', 'w', ...
            'Margin', 1.4, ...
            'EdgeColor', 'none');

        set(ax, ...
            'FontName', fontName, ...
            'FontSize', 8.5, ...
            'LineWidth', 0.8, ...
            'TickDir', 'out', ...
            'GridLineStyle', '--', ...
            'GridAlpha', 0.22, ...
            'Layer', 'top');

        box on;

        if a == 1 && c == 1
            legendHandles = [hHist, hFit, hIdeal];
        end
    end
end

lgd1 = legend(legendHandles, ...
    {'Histogram', 'Normal fit', 'Ideal 50%'}, ...
    'Orientation', 'horizontal', ...
    'Box', 'off', ...
    'FontSize', 8);

lgd1.Layout.Tile = 'south';

exportFig(fig1, fullfile(outDir, 'Fig_PlaintextAvalanche_Distribution'), dpi);

%% ========================================================================
% Fig. 2: Statistical metrics comparison
% ========================================================================
fig2 = figure('Name', 'Plaintext Avalanche Metrics', ...
              'Units', 'centimeters', ...
              'Position', [2 2 17.5 10.5], ...
              'Color', 'w');

t2 = tiledlayout(fig2, 2, 2, ...
                 'TileSpacing', 'compact', ...
                 'Padding', 'compact');

metricTitles = {'(a) Mean', ...
                '(b) Standard deviation', ...
                '(c) Minimum', ...
                '(d) Maximum'};

metricYLabels = {'Mean BCR (%)', ...
                 'Std. dev. (%)', ...
                 'Minimum BCR (%)', ...
                 'Maximum BCR (%)'};

barColors = [0.35 0.35 0.35; ...
             0.0000 0.4470 0.7410];

barHandles = [];

for m = 1:4
    ax = nexttile(t2);

    % Y: 2 cases × 2 algorithms
    Y = squeeze(metrics(:,:,m))';

    b = bar(1:2, Y, 0.68, 'grouped');
    hold on;

    for k = 1:2
        b(k).FaceColor = barColors(k,:);
        b(k).EdgeColor = [0.15 0.15 0.15];
        b(k).LineWidth = 0.55;
    end

    if m == 1
        yline(50, '--', ...
            'Color', [0.75 0.10 0.10], ...
            'LineWidth', 1.1);
    end

    set(ax, ...
        'XTick', 1:2, ...
        'XTickLabel', caseNames, ...
        'FontName', fontName, ...
        'FontSize', 8.8, ...
        'LineWidth', 0.8, ...
        'TickDir', 'out', ...
        'GridLineStyle', '--', ...
        'GridAlpha', 0.22, ...
        'Layer', 'top');

    ylabel(metricYLabels{m});
    title(metricTitles{m}, ...
        'FontWeight', 'normal', ...
        'FontSize', 9.5);

    vals = Y(:);
    vals = vals(isfinite(vals));

    if m == 1
        low = min(vals) - 2;
        high = max(vals) + 2;
        low = min(low, 50);
        high = max(high, 50);
        ylim([max(0, low), min(100, high)]);
    elseif m == 2
        ylim([0, max(vals) * 1.35 + eps]);
    else
        low = max(0, min(vals) - 3);
        high = min(100, max(vals) + 3);
        if high <= low
            high = low + 1;
        end
        ylim([low, high]);
    end

    % Value labels
    yl = ylim;
    offset = 0.025 * (yl(2) - yl(1));

    for k = 1:numel(b)
        xData = b(k).XEndPoints;
        yData = b(k).YEndPoints;

        for j = 1:numel(xData)
            text(xData(j), yData(j) + offset, ...
                sprintf('%.2f', yData(j)), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 7.6, ...
                'FontName', fontName);
        end
    end

    box on;

    if m == 1
        barHandles = b;
    end
end

lgd2 = legend(barHandles, algNames, ...
    'Orientation', 'horizontal', ...
    'Box', 'off', ...
    'FontSize', 8);

lgd2.Layout.Tile = 'south';

exportFig(fig2, fullfile(outDir, 'Fig_PlaintextAvalanche_Metrics'), dpi);

fprintf('\nAll SCI-style figures have been saved in folder: %s\n', outDir);
fprintf('Output formats: 600 dpi TIF and vector PDF.\n');

%% =========================================================================
% Local functions
% =========================================================================
function D = loadPlainAvalancheFile(fileName)

    if ~exist(fileName, 'file')
        error('File not found: %s', fileName);
    end

    S = load(fileName);

    if ~isfield(S, 'R_ct')
        error('Variable R_ct not found in %s.', fileName);
    end

    if ~isfield(S, 'R_ss')
        error('Variable R_ss not found in %s.', fileName);
    end

    R_ct = cleanVector(S.R_ct);
    R_ss = cleanVector(S.R_ss);

    % Automatically convert rate values to percentage values.
    % If the maximum value is <= 1.5, the data are assumed to be in [0,1].
    % If the data are already in percentage scale, keep unchanged.
    if max(R_ct) <= 1.5
        R_ct = R_ct * 100;
    end

    if max(R_ss) <= 1.5
        R_ss = R_ss * 100;
    end

    if isempty(R_ct)
        error('R_ct is empty in %s.', fileName);
    end

    if isempty(R_ss)
        error('R_ss is empty in %s.', fileName);
    end

    D.R_ct = R_ct;
    D.R_ss = R_ss;
end

function v = cleanVector(x)
    v = double(x(:));
    v = v(isfinite(v));
end

function exportFig(figHandle, fileBase, dpi)

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