
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
inc_conf;

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
        %{
        %JS 03/25 ditch array size issue session
        if strcmp(sbj, 'P007') && strcmp(ses, 'S002')
            continue;
        end
        %}

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
            %JS 03/21: take last occurence for each epoch
            if any(X)
                Epc(k, 1) = TS(find(X, 1, 'last')); % Get the last occurrence
            else
                disp(['No start-time found for ', conf.Re_epc{k}{1}, ' ... skipping.']);
            end

            %{
            if sum(X) > 1
                disp('Uh oh ... more than one start-time for relaxation calibration ... bailing out ...');
            end
            Epc(k, 1) = TS(X);
            %}

            re = conf.Re_epc{k}{2}; % Regular expression to match
            M = regexp(EV, re, 'match'); % Match the regular expression
            X = ~cellfun(@isempty, M); % Indices of all matches
            %JS 03/21: take last occurence for stop marker
            if any(X)
                Epc(k, 2) = TS(find(X, 1, 'last')); % Get the last occurrence
            else
                disp(['No stop-time found for ', conf.Re_epc{k}{2}, ' ... skipping.']);
            end
            %{
            if sum(X) > 1
                disp('Uh oh ... more than one start-time for relaxation calibration ... bailing out ...');
            end
            Epc(k, 2) = TS(X);
            %}
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
            %{
            %------------JS 03/26
            % Extract the values for Y and Z
            Y_temp = cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false))';
            Z_temp = Ts(x);
            
            % Check if subject is P007 and session is S002
            if strcmp(sbj, 'P007') && strcmp(ses, 'S002')
                % Add an extra NaN value to both Y_temp and Z_temp
                Y_temp(end + 1) = NaN; % Add NaN to the end of Y_temp
                Z_temp(end + 1) = NaN; % Add NaN to the end of Z_temp
                % Check the size of Y_temp and Z_temp after padding
                disp(['Size of Y_temp after padding: ', num2str(length(Y_temp))]);
                disp(['Size of Z_temp after padding: ', num2str(length(Z_temp))]);
            end

            Y(:,k) = Y_temp;
            Z(:,k) = Z_temp;
            %------------JS 03/26
            %}

            Y(:, k) = cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false))';
            %Y(:, k) = [cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false))'; NaN];
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
%{
            %-------------
            % JS 03/26: Get the values for Y and Z
            Y_temp = cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false))';
            Z_temp = Ts(x);
            
            % If subject is P007 and session is S002, pad with NaN to make them equal length
            if strcmp(sbj, 'P007') && strcmp(ses, 'S002')
                maxLen = max(length(Y_temp), length(Z_temp));
                Y_temp(end+1:maxLen) = NaN;  % Pad Y_temp with NaN
                Z_temp(end+1:maxLen) = NaN;  % Pad Z_temp with NaN
            end

            % Assign to Y and Z
            Y(:, k) = Y_temp;
            Z(:, k) = Z_temp;
            %-------------
%}
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

%{
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% add "highest 10% value" from baseline relaxation calibration
tbr_value = NaN; % Default value in case it's not found
tbr_timestamp = NaN;
tbr_pattern = 'highest 10% average TBR during relaxation calibration: (\d+(\.\d+)?)';

for k = 1:length(EV)
    match = regexp(EV{k}, tbr_pattern, 'tokens');
    if ~isempty(match)
        tbr_value = str2double(match{1}{1}); % Extract numeric value
        tbr_timestamp = TS(k); % Timestamp of event
        break; % Stop after first match
    end
end

% Add a new column for baseline values (initialize with NaN)
bsln_values = nan(height(T), 1);


% Find last index of "r" (relaxation) epochs
last_r_idx = find(strcmp(T.Epoch, 'r'), 1, 'last');

% Create new row for "r_highest" if TBR value is found
if ~isnan(tbr_value)
    new_row = {T.Subject{last_r_idx}, T.Sham(last_r_idx), T.Session{last_r_idx}, 'r_highest', ...
               nan(1, length(conf.Chn_names)), tbr_timestamp}; % NaN for channel data

    % Convert to table
    T_new = cell2table(new_row, 'VariableNames', T.Properties.VariableNames);
    
    % Add baseline values
    T.bsln_values = [bsln_values; tbr_value]; 
    
    % Append new row to table
    T = [T; T_new]; 
end
%}
%%%%%%%%%%%%%%%%%%
% Save .csv file %
%%%%%%%%%%%%%%%%%%

% Construct and save table with channel info as .csv
Ts_names = {};
for i = 1:length(conf.Chn_names)
    Ts_names{i} = strcat(conf.Chn_names{i}, '_ts');
end
T = table(Sbj, Shm, Ses,  Epc_typ, ...
          Chn(:, 1), Chn(:, 2), Chn(:, 3), Chn(:, 4), Chn(:, 5), Chn(:, 6), ...
          Tim(:, 1), Tim(:, 2), Tim(:, 3), Tim(:, 4), Tim(:, 5), Tim(:, 6), ...
         'VariableNames', cat(2, {'Subject', 'Sham', 'Session', 'Epoch'}, conf.Chn_names, Ts_names));
% Save the .csv file
file_name_save = strcat('events_channels.csv'); % Timeseries file name
path_save = strcat(conf.path_ana_root);
if exist(path_save, 'dir') ~= 7
    mkdir(path_save);
    disp(horzcat('Created directory ', path_save, ' ...'));
end
writetable(T, strcat(path_save, file_name_save));
