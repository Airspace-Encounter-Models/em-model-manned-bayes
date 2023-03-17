function S = bn_sample(G, r, N, alpha, num_samples, start, order)
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    % BN_SAMPLE Produces a sample from a Bayesian network.
    %   Returns a matrix whose rows consist of n-dimensional samples from the
    %   specified Bayesian network.
    %
    %   S = BN_SAMPLE(G, R, N, ALPHA, NUM_SAMPLES) returns a matrix S whose
    %   rows consist of n-dimensional samples from a Bayesian network with
    %   graphical structure G, sufficient statistics N, and prior ALPHA. The
    %   number of samples is specified by NUM_SAMPLES. The array R specifies
    %   the number of bins associated with each variable.
    %
    %   'start', a cell array with same number of elements as
    %   N, allows parameters to be preset. A parameter can only be preset if
    %   all of its parents, if any, are also preset. WARNING: Will currently
    %   only allow discrete parameters to be preset.
    %
    %   Optional argument 'order', is the sorted order of the graphical
    %   structure G. This is calculated using bn_sort in em_read.
    %
    % SEE ALSO bn_sort select_random em_read

    % topological sort bayes net
    if nargin < 7
        order = bn_sort(G);
    end

    n = length(N);

    % Input handling
    assert(iscell(start));
    assert(length(start) == n);
    assert(length(order) == n);

    % Preallocate
    S = zeros(num_samples, n);

    for sample_index = 1:num_samples
        % generate each sample
        for i = order
            parents = G(:, i);
            j = 1;

            if ~isempty(start{i}) & ~isnan(start{i})
                if any(parents) && length([start{parents > 0}]) < sum(parents)
                    error('Attempt to preset a dependent variable');
                else
                    S(sample_index, i) = start{i};
                end
            else
                if any(parents)
                    j = asub2ind(r(parents), S(sample_index, parents));
                end
                S(sample_index, i) = select_random(N{i}(:, j) + alpha{i}(:, j));
            end
        end
    end
