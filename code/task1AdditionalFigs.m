%clear workspace and close figures
clear; close all; clc;

%load data
data = load("1mNoCalib.mat");
dataLive = load("liveData.mat");

figure(1);  %before filtering plot
set(gcf, 'Position', [100, 100, 700, 700]);  %set figure size 
set(gca, 'FontSize', 24);
set(gca, 'GridLineStyle', '-', 'GridAlpha', 0.1, 'LineWidth', 2);
hold on;
plot(data.distanceTable.Time, data.distanceTable.Distance, 'k', ...
    'LineWidth', 2);
xlabel('Time (s)');
ylabel('Distance (m)');
ylim([0.975 1.025])

hold off;

figure(2);  %after filtering plot
set(gcf, 'Position', [100, 100, 700, 700]);  %set figure size 
set(gca, 'FontSize', 24);
set(gca, 'GridLineStyle', '-', 'GridAlpha', 0.1, 'LineWidth', 2);
hold on;
plot(data.distanceTable.Time, data.distanceTable.RollingAvg, 'k', ...
    'LineWidth', 2);
xlabel('Time (s)');
ylabel('Distance (m)');
ylim([0.975 1.025])

hold off;

%live data plot
%set figure size
figure('Units', 'inches', 'Position', [0, 0, 6, 4]);
%set font size
set(gca, 'FontSize', 12);
set(gca, 'GridLineStyle', '-', 'GridAlpha', 0.1, 'LineWidth', 1);
hold on;
plot(dataLive.distanceTable.Time, dataLive.distanceTable.Distance, 'b', ...
    'LineWidth', 1, 'DisplayName', 'Raw Data')
plot(dataLive.distanceTable.Time, dataLive.distanceTable.RollingAvg, 'r' ...
    , 'LineWidth', 1, 'DisplayName', 'Filtered Data');
xlabel('Time (s)');
ylabel('Distance (m)');
legend('show')
grid on


hold off;

