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

            re = conf.Re_epc{k}{2}; % Regular expression to match
            M = regexp(EV, re, 'match'); % Match the regular expression
            X = ~cellfun(@isempty, M); % Indices of all matches
            %JS 03/21: take last occurence for stop marker
            if any(X)
                Epc(k, 2) = TS(find(X, 1, 'last')); % Get the last occurrence
            else
                disp(['No stop-time found for ', conf.Re_epc{k}{2}, ' ... skipping.']);
            end
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%
        % Relaxation calibration
        st = Epc(1, 1); fn = Epc(1, 2); % Start and finish time stamps
        X = TS >= st & TS <= fn; % Indices into relevant epoch
        Ev = EV(X); Ts = TS(X); % Relevant events and time stamps
        % All channels
        Y = []; Z = [];

        % MODIFIED PROCESSING CODE FOR RELAXATION
        if strcmp(sbj, 'P007') && strcmp(ses, 'S003')
            % NaN padding version
            for k = 1:length(conf.Re_chn)
                re = conf.Re_chn{k};
                M = regexp(Ev, re, 'match');
                x = ~cellfun(@isempty, M);
                
                values = cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false));
                timestamps = Ts(x);
                
                if k == 1
                    Y = nan(max(length(values), length(timestamps)), length(conf.Re_chn));
                    Z = nan(max(length(values), length(timestamps)), length(conf.Re_chn));
                end
                
                if length(values) > length(timestamps)
                    timestamps(end+1:length(values)) = nan;
                elseif length(timestamps) > length(values)
                    values(end+1:length(timestamps)) = nan;
                end
                
                Y(1:length(values), k) = values;
                Z(1:length(timestamps), k) = timestamps;
            end
        else
            % Preallocate Y and Z with NaNs to ensure consistent size
            Y = nan(sum(~cellfun(@isempty, regexp(Ev, 'Channel', 'match'))), length(conf.Re_chn));
            Z = nan(size(Y));
            
            for k = 1:length(conf.Re_chn)
                re = conf.Re_chn{k};
                M = regexp(Ev, re, 'match');
                x = ~cellfun(@isempty, M);
                
                % Only process if there are matching events
                if any(x)
                    values = cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false));
                    Y(1:length(values), k) = values;
                    Z(1:length(Ts(x)), k) = Ts(x);
                end
            end
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

        % MODIFIED PROCESSING CODE FOR CONCENTRATION
        if strcmp(sbj, 'P007') && strcmp(ses, 'S003')
            % NaN padding version
            for k = 1:length(conf.Re_chn)
                re = conf.Re_chn{k};
                M = regexp(Ev, re, 'match');
                x = ~cellfun(@isempty, M);
                
                values = cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false));
                timestamps = Ts(x);
                
                if k == 1
                    Y = nan(max(length(values), length(timestamps)), length(conf.Re_chn));
                    Z = nan(max(length(values), length(timestamps)), length(conf.Re_chn));
                end
                
                if length(values) > length(timestamps)
                    timestamps(end+1:length(values)) = nan;
                elseif length(timestamps) > length(values)
                    values(end+1:length(timestamps)) = nan;
                end
                
                Y(1:length(values), k) = values;
                Z(1:length(timestamps), k) = timestamps;
            end
        else
            % Preallocate Y and Z with NaNs to ensure consistent size
            Y = nan(sum(~cellfun(@isempty, regexp(Ev, 'Channel', 'match'))), length(conf.Re_chn));
            Z = nan(size(Y));
            
            for k = 1:length(conf.Re_chn)
                re = conf.Re_chn{k};
                M = regexp(Ev, re, 'match');
                x = ~cellfun(@isempty, M);
                
                % Only process if there are matching events
                if any(x)
                    values = cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false));
                    Y(1:length(values), k) = values;
                    Z(1:length(Ts(x)), k) = Ts(x);
                end
            end
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

        % MODIFIED PROCESSING CODE FOR GAME
        if strcmp(sbj, 'P007') && strcmp(ses, 'S003')
            % NaN padding version
            for k = 1:length(conf.Re_chn)
                re = conf.Re_chn{k};
                M = regexp(Ev, re, 'match');
                x = ~cellfun(@isempty, M);
                
                values = cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false));
                timestamps = Ts(x);
                
                if k == 1
                    Y = nan(max(length(values), length(timestamps)), length(conf.Re_chn));
                    Z = nan(max(length(values), length(timestamps)), length(conf.Re_chn));
                end
                
                if length(values) > length(timestamps)
                    timestamps(end+1:length(values)) = nan;
                elseif length(timestamps) > length(values)
                    values(end+1:length(timestamps)) = nan;
                end
                
                Y(1:length(values), k) = values;
                Z(1:length(timestamps), k) = timestamps;
            end
        else
            % Preallocate Y and Z with NaNs to ensure consistent size
            Y = nan(sum(~cellfun(@isempty, regexp(Ev, 'Channel', 'match'))), length(conf.Re_chn));
            Z = nan(size(Y));
            
            for k = 1:length(conf.Re_chn)
                re = conf.Re_chn{k};
                M = regexp(Ev, re, 'match');
                x = ~cellfun(@isempty, M);
                
                % Only process if there are matching events
                if any(x)
                    values = cell2mat(cellfun(@(y) str2double(y(length(re) + 1:end)), Ev(x), 'UniformOutput', false));
                    Y(1:length(values), k) = values;
                    Z(1:length(Ts(x)), k) = Ts(x);
                end
            end
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
Ts_names = {};
for i = 1:length(conf.Chn_names)
    Ts_names{i} = strcat(conf.Chn_names{i}, '_ts');
end
T = table(Sbj, Shm, Ses,  Epc_typ, ...
          Chn(:, 1), Chn(:, 2), Chn(:, 3), Chn(:, 4), Chn(:, 5), Chn(:, 6), ...
          Tim(:, 1), Tim(:, 2), Tim(:, 3), Tim(:, 4), Tim(:, 5), Tim(:, 6), ...
         'VariableNames', cat(2, {'Subject', 'Sham', 'Session', 'Epoch'}, conf.Chn_names, Ts_names));
% Save the .csv file
file_name_save = strcat('events_channels_JS_test.csv'); % Timeseries file name
path_save = strcat(conf.path_ana_root);
if exist(path_save, 'dir') ~= 7
    mkdir(path_save);
    disp(horzcat('Created directory ', path_save, ' ...'));
end
writetable(T, strcat(path_save, file_name_save));