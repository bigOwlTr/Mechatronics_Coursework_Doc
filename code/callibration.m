clear;close all;clc;        %clearing the workspace and any windows
hold on;

data = struct();        %makes a struct to store variables and data
averages = [1,20];      %array to store averages

for i = 1:20    %loop for all 20 data points
    variableName = "mm"+i+"00";     %creates variable names
    %load all data into the struct with variable names
    data.(variableName) = load("C:\Users\colin\Documents\MATLAB\" + ...
        "mechatronicsCourseworkY1\callibrationData/"+i+"00");     
    %calculate avg distance for each distance table and converts to mm
    avgDist = 1000*mean(data.(variableName).distanceTable.Distance);        
    data.(variableName+"Avg") = avgDist;  %writes the avg to the data struct
    averages(i) = avgDist;                %add the avg to the avg array
end

x = 100:100:2000;                   %make x values for each true distance
figure(1);
set(gcf, 'Position', [100, 100, 700, 700]);  %set figure size to 650x650
set(gca, 'GridLineStyle', '-', 'GridAlpha', 0.1, 'LineWidth', 2);
set(gca, 'FontSize', 24);
hold on;
L1=plot(x, x, 'r', 'LineWidth', 2);  %red line showing the true distance
%plot the measured data points   
xlabel('True Distance (mm)');           %axis labels
ylabel('Measured Distance (mm)');
grid on;                                %draws grid on the graph
axis equal;
xlim([0 2050]);                         %axis limits
ylim([0 2050]);
xticks(0:250:2000);                     %forcing even axis labelling
yticks(0:250:2000); 

linearModel = fitlm(x,averages);        %creating linear model
yFit = predict(linearModel, x');        %yvalues predicted by linear model
L2=plot(x, yFit, 'g-', 'LineWidth', 2);    %plot linear model
%plot points for measured distances
L3=plot(x, averages, '^', 'MarkerFaceColor', 'b', 'MarkerEdgeColor', ...
    'b','MarkerSize',7.5);   
legend([L1,L2,L3], {'Ideal Line', 'Linear Model','Recorded Distance'}, ...
    'Location', 'northwest', 'FontSize', 24);

%displaying the coefficients of the linear model
disp("Linear model gradient: " + linearModel.Coefficients.Estimate(2) + ...
    " Linear model intercept: " + linearModel.Coefficients.Estimate(1) + ...
    " Linear model gradient standard error: " + ...
    linearModel.Coefficients.SE(2));   
hold off;

figure(2)   %plotting figure showing all distances and their consistancy
set(gcf, 'Position', [100, 100, 700, 700]);  %set figure size to 650x650
set(gca, 'GridLineStyle', '-', 'GridAlpha', 0.1, 'LineWidth', 1.5);
set(gca, 'FontSize', 24);
xlim([0 240])   %set xlim
ylim([0 2.1])
xticks(0:30:240)    %set xticks
hold on;

x = 1:240;
for i = 1:20   %for all the data
    %plot the data
    variableName = "mm"+i+"00";
    plot(x,data.(variableName).distanceTable.Distance,"LineWidth",2)
end
xlabel('Data Index'); 
ylabel('Measured Distance (mm)');
