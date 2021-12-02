function em_sample(parameters_filename, varargin)
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
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
    addRequired(p, 'parameters_filename'); % text specifying the name of the parameters file

    % Optional - Model
    addParameter(p, 'initial_output_filename', [getenv('AEM_DIR_BAYES') filesep 'output' filesep 'initial.txt']);
    addParameter(p, 'transition_output_filename', [getenv('AEM_DIR_BAYES') filesep 'output' filesep 'transition.txt']);
    addParameter(p, 'num_initial_samples', 100, @isnumeric);
    addParameter(p, 'num_transition_samples', 60, @isnumeric);

    % Optional - Sampling
    addParameter(p, 'start', {}, @iscell);

    % Optional - Boundaries
    addParameter(p, 'isOverwriteZeroBoundaries', false, @islogical); % If true, sample bins index and not produce a sampled value
    addParameter(p, 'idxZeroBoundaries', [1 2 3], @isnumeric); % Index of parameters.boundaries to force to be zero / empty

    % Optional
    addParameter(p, 'rng_seed', 42, @isnumeric); % Random seed

    % Parse
    parse(p, parameters_filename, varargin{:});

    %% Set random seed
    rng(p.Results.rng_seed, 'twister');

    %% Read and create priors
    % read parameters
    parms = EncounterModel('parameters_filename', parameters_filename, ...
                           'isOverwriteZeroBoundaries', p.Results.isOverwriteZeroBoundaries, 'idxZeroBoundaries', p.Results.idxZeroBoundaries);

    % create priors
    parms.prior = 'constant';

    % Update start if specified by user
    if ~any(strcmp(p.UsingDefaults, 'start'))
        parms.start = p.Results.start;
    end

    %% Create output files and create headers
    % Open output files
    f_initial = fopen(p.Results.initial_output_filename, 'w', 'native', 'UTF-8');
    f_transition = fopen(p.Results.transition_output_filename, 'w', 'native', 'UTF-8');

    % print initial headers
    fprintf(f_initial, 'id ');
    for ii = 1:parms.n_initial
        fprintf(f_initial, '%s ', parms.labels_initial{ii});
    end
    fprintf(f_initial, '\n');

    % print transition headers
    fprintf(f_transition, 'initial_id t ');
    for ii = 1:(parms.n_transition - parms.n_initial)
        fprintf(f_transition, '%s ', parms.labels_transition{parms.temporal_map(ii, 2)});
    end
    fprintf(f_transition, '\n');

    %% Iterate over samples
    % Iterate
    for ii = 1:p.Results.num_initial_samples
        % Create sample
        sample_time = p.Results.num_transition_samples;
        [initial, events] = dbn_hierarchical_sample(parms, parms.dirichlet_initial, parms.dirichlet_transition, ...
                                                    sample_time, parms.boundaries, parms.zero_bins, parms.resample_rates, parms.start);

        % Convert to samples
        samples = events2samples(initial, events);

        % print initial sample
        fprintf(f_initial, '%d ', ii);
        fprintf(f_initial, '%g ', samples(1:end - 1, 1));
        fprintf(f_initial, '%g', samples(end, 1));
        fprintf(f_initial, '\n');

        % print transition samples
        for j = 1:p.Results.num_transition_samples
            fprintf(f_transition, '%g %g ', ii, j - 1);
            fprintf(f_transition, '%g ', samples(parms.temporal_map(1:end - 1, 1), j));
            fprintf(f_transition, '%g', samples(parms.temporal_map(end, 1), j));
            fprintf(f_transition, '\n');
        end
    end

    % Close files
    fclose(f_initial);
    fclose(f_transition);
