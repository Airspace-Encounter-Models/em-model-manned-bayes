function order = bn_sort(G)
% BN_SORT Produces a topological sort of a Bayesian network.
%   Returns an array specifying the indices of variables in topological
%   order according to a graphical structure.
%
%   ORDER = BN_SORT(G) topologically sorts the variables in the specified
%   graph G and returns an array ORDER that contains the indices of the
%   variables in order. The matrix G is a square adjacency matrix.
%
% This code is based on the topological sort routine by Kevin Murphy. The
% source code was available from http://bnt.sourceforge.net/ but as of June
% 2014 was maintained on GitHub at https://github.com/bayesnet/bnt

% INPUT:
% G - a square adjacency matrix
%
% OUTPUT:
% order - an array of indices indicating order

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
