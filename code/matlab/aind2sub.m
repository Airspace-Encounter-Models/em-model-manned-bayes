function x = aind2sub(siz,ndx)
% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
% AIN2SUB Multiple subscripts from single linear index
%   Returns multiple subscripts from a single linear index assuming a matrix of a
%   specified size.
%
% SEE ALSO asub2ind

siz = siz(:);
x = zeros(size(siz));
n = length(siz);
k = [1; cumprod(siz(1:end-1))];
for i = n:-1:1,
  vi = rem(ndx-1, k(i)) + 1;         
  x(i) = (ndx - vi)/k(i) + 1; 
  ndx = vi;     
end
