
clear; % Clear existing variables, just in case
clc; % Clear console for visual clarity

rmpath(genpath('Toolboxes/')); % Don't pollute the path 
addpath(genpath('Toolboxes/')); % Add all files nested within Toolboxes

%%%%%%%%%%
% Config %
%%%%%%%%%%

% Import configuration struct with info shared across scripts
inc_conf;

typ = 'g'; % Epoch type (game)

%%%%%%%%%%%%%%
% Event data %
%%%%%%%%%%%%%%

% Data for .csv file
Fsh = []; % Fish data
% Tim = []; % Time stamps
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

        %%%%%%
        % Game
        
        % Fish events
        re = '^(?:Penalty|Nback|Regular)';
        M = regexp(EV, re, 'match'); % Match the regular expression
        X = ~cellfun(@isempty, M); % Indices of all matches
        Ev = EV(X);
        Ts = TS(X);
        len = length(Ev);
        Y = cell(len, 2); % Strings
        Z = nan(len, 2); % Numbers
        for k = 1:length(Ev)
            re = '^(Regular|Nback|Penalty)\s?Fish Collected: (Black|Green|Lavender|Orange|Purple|Red|Yellow)Fish\(Clone\), y-position (-*\d+\.\d+)';
            [~, tkn] = regexp(Ev{k}, re, 'match', 'tokens');
            Y{k, 1} = tkn{1}{1}; % Fish type
            Y{k, 2} = tkn{1}{2}; % Fish colour
            Y{k, 3} = str2double(tkn{1}{3});
            Y{k, 4} = Ts(k);
            % Z(k, :) = [str2double(tkn{1}{3}), Ts(k)]; % y-position and time stamp
        end
        % Now, concatenate the data over subjects and scans
        Fsh = cat(1, Fsh, Y); % Append channel matrix
        % Tim = cat(1, Tim, Z); % Update time stamp matrix
        epc_typ = {}; epc_typ(1:size(Y, 1), 1) = {typ}; Epc_typ = cat(1, Epc_typ, epc_typ); % Update epoch column
        sbjs = {}; sbjs(1:size(Y, 1), 1) = {sbj}; Sbj = cat(1, Sbj, sbjs); % Update subject column
        sess = {}; sess(1:size(Y, 1), 1) = {ses}; Ses = cat(1, Ses, sess); % Update session column
        shm = 0; % Subject is sham/control ...
        if ismember(sbj, conf.Sham) % ... or experimental
            shm = 1;
        end
        Shm = cat(1, Shm, shm * ones(size(Y, 1), 1)); % Update sham column
    end % End session loop
end % End subject loop
% Construct and save table with channel info as .csv
Ts_names = {};
for i = 1:length(conf.Fish_names)
    Ts_names{i} = strcat(conf.Fish_names{i}, '_ts');
end
T = table(Sbj, Shm, Ses,  Epc_typ, ...
          Fsh(:, 1), Fsh(:, 2), Fsh(:, 3), Fsh(:, 4), ...
         'VariableNames', cat(2, {'Subject', 'Sham', 'Session', 'Epoch'}, conf.Fish_names, {'Time_stamp'}));
%{
% Save the .csv file
file_name_save = strcat('events_fish.csv'); % Timeseries file name
path_save = strcat(conf.path_ana_root);
if exist(path_save, 'dir') ~= 7
    mkdir(path_save);
    disp(horzcat('Created directory ', path_save, ' ...'));
end
writetable(T, strcat(path_save, file_name_save));
%}

% Base file name for the timeseries data
file_name_base = 'events_fish'; % Base file name
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
