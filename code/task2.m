clear;close all;clc;        %Clearing the workspace and any windows

startValue = -10;           %start distance from centre
endValue = 10;              %end distance from centre

dataStruct = struct();      %initialse a struct to store data

%initialise plot with set size and location
figure('Units', 'inches', 'Position', [0, 0, 6, 4]);
hold on;

yyaxis left %plotting graph for left yaxis
ylim ([0, 1.5]);  %set left ylim
%left yaxis label
ylabel('Average Distance Recorded (m)'); 
xlim ([-11,11])          %set the xlim for the graph
grid on;
set(gca, 'GridLineStyle', '-', 'GridAlpha', 0.1, 'LineWidth', 1);
set(gca, 'FontSize', 12);   %tick size 

x = 1:240;  %x values for all measurements
for i =startValue:endValue  %for each distance from centre
    if i < 0    %for the negative distances
        %create file/variable name with _ in place of -
        variableName = "cm_"+-1*i+"beamangle";
    else
        %create file/variable name
        variableName = "cm"+i+"beamangle";
    end
    
    %write the file to same variable in the struct
    dataStruct.(variableName) = load("C:\Users\colin\Documents\MATLAB" + ...
        "\mechatronicsCourseworkY1\beamAngleData/" + variableName);

    %write a mean for each variable averaging the distance
    dataStruct.(variableName).Average = ... 
    mean(dataStruct.(variableName).distanceTable.Distance);
    %calculate standard deviation (sd)
    sd = std(dataStruct.(variableName).distanceTable.Distance);
    %write the sd of the linear model to the struct
    dataStruct.(variableName).SD = sd;
    %plot the distance averages with a blue triangle marker
    M1=plot(i, dataStruct.(variableName).Average, '^','MarkerEdgeColor', ...
        'b','MarkerFaceColor','b','MarkerSize',5);
end

%set yaxis for plotting the right
yyaxis right
%ylim ([-0.0005, 0.0005]);  %set right ylim
xlabel('Edge Position from Centre Line (cm)');       %xaxis label
%right yaxis label
ylabel('Standard Deviation (m)');

for i =startValue:endValue  %for each distance from centre
    if i < 0    %for the negative distances
        %create file/variable name with _ in place of -
        variableName = "cm_"+-1*i+"beamangle";
    else
        %create file/variable name
        variableName = "cm"+i+"beamangle";
    end

    %plot the se with the right y axis as red circle markers
    M2=plot(i, dataStruct.(variableName).SD, 'o','MarkerEdgeColor', ...
        'r','MarkerFaceColor','r','MarkerSize', 5);
end

legend([M1,M2], {'Measured Distance', 'Standard Deviation'}, ...
    'Location', 'north', 'FontSize', 12);

hold off

%initialise plot with set size and position
figure('Units', 'inches', 'Position', [0, 0, 6, 4]);
hold on;
ylabel('Distance (m)');     %ylabel
set(gca, 'GridLineStyle', '-', 'GridAlpha', 0.1, 'LineWidth', 1);
set(gca, 'FontSize', 12);   %font size
grid on
xlabel('Edge Position from Centre Line (cm)');       %xaxis label

for i =startValue:endValue  %for each distance from centre
    perpendicularDist = abs(i);
    %calculate expected distance
    expectedDistance = sqrt(0.5^2+(perpendicularDist/100)^2);

    if i < 0    %for the negative distances
        %create file/variable name with _ in place of -
        variableName = "cm_"+-1*i+"beamangle";
    else
        %create file/variable name
        variableName = "cm"+i+"beamangle";
    end

    %plot the distances with a blue triangle marker
    P1=plot(i, dataStruct.(variableName).Average, '^','MarkerEdgeColor', ...
        'b','MarkerFaceColor','b','MarkerSize',5);
    P2=plot(i, expectedDistance, 'o', 'MarkerEdgeColor', 'r', ...
        'MarkerFaceColor', 'r', 'MarkerSize', 5);
end

legend([P1,P2], {'Measured Distance', 'Expected Distance'}, ...
    'Location', 'north', 'FontSize', 12);