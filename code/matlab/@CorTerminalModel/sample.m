function [outInits, outSamples] = sample(obj,nSamples, varargin)
% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
%
% Samples the terminal encounter geometry model
%
% SEE ALSO: CorTerminalModel CorTerminalModel/track bn_sample 

%% Input handling
p = inputParser;
addRequired(p,'nSamples',@isnumeric);
addParameter(p,'seed',nan,@isnumeric);

% Parse
parse(p,nSamples, varargin{:});
seed = p.Results.seed;

%% Set random seed
if ~isnan(seed) && ~isempty(seed)
    oldSeed = rng;
    rng(seed,'twister');
end

%% Preallocate
outInits = zeros(nSamples,obj.n_initial);
outSamples = cell(nSamples,1);

%% Iterate over the number of samples
for ii=1:1:nSamples
    
    isGood = false;
    while ~isGood
        % Sample model
        initial = bn_sample(obj.G_initial, obj.r_initial, obj.N_initial, obj.dirichlet_initial, 1, obj.start, obj.order_initial);
        
        % Dediscretize
        for kk = 1:numel(initial)
            if isempty(obj.boundaries{kk})
            else
                initial(kk) = dediscretize(initial(kk), obj.boundaries{kk}, obj.zero_bins{kk});
            end
        end
        
        % Check initial bounds
        if ~isempty(obj.bounds_sample)
            if all(initial'>=obj.bounds_sample(:,1) & initial'<=obj.bounds_sample(:,2))
                isGood = true;
            else
                isGood = false;
            end
        else
            isGood = true;
        end
        
        % Parse sample and check sampled speed
        % Only do this if initial bounds are satisifed
        if isGood
            for kk=1:length(obj.labels_initial)
                fieldName = strrep(obj.labels_initial{kk},'"','');
                sample.(fieldName) = initial(kk);
            end
            
            % Check if encounter sample satisfies speed constraints
            isSpeed1 = sample.own_speed <= obj.dynLimits1.maxVel_ft_s && sample.own_speed >= obj.dynLimits1.minVel_ft_s;
            isSpeed2 = sample.int_speed <= obj.dynLimits2.maxVel_ft_s && sample.int_speed >= obj.dynLimits2.minVel_ft_s;
            if isSpeed1 && isSpeed2
                isGood = true;
            else
                isGood = false;
            end
        end
    end
    
    % Assign to output
    outInits(ii,:) = initial;
    outSamples{ii} = sample;
end

%% Change back to original seed
if ~isnan(seed) && ~isempty(seed)
    rng(oldSeed);
end
