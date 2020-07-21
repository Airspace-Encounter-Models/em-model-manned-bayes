% Copyright 2008 - 2020, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
function alpha = bn_dirichlet_prior(N, prior)
% INPUT:
% N - a cell array
% prior - either a numeric prior or 'dbe' for dbe prior (1/rq)

n = length(N);

alpha = cell(n, 1);

if strcmpi(prior,'dbe')
    % dbe prior
    for i = 1:n
        [r, q] = size(N{i});
        prior = 1/(r*q);
        alpha{i} = prior(ones(r, q));
    end    
else 
    % constant prior
    for i = 1:n
        [r, q] = size(N{i});
        alpha{i} = prior(ones(r, q));
    end
end

