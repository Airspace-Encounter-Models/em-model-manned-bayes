function S = bn_sample(G, r, N, alpha, num_samples)
% BN_SAMPLE Produces a sample from a Bayesian network.
%   Returns a matrix whose rows consist of n-dimensional samples from the
%   specified Bayesian network.
%
%   S = BN_SAMPLE(G, R, N, ALPHA, NUM_SAMPLES) returns a matrix S whose
%   rows consist of n-dimensional samples from a Bayesian network with
%   graphical structure G, sufficient statistics N, and prior ALPHA. The
%   number of samples is specified by NUM_SAMPLES. The array R specifies
%   the number of bins associated with each variable.

order = bn_sort(G);
n = length(N);

S = zeros(num_samples, n);

for sample_index = 1:num_samples
    % generate each sample
    for i = order
        parents = G(:,i);
        j = 1;
        if any(parents)
            j = asub2ind(r(parents), S(sample_index, parents));
        end
        S(sample_index, i) = select_random(N{i}(:, j) + alpha{i}(:, j));
    end
end
