% Copyright 2008 - 2023, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause

%% Instruction
% This script demonstrates how to use the UncorEncounterModel class to
% draw samples from a temporary protoype Canadian encounter model formatted
% into an ASCII file
% The default model parameter file is for a Helicopter below 10,000 ft ASL. 
% ICAO Classifcation table can be found here: https://www.icao.int/publications/DOC8643/Pages/Search.aspx 

%% Startup script
file_startup = [getenv('AEM_DIR_BAYES') filesep 'startup_bayes.m'];
run(file_startup);

%% Inputs
% Read ASCII formattedCanadian model parameter file
parameters_filename = [getenv('AEM_DIR_BAYES')  '/model/uncor_CA/Helicopter_Below_10000_ft_Data.txt'];

% Number of sample / tracks
n_samples = 20;

% Duration of each sample / track
sample_time = 210;

% Random seed
init_seed = 1;

%% Instantiate object
mdl = UncorEncounterModel('parameters_filename', parameters_filename);

%% Demonstrate how to generate samples
[out_inits, out_events, out_samples, out_EME] = mdl.sample(n_samples, sample_time, 'seed', init_seed);

%% Demonstrate how to generate tracks
% Local relative Cartesian coordinate system
out_results_NEU = mdl.track(n_samples, sample_time, 'initialSeed', init_seed, 'coordSys', 'NEU');