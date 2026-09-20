% ==========================================
% Information Entropy Comparison Boxplot (SCI Format, English Labels)
% ==========================================
clear; clc; close all;

% 1. Load data
load('hqc_original.mat');   % variable: Entropy_Original
load('hqc_proposed.mat');   % variable: Entropy_Proposed

% 2. Ensure column vectors
ent_orig = double(Entropy_Original(:));
ent_prop = double(Entropy_Proposed(:));

if length(ent_orig) ~= length(ent_prop)
    warning('Sample sizes differ between the two schemes!');
end

data_matrix = [ent_orig, ent_prop];

% 3. Create figure (suitable for single-column journal)
fig = figure('Units', 'centimeters', 'Position', [5, 5, 12, 9]);

% 4. Boxplot with English labels
h = boxplot(data_matrix, ...
    'Labels', {'Original HQC', 'Chaos-Enhanced HQC'}, ...   % English labels
    'Widths', 0.4, ...
    'Colors', [0 0.4470 0.7410; 0.8500 0.3250 0.0980], ... % blue / orange-red
    'Symbol', 'o', ...
    'OutlierSize', 4);

set(h, 'LineWidth', 1.5);
hold on;

% 5. Reference line for theoretical maximum entropy (H = 8.0)
yline(8.0, '--r', 'Theoretical Maximum (H = 8.0)', ...
    'LineWidth', 1.5, ...
    'LabelHorizontalAlignment', 'center', ...
    'LabelVerticalAlignment', 'bottom', ...
    'FontSize', 10, 'FontName', 'Times New Roman');

% 6. Format axes
ax = gca;
ax.FontName = 'Times New Roman';
ax.FontSize = 11;
ax.LineWidth = 1.2;
ax.TickDir = 'in';
box on;

ylabel('Shannon Entropy (bits)', 'FontSize', 12, 'FontWeight', 'bold', ...
       'FontName', 'Times New Roman');

% Adjust y-axis limits to highlight small differences
y_min = min(data_matrix(:)) - 0.0001;
y_max = 8.00005;
ylim([y_min, y_max]);

hold off;

% 7. Export as high-resolution TIFF
print(fig, 'Entropy_Comparison_Plot', '-dtiff', '-r300');
disp('Figure saved as Entropy_Comparison_Plot.tif');

% 8. Print statistics for manuscript
disp('--------------------------------------');
disp('Statistics for the manuscript:');

mean_orig = mean(ent_orig);
mean_prop = mean(ent_prop);
fprintf('Mean - Original HQC:     %.6f\n', mean_orig);
fprintf('Mean - Chaos-Enhanced HQC: %.6f\n', mean_prop);

median_orig = median(ent_orig);
median_prop = median(ent_prop);
fprintf('Median - Original HQC:     %.6f\n', median_orig);
fprintf('Median - Chaos-Enhanced HQC: %.6f\n', median_prop);

std_orig = std(ent_orig);
std_prop = std(ent_prop);
fprintf('Std Dev - Original HQC:     %.6f\n', std_orig);
fprintf('Std Dev - Chaos-Enhanced HQC: %.6f\n', std_prop);
disp('--------------------------------------');