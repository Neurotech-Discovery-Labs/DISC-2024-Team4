% This script extracts the relaxation and concentration baseline for each participant

clear;
clc;

%%%%%%%%%%
% Config %
%%%%%%%%%%

% Import configuration struct with info shared across scripts
inc_conf;

% Data storage for baseline values
baseline_values = [];

% Loop over all subjects
for i = 1:length(conf.Subject)
    sbj = conf.Subject{i};
    path_sbj = strcat(conf.path_dat_root, 'sub-', sbj, '/'); % Path to subject directory
    
    if exist(path_sbj, 'dir') == 7
        disp(horzcat('Processing data for subject ', sbj));
    else
        disp(horzcat('run_data: no data directory for ', sbj, ' ... reluctantly continuing ...')); disp(' ');
        continue;
    end

    % Loop over all sessions
    for j = 1:length(conf.Session)
        ses = conf.Session{j};
        
        % Skip bad data
        if strcmp(sbj, 'P0000') && strcmp(ses, 'S001')
            continue;
        end

        % Load the data
        path_load = strcat(path_sbj, 'ses-', ses, '/eeg/');
        file_name_load = strcat('sub-', sbj, '_ses-', ses, '_task-Default_run-001_eeg.xdf');
        if isfile(strcat(path_load, file_name_load))
            disp(horzcat('Got data for session ', ses));
        else
            disp(horzcat('run_data: ', path_load, file_name_load, ' does not exist ... reluctantly continuing ...'));
            continue;
        end
        
        % Load data
        D = load_xdf(strcat(path_load, file_name_load));
        
        % Find the game events stream
        for k = 1:length(D)
            if strcmp(D{k}.info.name, 'GameEvents')
                disp(horzcat('Got game events for subject ', sbj, ' on session ', ses));
                break;
            end
        end
        EV = D{k}.time_series; % Events
        TS = D{k}.time_stamps; % Time stamps
        
        % Get relaxation baseline value
        M2 = regexp(EV, "highest 10% average TBR during relaxation calibration: ", 'match');
        X2 = ~cellfun(@isempty, M2);
        if sum(X2) > 1
            disp('Multiple matches found for relaxation calibration, using last one.');
            %X2(find(X2 == true, 1, 'last')) = true;
            X1 = find(X2 == true);  % Find all matching indices
            % Keep only the last match
            X2(X1(1:end - 1)) = false;
        end
        if sum(X2) == 1
            valueStr = erase(EV{X2}, "highest 10% average TBR during relaxation calibration: ");
            r_baseline = str2double(valueStr);
        else
            r_baseline = NaN;
        end
        
        % Get concentration baseline value
        M3 = regexp(EV, "lowest 10% average TBR during concentration calibration: ", 'match');
        X3 = ~cellfun(@isempty, M3);
        if sum(X3) > 1
            disp('Multiple matches found for concentration calibration, using last one.');
            X1 = find(X3 == true);  % Find all matching indices
            % Keep only the last match
            X3(X1(1:end - 1)) = false;
            %X3(find(X3 == true, 1, 'last')) = true; %didn't work
        end
        if sum(X3) == 1
            valueStr = erase(EV{X3}, "lowest 10% average TBR during concentration calibration: ");
            c_baseline = str2double(valueStr);
        else
            c_baseline = NaN;
        end

        % Store results for the current subject-session pair
        baseline_values = [baseline_values; {sbj, ses, r_baseline, c_baseline}];
    end
end

% Convert the baseline values into a table
T = cell2table(baseline_values, 'VariableNames', {'Participant', 'Session', 'r_bsl', 'c_bsl'});

% Save the .csv file with an appended number to avoid overwriting
file_name_base = 'baseline_values'; % Base file name
path_save = strcat(conf.path_ana_root);

% Check if the directory exists, if not, create it
if exist(path_save, 'dir') ~= 7
    mkdir(path_save);
    disp(horzcat('Created directory ', path_save, ' ...'));
end

% Find the latest file number (if any) and increment it
file_number = 1; % Start with 1 if no file exists
while isfile(strcat(path_save, sprintf('%s_%d.csv', file_name_base, file_number)))
    file_number = file_number + 1; % Increment the number if the file already exists
end

% Create the new file name with the incremented number
file_name_save = strcat(path_save, sprintf('%s_%d.csv', file_name_base, file_number));

% Save the table
writetable(T, file_name_save);
disp(['File saved as: ', file_name_save]); % Print the saved file path