function out_start = InitStartTerminal(self, varargin)
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    %
    % Function creates a cell array that can be parsed to be used as the
    % optional arguement 'start' to bn_sample(). 'start' is a cell array
    % with same number of elements as n_initial, allows parameters to be preset.
    % A parameter can only be preset if all of its parents, if any, are also preset
    %
    % Currently only supports airspace_class, own_intent, int_intent model variables and
    % assumes an equal number of encounters for each combination of class & intent
    %
    % SEE ALSO CorTerminalModel bn_sample

    %% Inputs
    p = inputParser;

    addOptional(p, 'nSamples', 1000000, @isnumeric); % Number of encounters to generate
    addOptional(p, 'airspace_class', [false true true true], @islogical); % Airspace classes to keep, default is to exclude Class B
    addOptional(p, 'own_intent', [true true], @islogical); % Ownship intent, default is all
    addOptional(p, 'int_intent', [true true true], @islogical); % Intruder intent, default is all
    addOptional(p, 'isVerbose', false, @islogical); % If true, display to screen

    % Parse
    parse(p, varargin{:});
    n_samples = p.Results.nSamples;
    is_verbose = p.Results.isVerbose;

    %% Input checking

    % Check that first three variables are airspace_class, own_intent, int_intent
    assert(strcmp(self.labels_initial{1}, '"airspace_class"'));
    assert(strcmp(self.labels_initial{2}, '"own_intent"'));
    assert(strcmp(self.labels_initial{3}, '"int_intent"'));

    % Check that variables have the expected number of bins
    assert(numel(p.Results.airspace_class) == self.r_initial(1));
    assert(numel(p.Results.own_intent) == self.r_initial(2));
    assert(numel(p.Results.int_intent) == self.r_initial(3));

    %% Preallocate
    % Bin values to use
    idx_class = find(p.Results.airspace_class == true);
    idx_ownint = find(p.Results.own_intent == true);
    idx_intint = find(p.Results.int_intent == true);

    % Number of airspace class and ownship intent combinations
    n_combs = numel(idx_class) * numel(idx_ownint) * numel(idx_intint);

    % In rare case when user didn't request enough samples, display status
    if n_combs > n_samples
        fprintf('%i combinations but requested %i total samples, generating %i samples instead\n', n_combs, n_samples, n_combs);
        n_samples = n_combs;
    end

    % Number of encounters for each combination
    n_enc_per_comb = ceil(n_samples / n_combs);

    % Preallocate start_distribution
    out_start = cell(n_samples, self.n_initial);

    %% Iterate over airspace class and ownship intent
    % Initialize start and end indices
    s = 1;
    e = inf;

    % Iterate over airspace class
    for ii = idx_class

        % Iterate over ownship intent
        for jj = idx_ownint

            % Iterate over intruder intent
            for kk = idx_intint
                % Update end index
                e = s + n_enc_per_comb - 1;

                % Assign
                out_start(s:e, 1) = repmat({ii}, n_enc_per_comb, 1);
                out_start(s:e, 2) = repmat({jj}, n_enc_per_comb, 1);
                out_start(s:e, 3) = repmat({kk}, n_enc_per_comb, 1);

                % Display status
                if is_verbose
                    fprintf('encounters %i-%i, airspace_class = %i, own_intent = %i, int_intent = %i\n', s, e, ii, jj, kk);
                end

                % Update start index
                s = e + 1;
            end
        end
    end
