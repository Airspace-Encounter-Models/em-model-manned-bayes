function parms = em_read(parameters_filename,varargin)
% Copyright 2008 - 2020, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
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

%% Inputs
% Create inputParser
p = inputParser;

% Required
addRequired(p,'parameters_filename'); % text specifying the name of the parameters file

% Optional - Boundaries
% `RUN_1_emsample.m` and `RUN_2_sample2track` assume that when the altitude layer is sampled, 
% an actual numeric value is returned (e.g. 650) instead of the sampled index (e.g. 2). 
% This is different than `em-pairing-uncor-importancesampling` which expects 
% the altitude sample to return an index instead of an altitude value. 
% This behavior is controlled by the boundaries parameter. 
% If in the parameter file, it is listed as `*`, it will return just the index (e.g. 2). 
% If there are values, such as `50 500 1200 3000 5000,` it will return a value (e.g. 650).
addOptional(p,'isOverwriteZeroBoundaries',false,@islogical); % If true, use idxZeroBoundaries to force the return of a bin index for variables = idxZeroBoundaries
addOptional(p,'idxZeroBoundaries',[1 2 3], @isnumeric); % Index of parameters.boundaries that will return a bin index (e.g. 1) when sampled instead of a numeric value (e.g. 50) (The default of [1 2 3] is for most uncor, 1=G,2=A,3=L)

% Parse
parse(p,parameters_filename,varargin{:});

%% Read file
f = fopen(parameters_filename,'r');
validate_label(f, '# labels_initial');
parms.labels_initial = scanline(f, '%s', ',');
parms.n_initial = numel(parms.labels_initial);
validate_label(f, '# G_initial');
parms.G_initial = logical(scanmatrix(f, parms.n_initial));
validate_label(f, '# r_initial');
parms.r_initial = scanmatrix(f);
validate_label(f, '# N_initial');
dims_initial = getdims(parms.G_initial, parms.r_initial, 1:parms.n_initial);
parms.N_initial = array2cells(scanmatrix(f), dims_initial);
validate_label(f, '# labels_transition');
parms.labels_transition = scanline(f, '%s', ',');
parms.n_transition = numel(parms.labels_transition);
validate_label(f, '# G_transition');
parms.G_transition = logical(scanmatrix(f, parms.n_transition));
validate_label(f, '# r_transition');
parms.r_transition = scanmatrix(f);
validate_label(f, '# N_transition');
dims_transition = getdims(parms.G_transition, parms.r_transition, (parms.n_initial+1):parms.n_transition);
parms.N_transition = array2cells(scanmatrix(f), dims_transition);
validate_label(f, '# boundaries');
parms.boundaries = cell(1,parms.n_initial);
for i=1:parms.n_initial
    parms.boundaries{i} = scanmatrix(f);
end
validate_label(f, '# resample_rates');
parms.resample_rates = scanmatrix(f);
fclose(f);

%% Extract map and zero bins
parms.temporal_map = extract_temporal_map(parms.labels_transition);
parms.zero_bins = extract_zero_bins(parms.boundaries);

%% Overwrite
% boundaries
if p.Results.isOverwriteZeroBoundaries
    parms.boundaries(p.Results.idxZeroBoundaries) = repmat({double.empty(0,1)},size(p.Results.idxZeroBoundaries));
end

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
