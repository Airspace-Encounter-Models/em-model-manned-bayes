function d = discretize_bayes(x, thresholds)
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    %
    % Group bins x based on thresholds
    %
    % This function was originally created before MATLAB R2015a, when the
    % discretize function was added to MATLAB. For backwards compatibility, we
    % have not fully tested to the built-in discretize function yet with the
    % Bayesian network code.
    %
    % SEE ALSO hierarchical_discretize

    d = zeros(size(x));
    n = numel(x);
    for ii = 1:n
        if x(ii) >= thresholds(end)
            d(ii) = numel(thresholds) + 1;
        else
            d(ii) = find(x(ii) < thresholds, 1);
        end
    end
