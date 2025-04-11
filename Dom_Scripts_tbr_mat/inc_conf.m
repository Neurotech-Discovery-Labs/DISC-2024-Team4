
% Configuration params
conf = struct;

% Path to raw session data root directory
conf.path_dat_root = 'C:\Users\General Use\Desktop\BrainSync\BrainSyncSessions\';
% Path to analysis root directory
conf.path_ana_root = 'C:\Users\General Use\Desktop\BrainSync\Analysis root\';

% Expected subjects and sessions
%conf.Subject = {'P007'};
conf.Subject = {'P0000', 'P001', 'P002','P003', 'P004', 'P005', 'P006', 'P007', 'P008', 'P009', 'P010', 'P011', 'P012', 'P013'};
%conf.Session = {'S002'};
conf.Session = {'S001', 'S002', 'S003', 'S004', 'S005'};
conf.Sham = {'P003', 'P004', 'P006','P007', 'P010', 'P011', 'P012'};

% Regular expressions for start and finish of epochs
conf.Re_epc = {{'^Started Relaxation Calibration$', '^Stopped Relaxation Calibration$'}, ...
               {'^Started Concentration Calibration$', '^Stopped Concentration Calibration$'}, ...
               {'^Started Neurofeedback Game$', '^Ended Game'}
};

% Regular expressions for channels
conf.Re_chn = {'Channel 9 Theta: ', 'Channel 10 Theta: ', 'Channel 9 Beta: ', 'Channel 10 Beta: ', 'Channel 9 TBR: ', 'Channel 10 TBR: '};
% Names of channels for .csv files
conf.Chn_names = {'Theta_l', 'Theta_r', 'Beta_l', 'Beta_r', 'TBR_l', 'TBR_r'};

% Regular expressions for game events on every frame
conf.Re_game = {'Intensity: ', 'Score: ', 'dolphin y-position: '};
% Corresponding names for .csv files
conf.Game_names = {'Intensity', 'Score', 'Y_pos'};

% Column names for fish info in .csv files
conf.Fish_names = {'Type', 'Colour', 'Y_pos'};