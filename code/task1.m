clear;close all;clc;       %clearing the workspace and any windows

calibrationGradient = 0.99786;    %callibration gradient
calibrationFactor = 1/calibrationGradient;    %callibration factor
calibrationOffset = -1.3515/1000;  %callibration offset converted back to m 

debug = 1;                         %set to 1 for debug console values

frequency = 24;             %target frequency
period = 1/frequency;       %convert frequency to period
duration = 10;              %measurement duration in seconds
windowSize = 25;            %rolling avg window size

%total number of measurements so table size can be pre-allocated
totalMeasurements = frequency*duration;

%initialise the table with column names and totalMeasurements length
distanceTable = table(NaN(totalMeasurements,1),NaN(totalMeasurements,1), ...
    NaN(totalMeasurements,1),NaN(totalMeasurements,1),'VariableNames',...
    {'Time','Distance','RollingAvg','LoopIterationTime'});

%set up the arduino connection with ultrasound library
arduinoObj = arduino('COM3','Uno',"Libraries","Ultrasonic");  
%set up ultrasound library
ultrasonicObj = ultrasonic(arduinoObj,'D11','D12');             

figure;     %initialise plot
hold on;
%initialise empty plot for raw data and rolling avg
distPlot = plot(NaN,NaN,'b','DisplayName','Raw Data');         
ravgPlot = plot(NaN,NaN,'r','DisplayName','Rolling Average');   
legend('show');           %show legend 
xlabel('Time [s]');       %axis labels
ylabel('Distance [m]');

%calling pause first time outside loop to prevent initialisation lag of 0.1s
pause(1)  

tic     %starts timer

%starts for loop until every planned meaurement is taken
for i = 1:totalMeasurements              
    %time measurement should be taken based off index and frequency
    targetStart = i*(period);
    %how long the pause needs to be until that target time
    pauseTime = targetStart - toc;  
    %do the pause time to reach targetTime
    pause(pauseTime);                  

    timeBefore = toc;   %time just before distance is measured
    currentDistance = calibrationFactor*readDistance(ultrasonicObj)...
    -calibrationOffset;  %current distance measurement
    timeAfter = toc;    %time after distance is measured

    %writes the current distance 
    distanceTable.Distance(i) = currentDistance;
    
    %writes the time immediately after the measurement is made to the table
    distanceTable.Time(i) = timeAfter;                                

    %if enough data to calculate rolling avg
    if i >= windowSize   
        %calculate rolling avg based on window size and distance
        rollingAvg = mean(distanceTable.Distance(i-windowSize+1:i));  
    else%if not enough data points write NaN
        rollingAvg = nan;
    end

    %add the rolling avg to the distanceTable
    distanceTable.RollingAvg(i)= rollingAvg;

    %update update raw data and rolling avg plots with new data
    set(distPlot,'XData',distanceTable.Time(1:i),'YData', ...
        distanceTable.Distance(1:i));      
    set(ravgPlot,'XData',distanceTable.Time(1:i),'YData', ...
        distanceTable.RollingAvg(1:i));   
    drawnow;  %force it to draw now
    
    %diagnostic output to console with live data and times
    if debug == 1
        disp(['Target Start: ',num2str(targetStart,'%5f'), ' Measurement'...
            ' start deviation: ', num2str(timeBefore-targetStart,'%5f'), ...
            ' Measurement duration: ',num2str(timeAfter-timeBefore, ...
            '%5f'), ' End of loop:',num2str(toc, '%5f'), ' Distance: ', ...
            num2str(currentDistance, '%5f')]); 
    end
end

