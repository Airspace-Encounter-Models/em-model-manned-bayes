% Copyright 2008 - 2020, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
function [order,err] = bn_sort(G)
% BN_SORT Produces a topological sort of a Bayesian network.
%   Returns an array specifying the indices of variables in topological
%   order according to a graphical structure.
%
%   ORDER = BN_SORT(G)
%   [ORDER,ERR] = BN_SORT(G)
%
%   topologically sorts the variables in the specified graph G and returns
%   an array ORDER that contains the indices of the variables in order.
%   Optionally returns the error flag ERROR if thegraph could not be
%   sorted.  The matrix G is a square adjacency matrix.
%
% INPUT:
% G - a square adjacency matrix
%
% OUTPUT:
% order - an array of indices indicating order
% err - error flag

n = length(G);
indeg = zeros(1,n);
zero_indeg = []; % a stack of nodes with no parents
for i=1:n
  indeg(i) = sum(G(:,i));
  if indeg(i)==0
    zero_indeg = [i zero_indeg];
  end
end

t=1;
order = zeros(1,n);
while ~isempty(zero_indeg)
  v = zero_indeg(1); % pop v
  zero_indeg = zero_indeg(2:end);
  order(t) = v;
  t = t + 1;
  cs = find(G(v,:));
  for j=1:length(cs)
    c = cs(j);
    indeg(c) = indeg(c) - 1;
    if indeg(c) == 0
      zero_indeg = [c zero_indeg]; % push c 
    end
  end
end

% report error if 'order' array not complete
if nargout > 1
  err = (t <= n);
end
