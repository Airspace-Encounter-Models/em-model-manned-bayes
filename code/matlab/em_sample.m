function em_sample(parameters_filename, varargin)
% Copyright 2008 - 2020, MIT Lincoln Laboratory
% SPDX-License-Identifier: GPL-2.0-only
% EM_SAMPLE Outputs samples from an encounter model to files.
%   Outputs samples into two specified files from an encounter model
%   described in a file.
%
%   EM_SAMPLES takes as input the following arguments:
%   PARAMETERS_FILENAME: a text specifying the name of the parameters file
%   INITIAL_OUTPUT_FILENAME: a string specifying the the name of the file
%   to store transition samples
%   NUM_INITIAL_SAMPLES: the number of samples to generate
%   NUM_TRANSITION_SAMPLES: the number of steps to sample from the
%   transition network

%% Input parser
p = inputParser;

% Required
addRequired(p,'parameters_filename'); % text specifying the name of the parameters file

% Optional - Model
addOptional(p,'initial_output_filename',[getenv('AEM_DIR_BAYES') filesep 'output' filesep 'initial.txt']);
addOptional(p,'transition_output_filename',[getenv('AEM_DIR_BAYES') filesep 'output' filesep 'transition.txt']);
addOptional(p,'num_initial_samples',100,@isnumeric);
addOptional(p,'num_transition_samples',60,@isnumeric);

% Optional - Boundaries
addOptional(p,'isOverwriteZeroBoundaries',false,@islogical); % If true, sample bins index and not produce a sampled value
addOptional(p,'idxZeroBoundaries',[1 2 3], @isnumeric); % Index of parameters.boundaries to force to be zero / empty

% Optional
addOptional(p,'rng_seed',42,@isnumeric); % Random seed

% Parse
parse(p,parameters_filename,varargin{:});

%% Set random seed
rng(p.Results.rng_seed,'twister');

%% Read and create priors
% read parameters
parameters = em_read(parameters_filename,...
    'isOverwriteZeroBoundaries',p.Results.isOverwriteZeroBoundaries,'idxZeroBoundaries',p.Results.idxZeroBoundaries);

% create priors
dirichlet_initial = bn_dirichlet_prior(parameters.N_initial);
dirichlet_transition = bn_dirichlet_prior(parameters.N_transition);

%% Create output files and create headers
% Open output files
f_initial = fopen(p.Results.initial_output_filename, 'w','native','UTF-8');
f_transition = fopen(p.Results.transition_output_filename, 'w','native','UTF-8');

% print initial headers
fprintf(f_initial, 'id ');
for i = 1:parameters.n_initial
    fprintf(f_initial, '%s ', parameters.labels_initial{i});
end
fprintf(f_initial, '\n');

% print transition headers
fprintf(f_transition, 'initial_id t ');
for i = 1:(parameters.n_transition - parameters.n_initial)
    fprintf(f_transition, '%s ', parameters.labels_transition{parameters.temporal_map(i,2)});
end
fprintf(f_transition, '\n');

%% Iterate over samples
% Iterate
for i = 1:p.Results.num_initial_samples
    % Create sample
    [x, ~, ~] = create_sample(parameters, dirichlet_initial, dirichlet_transition, p.Results.num_transition_samples);
    
    % print initial sample
    fprintf(f_initial, '%d ', i);
    fprintf(f_initial, '%g ', x(1:end-1,1));
    fprintf(f_initial, '%g', x(end,1));
    fprintf(f_initial, '\n');
    
    % print transition samples
    for j = 1:p.Results.num_transition_samples
        fprintf(f_transition, '%g %g ', i, j - 1);
        fprintf(f_transition, '%g ', x(parameters.temporal_map(1:end-1,1), j));
        fprintf(f_transition, '%g', x(parameters.temporal_map(end,1), j));
        fprintf(f_transition, '\n');
    end
end

% Close files
fclose(f_initial);
fclose(f_transition);

function alpha = bn_dirichlet_prior(N)
n = length(N);
alpha = cell(n, 1);
for i = 1:n
    [r, q] = size(N{i});
    alpha{i} = ones(r, q);
end

function [x, initial, events] = create_sample(p, dirichlet_initial, dirichlet_transition, sample_time)
% Sample model
[initial, events] = dbn_sample(p.G_initial, p.G_transition, p.temporal_map, p.r_transition, p.N_initial, p.N_transition, dirichlet_initial, dirichlet_transition, sample_time);
if isempty(events)
    events = [sample_time 0 0];
else
    events = [events; sample_time - sum(events(:,1)) 0 0];
end

% Within-bin resampling
events = resample_events(initial, events, p.resample_rates);

% Dediscretize
for i = 1:numel(initial)
    if isempty(p.boundaries{i})
    else
        initial(i) = dediscretize(initial(i), p.boundaries{i}, p.zero_bins{i});
    end
end
if ~isempty(events)
    for i = 1:(size(events,1)-1)
        events(i,3) = dediscretize(events(i,3), p.boundaries{events(i,2)}, p.zero_bins{events(i,2)});
    end
end
x = events2samples(initial, events);
