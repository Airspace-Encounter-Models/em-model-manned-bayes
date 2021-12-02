% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause

%% Inputs
% Data source
src_data = 'terminalradar';

% Number of total tracks
n_samples = 18;

% Random seed
init_seed = 1;

% Aircraft type 1 used to set dynamic limits when rejection sampling
ac_type1 = 'RTCA228_A1';

%% Instantiate object
mdl = CorTerminalModel('srcData', src_data);

%% Demonstrate how to update aircraft type
% This is used to set dynamic limits of aircraft when rejection sampling to
% create encounters
fprintf('The default minimum velocity for %s aircraft 1 is %0.2f feet per second\n', mdl.acType1, mdl.dynLimits1.minVel_ft_s);
mdl.acType1 = ac_type1;
fprintf('The minimum velocity for %s aircraft 1 is %0.2f feet per second\n', mdl.acType1, mdl.dynLimits1.minVel_ft_s);

%% Create set of start distributions
starts = mdl.InitStartTerminal('nSamples', n_samples, ...
                               'own_intent', [true true], ...
                               'int_intent', [true true true], ...
                               'airspace_class', [false true true true]);

%% Iterate over start distributions
for ii = 1:1:size(starts, 1)
    % Set start distribution
    mdl.start = starts(ii, :);

    % Demonstrate how to generate samples
    [out_inits, out_samples] = mdl.sample(500, 'seed', init_seed);
    mdl.plotSamplesGeo(out_samples);

    % Demonstrate how to create an encounter with tracks
    [out_results, gen_time_s] = ...
        mdl.track(1, 'firstID', ii, 'initialSeed', init_seed, 'isPlot', true);
end
