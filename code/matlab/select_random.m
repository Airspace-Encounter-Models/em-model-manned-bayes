% Copyright 2008 - 2020, MIT Lincoln Laboratory
% SPDX-License-Identifier: GPL-2.0-only
function index = select_random(weights)
% SELECT_RANDOM Randomly selects an index according to specified weights.
%   Returns a randomly selected index according to the distribution
%   specified by a vector of weights.
%
%   INDEX = SELECT_RANDOM(WEIGHTS) returns a scalar index INDEX selected 
%   randomly according to the specified weights WEIGHTS represented as an
%   array.
s = cumsum(weights);
index = find(s >= s(end)*rand, 1);
