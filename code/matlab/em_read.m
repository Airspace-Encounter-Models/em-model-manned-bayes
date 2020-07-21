% Copyright 2008 - 2020, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
function parameters = em_read(filename)
% EM_READ  Reads an encounter model parameters file.
% Reads an encounter model parameters file and returns a structure
% containing the parsed data.
%
%   EM_READ(FILENAME) reads the parameters contained in the specified file
%   and returns the parameters in a structure. Included in this structure
%   are the following fields:
%        labels_initial
%             n_initial
%             G_initial
%             r_initial
%             N_initial
%     labels_transition
%          n_transition
%          G_transition
%          r_transition
%          N_transition
%            boundaries
%        resample_rates
%          temporal_map
%             zero_bins

%% Read file
f = fopen(filename,'r');
validate_label(f, '# labels_initial');
p.labels_initial = scanline(f, '%s', ',');
p.n_initial = numel(p.labels_initial);
validate_label(f, '# G_initial');
p.G_initial = logical(scanmatrix(f, p.n_initial));
validate_label(f, '# r_initial');
p.r_initial = scanmatrix(f);
validate_label(f, '# N_initial');
dims_initial = getdims(p.G_initial, p.r_initial, 1:p.n_initial);
p.N_initial = array2cells(scanmatrix(f), dims_initial);
validate_label(f, '# labels_transition');
p.labels_transition = scanline(f, '%s', ',');
p.n_transition = numel(p.labels_transition);
validate_label(f, '# G_transition');
p.G_transition = logical(scanmatrix(f, p.n_transition));
validate_label(f, '# r_transition');
p.r_transition = scanmatrix(f);
validate_label(f, '# N_transition');
dims_transition = getdims(p.G_transition, p.r_transition, (p.n_initial+1):p.n_transition);
p.N_transition = array2cells(scanmatrix(f), dims_transition);
validate_label(f, '# boundaries');
p.boundaries = cell(1,p.n_initial);
for i=1:p.n_initial
    p.boundaries{i} = scanmatrix(f);
end
validate_label(f, '# resample_rates');
p.resample_rates = scanmatrix(f);
fclose(f);

%% Extract map and zero bins
p.temporal_map = extract_temporal_map(p.labels_transition);
p.zero_bins = extract_zero_bins(p.boundaries);
parameters = p;

function zero_bins = extract_zero_bins(boundaries)
zero_bins = cell(1, numel(boundaries));
for i = 1:numel(boundaries)
    b = boundaries{i};
    z = [];
    if numel(b) > 2
        for j = 2:numel(b)
            if b(j - 1) < 0 && b(j) > 0
                z = j - 1;
            end
        end
    end
    zero_bins{i} = z;    
end

function temporal_map = extract_temporal_map(labels_transition)
% Does not assume that order of variables at t match that at
% t+1 (order assumption not true for ECEM, but true for previous models)
temporal_map = [];
for i = 1:numel(labels_transition)
    t = findstr(labels_transition{i}, '(t)');
    if ~isempty(t)
        temporal_map = [temporal_map;i,find(contains(labels_transition,[labels_transition{i}(1:t),'t+1)']))]; 
    end
end
    
function x = scanline(fid, typename, delimiter)
a = textscan(fgetl(fid), typename, 'Delimiter', delimiter);
x = a{1};

function x = scanmatrix(fid, num_rows)
if nargin < 2
    x = scanline(fid, '%f', ' ');
else
    x = zeros(num_rows);    
    for i = 1:num_rows
        x(i,:) = scanline(fid, '%f', ' ');
    end
end

function c = array2cells(x, dims)
c = cell(size(dims, 1), 1);
index = 1;
for i = 1:numel(c)
    c{i} = zeros(dims(i,1), dims(i,2));
    c{i}(:) = x(index:(index-1+numel(c{i})));
    index = index + numel(c{i});
end

function dims = getdims(G, r, vars)
n = size(G,1);
dims = zeros(n, 2);
for i = vars
   q = prod(r(G(:,i))); % q_i
   dims(i,:) = [r(i) q];
end

function validate_label(fid, s)
t = fgetl(fid);
if ~strcmp(t, s)
    error('Invalid parameters file');
end
