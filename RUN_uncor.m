% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause

%% Instruction
% This script demonstrates how to use the UncorEncounterModel class to
% draw samples from an uncorrelated encounter model and 
% generate independent aircraft tracks by rejection sampling the model.
% The default model parameter file is for a conventional aircraft. If a
% different model is used, the start distribution needs to be updated.

%% Startup script
    file_startup = [getenv('AEM_DIR_BAYES') filesep 'startup_bayes.m'];
run(file_startup);

%% Inputs
file_name='uncor_1200only_fwse_v1p2.txt';

if contains (file_name, '.txt')
    % MIT ASCII model parameter file
    parameters_filename = [getenv('AEM_DIR_BAYES') filesep 'model' filesep file_name];
elseif contains (file_name, '.mat')
    % Canadian model parameter file
    parameters_filename = [getenv('CANADIAN_MODELS') filesep file_name];
end
% Number of sample / tracks
n_samples = 1;

% Duration of each sample / track
sample_time = 210;

% Random seed
init_seed = 1;

%% Instantiate object
mdl = UncorEncounterModel('parameters_filename', parameters_filename);

%% Set start distribution 
% Preallocate new start distribution local to workspace
% The size of the variable corresponds to the number of
% variables in the initial network
start = cell(mdl.n_initial, 1);

% Force the model to sample from specific variable bins
% These values are for the uncorrelated conventional aircraft models. If
% using an unconventional model (i.e. gliders) or the due regard model,
% update or comment out accordingly. Also comment out if you don't want to
% define a start distribution.
%To use Canadian models, please comment those out
start{1} = 1; % Geographic domain - CONUS (G = 1)
start{2} = 4; % Airspace class - Other airspace (A = 4)
start{3} = 2; % Altitude layer - [500, 1200) feet AGL (L = 2)

% Update the object with the start distribution
mdl.start = start;

%% Demonstrate how to generate samples
[out_inits, out_events, out_samples, out_EME] = mdl.sample(n_samples, sample_time, 'seed', init_seed);

%% Demonstrate how to generate tracks
% Local relative Cartesian coordinate system
out_results_NEU = mdl.track(n_samples, sample_time, 'initialSeed', init_seed, 'coordSys', 'NEU');

% Geodetic coordinate system
% lat0_deg = 44.25889; lon0_deg = -71.31887; % Lake of the Clouds, White Mountains, NH
% lat0_deg = 40.01031; lon0_deg = -105.22097; % Flatirons Golf Course, Boulder, CO
% lat0_deg = 46.96983; lon0_deg = -101.54661; % Bison Wind Project, ND
lat0_deg = 42.29959; lon0_deg = -71.22220; % Exit 35C on I95, Massachusetts

% Geodetic track maintaining at least 2000 feet laterally from a point obstacle
out_results_geo2000 = mdl.track(n_samples, sample_time, 'initialSeed', init_seed, 'coordSys', 'geodetic', ...
                                'lat0_deg', lat0_deg, 'lon0_deg', lon0_deg, ...
                                'dofMaxRange_ft', 2000, 'isPlot', true);

% Geodetic track maintaining at least 500 feet laterally from a point obstacle
out_results_geo500 = mdl.track(n_samples, sample_time, 'initialSeed', init_seed, 'coordSys', 'geodetic', ...
                               'lat0_deg', lat0_deg, 'lon0_deg', lon0_deg, ...
                               'dofMaxRange_ft', 500, 'isPlot', true);
