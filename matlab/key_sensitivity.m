% =========================================================================
% Key Sensitivity Analysis for Original HQC and Chaos-enhanced HQC
% SCI-style figures, English labels, 600 dpi TIF output
% =========================================================================
clear; clc; close all;

%% ===================== 1. Global figure style ===========================
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

outDir = 'SCI_KeySensitivity_Figures';
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

dpi = 600;

%% ===================== 2. Load data =====================================
% 原始 HQC 结果
file_original = 'y_key_sensitivity_original.mat';

% HQC + 混沌系统结果
file_chaos = 'key_sensitivity.mat';

D_original = loadKeySensitivityFile(file_original);
D_chaos    = loadKeySensitivityFile(file_chaos);

algNames = {'Original HQC', 'Chaos-enhanced HQC'};
caseNamesShort = {'SK', 'PK-C', 'PK-K'};
caseNamesLong  = {'Secret key', ...
                  'Public key: ciphertext', ...
                  'Public key: shared key'};

% data{algorithm, case}
% case 1: secret key sensitivity
% case 2: public key sensitivity for ciphertext
% case 3: public key sensitivity for shared key
data = cell(2, 3);

data{1,1} = D_original.sk;
data{1,2} = D_original.pk_c;
data{1,3} = D_original.pk_k;

data{2,1} = D_chaos.sk;
data{2,2} = D_chaos.pk_c;
data{2,3} = D_chaos.pk_k;

%% ===================== 3. Basic statistics ==============================
metrics = zeros(2, 3, 4); 
% metrics(:, :, 1): mean
% metrics(:, :, 2): std
% metrics(:, :, 3): min
% metrics(:, :, 4): max

for a = 1:2
    for c = 1:3
        d = data{a,c};
        metrics(a,c,1) = mean(d);
        metrics(a,c,2) = std(d);
        metrics(a,c,3) = min(d);
        metrics(a,c,4) = max(d);
    end
end

fprintf('\nKey sensitivity statistics:\n');
fprintf('===============================================================\n');
fprintf('%-22s %-8s %10s %10s %10s %10s\n', ...
    'Algorithm', 'Case', 'Mean', 'Std.', 'Min.', 'Max.');
fprintf('---------------------------------------------------------------\n');

for a = 1:2
    for c = 1:3
        fprintf('%-22s %-8s %10.4f %10.4f %10.4f %10.4f\n', ...
            algNames{a}, caseNamesShort{c}, ...
            metrics(a,c,1), metrics(a,c,2), ...
            metrics(a,c,3), metrics(a,c,4));
    end
end
fprintf('===============================================================\n');

%% ========================================================================
% Fig. 1 Distribution comparison
% ========================================================================
fig1 = figure('Name', 'Key Sensitivity Distribution', ...
              'Units', 'centimeters', ...
              'Position', [2 2 18 12.5], ...
              'Color', 'w');

t1 = tiledlayout(fig1, 2, 3, ...
                 'TileSpacing', 'compact', ...
                 'Padding', 'compact');

% Colorblind-friendly colors
caseColors = [0.0000 0.4470 0.7410;   % blue
              0.8500 0.3250 0.0980;   % orange-red
              0.4660 0.6740 0.1880];  % green

fitColor   = [0.75 0.10 0.10];
idealColor = [0.15 0.15 0.15];

% Determine x-axis limits for each case
xLims = zeros(3,2);
for c = 1:3
    allv = [data{1,c}(:); data{2,c}(:)];
    allv = allv(isfinite(allv));

    xmin = min(allv);
    xmax = max(allv);

    low  = max(0, floor((xmin - 2) / 5) * 5);
    high = min(100, ceil((xmax + 2) / 5) * 5);

    % If values are concentrated around 50%, use a compact range
    if high - low < 30
        low = 35;
        high = 65;
    end

    % Ensure 50% ideal value is visible
    low  = min(low, 50);
    high = max(high, 50);

    xLims(c,:) = [low, high];
end

legendHandles = [];

for a = 1:2
    for c = 1:3
        ax = nexttile(t1);
        d = data{a,c};
        col = caseColors(c,:);

        edges = linspace(xLims(c,1), xLims(c,2), 31);
        binWidth = edges(2) - edges(1);

        hHist = histogram(d, edges, ...
            'Normalization', 'probability', ...
            'FaceColor', col, ...
            'FaceAlpha', 0.78, ...
            'EdgeColor', 'w', ...
            'LineWidth', 0.45);
        hold on;

        % Normal fitting curve, scaled to probability histogram
        mu = mean(d);
        sigma = std(d);
        xFit = linspace(xLims(c,1), xLims(c,2), 300);

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
            char('a' + (a-1)*3 + c - 1), algNames{a}, caseNamesShort{c}), ...
            'FontWeight', 'normal', ...
            'FontSize', 9.2);

        xlabel('BCR (%)');
        if c == 1
            ylabel('Probability');
        end

        xlim(xLims(c,:));

        yl = ylim;
        ylim([0, yl(2) * 1.20]);

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

exportFig(fig1, fullfile(outDir, 'Fig_KeySensitivity_Distribution'), dpi);

%% ========================================================================
% Fig. 2 Statistical metrics comparison
% ========================================================================
fig2 = figure('Name', 'Key Sensitivity Metrics', ...
              'Units', 'centimeters', ...
              'Position', [2 2 18 11], ...
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

algColors = [0.25 0.25 0.25;          % Original HQC: gray
             0.0000 0.4470 0.7410];   % Chaos-enhanced HQC: blue

barHandles = [];

for m = 1:4
    ax = nexttile(t2);

    % Y is 3 cases × 2 algorithms
    Y = squeeze(metrics(:,:,m))';

    b = bar(1:3, Y, 0.72, 'grouped');
    hold on;

    for k = 1:2
        b(k).FaceColor = algColors(k,:);
        b(k).EdgeColor = [0.15 0.15 0.15];
        b(k).LineWidth = 0.55;
    end

    if m == 1
        yline(50, '--', ...
            'Color', [0.75 0.10 0.10], ...
            'LineWidth', 1.1);
    end

    set(ax, ...
        'XTick', 1:3, ...
        'XTickLabel', caseNamesShort, ...
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

    % Set proper y-axis limits
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

exportFig(fig2, fullfile(outDir, 'Fig_KeySensitivity_Metrics'), dpi);

fprintf('\nAll SCI-style figures have been saved in folder: %s\n', outDir);
fprintf('Output formats: 600 dpi TIF and vector PDF.\n');

%% =========================================================================
% Local functions
% =========================================================================

function D = loadKeySensitivityFile(fileName)
    if ~exist(fileName, 'file')
        error('File not found: %s', fileName);
    end

    S = load(fileName);

    % Secret key BCR:
    % Prefer filtered effective samples. If unavailable, filter sk_bcr by BCR >= 5%.
    if isfield(S, 'sk_bcr_effective') && ~isempty(S.sk_bcr_effective)
        sk = cleanVector(S.sk_bcr_effective);
    elseif isfield(S, 'sk_bcr') && ~isempty(S.sk_bcr)
        sk_all = cleanVector(S.sk_bcr);
        sk = sk_all(sk_all >= 5.0);
    else
        error('No secret-key BCR data found in %s.', fileName);
    end

    if isfield(S, 'pk_c_bcr') && ~isempty(S.pk_c_bcr)
        pk_c = cleanVector(S.pk_c_bcr);
    else
        error('No pk_c_bcr data found in %s.', fileName);
    end

    if isfield(S, 'pk_k_bcr') && ~isempty(S.pk_k_bcr)
        pk_k = cleanVector(S.pk_k_bcr);
    else
        error('No pk_k_bcr data found in %s.', fileName);
    end

    if isempty(sk)
        error('Secret-key effective BCR data are empty in %s.', fileName);
    end
    if isempty(pk_c)
        error('Public-key ciphertext BCR data are empty in %s.', fileName);
    end
    if isempty(pk_k)
        error('Public-key shared-key BCR data are empty in %s.', fileName);
    end

    D.sk   = sk;
    D.pk_c = pk_c;
    D.pk_k = pk_k;
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