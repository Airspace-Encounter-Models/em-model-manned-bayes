function ndx = asub2ind(siz,x)
% ASUB2IND Linear index from multiple subscripts.
%   Returns a linder index from multiple subscripts assuming a matrix of a
%   specified size.
%
%   NDX = ASUB2IND(SIZ,X) returns the linear index NDX of the element in a
%   matrix of dimension SIZ associated with subscripts specified in X.

k = [1 cumprod(siz(1:end-1))'];
ndx = k(:)'*(x(:)-1) + 1;
