function alpha = setTransitionPriors(G, r, temporal_map, prior)
%SETTRANSITIONPRIORS  Sets prior probability for each transition variable
%at it's previous value to the specified value (i.e., non-transitioning). 

assert(numel(prior) == 1);

alpha = cell(length(G), 1);

dynamic_variables = temporal_map(:,2);
order = bn_sort(G);

for ii=order
  
  if any(dynamic_variables == ii)
    parents = G(:,ii);
    if any(parents)
      
      n = prod(r(parents));
      
      % index of the parent variable at t (within full set)
      jj = temporal_map(dynamic_variables == ii,1);
      alpha{ii} = zeros(r(jj), n);
      
      n = n/r(jj);
      for kk = 1:r(jj)
        alpha{ii}(kk, n*(kk-1)+1:n*kk) = prior;
      end
      
    end
  
  end
  
end
