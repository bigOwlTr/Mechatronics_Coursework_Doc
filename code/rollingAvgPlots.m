%clear workspace and close figures
clear; close all; clc;

%load data
windowData = load("rollingAvgData/1m5windowUncalib.mat");

%make data table
dataTable = table(NaN(240,1),NaN(240,1), ...
    NaN(240,1),NaN(240,1),'VariableNames', ...
    {'window5','window10','window25','window50'});

%fill dataTable
for i = 1:240
    %window5 data
    dataTable.window5(i) = windowData.distanceTable.RollingAvg(i);

    %calculate rolling averages for other window sizes
    if i >= 10
        dataTable.window10(i) = mean(windowData.distanceTable.Distance(i-10+1:i));
    end
    if i >= 25
        dataTable.window25(i) = mean(windowData.distanceTable.Distance(i-25+1:i));
    end
    if i >= 50
        dataTable.window50(i) = mean(windowData.distanceTable.Distance(i-50+1:i));
    end
end

%calculate mean and standard deviation ignoring NaN values
meanAndSD = table(NaN(2,1),NaN(2,1), ...
    NaN(2,1),NaN(2,1),'VariableNames', ...
    {'window5','window10','window25','window50'});

meanAndSD.window5(1) = mean(dataTable.window5, 'omitnan');
meanAndSD.window10(1) = mean(dataTable.window10, 'omitnan');
meanAndSD.window25(1) = mean(dataTable.window25, 'omitnan');
meanAndSD.window50(1) = mean(dataTable.window50, 'omitnan');

meanAndSD.window5(2) = std(dataTable.window5, 'omitnan');
meanAndSD.window10(2) = std(dataTable.window10, 'omitnan');
meanAndSD.window25(2) = std(dataTable.window25, 'omitnan');
meanAndSD.window50(2) = std(dataTable.window50, 'omitnan');

disp(meanAndSD);


%create figure with specified size
figure('Units', 'inches', 'Position', [0, 0, 6, 4]);

%set font size
set(gca, 'FontSize', 12);
set(gca, 'GridLineStyle', '-', 'GridAlpha', 0.1, 'LineWidth', 1);

%plot rolling averages
hold on;
plot(windowData.distanceTable.Time, dataTable.window5, 'b', 'LineWidth', 1, 'DisplayName', '5-window');
plot(windowData.distanceTable.Time, dataTable.window10, 'g', 'LineWidth', 1, 'DisplayName', '10-window');
plot(windowData.distanceTable.Time, dataTable.window25, 'm', 'LineWidth', 1, 'DisplayName', '25-window');
plot(windowData.distanceTable.Time, dataTable.window50, 'r', 'LineWidth', 1, 'DisplayName', '50-window');
hold off;

%label axes
xlabel('Time (s)');
ylabel('Distance (m)');

xlim([0 10])

%add legend
legend('show');


