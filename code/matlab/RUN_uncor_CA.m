% Copyright 2008 - 2021, MIT Lincoln Laboratory
% Copyright 2023, Carleton University and National Research Council of
% Canada
% SPDX-License-Identifier: BSD-2-Clause

%% Instruction
% This script demonstrates how to use the UncorEncounterModel_CA class to
% draw samples from Canadian encounter model
% The default model parameter file is for Light Wake Turbulance Class aircraft below 10,000 ft ASL. 
% ICAO Classifcation table can be found here: https://www.icao.int/publications/DOC8643/Pages/Search.aspx 

%% Startup script
    file_startup = [getenv('AEM_DIR_BAYES') filesep 'startup_bayes.m'];
run(file_startup);

%% Inputs

% Read Canadian model parameter file
parameters_filename = [getenv('CANADIAN_MODELS') filesep 'Light_Aircraft_Below_10000_ft_Data.mat'];

% Number of sample / tracks
n_samples = 1;

% Duration of each sample / track
sample_time = 210;

% Random seed
init_seed = 1;


%% Instantiate object
mdl = UncorEncounterModel_CA('parameters_filename', parameters_filename);

%% Demonstrate how to generate samples
[out_inits, out_events, out_samples, out_EME] = mdl.sample(n_samples, sample_time, 'seed', init_seed);

%% Demonstrate how to generate tracks
% Local relative Cartesian coordinate system
out_results_NEU = mdl.track(n_samples, sample_time, 'initialSeed', init_seed, 'coordSys', 'NEU');

