
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

typ = 'g'; % Game (epoch type)

for ii = 1:length(conf.Re_game)

    % Data for .csv file
    Gam = []; % Game values
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
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Get epoch start and finish
            Epc = nan(1, 2); % Just 1 epoch with start and stop timestamps
            re = conf.Re_epc{3}{1}; % Regular expression to match for start of epoch
            M = regexp(EV, re, 'match'); % Match the regular expression
            X = ~cellfun(@isempty, M); % Indices of all matches
            if sum(X) > 1
                disp('Uh oh ... more than one start-time for relaxation calibration ... bailing out ...');
            end
            Epc(1, 1) = TS(X);
            % Finish
            re = conf.Re_epc{3}{2}; % Regular expression to match for end of epoch
            M = regexp(EV, re, 'match'); % Match the regular expression
            X = ~cellfun(@isempty, M); % Indices of all matches
            if sum(X) > 1
                disp('Uh oh ... more than one start-time for relaxation calibration ... bailing out ...');
            end
            Epc(1, 2) = TS(X);
            
            %%%%%%
            % Game
            st = Epc(1, 1); fn = Epc(1, 2); % Start and finish time stamps
            X = TS >= st & TS <= fn; % Indices into relevant epoch
            Ev = EV(X); Ts = TS(X); % Relevant events and time stamps
            % Intensity, score or position
            Y = []; Z = [];
            re = conf.Re_game{ii};
            M = regexp(Ev, re, 'match'); % Match the regular expression
            x = ~cellfun(@isempty, M); % Indices of all matches
            Y = cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false))';
            Z = Ts(x)';
            % Now, concatenate the data over subjects and scans
            Gam = cat(1, Gam, Y); % Append channel matrix
            Tim = cat(1, Tim, Z); % Update time stamp matrix
            epc_typ = {}; epc_typ(1:size(Y, 1), 1) = {typ}; Epc_typ = cat(1, Epc_typ, epc_typ); % Update epoch column
            sbjs = {}; sbjs(1:size(Y, 1), 1) = {sbj}; Sbj = cat(1, Sbj, sbjs); % Update subject column
            sess = {}; sess(1:size(Y, 1), 1) = {ses}; Ses = cat(1, Ses, sess); % Update session column
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
    %{
    % Construct and save table with intensity info as .csv
    T = table(Sbj, Shm, Ses,  Epc_typ, Gam, Tim, ...
             'VariableNames', {'Subject', 'Sham', 'Session', 'Epoch', conf.Game_names{ii}, 'Time_stamp'});
    % Save the .csv file
    file_name_save = strcat('events_game_', conf.Game_names{ii}, '.csv'); % Timeseries file name
    path_save = strcat(conf.path_ana_root);
    if exist(path_save, 'dir') ~= 7
        mkdir(path_save);
        disp(horzcat('Created directory ', path_save, ' ...'));
    end
    writetable(T, strcat(path_save, file_name_save));
    %}
    %%%%%%%%% JS 03/27 --- save appended name
    % Construct and save table with intensity info as .csv
    T = table(Sbj, Shm, Ses, Epc_typ, Gam, Tim, ...
               'VariableNames', {'Subject', 'Sham', 'Session', 'Epoch', conf.Game_names{ii}, 'Time_stamp'});
    
    % Base file name for the game data
    file_name_base = strcat('events_game_', conf.Game_names{ii}); % Base file name
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
    %%%%%%%%% JE 03/27 --- end
end
