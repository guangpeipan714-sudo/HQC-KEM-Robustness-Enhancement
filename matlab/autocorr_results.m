% =========================================================================
% 自相关对比图（SCI 四区期刊格式）
% 读取混沌增强 HQC 和原始 HQC 的自相关数据并绘图
% 修改内容：
% 1. 纵坐标加入负值范围，使 R(k)=0 附近曲线更居中
% 2. 手动设置 y 轴刻度，保留 0 坐标
% 3. 隐藏坐标轴右上角交互工具栏
% 4. 使用 exportgraphics 导出高清 TIFF 图像
% =========================================================================

clear; close all; clc;

% ---------- 1. 加载数据 ----------
% 混沌增强 HQC 序列自相关
data_chaos = load('autocorr_mixed_only.mat');
R_mixed = data_chaos.R_mixed;
lag_chaos = 0:(length(R_mixed)-1);

% 原始 HQC 随机序列自相关
data_orig = load('y_autocorrelation_original.mat');
R_orig = data_orig.autocorr;
lag_orig = 0:(length(R_orig)-1);

% 统一最大延迟，避免两组数据长度不一致
max_lag = min(max(lag_orig), max(lag_chaos));

R_orig_plot  = R_orig(1:max_lag+1);
R_mixed_plot = R_mixed(1:max_lag+1);
lag_plot = 0:max_lag;

% ---------- 2. 绘图参数设置 ----------
fontSize = 12;
legendFontSize = 11;
lineWidth = 1.8;
figWidth = 12;
figHeight = 8.5;

% ---------- 3. 创建图形 ----------
fig = figure('Units', 'centimeters', ...
             'Position', [2 2 figWidth figHeight], ...
             'Color', 'white');

% 绘制原始 HQC 自相关曲线
plot(lag_plot, R_orig_plot, 'b-', 'LineWidth', lineWidth);
hold on;

% 绘制混沌增强 HQC 自相关曲线
plot(lag_plot, R_mixed_plot, 'r--', 'LineWidth', lineWidth);

% 添加 y = 0 参考线
yline(0, 'k:', 'LineWidth', 1.0);

% ---------- 4. 坐标轴与标签 ----------
xlabel('Lag {\it k}', 'FontSize', fontSize);
ylabel('Autocorrelation {\it R}({\it k})', 'FontSize', fontSize);

legend('Original HQC', 'Chaos-Enhanced HQC', ...
       'Location', 'northeast', ...
       'FontSize', legendFontSize, ...
       'Box', 'off');

% 坐标轴范围
xlim([0 max_lag]);

% 纵坐标加入负半轴，并保留 0 坐标
ylim([-0.10, 1.05]);
yticks([-0.1 0 0.1 0.3 0.5 0.7 0.9 1.0]);

% 网格与边框
grid on;
box on;

% 坐标轴字体与线宽
ax = gca;
set(ax, 'FontSize', fontSize, ...
        'LineWidth', 0.8, ...
        'TickDir', 'in');

% 隐藏右上角坐标轴交互工具栏，避免截图出现图标
ax.Toolbar.Visible = 'off';

% 调整绘图区位置，避免底部标签被截断
ax.Position = [0.13, 0.18, 0.82, 0.75];

% ---------- 5. 导出高清图片 ----------
exportgraphics(fig, 'Autocorrelation_Comparison.tif', ...
               'Resolution', 600, ...
               'ContentType', 'image');