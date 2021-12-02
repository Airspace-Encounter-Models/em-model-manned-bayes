function [outInits, outSamples] = sample(self, nSamples, varargin)
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    %
    % Samples the terminal encounter geometry model
    %
    % SEE ALSO: CorTerminalModel CorTerminalModel/track bn_sample

    %% Input handling
    p = inputParser;
    addRequired(p, 'nSamples', @isnumeric);
    addParameter(p, 'seed', nan, @isnumeric);

    % Parse
    parse(p, nSamples, varargin{:});
    seed = p.Results.seed;

    %% Set random seed
    if ~isnan(seed) && ~isempty(seed)
        oldSeed = rng;
        rng(seed, 'twister');
    end

    %% Preallocate
    outInits = zeros(nSamples, self.n_initial);
    outSamples = cell(nSamples, 1);

    %% Iterate over the number of samples
    for ii = 1:1:nSamples

        isGood = false;
        while ~isGood
            % Sample model
            initial = bn_sample(self.G_initial, self.r_initial, self.N_initial, self.dirichlet_initial, 1, self.start, self.order_initial);

            % Dediscretize
            for kk = 1:numel(initial)
                if isempty(self.boundaries{kk})
                else
                    initial(kk) = dediscretize(initial(kk), self.boundaries{kk}, self.zero_bins{kk});
                end
            end

            % Check initial bounds
            if ~isempty(self.bounds_sample)
                if all(initial' >= self.bounds_sample(:, 1) & initial' <= self.bounds_sample(:, 2))
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
                for kk = 1:length(self.labels_initial)
                    fieldName = strrep(self.labels_initial{kk}, '"', '');
                    sample.(fieldName) = initial(kk);
                end

                % Check if encounter sample satisfies speed constraints
                isSpeed1 = sample.own_speed <= self.dynLimits1.maxVel_ft_s && sample.own_speed >= self.dynLimits1.minVel_ft_s;
                isSpeed2 = sample.int_speed <= self.dynLimits2.maxVel_ft_s && sample.int_speed >= self.dynLimits2.minVel_ft_s;
                if isSpeed1 && isSpeed2
                    isGood = true;
                else
                    isGood = false;
                end
            end
        end

        % Assign to output
        outInits(ii, :) = initial;
        outSamples{ii} = sample;
    end

    %% Change back to original seed
    if ~isnan(seed) && ~isempty(seed)
        rng(oldSeed);
    end
