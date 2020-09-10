function order = bn_sort(G)
% Copyright 2008 - 2020, MIT Lincoln Laboratory
% SPDX-License-Identifier: GPL-2.0-only
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
    if isobject(G)
        % Assumes is a digraph
        [order,~] = toposort(G,'Order','stable');
    else
        % Convert to digraph
        [order,~] = toposort(digraph(G),'Order','stable');
    end
catch err
      error('Network could not be hierarchically sorted');
end
