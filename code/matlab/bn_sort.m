function order = bn_sort(g)
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    % BN_SORT Produces a topological order of directed acyclic graph, such as a
    % Bayesian network. This function was updated in 2020 to use the MATLAB
    % built-in toposort function instead of the 3rd party
    % /bayesnet/bnt/graph/topological_sort.m
    %
    % INPUT:
    % G - a square adjacency matrix
    %
    % See also toposort, digraph

    try
        if isobject(g)
            % Assumes is a digraph
            [order, ~] = toposort(g, 'Order', 'stable');
        else
            % Convert to digraph
            [order, ~] = toposort(digraph(g), 'Order', 'stable');
        end
    catch err
        error('Network could not be hierarchically sorted');
    end
