classdef task3 < matlab.apps.AppBase
    
    % Properties that correspond to app component
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        GridLayout                      matlab.ui.container.GridLayout
        LeftPanel                       matlab.ui.container.Panel
        GridLayout2                     matlab.ui.container.GridLayout
        RollingAverageEditField         matlab.ui.control.NumericEditField
        RollingAverageEditFieldLabel    matlab.ui.control.Label
        CurrentFrequencyEditField       matlab.ui.control.NumericEditField
        CurrentFrequencyEditFieldLabel  matlab.ui.control.Label
        StopButton                      matlab.ui.control.Button
        StartButton                     matlab.ui.control.Button
        TargetFrequencyEditField        matlab.ui.control.NumericEditField
        TargetFrequencyEditFieldLabel   matlab.ui.control.Label
        AlarmThresholdEditField         matlab.ui.control.NumericEditField
        AlarmThresholdEditFieldLabel    matlab.ui.control.Label
        CenterPanel                     matlab.ui.container.Panel
        RecordMeasurementButton         matlab.ui.control.Button
        ClearMeasurementButton          matlab.ui.control.Button
        SaveMeasurementButton           matlab.ui.control.Button
        RecordingsTable                 matlab.ui.control.Table
        UIAxes                          matlab.ui.control.UIAxes
        RightPanel                      matlab.ui.container.Panel
        requiredarkSwitch               matlab.ui.control.Switch
        requiredarkSwitchLabel          matlab.ui.control.Label
        AlarmSwitch                     matlab.ui.control.Switch
        AlarmSwitchLabel                matlab.ui.control.Label
        buttonToRecord                  matlab.ui.control.Switch
        buttonToRecordLabel             matlab.ui.control.Label
        RollingAvgValueEditFieldLabel   matlab.ui.control.Label
        RollingAvgValueEditField        matlab.ui.control.NumericEditField
    end

    % Properties that correspond to app
    properties (Access = private)
        onePanelWidth = 576;        %setting side panel widths for the gui
        twoPanelWidth = 768;        %setting main panel width for the gui
        DataQueue;                  %dataqueue for worker communication
        ArduinoWorker;              %to store the arduino worker
        IsMeasuring = false;        %measurement status flag            
        MeasurementBuffer = [];     %creates the rolling buffer array
        BufferSize = 0;             %initialises the buffer size as 0
        RollingAverage  = 0;        %initialises the rolling avg as 0
        calibrationFactor = 1/0.99786;       %calibration factor
        calibrationOffset = -1.3515/1000;    %calibration offset in m
        CurrentFrequency = 0;       %initialises current frequency as 0
        IsAlarm = 'Off';            %alarm switch status flag
        buttonToRecordState = 'Off';%button to record switch status flag
        requireDarkState = 'Off';   %require dark switch status flag
    end
   
    % Callbacks that handle component events
    methods (Access = private)

        %function to begin measurements
        function startMeasurements(app) 
            try
                if app.IsMeasuring      %check if measurments are on
                    disp('Measurements already running.');
                    return;             %if they are disp msg and return
                end

                %setup dataqueue for communication
                app.DataQueue = parallel.pool.DataQueue; 
                %callback to monitor data queue and send to plotting
                afterEach(app.DataQueue, @(data)updatePlotCallback(app, ...
                    data));
                %read off frequency from ui
                frequency = app.TargetFrequencyEditField.Value;

                if frequency <= 0   %check for valid frequency
                    uialert(app.UIFigure, ...
                        'Frequency must be greater than 0.', ...
                        'Invalid input');
                    return;      %disp msg and return for invalid frequency
                end
        
                %check for worker pool or create one
                if isempty(gcp('nocreate'))
                    %if no pool is running, create a new pool with 1 worker
                    parpool(1);
                    disp('Parallel pool started with 1 worker.');
                else
                    disp('Parallel pool is already running.');
                end

                %set the measuring flag to true
                app.IsMeasuring = true;
                %set current frequency to target frequency for initialising
                app.CurrentFrequency = frequency;
                %disp initialising msg and the frequency target
                disp(['Starting measurement loop with frequency: ', ...
                    num2str(frequency)]);   
                
                %begin the parallel worker task and pass in all required
                %variables for it
                app.ArduinoWorker = parfeval(@app.arduinoWorker, 0, ...
                    app.DataQueue, frequency, ...
                    app.IsAlarm, app.AlarmThresholdEditField.Value, ...
                    app.buttonToRecordState, app.requireDarkState);
                
                %another message for after the worker is initialised
                disp('Measurement task started.');
                
            catch exception %catch exceptions to the startup
                app.IsMeasuring = false;    %reset flag
                uialert(app.UIFigure, ['Error: ', exception.message], ...
                    'Measurement Error');   %exception msg
            end
        end

        %function to stop measurements 
        function stopMeasurements(app)    
            app.IsMeasuring = false;    %sets the measuring flag to false

            if ~isempty(app.ArduinoWorker) %if worker is running
                cancel(app.ArduinoWorker); %stop the worker
                app.ArduinoWorker = [];
                disp('Measurement task stopped.'); %disp msg when stopped
            end
        end
    
        %plotting and gui updates
        function updatePlotCallback(app, data)    
            %update the frequency from the measurement period
            app.CurrentFrequencyEditField.Value = 1 / data(1);
            app.updateBuffer(data(2));  %send distance to buffer function

            if data(3) == true  %check if record measurement button pressed
                %if so use record measuremnt button callback
                app.RecordMeasurementButtonPushed()
            end
            
            if isempty(app.UIAxes.Children) %check if axis empty
                %initialise line and plot
                plot(app.UIAxes, 0, app.RollingAverage, '-');
                app.UIAxes.XLim = [0, 5 * app.CurrentFrequency]; 
                app.UIAxes.YLimMode = 'auto';
                app.UIAxes.XLimMode = 'manual'; 
            else
                %update line and plot if already existing by appending
                lineAvg = app.UIAxes.Children(1); 
                newX = lineAvg.XData(end) + 1; 
                lineAvg.XData = [lineAvg.XData newX];
                lineAvg.YData = [lineAvg.YData app.RollingAverage]; 
                
                %if new data is outside xlim then update xlim for scrolling
                if newX > app.UIAxes.XLim(2)
                    %set up scrolling for 5 sec scroll time
                    newXLimStart = newX - 5 * app.CurrentFrequency;
                    newXLimEnd = newX;
                    
                    %if new limits are valid then update them
                    if ~isnan(newXLimStart) && isfinite(newXLimStart)
                        app.UIAxes.XLim = [newXLimStart, newXLimEnd];
                    else    %else just return without updating
                        return;
                    end
                end

                %update the ylim based on current data
                %set as 50 percent above and below rounded to 2 sig fig
                ylimMin = round(app.RollingAverage*0.5, 2, "significant");
                ylimMax = round(app.RollingAverage*1.5, 2, "significant");
                %set ylim as new ones we just calculated
                app.UIAxes.YLim=[ylimMin ylimMax];
                %specify manual ylim
                app.UIAxes.YLimMode = 'manual';
                %turn on axis grids for readability
                app.UIAxes.YGrid = 'on';
            end
        end
        
        %updates the rolling buffer
        function updateBuffer(app, newReading)  
            %add the new/current reading to the buffer
            app.MeasurementBuffer = [app.MeasurementBuffer, newReading];  
            %define the buffer size as specified in the gui
            app.BufferSize = app.RollingAverageEditField.Value;
            
            %if buffer exceeds specified size trim it
            if length(app.MeasurementBuffer) > app.BufferSize
                app.MeasurementBuffer = app.MeasurementBuffer(end - ...
                    app.BufferSize + 1:end);  %trim the buffer to size
            end
            
            %calculate and update rolling average with calibration
            app.RollingAverage = mean(app.MeasurementBuffer)*...
            app.calibrationFactor - app.calibrationOffset;

            %if within calibration range text is black
            if app.RollingAverage <= 2 && app.RollingAverage>=0.02
                app.RollingAvgValueEditField.FontColor = [0, 0, 0];
            else % if outside calibration range make text red
                app.RollingAvgValueEditField.FontColor = [1, 0, 0];
            end

            app.RollingAvgValueEditField.Value = app.RollingAverage;
        end

        %the parallel arduino loop
        function arduinoWorker(~, dataQueue, frequency, IsAlarm, ...
                AlarmThresholdEditFieldValue, buttonToRecordState, ...
                requireDarkState)
            %alarm threshold as set in gui
            alarmThreshold = AlarmThresholdEditFieldValue;   
            %initialise arduino connection
            arduinoObj = arduino('COM3', 'Uno', 'Libraries', 'Ultrasonic'); 
            %set up for ultrasonic sensor
            ultrasonicObj = ultrasonic(arduinoObj, 'D11', 'D12');  
            %start the timer for measurement period calculation
            measurementTimerStart = tic;  
            %start timer for alarm non-blocking timing
            alarmTimerStart = tic;  
            %initialise current distance as 0
            currentDistance = 0;
            %how often to check if the digital button is pressed
            buttonCheckPeriod = 0.1;
            %start timer for button checking
            buttonCheckTimer = tic;
            %start timer for the button press cooldown period
            buttonCooldown = tic;
            %read initial photodiode voltage
            photoDiodeVoltage = readVoltage(arduinoObj, 'A2');
            %set led status flag to off
            ledOnState = false;

            while true  %loop that will always cycle so long as worker runs 
                %work out elapsed time since last measurement each cycle
                elapsedMeasurementTime = toc(measurementTimerStart);

                %if elapsed time is over measurement period
                if elapsedMeasurementTime >= 1 / frequency
                    %restart the measurement timer
                    measurementTimerStart = tic; 

                    try     %try to read current distance from sensor
                        currentDistance = readDistance(ultrasonicObj);
                    catch exception %catch just writes distance as NaN
                        currentDistance = NaN; 
                    end

                    %send to the dataqueue
                   send(dataQueue, [elapsedMeasurementTime, ...
                            currentDistance, false]);
                end

                %if the button is being used then use logic to check for
                %the button being pressed
                if buttonToRecordState == "On"
                    %write the current time since it was last checked
                    buttonCheckElapsed = toc(buttonCheckTimer);
                    
                    %if time since last check is long enough and it is long
                    %enough since the button was last pressed
                    if buttonCheckElapsed >= buttonCheckPeriod && ...
                        toc(buttonCooldown) >= 0.75
                        %restart the button check timer
                        buttonCheckTimer = tic;

                        %check voltage against custom threshold to prevent
                        %false positives
                        if readVoltage(arduinoObj, 'A4') >= 4.88
                            
                            %if button pressed resend to data queue with
                            %true for the button state
                            send(dataQueue, [elapsedMeasurementTime, ...
                                currentDistance, true]);
                            %restart timer for button cooldown
                            buttonCooldown = tic;
                        end
                    end
                end

                %if alarm state is on and distance is within alarm threshold
                if IsAlarm == "On"  && currentDistance <= alarmThreshold
                    %if required dark is off or it is infact dark
                    if requireDarkState == "Off" || photoDiodeVoltage<=0.36
                        potentiometerVoltage = readVoltage(arduinoObj,'A3');
                        %set alarm frequency based off inverse distance and
                        %potentiometer, if no measurement flash at max freq
                        if currentDistance >= 0
                            alarmFreq = 10*potentiometerVoltage*(1/currentDistance);
                        else 
                            alarmFreq = 10*potentiometerVoltage;
                        end
                        %led on time based on alarm period
                        ledOnTime = 1 / alarmFreq;
                        %start timer for alarm logic
                        alarmElapsedTime = toc(alarmTimerStart);

                        if ~ledOnState  %if led is off
                            %if passed when led should be turned on
                            if alarmElapsedTime > ledOnTime
                                %turn led on and set flag as true
                                writeDigitalPin(arduinoObj, 'D13', 1);
                                ledOnState = true;
                            end
                        else            %if led is on
                            %turn led off
                            writeDigitalPin(arduinoObj, 'D13', 0);
                            %set flag as off
                            ledOnState = false;
                            %read photodiode voltage as led is off
                            photoDiodeVoltage=readVoltage(arduinoObj,'A2');
                            %start the alarm timer again
                            alarmTimerStart = tic;
                        end
                    else    %if alarm is only off due to it not being dark
                        %measure photodiode voltage
                        photoDiodeVoltage = readVoltage(arduinoObj, 'A2');
                    end
                end 

                %after checking all pause to prevent busy waiting
                pause(0.001);
            end
        end

        %function to record measurement to a table
        function recordMeasurment(app, ~)
                if ~isnan(app.RollingAverage)   %if data is not NaN
                    currentTime = datetime('now'); %get current datestamp
                    currentTimeStr = char(currentTime, ...
                        'dd-MM-yyyy HH:mm:ss');  %convert to a string
                    %create new row to be added
                    newRow = {currentTimeStr, app.RollingAverage}; 
                    %append to existing table
                    app.RecordingsTable.Data = [app.RecordingsTable.Data; 
                        newRow];  
                else    %if data is NaN
                    uialert(app.UIFigure, ['Measurement is invalid ' ...
                        '(NaN).'],'Recording Error');
                end
        end

        %function to save recorded measurements to csv
        function saveMeasurement(app, ~)
            %fetch table data
            tableData = app.RecordingsTable.Data;
            if ~isempty(tableData)  %if table is not empty
                %open window with prompts for filename and path
                [fileName, filePath] = uiputfile('*.csv', ...
                    'Save Table as CSV');
                %create fullfilepath from path and name
                fullFilePath = [filePath, fileName];
                if isequal(fileName, 0) %check if there is no file name
                    return; %if not then return
                else    %if there is a file name
                    try
                        %timestamps are string
                        tableData(:, 1) = cellfun(@string, ...
                            tableData(:, 1),'UniformOutput', false);
                        %distances are numeric
                        tableData(:, 2) = cellfun(@double, ...
                            tableData(:, 2), 'UniformOutput', false);  
                        
                        %create table
                        T = cell2table(tableData, 'VariableNames', ...
                            {'Timestamp', 'Distance(m)'});
                        
                        % write table
                        writetable(T, fullFilePath);
                        
                        %show success message
                        uialert(app.UIFigure, ...
                            'Table data saved successfully!', ...
                            'Save Complete');
                    catch ME    %catch errors
                        %error message
                        uialert(app.UIFigure, ['Failed to save file: ', ...
                            ME.message], 'Save Error');
                    end
                end
            else    %if table is empty
                %msg explaining table empty
                uialert(app.UIFigure, ['No data to save. ' ...
                    'The table is empty.'], 'Save Error');
            end
        end

        % Changes arrangement of the app based on UIFigure width
        function updateAppLayout(app, ~)
            currentFigureWidth = app.UIFigure.Position(3);
            if(currentFigureWidth <= app.onePanelWidth)
                % Change to a 3x1 grid
                app.GridLayout.RowHeight = {480, 480, 480};
                app.GridLayout.ColumnWidth = {'1x'};
                app.CenterPanel.Layout.Row = 1;
                app.CenterPanel.Layout.Column = 1;
                app.LeftPanel.Layout.Row = 2;
                app.LeftPanel.Layout.Column = 1;
                app.RightPanel.Layout.Row = 3;
                app.RightPanel.Layout.Column = 1;
            elseif (currentFigureWidth > app.onePanelWidth && ...
                    currentFigureWidth <= app.twoPanelWidth)
                % Change to a 2x2 grid
                app.GridLayout.RowHeight = {480, 480};
                app.GridLayout.ColumnWidth = {'1x', '1x'};
                app.CenterPanel.Layout.Row = 1;
                app.CenterPanel.Layout.Column = [1,2];
                app.LeftPanel.Layout.Row = 2;
                app.LeftPanel.Layout.Column = 1;
                app.RightPanel.Layout.Row = 2;
                app.RightPanel.Layout.Column = 2;
            else
                % Change to a 1x3 grid
                app.GridLayout.RowHeight = {'1x'};
                app.GridLayout.ColumnWidth = {220, '1x', 220};
                app.LeftPanel.Layout.Row = 1;
                app.LeftPanel.Layout.Column = 1;
                app.CenterPanel.Layout.Row = 1;
                app.CenterPanel.Layout.Column = 2;
                app.RightPanel.Layout.Row = 1;
                app.RightPanel.Layout.Column = 3;
            end
        end

    end

    % Component initialization
    methods (Access = private)

        % Callback for StartButton
        function StartButtonPushed(app, ~)
            app.startMeasurements();  %calls startMeasurements function
        end

        % Callback for StopButton
        function StopButtonPushed(app, ~)
            app.stopMeasurements();  %calls stopMeasurements function
        end

        % Callback for RecordMeasurementButton
        function RecordMeasurementButtonPushed(app, ~)
            app.recordMeasurment(); %calls recordMeasurement function
        end

        % Callback for ClearMeasurementButton
        function ClearMeasurementButtonPushed(app, ~)
            app.RecordingsTable.Data = {}; %set data array to empty   
        end

        %callback for SaveMeasurementButton
        function SaveMeasurementButtonPushed(app, ~)
            app.saveMeasurement();  %calls saveMeasurement function
        end
    
        %callback for AlarmSwitch
        function AlarmSwitchValueChanged(app, ~) 
            %set to switch value
            app.IsAlarm = app.AlarmSwitch.Value; 
        end

        %callback for buttonToRecord
        function buttonToRecordValueChanged(app, ~)
            %set to switch value
            app.buttonToRecordState = app.buttonToRecord.Value; 
        end

        %callback for requireDark
        function requireDarkValueChanged(app, ~)
            %set to switch value
            app.requireDarkState = app.requiredarkSwitch.Value; 
        end

        %creates the UI componants
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Position = [50 50 1000 500];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, ...
                @updateAppLayout, true);

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {220, '1x', 220};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Scrollable = 'on';

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.LeftPanel);
            app.GridLayout2.ColumnWidth = {'fit', 'fit'};
            app.GridLayout2.RowHeight = {'1x', 22.03, '1x', '1x', '1x', ...
                '1x', '1x', '1x', '1x', '1x', '1x', 'fit'};

            % Create TargetFrequencyEditFieldLabel
            app.TargetFrequencyEditFieldLabel = uilabel(app.GridLayout2);
            app.TargetFrequencyEditFieldLabel.HorizontalAlignment = 'right';
            app.TargetFrequencyEditFieldLabel.Layout.Row = 3;
            app.TargetFrequencyEditFieldLabel.Layout.Column = 1;
            app.TargetFrequencyEditFieldLabel.Text = 'Target Frequency';

            % Create TargetFrequencyEditField
            app.TargetFrequencyEditField = uieditfield(app.GridLayout2, ...
                'numeric');
            app.TargetFrequencyEditField.Layout.Row = 3;
            app.TargetFrequencyEditField.Layout.Column = 2;
            app.TargetFrequencyEditField.Value = 10;

            % Create StartButton
            app.StartButton = uibutton(app.GridLayout2, 'push');
            app.StartButton.Layout.Row = 1;
            app.StartButton.Layout.Column = 1;
            app.StartButton.Text = 'Start';
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, ...
                @StartButtonPushed, true);

            % Create StopButton
            app.StopButton = uibutton(app.GridLayout2, 'push');
            app.StopButton.Layout.Row = 1;
            app.StopButton.Layout.Column = 2;
            app.StopButton.Text = 'Stop';
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, ...
                @StopButtonPushed, true);

            % Create CurrentFrequencyEditFieldLabel
            app.CurrentFrequencyEditFieldLabel = uilabel(app.GridLayout2);
            app.CurrentFrequencyEditFieldLabel.HorizontalAlignment ='right';
            app.CurrentFrequencyEditFieldLabel.Layout.Row = 4;
            app.CurrentFrequencyEditFieldLabel.Layout.Column = 1;
            app.CurrentFrequencyEditFieldLabel.Text = 'Current Frequency';

            % Create CurrentFrequencyEditField
            app.CurrentFrequencyEditField = uieditfield(app.GridLayout2, ...
                'numeric');
            app.CurrentFrequencyEditField.Editable = 'off';
            app.CurrentFrequencyEditField.Layout.Row = 4;
            app.CurrentFrequencyEditField.Layout.Column = 2;

            % Create RollingAverageEditFieldLabel
            app.RollingAverageEditFieldLabel = uilabel(app.GridLayout2);
            app.RollingAverageEditFieldLabel.HorizontalAlignment = 'right';
            app.RollingAverageEditFieldLabel.Layout.Row = 5;
            app.RollingAverageEditFieldLabel.Layout.Column = 1;
            app.RollingAverageEditFieldLabel.Text = 'Rolling Avg Window ';

            % Create RollingAverageEditField
            app.RollingAverageEditField = uieditfield(app.GridLayout2, ...
                'numeric');
            app.RollingAverageEditField.Layout.Row = 5;
            app.RollingAverageEditField.Layout.Column = 2;
            app.RollingAverageEditField.Value = 10;

            % Create RollingAvgValueEditFieldLabel
            app.RollingAvgValueEditFieldLabel = uilabel(app.GridLayout2);
            app.RollingAvgValueEditFieldLabel.HorizontalAlignment = 'right';
            app.RollingAvgValueEditFieldLabel.Layout.Row = 6;
            app.RollingAvgValueEditFieldLabel.Layout.Column = 1;
            app.RollingAvgValueEditFieldLabel.Text = 'Rolling Avg';


            % Create RollingAvgValueEditField
            app.RollingAvgValueEditField = uieditfield(app.GridLayout2, ...
                'numeric');
            app.RollingAvgValueEditField.Editable = 'off';
            app.RollingAvgValueEditField.Layout.Row = 6;
            app.RollingAvgValueEditField.Layout.Column = 2;

             % Create AlarmThresholdEditFieldLabel
            app.AlarmThresholdEditFieldLabel = uilabel(app.GridLayout2);
            app.AlarmThresholdEditFieldLabel.HorizontalAlignment = 'right';
            app.AlarmThresholdEditFieldLabel.Layout.Row = 7;
            app.AlarmThresholdEditFieldLabel.Layout.Column = 1;
            app.AlarmThresholdEditFieldLabel.Text = 'Alarm Threshold';
        

            % Create AlarmThresholdEditField
            app.AlarmThresholdEditField = uieditfield(app.GridLayout2, ...
                'numeric');
            app.AlarmThresholdEditField.Layout.Row = 7;
            app.AlarmThresholdEditField.Layout.Column = 2;
            app.AlarmThresholdEditField.Value = 0.5;


            % Create CenterPanel
            app.CenterPanel = uipanel(app.GridLayout);
            app.CenterPanel.Layout.Row = 1;
            app.CenterPanel.Layout.Column = 2;

            % Create UIAxes
            app.UIAxes = uiaxes(app.CenterPanel);
            title(app.UIAxes, 'Measured Distance')
            xlabel(app.UIAxes, 'Recording Index')
            ylabel(app.UIAxes, 'Distance (m)')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [5 5 540 300];
            

            % Create RecordingsTable
            app.RecordingsTable = uitable(app.CenterPanel);
            app.RecordingsTable.Position = [155 315 390 175];
            app.RecordingsTable.ColumnName = {'Timestamp', 'Distance'};
            app.RecordingsTable.ColumnEditable = [false false];

            % Create RecordMeasurementButton
            app.RecordMeasurementButton = uibutton(app.CenterPanel, 'push');
            app.RecordMeasurementButton.Position = [15 460 125 30];
            app.RecordMeasurementButton.Text = 'Record Measurement';
            app.RecordMeasurementButton.ButtonPushedFcn = ...
            createCallbackFcn(app, @RecordMeasurementButtonPushed, true);

             % Create ClearMeasurementButton
            app.ClearMeasurementButton = uibutton(app.CenterPanel, 'push');
            app.ClearMeasurementButton.Position = [15 415 125 30];
            app.ClearMeasurementButton.Text = 'Clear Measurements';
            app.ClearMeasurementButton.ButtonPushedFcn = ...
            createCallbackFcn(app, @ClearMeasurementButtonPushed, true);

              % Create SaveMeasurementButton
            app.SaveMeasurementButton = uibutton(app.CenterPanel, 'push');
            app.SaveMeasurementButton.Position = [15 370 125 30];
            app.SaveMeasurementButton.Text = 'Save Measurements';
            app.SaveMeasurementButton.ButtonPushedFcn = ...
            createCallbackFcn(app, @SaveMeasurementButtonPushed, true);


            % Create RightPanel
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 3;

            % Create buttonToRecordLabel
            app.buttonToRecordLabel = uilabel(app.RightPanel);
            app.buttonToRecordLabel.HorizontalAlignment = 'center';
            app.buttonToRecordLabel.Position = [105 385 100 22];
            app.buttonToRecordLabel.Text = 'Button to record';

            % Create buttonToRecord
            app.buttonToRecord = uiswitch(app.RightPanel, 'slider');
            app.buttonToRecord.Position = [130 415 45 20];
            app.buttonToRecord.ValueChangedFcn = ...
            createCallbackFcn(app, @buttonToRecordValueChanged, true);

            % Create AlarmSwitchLabel
            app.AlarmSwitchLabel = uilabel(app.RightPanel);
            app.AlarmSwitchLabel.HorizontalAlignment = 'center';
            app.AlarmSwitchLabel.Position = [36 385 36 22];
            app.AlarmSwitchLabel.Text = 'Alarm';

            % Create AlarmSwitch
            app.AlarmSwitch = uiswitch(app.RightPanel, 'slider');
            app.AlarmSwitch.Position = [30 415 45 20];
            app.AlarmSwitch.ValueChangedFcn = ...
            createCallbackFcn(app, @AlarmSwitchValueChanged, true);

            % Create requiredarkSwitchLabel
            app.requiredarkSwitchLabel = uilabel(app.RightPanel);
            app.requiredarkSwitchLabel.HorizontalAlignment = 'center';
            app.requiredarkSwitchLabel.Position = [15 274 80 44];
            app.requiredarkSwitchLabel.WordWrap = 'on';
            app.requiredarkSwitchLabel.Text = 'Require dark for alarm';

            % Create requiredarkSwitch
            app.requiredarkSwitch = uiswitch(app.RightPanel, 'slider');
            app.requiredarkSwitch.Position = [29 319 45 20];
            app.requiredarkSwitch.ValueChangedFcn = ...
            createCallbackFcn(app, @requireDarkValueChanged, true);

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';

        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = task3

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)
             
            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)
            
            %call stopMeasurement function to kill worker before close
            app.stopMeasurements();

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end