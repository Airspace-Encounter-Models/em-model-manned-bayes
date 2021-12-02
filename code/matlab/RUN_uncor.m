% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
%% Inputs
% ASCII model parameter file
parameters_filename = [getenv('AEM_DIR_BAYES') filesep 'model' filesep 'uncor_1200exclude_fwse_v1p2.txt'];

% Number of sample / tracks
n_samples = 1;

% Duration of each sample / track
sample_time = 210;

% Random seed
init_seed = 1;

% Start distribution
start = cell(7, 1);
start{1} = 1;
start{2} = 4;
start{3} = 2;

%% Instantiate object
mdl = UncorEncounterModel('parameters_filename', parameters_filename);
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
lat0_deg = 42.29959;
lon0_deg = -71.22220; % Exit 35C on I95, Massachusetts

out_results_geo2000 = mdl.track(n_samples, sample_time, 'initialSeed', init_seed, 'coordSys', 'geodetic', ...
                                'lat0_deg', lat0_deg, 'lon0_deg', lon0_deg, ...
                                'dofMaxRange_ft', 2000, 'isPlot', true);

out_results_geo500 = mdl.track(n_samples, sample_time, 'initialSeed', init_seed, 'coordSys', 'geodetic', ...
                               'lat0_deg', lat0_deg, 'lon0_deg', lon0_deg, ...
                               'dofMaxRange_ft', 500, 'isPlot', true);
