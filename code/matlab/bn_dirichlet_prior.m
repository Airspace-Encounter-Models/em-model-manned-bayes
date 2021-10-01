function alpha = bn_dirichlet_prior(N, prior)
% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
% INPUT:
% N - a cell array
% prior - either a numeric prior or 'dbe' for dbe prior (1/rq)

% Input handling
if nargin < 2
    prior = 0;
end

% Preallocate
n = length(N);
alpha = cell(n, 1);

% Behavior dependent on if prior is a char or double
switch class(prior)
    case 'char'
        if strcmpi(prior,'dbe')
            % dbe prior
            for i = 1:n
                [r, q] = size(N{i});
                prior = 1/(r*q);
                alpha{i} = prior(ones(r, q));
            end
        else
            error('prior:notdbe','Unknown prior of %s, if char expecting prior = ''dbe''',prior)
        end
    case 'double'
        % constant prior
        for i = 1:n
            [r, q] = size(N{i});
            alpha{i} = prior(ones(r, q));
        end
    otherwise
        error('prior:unknown','Second argument must be a char or double. It was a %s',class(prior));
end

