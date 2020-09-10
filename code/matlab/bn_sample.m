function S = bn_sample(G, r, N, alpha, num_samples, start)
% Copyright 2008 - 2020, MIT Lincoln Laboratory
% SPDX-License-Identifier: GPL-2.0-only
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
%   Optional argument 'start', a cell array with same number of elements as
%   N, allows parameters to be preset. A parameter can only be preset if
%   all of its parents, if any, are also preset. WARNING: Will currently
%   only allow discrete parameters to be preset.

% topological sort bayes net
order = bn_sort(G);

n = length(N);

if nargin < 6
  start = cell(1,n);
else
  assert(iscell(start));
  assert(length(start) == n);
end

S = zeros(num_samples, n);

for sample_index = 1:num_samples
    % generate each sample
    for i = order
        parents = G(:,i);
        j = 1;
        
        if ~isempty(start{i})
          if any(parents) && length([start{parents>0}]) < sum(parents)
            error('Attempt to preset a dependent variable')
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
