function CompleteWithTriggers()
    % Clear the workspace and close screens
    clear all;
    close all;
    sca;

    % Set up Psychtoolbox
    Screen('Preference', 'SkipSyncTests', 1); % Use 0 for actual experiments
    screenNumber = max(Screen('Screens'));

    % Collect all information on a single page, including User ID
    prompt = {'Enter Participant Name:', 'Enter Surname:', 'Enter Age:', 'Enter Gender (M/F):', 'Enter User ID:'};
    dlgtitle = 'Participant Information';
    dims = [1 35];
    definput = {'', '', '', '', ''}; % Default input fields
    participant_info = inputdlg(prompt, dlgtitle, dims, definput);

    % Extract participant info from the input form
    participant_name = participant_info{1};
    surname = participant_info{2};
    age = str2double(participant_info{3});
    gender = upper(participant_info{4}); % Convert to uppercase for consistency (M/F)
    user_id = participant_info{5}; % User ID

    % Validate age
    if isnan(age) || age <= 0
        error('Invalid age entered. Please enter a positive integer.');
    end

    % Validate gender
    if ~ismember(gender, {'M', 'F'})
        error('Invalid gender entered. Please enter M or F.');
    end

    % Create a dropdown for Chronotype
    chronotypeOptions = {'Morning', 'Intermediate', 'Evening', 'Unsure'};
    [chronotypeChoice, ok] = listdlg('PromptString', 'Select Chronotype:', ...
                                     'SelectionMode', 'single', ...
                                     'ListString', chronotypeOptions);
    if ~ok
        error('Chronotype selection was cancelled. Exiting the task.');
    end
    chronotype = chronotypeOptions{chronotypeChoice}; % Get selected chronotype option

    % Open a window for the task
    [window, windowRect] = PsychImaging('OpenWindow', screenNumber, [0 0 0]);
    [screenXpixels, screenYpixels] = Screen('WindowSize', window);

    % Set text size for the main text (larger)
    defaultTextSize = 60; % Define a default text size for the main task
    Screen('TextSize', window, defaultTextSize);

    % Box parameters (25% of display width)
    boxWidth = 0.25 * screenXpixels;
    boxHeight = 0.25 * screenYpixels;
    boxXOffset = screenXpixels * 0.25;
    boxYPos = screenYpixels * 0.5;

    % Task parameters
    numBlocks = 16;         % Number of blocks
    trialsPerBlock = 24;    % Number of trials per block
    choices = [5, 25];      % Values for the boxes
    total_score = 0;        % Total score across all blocks

    % Log file setup
    logFile = fopen([surname '_' participant_name '_' num2str(age) '_logfile.txt'], 'a');
    fprintf(logFile, 'Block,Trial,Option1,Option2,ActualValue1,ActualValue2,ChoiceMade,CorrectChoice,ResponseTime,CurrentScore,ParticipantName,Surname,Age,Gender,Chronotype,UserID\n');

    % Initialize the Dio object for triggering (using parallel port LPT1)
    dio = digitalio('parallel', 'LPT1');
    addline(dio, 0:7, 'out');
    putvalue(dio.line, 0); % Set initial value to zero

    % Define trigger codes
    TRIGGER_ITI = 10;
    TRIGGER_FIXATION = 20;
    TRIGGER_STIMULUS_PRESENTATION = 30;
    TRIGGER_PARTICIPANT_CHOICE = 40;
    TRIGGER_GAIN_CORRECT = 50;
    TRIGGER_GAIN_ERROR = 60;
    TRIGGER_LOSS_CORRECT = 70;
    TRIGGER_LOSS_ERROR = 80;
    TRIGGER_END_OF_BLOCK = 90;

    % Using try-catch to handle unexpected interruptions
    try
        % Start the block loop
        for block = 1:numBlocks
            block_score = 0; % Reset block score for each block

            % Start the task loop for each block
            for trial = 1:trialsPerBlock
                % Trigger for inter-trial interval (ITI)
                triggerCode(dio, TRIGGER_ITI);

                % Show black ITI screen for 1000ms
                Screen('FillRect', window, [0 0 0]);
                Screen('Flip', window);
                WaitSecs(1);  % ITI screen duration (1000 ms)

                % Trigger for fixation
                triggerCode(dio, TRIGGER_FIXATION);

                % Show fixation cross for 500ms before the boxes
                DrawFormattedText(window, '+', 'center', 'center', [255 255 255]);
                Screen('Flip', window);
                WaitSecs(0.5);  % Fixation cross duration (500 ms)

                % Determine box values: same or different?
                if randi([0, 1]) == 0
                    % Same numbers: one positive, one negative
                    boxValues = [choices(randi([1, 2])), choices(randi([1, 2]))];
                    random_sign = randi([0, 1]) * 2 - 1; % Random +1 or -1
                    boxValues = boxValues * random_sign; % Apply sign to both values
                    boxValues(2) = -boxValues(2); % Make one positive, one negative
                else
                    % Different numbers: both positive or both negative
                    random_sign = randi([0, 1]) * 2 - 1; % Random +1 or -1 for both
                    boxValues = random_sign * [5, 25]; % Both positive or both negative
                    boxValues = boxValues(randperm(2)); % Randomize order
                end

                % Assign left and right values based on shuffle
                leftValue = boxValues(1);
                rightValue = boxValues(2);

                % Trigger for stimulus presentation
                triggerCode(dio, TRIGGER_STIMULUS_PRESENTATION);

                % Box coordinates (left and right)
                leftBox = [boxXOffset-boxWidth/2, boxYPos-boxHeight/2, boxXOffset+boxWidth/2, boxYPos+boxHeight/2];
                rightBox = [screenXpixels-boxXOffset-boxWidth/2, boxYPos-boxHeight/2, screenXpixels-boxXOffset+boxWidth/2, boxYPos+boxHeight/2];

                % Show the two boxes without the sign (+/-) during selection
                Screen('FillRect', window, [255 255 255], leftBox); % Left Box
                Screen('FillRect', window, [255 255 255], rightBox); % Right Box

                % Display the numbers inside the boxes (without signs)
                DrawFormattedText(window, sprintf('%d', abs(leftValue)), 'center', 'center', [0 0 0], [], [], [], [], [], leftBox);
                DrawFormattedText(window, sprintf('%d', abs(rightValue)), 'center', 'center', [0 0 0], [], [], [], [], [], rightBox);

                % Flip the screen to show the boxes
                Screen('Flip', window);

                % Wait for participant response (F for left box, J for right box)
                response = [];
                response_time = 0;
                start_time = GetSecs;

                while isempty(response)
                    % Check for key presses (F for left, J for right)
                    [keyIsDown, secs, keyCode] = KbCheck;
                    if keyIsDown
                        if keyCode(KbName('f'))
                            response = 1; % Left box chosen
                            response_time = secs - start_time;

                            % Trigger for participant's choice
                            triggerCode(dio, TRIGGER_PARTICIPANT_CHOICE);
                        elseif keyCode(KbName('j'))
                            response = 2; % Right box chosen
                            response_time = secs - start_time;

                            % Trigger for participant's choice
                            triggerCode(dio, TRIGGER_PARTICIPANT_CHOICE);
                        end
                    end
                end

                % Gray border around the selected box for 1000ms
                Screen('FillRect', window, [255 255 255], leftBox); % Redraw Left Box
                Screen('FillRect', window, [255 255 255], rightBox); % Redraw Right Box
                DrawFormattedText(window, sprintf('%d', abs(leftValue)), 'center', 'center', [0 0 0], [], [], [], [], [], leftBox);
                DrawFormattedText(window, sprintf('%d', abs(rightValue)), 'center', 'center', [0 0 0], [], [], [], [], [], rightBox);

                if response == 1
                    Screen('FrameRect', window, [128 128 128], leftBox, 10); % Gray border for left box
                elseif response == 2
                    Screen('FrameRect', window, [128 128 128], rightBox, 10); % Gray border for right box
                end

                % Flip the screen to show the gray border and wait for 1000ms
                Screen('Flip', window);
                WaitSecs(1);  % Gray border duration (1000 ms)

                % Show actual values after choice
                Screen('FillRect', window, [255 255 255], leftBox); % Redraw Left Box
                Screen('FillRect', window, [255 255 255], rightBox); % Redraw Right Box
                DrawFormattedText(window, sprintf('%+d', leftValue), 'center', 'center', [0 0 0], [], [], [], [], [], leftBox);
                DrawFormattedText(window, sprintf('%+d', rightValue), 'center', 'center', [0 0 0], [], [], [], [], [], rightBox);

                % Feedback: Green/red border depending on correctness and send triggers
                feedback_trigger = 0;
                if response == 1
                    if leftValue > rightValue
                        Screen('FrameRect', window, [0 255 0], leftBox, 10); % Green border if left is correct
                        feedback_trigger = (leftValue > 0) * TRIGGER_GAIN_CORRECT + (leftValue < 0) * TRIGGER_LOSS_CORRECT;
                    else
                        Screen('FrameRect', window, [255 0 0], leftBox, 10); % Red border if left is incorrect
                        feedback_trigger = (leftValue > 0) * TRIGGER_GAIN_ERROR + (leftValue < 0) * TRIGGER_LOSS_ERROR;
                    end
                elseif response == 2
                    if rightValue > leftValue
                        Screen('FrameRect', window, [0 255 0], rightBox, 10); % Green border if right is correct
                        feedback_trigger = (rightValue > 0) * TRIGGER_GAIN_CORRECT + (rightValue < 0) * TRIGGER_LOSS_CORRECT;
                    else
                        Screen('FrameRect', window, [255 0 0], rightBox, 10); % Red border if right is incorrect
                        feedback_trigger = (rightValue > 0) * TRIGGER_GAIN_ERROR + (rightValue < 0) * TRIGGER_LOSS_ERROR;
                    end
                end

                % Send feedback trigger
                if feedback_trigger ~= 0
                    triggerCode(dio, feedback_trigger);
                end

                % Flip the screen to show the feedback (green/red border) for 1500ms
                Screen('Flip', window);
                WaitSecs(1.5);  % Feedback duration (1500 ms)

                % Correct choice logic based on signed values
                if leftValue > rightValue
                    correct_choice = 1; % Left box is better
                else
                    correct_choice = 2; % Right box is better
                end

                % Update score for each trial based on chosen actual value
                if response == 1
                    trial_score = leftValue; % Score is based on the actual value chosen
                else
                    trial_score = rightValue;
                end
                block_score = block_score + trial_score; % Accumulate block score

                % Add the block score to the total score
                total_score = total_score + trial_score;

                % Log the trial data with clear formatting
                fprintf(logFile, '%d,%d,%d,%d,%+d,%+d,%d,%d,%.2f,%d,%s,%s,%d,%s,%s,%s\n', ...
                    block, trial, abs(leftValue), abs(rightValue), leftValue, rightValue, response, correct_choice, response_time, total_score, participant_name, surname, age, gender, chronotype, user_id);
            end

            % Trigger for end of block and scoreboard screen
            triggerCode(dio, TRIGGER_END_OF_BLOCK);

            % Display the scoreboard at the end of each block
            Screen('FillRect', window, [0 0 0]);

            % "Block Complete" at normal size
            Screen('TextSize', window, 60);
            DrawFormattedText(window, sprintf('Block %d Complete', block), 'center', screenYpixels * 0.3, [255 255 255]);

            % "Your Score" bigger but without bold effect to avoid rendering issue
            Screen('TextSize', window, 80);
            DrawFormattedText(window, sprintf('Your Score: %d', total_score), 'center', screenYpixels * 0.5, [255 255 255]);

            % "Press SPACE to continue" smaller and "SPACE" capital
            Screen('TextSize', window, 40);
            DrawFormattedText(window, 'Press SPACE to continue', 'center', screenYpixels * 0.7, [255 255 255]);

            % Flip the screen to display the scoreboard
            Screen('Flip', window);

            % Wait for space bar to continue
            while 1
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyIsDown && keyCode(KbName('space'))
                    break; % Continue to the next block
                end
                WaitSecs(0.01); % Prevent high CPU usage
            end

            % Reset font size to default for the next block
            Screen('TextSize', window, defaultTextSize);
        end

    catch err
        % Catch block to handle forced closure and ensure data is saved
        disp('Error or interruption occurred, saving data...');
        fprintf(logFile, 'Task was interrupted: %s\n', err.message);
    end

    % Close the log file
    fclose(logFile);

    % Close Psychtoolbox window
    sca;
end

% Function to send triggers
function triggerCode(dio, code)
    putvalue(dio.line, code);
    pause(0.05); % Slight delay to ensure the trigger is registered
    putvalue(dio.line, 0); % Reset the trigger after sending
    pause(0.05);
end
