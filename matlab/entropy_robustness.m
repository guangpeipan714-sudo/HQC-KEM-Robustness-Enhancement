% plot_entropy_robustness.m
% Multi-source entropy degradation robustness (SCI format, English, TIFF output)
clear; clc; close all;
d = load('entropy_robustness.mat');

eb    = double(d.entropy_bits(:));
upper = double(d.upper_minH);

% ---- Global SCI-style settings ----
set(0,'DefaultAxesFontName','Times New Roman');
set(0,'DefaultTextFontName','Times New Roman');
FS   = 12;            % axis font size
FSL  = 11;            % legend font size
LW   = 1.8;           % line width
MS   = 7;             % marker size
DPI  = '-r600';       % 600 dpi for print

col_orig = [0.85 0.33 0.10];   % Original HQC
col_same = [0.00 0.45 0.74];   % Chaos Same-Source
col_dual = [0.47 0.67 0.19];   % Chaos Dual-Source

% ============ Figure 1: two-panel (min-entropy + uniqueness) ============
fig1 = figure('Color','w','Units','centimeters','Position',[2 2 24 9]);

% ---- Panel (a): sample-level min-entropy ----
subplot(1,2,1); hold on; grid on; box on;
plot(eb, d.minH_orig(:), '-o','LineWidth',LW,'MarkerSize',MS,'Color',col_orig,'MarkerFaceColor',col_orig);
plot(eb, d.minH_same(:), '--s','LineWidth',LW,'MarkerSize',MS,'Color',col_same,'MarkerFaceColor','w');
plot(eb, d.minH_dual(:), '-^','LineWidth',LW+0.2,'MarkerSize',MS+1,'Color',col_dual,'MarkerFaceColor',col_dual);
yline(upper,':k','LineWidth',1.3);
text(eb(end), upper, '  Upper bound log_2(N)', 'FontName','Times New Roman', ...
     'FontSize',FSL,'VerticalAlignment','bottom','HorizontalAlignment','right');
xlabel('Primary Source Entropy (bit)','FontSize',FS,'FontWeight','bold');
ylabel('Sample-level Min-Entropy (bit)','FontSize',FS,'FontWeight','bold');
title('(a) Output Min-Entropy under Degradation','FontSize',FS,'FontWeight','bold');
legend({'Original HQC','Chaos Same-Source','Chaos Dual-Source'}, ...
       'Location','southeast','FontSize',FSL,'Box','on');
set(gca,'FontSize',FS,'LineWidth',1.2);
xlim([min(eb) max(eb)]); ylim([0 upper*1.12]);

% ---- Panel (b): output uniqueness ratio ----
subplot(1,2,2); hold on; grid on; box on;
plot(eb, d.uniq_orig(:), '-o','LineWidth',LW,'MarkerSize',MS,'Color',col_orig,'MarkerFaceColor',col_orig);
plot(eb, d.uniq_same(:), '--s','LineWidth',LW,'MarkerSize',MS,'Color',col_same,'MarkerFaceColor','w');
plot(eb, d.uniq_dual(:), '-^','LineWidth',LW+0.2,'MarkerSize',MS+1,'Color',col_dual,'MarkerFaceColor',col_dual);
xlabel('Primary Source Entropy (bit)','FontSize',FS,'FontWeight','bold');
ylabel('Output Uniqueness Ratio','FontSize',FS,'FontWeight','bold');
title('(b) Output Uniqueness under Degradation','FontSize',FS,'FontWeight','bold');
legend({'Original HQC','Chaos Same-Source','Chaos Dual-Source'}, ...
       'Location','southeast','FontSize',FSL,'Box','on');
set(gca,'FontSize',FS,'LineWidth',1.2);
xlim([min(eb) max(eb)]); ylim([0 1.06]);

% ---- Save as uncompressed/LZW TIFF at 600 dpi ----
print(fig1,'fig_entropy_robustness','-dtiff',DPI);
disp('Saved fig_entropy_robustness.tif');

% ============ Figure 2: bar chart at a low-entropy point ============
idx  = find(eb <= 8, 1, 'last');       % pick a low-entropy point (e.g. 8 bit)
vals = [d.uniq_orig(idx), d.uniq_same(idx), d.uniq_dual(idx)];

fig2 = figure('Color','w','Units','centimeters','Position',[2 2 13 10]);
b = bar(vals, 0.6,'FaceColor','flat'); hold on; box on; grid on;
b.CData = [col_orig; col_same; col_dual];
set(gca,'XTickLabel',{'Original HQC','Chaos Same-Source','Chaos Dual-Source'}, ...
        'FontSize',FS,'LineWidth',1.2);
ylabel('Output Uniqueness Ratio','FontSize',FS,'FontWeight','bold');
title(sprintf('Output Uniqueness at %d-bit Primary Entropy', eb(idx)), ...
      'FontSize',FS,'FontWeight','bold');
ylim([0 1.08]);
for i = 1:3
    text(i, vals(i)+0.025, sprintf('%.3f',vals(i)), ...
         'HorizontalAlignment','center','FontName','Times New Roman','FontSize',FSL);
end
xtickangle(12);

print(fig2,'fig_entropy_robustness_bar','-dtiff',DPI);
disp('Saved fig_entropy_robustness_bar.tif');