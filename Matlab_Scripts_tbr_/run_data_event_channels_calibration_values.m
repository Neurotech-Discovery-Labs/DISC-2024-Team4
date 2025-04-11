
% Dominic Standage, 2025.03.12
% This script assumes that the toolbox for importing XDF files is somewhere
% nested in Toolboxes/ inside the current directory,
% e.g. Toolboxes/eeg-lab/ or whatever

clear; % Clear existing variables, just in case
clc; % Clear console for visual clarity

% There's a better way to do this ...
rmpath(genpath('Toolboxes/')); % Don't pollute the path 
addpath(genpath('Toolboxes/')); % Add all files nested within Toolboxes

%%%%%%%%%%
% Config %
%%%%%%%%%%

% Import configuration struct with info shared across scripts
inc_conf_test;

%%%%%%%%%%%%%%
% Event data %
%%%%%%%%%%%%%%

% Data for .csv file
Chn = []; % Channel data
Tim = []; % Time stamps
Epc_typ = {}; % Epoch type
Sbj = {}; % Subjects
Ses = {}; % Sessions
Shm = []; % Sham (1) or experimental (0)
Cb_values = []; % average baseline relaxation and concentration values

for i = 1:length(conf.Subject)
    sbj = conf.Subject{i};
    path_sbj = strcat(conf.path_dat_root, 'sub-', sbj, '/'); % Path to subject directory
    if exist(path_sbj, 'dir') == 7
        disp(horzcat('Processing data for subject ', sbj));
    else
        disp(horzcat('run_data: no data directory for ', sbj, ' ... reluctantly continuing ...')); disp(' ');
        continue;
    end

    for j = 1:length(conf.Session)
        ses = conf.Session{j};
        % Ditch bad data
        if strcmp(sbj, 'P0000') && strcmp(ses, 'S001')
            continue;
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Get the data for this subject and session
        path_load = strcat(path_sbj, 'ses-', ses, '/eeg/'); % Path to session data
        file_name_load = strcat('sub-', sbj, '_ses-', ses, '_task-Default_run-001_eeg.xdf'); % Data file name
        if isfile(strcat(path_load, file_name_load))
            disp(horzcat('Got data for session ', ses));
        else
            disp(horzcat('run_data: ', path_load, file_name_load, ' does not exist ... reluctantly continuing ...'));
            continue;
        end
        % Load the data
        D = load_xdf(strcat(path_load, file_name_load));
        % Data streams are randomly assigned to D, so get the index into 
        % the game events stream, for convenience
        for k = 1:length(D) 
            if strcmp(D{k}.info.name, 'GameEvents') % Save event data as .csv
                disp(horzcat('Got game events for subject ', sbj, ' on session ', ses, ' ...'));
                break; % Jump out of the current loop
            end
        end
        EV = D{k}.time_series; % Events
        TS = D{k}.time_stamps; % Time stamps
        
        %%%%%%%%%%%%
        % Get epochs
        Epc = nan(3, 2); % 3 epochs with start and stop timestamps
        for k = 1:length(conf.Re_epc)
            re = conf.Re_epc{k}{1}; % Regular expression to match
            M = regexp(EV, re, 'match'); % Match the regular expression
            X = ~cellfun(@isempty, M); % Indices of all matches
            if sum(X) > 1
                disp('Hmmm ... more than one start time for epoch ... using the last one ...');
                X1 = find(X == true);
                % X = X1(end);
                X(X1(1:end - 1)) = false;
            end
            Epc(k, 1) = TS(X);

            re = conf.Re_epc{k}{2}; % Regular expression to match
            M = regexp(EV, re, 'match'); % Match the regular expression
            X = ~cellfun(@isempty, M); % Indices of all matches
            if sum(X) > 1
                disp('Hmmm ... more than one stop time for epoch ... using the last one ...');
                X1 = find(X == true);
                % X = X1(end);
                X(X1(1:end - 1)) = false;
            end
            Epc(k, 2) = TS(X);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%
        % Relaxation calibration
        st = Epc(1, 1); fn = Epc(1, 2); % Start and finish time stamps
        X = TS >= st & TS <= fn; % Indices into relevant epoch
        Ev = EV(X); Ts = TS(X); % Relevant events and time stamps
        % All channels
        Y = []; % Collect bandpower info for all channels
        Z = []; % Also collect corresponding time stamps
        for k = 1:length(conf.Re_chn) % Use the regular expressions for channels
            re = conf.Re_chn{k};
            M = regexp(Ev, re, 'match'); % Match the regular expression
            x = ~cellfun(@isempty, M); % Indices of all matches
            % DS 2025.03.26
            % Y(:, k) = cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false))';
            % At least one subject/session (P007/S002) has a short
            % timeseries, so pad the timeseries at the beginning (for
            % now, at least) with duplicate entries (one sample in the
            % known case).
            Y1 = cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false))';
            y_len = size(Y, 1);
            y1_len = size(Y1, 1);
            if y1_len < y_len % Handle the shorter-timeseries case
                disp(strcat('Uh oh ... short timeseries ... PADDING BEGINNING WITH DUPLICATE ENTRIES ...'))
                n = y_len - y1_len;
                Y1 = [Y1(1:n); Y1]; % Repeat the first n entries
                x0 = 1;
                while sum(x) < size(Y1, 1) % Loop until x is the correct sum (serves as length)
                    if x(x0) == false
                        x(x0) = true;
                    end
                    x0 = x0 + 1;
                end
            end
            Y(:, k) = Y1;
            Z(:, k) = Ts(x);
        end
        typ = 'r'; % Relaxation
        Chn = cat(1, Chn, Y); % Update channel matrix
        Tim = cat(1, Tim, Z); % Update time stamp matrix
        epc_typ = {}; epc_typ(1:size(Y, 1), 1) = {typ}; Epc_typ = cat(1, Epc_typ, epc_typ); % Update epoch column
        sbjs = {}; sbjs(1:size(Y, 1), 1)= {sbj}; Sbj = cat(1, Sbj, sbjs); % Update subject column
        sess = {}; sess(1:size(Y, 1), 1)= {ses}; Ses = cat(1, Ses, sess); % Update session column
        shm = 0; % Subject is sham/control ...
        if ismember(sbj, conf.Sham) % ... or experimental
            shm = 1;
        end
        Shm = cat(1, Shm, shm * ones(size(Y, 1), 1)); % Update sham column
        
        %%%%%%% JS 03/27 --- Get the relaxation calibration value (after epoch)

        % Match the event labels with the target prefix using regular expressions
        M2 = regexp(Ev, "highest 10% average TBR during relaxation calibration: ", 'match');  % Match the target prefix
        X2 = ~cellfun(@isempty, M);  % Indices of all matches
        
        % If there are multiple matches, use the last one
        if sum(X2) > 1
            disp('More than one match found for the target prefix ... using the last match.');
            X1 = find(X2 == true);  % Find all matching indices
            % Keep only the last match
            X2(X1(1:end - 1)) = false;
        end
        
        % Extract the event corresponding to the matched index
        if sum(X2) == 1
            % Remove the prefix from the matched string and convert to double
            valueStr = erase(Ev{X2}, "highest 10% average TBR during relaxation calibration: ");
            value1 = str2double(valueStr);  % Convert the extracted value to a number
        else
            value1 = NaN;  % If no match found, return NaN
        end
        
        % Add the result to the Calibration_Values
        Cb_values = cat(1, Cb_values, {sbj, ses, 'relaxation', value1});
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%
        % Concentation calibration
        st = Epc(2, 1); fn = Epc(2, 2); % Start and finish time stamps
        X = TS >= st & TS <= fn; % Indices into relevant epoch
        Ev = EV(X); Ts = TS(X); % Relevant events and time stamps
        % All channels
        Y = []; Z = [];
        for k = 1:length(conf.Re_chn) % Use the regular expressions for channels
            re = conf.Re_chn{k};
            M = regexp(Ev, re, 'match'); % Match the regular expression
            x = ~cellfun(@isempty, M); % Indices of all matches
            Y(:, k) = cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false))';
            Z(:, k) = Ts(x);
        end
        typ = 'c'; % Concentration
        Chn = cat(1, Chn, Y); % Update channel matrix
        Tim = cat(1, Tim, Z); % Update time stamp matrix
        epc_typ = {}; epc_typ(1:size(Y, 1), 1) = {typ}; Epc_typ = cat(1, Epc_typ, epc_typ); % Update epoch column
        sbjs = {}; sbjs(1:size(Y, 1), 1)= {sbj}; Sbj = cat(1, Sbj, sbjs); % Update subject column
        sess = {}; sess(1:size(Y, 1), 1)= {ses}; Ses = cat(1, Ses, sess); % Update session column
        shm = 0; % Subject is sham/control ...
        if ismember(sbj, conf.Sham) % ... or experimental
            shm = 1;
        end
        Shm = cat(1, Shm, shm * ones(size(Y, 1), 1)); % Update sham column
        
        %%%%%% JS 03/27 --- Get the concentration calibration value (after epoch)
        % Match the event labels with the target prefix using regular expressions
        M3 = regexp(Ev, "lowest 10% average TBR during concentration calibration: ", 'match');  % Match the target prefix
        X3 = ~cellfun(@isempty, M3);  % Indices of all matches
        
        % If there are multiple matches, use the last one
        if sum(X3) > 1
            disp('More than one match found for the target prefix ... using the last match.');
            X1 = find(X3 == true);  % Find all matching indices
            % Keep only the last match
            X3(X1(1:end - 1)) = false;
        end
        
        % Extract the event corresponding to the matched index
        if sum(X3) == 1
            % Remove the prefix from the matched string and convert to double
            valueStr = erase(Ev{X3}, "lowest 10% average TBR during concentration calibration: ");
            value2 = str2double(valueStr);  % Convert the extracted value to a number
        else
            value2 = NaN;  % If no match found, return NaN
        end
        
        % Add the result to the Calibration_Values
        Cb_values = cat(1, Cb_values, {sbj, ses, 'concentration', value2});

        
        %%%%%%
        % Game
        st = Epc(3, 1); fn = Epc(3, 2); % Start and finish time stamps
        X = TS >= st & TS <= fn; % Indices into relevant epoch
        Ev = EV(X); Ts = TS(X); % Relevant events and time stamps
        % All channels
        Y = []; Z = [];
        for k = 1:length(conf.Re_chn) % Use the regular expressions for channels
            re = conf.Re_chn{k};
            M = regexp(Ev, re, 'match'); % Match the regular expression
            x = ~cellfun(@isempty, M); % Indices of all matches
            Y(:, k) = cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false))';
            Z(:, k) = Ts(x);
        end
        typ = 'g'; % Game
        Chn = cat(1, Chn, Y); % Append channel matrix
        Tim = cat(1, Tim, Z); % Update time stamp matrix
        epc_typ = {}; epc_typ(1:size(Y, 1), 1) = {typ}; Epc_typ = cat(1, Epc_typ, epc_typ); % Update epoch column
        sbjs = {}; sbjs(1:size(Y, 1), 1)= {sbj}; Sbj = cat(1, Sbj, sbjs); % Update subject column
        sess = {}; sess(1:size(Y, 1), 1)= {ses}; Ses = cat(1, Ses, sess); % Update session column
        shm = 0; % Subject is sham/control ...
        if ismember(sbj, conf.Sham) % ... or experimental
            shm = 1;
        end
        Shm = cat(1, Shm, shm * ones(size(Y, 1), 1)); % Update sham column
        
    end % End session loop
    disp(' ');
end % End subject loop

%%%%%%%%%%%%%%%%%%
% Save .csv file %
%%%%%%%%%%%%%%%%%%

% Construct and save table with channel info as .csv
% JS 03/27 --- Add an empty column
Baseline = NaN(size(Sbj));
Ts_names = {};
for i = 1:length(conf.Chn_names)
    Ts_names{i} = strcat(conf.Chn_names{i}, '_ts');
end
T = table(Sbj, Shm, Ses,  Epc_typ, ...
          Chn(:, 1), Chn(:, 2), Chn(:, 3), Chn(:, 4), Chn(:, 5), Chn(:, 6), ...
          Tim(:, 1), Tim(:, 2), Tim(:, 3), Tim(:, 4), Tim(:, 5), Tim(:, 6), ...
          Baseline,...
         'VariableNames', cat(2, {'Subject', 'Sham', 'Session', 'Epoch'}, conf.Chn_names, Ts_names, {'Baseline'}));

%%%%%% JS 03/27 --- add baseline for each session, sbj loop
% Initialize variables for r-baseline and c-baseline
r_baseline_all = []; % To store r-baseline values for each subject-session
c_baseline_all = []; % To store c-baseline values for each subject-session

% Loop over each subject and session combination (assuming 'Sbj' and 'Ses' are your columns)
for i = 1:length(Sbj)
    sbj = Sbj{i}; % Get the subject name
    ses = Ses{i}; % Get the session name
    
    % Find the last occurrence of the "r" (relaxation) epoch for this subject-session pair
    r_epoch_idx = find(strcmp(T.Subject, sbj) & strcmp(T.Session, ses) & strcmp(T.EpochType, 'r'));
    if ~isempty(r_epoch_idx)
        last_r_idx = r_epoch_idx(end); % Last occurrence of "r"
        r_baseline = T.Baseline(last_r_idx); % r-baseline
    else
        r_baseline = NaN; % If no "r" epoch, set baseline as NaN
    end
    r_baseline_all = [r_baseline_all; r_baseline]; % Append to r-baseline list

    % Find the last occurrence of the "c" (concentration) epoch for this subject-session pair
    c_epoch_idx = find(strcmp(T.Subject, sbj) & strcmp(T.Session, ses) & strcmp(T.EpochType, 'c'));
    if ~isempty(c_epoch_idx)
        last_c_idx = c_epoch_idx(end); % Last occurrence of "c"
        c_baseline = T.Baseline(last_c_idx); % c-baseline
    else
        c_baseline = NaN; % If no "c" epoch, set baseline as NaN
    end
    c_baseline_all = [c_baseline_all; c_baseline]; % Append to c-baseline list
end

%%%%%%% JS 03/27 --- end

%%%% JS 03/27 ---- save as new file name
% Save the .csv file with an appended number to avoid overwriting
file_name_base = 'events_channels'; % Base file name
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

%%%%%%% JS 03/27 --- end save as new file name